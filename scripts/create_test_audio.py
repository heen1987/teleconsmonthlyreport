#!/usr/bin/env python3
"""
AI-PMS 테스트용 1분 WAV 파일 생성 스크립트.

사용법:
    python3 scripts/create_test_audio.py
    python3 scripts/create_test_audio.py --output /path/to/output.wav
"""
import argparse
import math
import os
import struct
import wave

SAMPLE_RATE = 16_000   # Whisper 권장 샘플레이트
DURATION    = 60       # 초
CHANNELS    = 1        # 모노
SAMPWIDTH   = 2        # 16-bit
AMPLITUDE   = 12_000


def gen_samples(duration: int, sample_rate: int) -> bytes:
    """
    처음 2초: 440 Hz 톤 (회의 시작 신호처럼 들림)
    이후: 무음 (실제 회의 녹음 대체)
    """
    buf = bytearray()
    total = duration * sample_rate
    for i in range(total):
        t = i / sample_rate
        if t < 2.0:
            val = int(AMPLITUDE * math.sin(2 * math.pi * 440 * t))
        else:
            val = 0
        buf += struct.pack("<h", val)
    return bytes(buf)


def main() -> None:
    parser = argparse.ArgumentParser(description="테스트용 1분 WAV 생성")
    parser.add_argument(
        "--output",
        default=os.path.join(os.path.dirname(__file__), "test_meeting_audio.wav"),
        help="출력 경로 (기본: scripts/test_meeting_audio.wav)",
    )
    parser.add_argument("--duration", type=int, default=DURATION, help="녹음 길이(초)")
    args = parser.parse_args()

    print(f"WAV 생성 중: {args.output}  ({args.duration}초, {SAMPLE_RATE}Hz, mono, 16-bit)")
    samples = gen_samples(args.duration, SAMPLE_RATE)

    with wave.open(args.output, "wb") as w:
        w.setnchannels(CHANNELS)
        w.setsampwidth(SAMPWIDTH)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(samples)

    size_kb = os.path.getsize(args.output) / 1024
    print(f"완료: {args.output}  ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
