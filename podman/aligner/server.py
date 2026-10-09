"""POST /align: audio + transcript -> per-word start/end times (Qwen3-ForcedAligner-0.6B-hf)."""

import os
import subprocess
import threading

import numpy as np
import torch
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from transformers import AutoModelForTokenClassification, AutoProcessor

MODEL = os.environ.get("MODEL", "Qwen/Qwen3-ForcedAligner-0.6B-hf")
SAMPLE_RATE = 16000
# The model card supports up to 5 minutes of speech per request
MAX_SECONDS = float(os.environ.get("MAX_SECONDS", "300"))

processor = AutoProcessor.from_pretrained(MODEL)
model = AutoModelForTokenClassification.from_pretrained(MODEL, dtype=torch.bfloat16).to("cuda").eval()
# One forward pass at a time on the GPU; requests are handled in FastAPI's thread pool
gpu_lock = threading.Lock()

app = FastAPI(title="Qwen3 forced aligner")


def decode_audio(data: bytes) -> np.ndarray:
    """Decode any format ffmpeg understands to 16 kHz mono float32."""
    result = subprocess.run(
        ["ffmpeg", "-nostdin", "-loglevel", "error", "-i", "pipe:0",
         "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "pipe:1"],
        input=data, capture_output=True, check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise HTTPException(400, f"could not decode audio: {result.stderr.decode(errors='replace').strip()}")
    return np.frombuffer(result.stdout, dtype=np.float32)


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL}


@app.post("/align")
def align(
    file: UploadFile = File(...),
    transcript: str = Form(...),
    language: str | None = Form(None),
):
    """language: a name ("English") or code ("en"); one of the 11 the aligner supports."""
    if not transcript.strip():
        raise HTTPException(400, "transcript is empty")
    audio = decode_audio(file.file.read())
    duration = len(audio) / SAMPLE_RATE
    if duration > MAX_SECONDS:
        raise HTTPException(413, f"audio is {duration:.1f}s; the limit is {MAX_SECONDS:.0f}s")

    try:
        inputs, word_lists = processor.prepare_forced_aligner_inputs(
            audio=audio, transcript=transcript, language=language
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    if not word_lists[0]:
        raise HTTPException(400, "transcript has no alignable words")

    with gpu_lock, torch.inference_mode():
        inputs = inputs.to("cuda", dtype=torch.bfloat16)
        logits = model(**inputs).logits
        words = processor.decode_forced_alignment(
            logits=logits,
            input_ids=inputs["input_ids"],
            word_lists=word_lists,
            timestamp_token_id=model.config.timestamp_token_id,
        )[0]

    return {
        "duration": round(duration, 3),
        "words": [{"word": w["text"], "start": w["start_time"], "end": w["end_time"]} for w in words],
    }
