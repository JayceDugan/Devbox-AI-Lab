"""Apply vLLM PR #60631 to the installed vLLM (build-time only).

TODO(remove): https://github.com/vllm-project/vllm/pull/60631 — Triton prefill attention
uses 128-row tiles, which for embeddinggemma-2's 256-wide heads need 160 KB of shared
memory per block. RTX 50xx (sm_120) has ~99 KB, so the engine fails to start with
`OutOfResources: Required: 163840, Hardware limit: 101376`. Once a vLLM image ships
the fix, this script reports it and does nothing; then delete it and the Containerfile
step (see podman/ai-5080/README.md).
"""

import pathlib
import sys

import vllm

path = pathlib.Path(vllm.__file__).parent / "v1/attention/ops/triton_prefill_attention.py"
src = path.read_text()

if "get_max_shared_memory_bytes" in src.split("def context_attention_fwd", 1)[-1]:
    print(f"vLLM {vllm.__version__} already contains the PR #60631 fix: remove this patch step")
    sys.exit(0)

IMPORT_ANCHOR = "from vllm.utils.math_utils import RCP_LN2\n"
IMPORT = "from vllm.utils.mem_utils import get_max_shared_memory_bytes\n"
BLOCK_ANCHOR = """    if Lk >= 512:
        BLOCK = min(BLOCK, 32)
"""
BLOCK_FIX = """    elif (
        Lk >= 256
        and current_platform.is_cuda()
        and get_max_shared_memory_bytes() < 160 * 1024
    ):
        # 128-row tiles of 256-wide heads need 160KB of shared memory;
        # 64-row ones need 72KB.
        BLOCK = min(BLOCK, 64)
"""

for anchor in (IMPORT_ANCHOR, BLOCK_ANCHOR):
    if src.count(anchor) != 1:
        sys.exit(f"vLLM {vllm.__version__}: patch anchor not found exactly once in {path}:\n{anchor}")

src = src.replace(IMPORT_ANCHOR, IMPORT_ANCHOR + IMPORT)
src = src.replace(BLOCK_ANCHOR, BLOCK_ANCHOR + BLOCK_FIX)
path.write_text(src)
print(f"Patched vLLM {vllm.__version__} with PR #60631")
