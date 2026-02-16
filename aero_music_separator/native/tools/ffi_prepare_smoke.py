#!/usr/bin/env python3
import argparse
import ctypes
import json
import math
import os
import shutil
import struct
import subprocess
import tempfile
import time
import wave
from pathlib import Path

AMS_OK = 0
AMS_ERR_CANCELLED = 5

AMS_JOB_SUCCEEDED = 2
AMS_JOB_FAILED = 3
AMS_JOB_CANCELLED = 4


class AmsPrepareConfig(ctypes.Structure):
    _fields_ = [
        ("input_path", ctypes.c_char_p),
        ("work_dir", ctypes.c_char_p),
        ("output_prefix", ctypes.c_char_p),
    ]


class AmsRunConfig(ctypes.Structure):
    _fields_ = [
        ("input_path", ctypes.c_char_p),
        ("prepared_input_path", ctypes.c_char_p),
        ("output_dir", ctypes.c_char_p),
        ("output_prefix", ctypes.c_char_p),
        ("output_format", ctypes.c_int32),
        ("chunk_size", ctypes.c_int32),
        ("overlap", ctypes.c_int32),
    ]


def make_test_audio(path: Path) -> None:
    sample_rate = 48000
    duration_sec = 1.5
    freq = 440.0
    total_samples = int(sample_rate * duration_sec)

    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        for i in range(total_samples):
            phase = 2.0 * math.pi * freq * (i / sample_rate)
            value = int(max(-1.0, min(1.0, math.sin(phase) * 0.5)) * 32767)
            wf.writeframesraw(struct.pack("<h", value))
        wf.writeframes(b"")


def configure_ffi(lib: ctypes.CDLL) -> None:
    lib.ams_last_error.restype = ctypes.c_char_p

    lib.ams_engine_open.argtypes = [
        ctypes.c_char_p,
        ctypes.c_int32,
        ctypes.POINTER(ctypes.c_uint64),
    ]
    lib.ams_engine_open.restype = ctypes.c_int32

    lib.ams_engine_close.argtypes = [ctypes.c_uint64]
    lib.ams_engine_close.restype = ctypes.c_int32

    lib.ams_prepare_start.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(AmsPrepareConfig),
        ctypes.POINTER(ctypes.c_uint64),
    ]
    lib.ams_prepare_start.restype = ctypes.c_int32

    lib.ams_prepare_poll.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int32),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_int32),
    ]
    lib.ams_prepare_poll.restype = ctypes.c_int32

    lib.ams_prepare_get_result_json.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_void_p),
    ]
    lib.ams_prepare_get_result_json.restype = ctypes.c_int32

    lib.ams_prepare_destroy.argtypes = [ctypes.c_uint64]
    lib.ams_prepare_destroy.restype = ctypes.c_int32

    lib.ams_job_start.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(AmsRunConfig),
        ctypes.POINTER(ctypes.c_uint64),
    ]
    lib.ams_job_start.restype = ctypes.c_int32

    lib.ams_job_poll.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int32),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_int32),
    ]
    lib.ams_job_poll.restype = ctypes.c_int32

    lib.ams_job_get_result_json.argtypes = [
        ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_void_p),
    ]
    lib.ams_job_get_result_json.restype = ctypes.c_int32

    lib.ams_job_destroy.argtypes = [ctypes.c_uint64]
    lib.ams_job_destroy.restype = ctypes.c_int32

    lib.ams_string_free.argtypes = [ctypes.c_char_p]
    lib.ams_string_free.restype = None


def last_error(lib: ctypes.CDLL) -> str:
    raw = lib.ams_last_error()
    return raw.decode("utf-8", errors="replace") if raw else "unknown native error"


def ensure_ok(lib: ctypes.CDLL, code: int, where: str) -> None:
    if code == AMS_OK:
        return
    raise RuntimeError(f"{where} failed: code={code}, error={last_error(lib)}")


def read_json_string(lib: ctypes.CDLL, ptr_value: int) -> dict:
    raw = ctypes.string_at(ptr_value).decode("utf-8")
    lib.ams_string_free(ctypes.c_char_p(ptr_value))
    return json.loads(raw)


def poll_until_done(lib: ctypes.CDLL, poll_fn, handle: int, label: str) -> int:
    out_state = ctypes.c_int32()
    out_progress = ctypes.c_double()
    out_stage = ctypes.c_int32()

    timeout_sec = 180.0
    start = time.time()
    while True:
        ensure_ok(lib, poll_fn(handle, ctypes.byref(out_state), ctypes.byref(out_progress), ctypes.byref(out_stage)), f"{label} poll")
        state = out_state.value
        if state in (AMS_JOB_SUCCEEDED, AMS_JOB_FAILED, AMS_JOB_CANCELLED):
            return state
        if time.time() - start > timeout_sec:
            raise TimeoutError(f"{label} timed out")
        time.sleep(0.1)


