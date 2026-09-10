# Harness smoke test — 2026-09-10

Evidence the agent harness is actively working, run live in this repo on
`tensorrt-llm-qwen-38`. Author is the model itself (Qwen3.8-27B-NVFP4 served
via TensorRT-LLM), so this file's existence + its commit prove the full
loop: inference → tool call → repo write → git commit.

| Check | Result |
|---|---|
| Bash / git | `git status` + `git log` clean, 0.11 s |
| Read (repo tree, `.gitignore`) | OK |
| Write | this file |
| zvec-grep MCP (`mcp__zvec_grep_search`) | 10 hybrid (fts+vector) hits, `served_from_current_index`, background refresh running |

Freshness was `possibly_stale` at query time — expected, the background
refresh was mid-run; results were still sufficient.