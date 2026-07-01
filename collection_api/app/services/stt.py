from __future__ import annotations

import asyncio
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import unquote, urlparse

from app.core.config import settings


SUPPORTED_TEXT_SUFFIXES = {".txt", ".md", ".vtt", ".srt"}
WHISPER_NATIVE_AUDIO_SUFFIXES = {".wav"}
WINDOWS_DRIVE_PATH_RE = re.compile(r"^[A-Za-z]:[\\/]")
WINDOWS_FILE_URI_PATH_RE = re.compile(r"^/[A-Za-z]:")


def storage_uri_to_path(storage_uri: str) -> Path:
    if WINDOWS_DRIVE_PATH_RE.match(storage_uri):
        return Path(storage_uri)

    parsed = urlparse(storage_uri)
    if parsed.scheme == "file":
        path_text = unquote(parsed.path)
        if parsed.netloc:
            return Path(f"//{parsed.netloc}{path_text}")
        if WINDOWS_FILE_URI_PATH_RE.match(path_text):
            path_text = path_text[1:]
        return Path(path_text)
    if parsed.scheme:
        raise RuntimeError(f"Unsupported audio storage URI scheme: {parsed.scheme}")
    return Path(storage_uri)


def _default_model_path() -> Path:
    if settings.whisper_model_path:
        configured = Path(settings.whisper_model_path)
        if not configured.is_absolute():
            configured = Path(__file__).resolve().parents[3] / configured
        return configured
    return Path(__file__).resolve().parents[3] / "models" / "whisper" / "ggml-small.bin"


def _prepare_audio_for_whisper(audio_path: Path, temp_dir: str) -> Path:
    if audio_path.suffix.lower() in WHISPER_NATIVE_AUDIO_SUFFIXES:
        return audio_path

    ffmpeg_bin = Path(settings.ffmpeg_bin)
    if not ffmpeg_bin.exists():
        raise RuntimeError(f"ffmpeg not found: {ffmpeg_bin}")

    output_path = Path(temp_dir) / f"{audio_path.stem}-whisper.wav"
    command = [
        str(ffmpeg_bin),
        "-y",
        "-i",
        str(audio_path),
        "-ar",
        "16000",
        "-ac",
        "1",
        "-c:a",
        "pcm_s16le",
        str(output_path),
    ]
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        timeout=settings.whisper_timeout_seconds,
    )
    if completed.returncode != 0:
        message = (completed.stderr or completed.stdout).strip()
        raise RuntimeError(f"Audio conversion failed: {message[:500]}")
    if not output_path.exists() or output_path.stat().st_size == 0:
        raise RuntimeError("Audio conversion did not create a WAV file")
    return output_path


def _transcribe_with_whisper(audio_path: Path, language: str) -> str:
    if not audio_path.exists():
        raise RuntimeError(f"Audio file not found: {audio_path}")
    if audio_path.suffix.lower() in SUPPORTED_TEXT_SUFFIXES:
        return audio_path.read_text(encoding="utf-8").strip()

    whisper_bin = Path(settings.whisper_cpp_bin)
    model_path = _default_model_path()
    if not whisper_bin.exists():
        raise RuntimeError(f"whisper-cli not found: {whisper_bin}")
    if not model_path.exists():
        raise RuntimeError(f"Whisper model not found: {model_path}")

    with tempfile.TemporaryDirectory(prefix="ai-pms-stt-") as temp_dir:
        whisper_input = _prepare_audio_for_whisper(audio_path, temp_dir)
        output_base = Path(temp_dir) / audio_path.stem
        command = [
            str(whisper_bin),
            "-m",
            str(model_path),
            "-f",
            str(whisper_input),
            "-l",
            language,
            "-otxt",
            "-of",
            str(output_base),
            "-np",
        ]
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=settings.whisper_timeout_seconds,
        )
        if completed.returncode != 0:
            message = (completed.stderr or completed.stdout).strip()
            raise RuntimeError(f"Whisper transcription failed: {message[:500]}")
        transcript_path = output_base.with_suffix(".txt")
        if not transcript_path.exists():
            raise RuntimeError("Whisper transcription did not create a .txt output")
        transcript = transcript_path.read_text(encoding="utf-8").strip()
        if not transcript:
            raise RuntimeError("Whisper transcription returned empty text")
        return transcript


async def transcribe_audio_uri(storage_uri: str, language: str = "ko") -> str:
    audio_path = storage_uri_to_path(storage_uri)
    return await asyncio.to_thread(_transcribe_with_whisper, audio_path, language)