def run_prepare_smoke(lib: ctypes.CDLL, temp_root: Path, input_audio: Path, output_prefix: str) -> dict:
    prepare_handle = ctypes.c_uint64(0)
    config = AmsPrepareConfig(
        input_path=str(input_audio).encode("utf-8"),
        work_dir=str(temp_root / f"prepare_{output_prefix}").encode("utf-8"),
        output_prefix=output_prefix.encode("utf-8"),
    )

    ensure_ok(
        lib,
        lib.ams_prepare_start(0, ctypes.byref(config), ctypes.byref(prepare_handle)),
        "prepare start",
    )

    try:
        state = poll_until_done(lib, lib.ams_prepare_poll, prepare_handle.value, "prepare")
        if state != AMS_JOB_SUCCEEDED:
            raise RuntimeError(f"prepare state is not succeeded: {state}")

        out_json = ctypes.c_void_p()
        ensure_ok(
            lib,
            lib.ams_prepare_get_result_json(prepare_handle.value, ctypes.byref(out_json)),
            "prepare result",
        )
        result = read_json_string(lib, out_json.value)
    finally:
        ensure_ok(lib, lib.ams_prepare_destroy(prepare_handle.value), "prepare destroy")

    canonical = Path(result["canonical_input_file"])
    if not canonical.exists():
        raise FileNotFoundError(f"canonical file not found: {canonical}")
    if result.get("sample_rate") != 44100 or result.get("channels") != 2:
        raise RuntimeError(f"unexpected canonical format metadata: {result}")
    return result


def transcode_with_ffmpeg(ffmpeg_cli: str, input_path: Path, output_path: Path, codec: str) -> None:
    cmd = [
        ffmpeg_cli,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(input_path),
        "-vn",
        "-ac",
        "2",
        "-ar",
        "48000",
        "-c:a",
        codec,
        str(output_path),
    ]
    subprocess.run(cmd, check=True)


def ffmpeg_encoder_available(ffmpeg_cli: str, encoder: str) -> bool:
    result = subprocess.run(
        [ffmpeg_cli, "-hide_banner", "-loglevel", "error", "-encoders"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return False
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1] == encoder:
            return True
    return False


def pick_ffmpeg_encoder(ffmpeg_cli: str, candidates: tuple[str, ...]) -> str:
    for codec in candidates:
        if ffmpeg_encoder_available(ffmpeg_cli, codec):
            return codec
    return ""


def run_ogg_opus_prepare_smoke(lib: ctypes.CDLL, temp_root: Path, source_wav: Path) -> None:
    ffmpeg_cli = shutil.which("ffmpeg")
    if ffmpeg_cli is None:
        print("[smoke] ffmpeg CLI not found, skip OGG/OPUS decode smoke")
        return

    codec_plan = (
        ("OGG", "input.ogg", "smoke_ogg", ("libvorbis", "vorbis")),
        ("OPUS", "input.opus", "smoke_opus", ("libopus", "opus")),
    )

    for label, out_name, output_prefix, codec_candidates in codec_plan:
        codec = pick_ffmpeg_encoder(ffmpeg_cli, codec_candidates)
        if not codec:
            print(f"[smoke] {label} encoder unavailable ({', '.join(codec_candidates)}), skip")
            continue

        output_path = temp_root / out_name
        try:
            transcode_with_ffmpeg(ffmpeg_cli, source_wav, output_path, codec)
        except subprocess.CalledProcessError as exc:
            print(f"[smoke] {label} transcode failed with {codec}, skip: {exc}")
            continue

        result = run_prepare_smoke(lib, temp_root, output_path, output_prefix)
        print(f"[smoke] {label} decode prepare ok ({codec}): {result['canonical_input_file']}")


def run_wav_variant_prepare_smoke(lib: ctypes.CDLL, temp_root: Path, source_wav: Path) -> None:
    ffmpeg_cli = shutil.which("ffmpeg")
    if ffmpeg_cli is None:
        print("[smoke] ffmpeg CLI not found, skip WAV variant decode smoke")
        return

    wav_codecs = (
        "pcm_u8",
        "pcm_s24le",
        "pcm_s32le",
        "pcm_f64le",
        "pcm_alaw",
        "pcm_mulaw",
        "adpcm_ima_wav",
        "adpcm_ms",
    )

    for codec in wav_codecs:
        variant_input = temp_root / f"input_{codec}.wav"
        transcode_with_ffmpeg(ffmpeg_cli, source_wav, variant_input, codec)
        result = run_prepare_smoke(lib, temp_root, variant_input, f"smoke_{codec}")
        print(f"[smoke] WAV variant decode prepare ok ({codec}): {result['canonical_input_file']}")


def run_optional_job_smoke(lib: ctypes.CDLL, model_path: Path, source_input: Path, prepare_result: dict, temp_root: Path) -> None:
    engine = ctypes.c_uint64(0)
    ensure_ok(
        lib,
        lib.ams_engine_open(str(model_path).encode("utf-8"), 0, ctypes.byref(engine)),
        "engine open",
    )

    job_handle = ctypes.c_uint64(0)
    try:
        output_dir = temp_root / "job_output"
        output_dir.mkdir(parents=True, exist_ok=True)

        run_config = AmsRunConfig(
            input_path=str(source_input).encode("utf-8"),
            prepared_input_path=str(prepare_result["canonical_input_file"]).encode("utf-8"),
            output_dir=str(output_dir).encode("utf-8"),
            output_prefix=b"smoke",
            output_format=0,
            chunk_size=-1,
            overlap=-1,
        )

        ensure_ok(
            lib,
            lib.ams_job_start(engine.value, ctypes.byref(run_config), ctypes.byref(job_handle)),
            "job start",
        )

        state = poll_until_done(lib, lib.ams_job_poll, job_handle.value, "job")
        if state != AMS_JOB_SUCCEEDED:
            raise RuntimeError(f"job state is not succeeded: {state}")

        out_json = ctypes.c_void_p()
        ensure_ok(
            lib,
            lib.ams_job_get_result_json(job_handle.value, ctypes.byref(out_json)),
            "job result",
        )
        result = read_json_string(lib, out_json.value)

        canonical = str(prepare_result["canonical_input_file"])
        model_input = result.get("model_input_file")
        canonical_input = result.get("canonical_input_file")
        if model_input != canonical or canonical_input != canonical:
            raise RuntimeError(
                "job result consistency check failed: "
                f"model_input_file={model_input}, canonical_input_file={canonical_input}, canonical={canonical}"
            )
    finally:
        if job_handle.value != 0:
            ensure_ok(lib, lib.ams_job_destroy(job_handle.value), "job destroy")
        if engine.value != 0:
            ensure_ok(lib, lib.ams_engine_close(engine.value), "engine close")


def parse_env_dll_dirs() -> list[str]:
    raw = os.environ.get("AMS_DLL_DIRS", "").strip()
    if not raw:
        return []
    return [entry for entry in raw.split(os.pathsep) if entry]


def setup_windows_dll_dirs(lib_path: Path, extra_dirs: list[str]) -> list[object]:
    if os.name != "nt":
        return []

    handles = []
    seen = set()
    candidates = [str(lib_path.parent), *parse_env_dll_dirs(), *extra_dirs]
    ffmpeg_bin = os.environ.get("AMS_FFMPEG_BIN_DIR", "").strip()
    if ffmpeg_bin:
        candidates.append(ffmpeg_bin)

    for raw_dir in candidates:
        if not raw_dir:
            continue
        dir_path = Path(raw_dir).resolve()
        dir_key = str(dir_path).lower()
        if dir_key in seen:
            continue
        seen.add(dir_key)
        if not dir_path.is_dir():
            continue
        try:
            handles.append(os.add_dll_directory(str(dir_path)))
            print(f"[smoke] Added Windows DLL search dir: {dir_path}")
        except OSError as exc:
            print(f"[smoke] Failed to add DLL search dir {dir_path}: {exc}")
    return handles


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke test for Aero separator FFI prepare/job flow")
    parser.add_argument("--library", required=True, help="Path to aero_separator_ffi dynamic library")
    parser.add_argument("--model", default="", help="Optional model path for full job smoke")
    parser.add_argument(
        "--verify-ogg-opus",
        action="store_true",
        help="Also verify OGG/Vorbis and OPUS decode by prepare task",
    )
    parser.add_argument(
        "--verify-wav-variants",
        action="store_true",
        help="Also verify common WAV codec variants decode by prepare task",
    )
    parser.add_argument(
        "--dll-dir",
        action="append",
        default=[],
        help="Additional DLL search directory on Windows (can be repeated)",
    )
    args = parser.parse_args()

    lib_path = Path(args.library)
    if not lib_path.exists():
        raise FileNotFoundError(f"library not found: {lib_path}")

    _dll_dir_handles = setup_windows_dll_dirs(lib_path, args.dll_dir)
    lib = ctypes.CDLL(str(lib_path))
    configure_ffi(lib)

    with tempfile.TemporaryDirectory(prefix="aero_smoke_") as tmp:
        temp_root = Path(tmp)
        source_input = temp_root / "input_48k_mono.wav"
        make_test_audio(source_input)

        prepare_result = run_prepare_smoke(lib, temp_root, source_input, "smoke_wav")
        print(f"[smoke] prepare ok: {prepare_result['canonical_input_file']}")
        if args.verify_ogg_opus:
            run_ogg_opus_prepare_smoke(lib, temp_root, source_input)
        if args.verify_wav_variants:
            run_wav_variant_prepare_smoke(lib, temp_root, source_input)

        model_path = Path(args.model) if args.model else None
        if model_path and model_path.exists():
            run_optional_job_smoke(lib, model_path, source_input, prepare_result, temp_root)
            print("[smoke] job with prepared_input_path ok")
        else:
            print("[smoke] model not provided, skipped job smoke")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
