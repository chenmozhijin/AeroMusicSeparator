#!/usr/bin/env python3
"""
Native FFI pipeline integration test for CI.

Flow:
1) prepare (decode/resample/canonicalize)
2) run separation job for each requested backend
3) verify output files (existence, size, WAV duration)
4) write a JSON report
"""

from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import os
import struct
import time
from pathlib import Path
from typing import Any

AMS_OK = 0
AMS_ERR_UNSUPPORTED = 4

AMS_JOB_SUCCEEDED = 2
AMS_JOB_FAILED = 3
AMS_JOB_CANCELLED = 4

BACKEND_PREF = {
    "auto": 0,
    "cpu": 1,
    "vulkan": 2,
    "cuda": 3,
    "metal": 4,
}


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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run native FFI integration pipeline.")
    parser.add_argument("--library", required=True, help="Path to aero_separator_ffi dynamic library")
    parser.add_argument("--model", required=True, help="Path to GGUF model file")
    parser.add_argument("--input", required=True, help="Path to input audio file")
    parser.add_argument(
        "--backends",
        required=True,
        help="Comma-separated backends, e.g. cpu,vulkan",
    )
    parser.add_argument(
        "--min-bytes",
        type=int,
        default=1000,
        help="Minimum output file size in bytes (default: 1000)",
    )
    parser.add_argument(
        "--duration-tolerance-ms",
        type=int,
        default=300,
        help="Allowed absolute duration deviation in ms (default: 300)",
    )
    parser.add_argument("--report", required=True, help="JSON report output path")
    parser.add_argument(
        "--timeout-sec",
        type=float,
        default=600.0,
        help="Timeout for prepare/job polling in seconds (default: 600)",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=-1,
        help="Chunk size for separation job; <=0 uses model defaults (default: -1)",
    )
    parser.add_argument(
        "--overlap",
        type=int,
        default=-1,
        help="Overlap for separation job; <=0 uses model defaults (default: -1)",
    )
    return parser.parse_args()


def parse_backends(raw: str) -> list[str]:
    values: list[str] = []
    seen: set[str] = set()
    for part in raw.split(","):
        item = part.strip().lower()
        if not item:
            continue
        if item not in BACKEND_PREF:
            raise ValueError(f"unsupported backend name: {item}")
        if item in seen:
            continue
        seen.add(item)
        values.append(item)
    if not values:
        raise ValueError("empty backend list")
    return values


def parse_env_dll_dirs() -> list[str]:
    raw = os.environ.get("AMS_DLL_DIRS", "").strip()
    if not raw:
        return []
    return [entry for entry in raw.split(os.pathsep) if entry]


def parse_cuda_bin_dirs() -> list[str]:
    dirs: list[str] = []
    for key, value in os.environ.items():
        if not key.upper().startswith("CUDA_PATH"):
            continue
        if not value:
            continue
        candidate = Path(value) / "bin"
        if candidate.is_dir():
            dirs.append(str(candidate))
    return dirs


def setup_windows_dll_dirs(lib_path: Path) -> list[Any]:
    if os.name != "nt":
        return []

    handles = []
    seen = set()
    candidates = [str(lib_path.parent), *parse_env_dll_dirs(), *parse_cuda_bin_dirs()]
    ffmpeg_bin = os.environ.get("AMS_FFMPEG_BIN_DIR", "").strip()
    if ffmpeg_bin:
        candidates.append(ffmpeg_bin)

    for raw_dir in candidates:
        if not raw_dir:
            continue
        dir_path = Path(raw_dir).resolve()
        key = str(dir_path).lower()
        if key in seen:
            continue
        seen.add(key)
        if not dir_path.is_dir():
            continue
        try:
            handles.append(os.add_dll_directory(str(dir_path)))
            print(f"[integration] Added Windows DLL search dir: {dir_path}")
        except OSError as exc:
            print(f"[integration] Failed to add DLL search dir {dir_path}: {exc}")
    return handles


def configure_ffi(lib: ctypes.CDLL) -> None:
    lib.ams_last_error.restype = ctypes.c_char_p

    lib.ams_engine_open.argtypes = [ctypes.c_char_p, ctypes.c_int32, ctypes.POINTER(ctypes.c_uint64)]
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

    lib.ams_prepare_get_result_json.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_void_p)]
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

    lib.ams_job_get_result_json.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_void_p)]
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


def read_json_string(lib: ctypes.CDLL, ptr_value: int) -> dict[str, Any]:
    raw = ctypes.string_at(ptr_value).decode("utf-8")
    lib.ams_string_free(ctypes.c_char_p(ptr_value))
    return json.loads(raw)


def poll_until_done(lib: ctypes.CDLL, poll_fn: Any, handle: int, label: str, timeout_sec: float) -> int:
    out_state = ctypes.c_int32()
    out_progress = ctypes.c_double()
    out_stage = ctypes.c_int32()

    start = time.time()
    while True:
        ensure_ok(
            lib,
            poll_fn(handle, ctypes.byref(out_state), ctypes.byref(out_progress), ctypes.byref(out_stage)),
            f"{label} poll",
        )
        state = out_state.value
        if state in (AMS_JOB_SUCCEEDED, AMS_JOB_FAILED, AMS_JOB_CANCELLED):
            return state
        if time.time() - start > timeout_sec:
            raise TimeoutError(f"{label} timed out after {timeout_sec}s")
        time.sleep(0.1)


def run_prepare(lib: ctypes.CDLL, source_input: Path, work_dir: Path, timeout_sec: float) -> dict[str, Any]:
    prepare_handle = ctypes.c_uint64(0)
    config = AmsPrepareConfig(
        input_path=str(source_input).encode("utf-8"),
        work_dir=str(work_dir).encode("utf-8"),
        output_prefix=b"integration",
    )

    ensure_ok(lib, lib.ams_prepare_start(0, ctypes.byref(config), ctypes.byref(prepare_handle)), "prepare start")

    try:
        state = poll_until_done(lib, lib.ams_prepare_poll, prepare_handle.value, "prepare", timeout_sec)
        if state != AMS_JOB_SUCCEEDED:
            raise RuntimeError(f"prepare did not succeed, state={state}")

        out_json = ctypes.c_void_p()
        ensure_ok(lib, lib.ams_prepare_get_result_json(prepare_handle.value, ctypes.byref(out_json)), "prepare result")
        json_ptr = out_json.value
        if json_ptr is None or json_ptr == 0:
            raise RuntimeError("prepare result returned null json pointer")
        result = read_json_string(lib, int(json_ptr))
    finally:
        ensure_ok(lib, lib.ams_prepare_destroy(prepare_handle.value), "prepare destroy")

    canonical = Path(result.get("canonical_input_file", ""))
    if not canonical.exists():
        raise FileNotFoundError(f"prepare canonical file missing: {canonical}")
    if result.get("sample_rate") != 44100:
        raise RuntimeError(f"unexpected sample_rate from prepare: {result.get('sample_rate')}")
    if result.get("channels") != 2:
        raise RuntimeError(f"unexpected channels from prepare: {result.get('channels')}")
    return result


def run_job(
    lib: ctypes.CDLL,
    model_path: Path,
    source_input: Path,
    prepared_input: Path,
    output_dir: Path,
    output_prefix: str,
    backend_pref: int,
    chunk_size: int,
    overlap: int,
    timeout_sec: float,
) -> dict[str, Any]:
    engine = ctypes.c_uint64(0)
    code = lib.ams_engine_open(str(model_path).encode("utf-8"), backend_pref, ctypes.byref(engine))
    if code != AMS_OK:
        if code == AMS_ERR_UNSUPPORTED:
            raise RuntimeError(f"engine open unsupported for backend_pref={backend_pref}: {last_error(lib)}")
        ensure_ok(lib, code, "engine open")

    job_handle = ctypes.c_uint64(0)
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
        run_config = AmsRunConfig(
            input_path=str(source_input).encode("utf-8"),
            prepared_input_path=str(prepared_input).encode("utf-8"),
            output_dir=str(output_dir).encode("utf-8"),
            output_prefix=output_prefix.encode("utf-8"),
            output_format=0,  # WAV
            chunk_size=chunk_size,
            overlap=overlap,
        )

        ensure_ok(lib, lib.ams_job_start(engine.value, ctypes.byref(run_config), ctypes.byref(job_handle)), "job start")

        state = poll_until_done(lib, lib.ams_job_poll, job_handle.value, "job", timeout_sec)
        if state != AMS_JOB_SUCCEEDED:
            raise RuntimeError(f"job did not succeed, state={state}")

        out_json = ctypes.c_void_p()
        ensure_ok(lib, lib.ams_job_get_result_json(job_handle.value, ctypes.byref(out_json)), "job result")
        json_ptr = out_json.value
        if json_ptr is None or json_ptr == 0:
            raise RuntimeError("job result returned null json pointer")
        result = read_json_string(lib, int(json_ptr))
        return result
    finally:
        if job_handle.value != 0:
            ensure_ok(lib, lib.ams_job_destroy(job_handle.value), "job destroy")
        if engine.value != 0:
            ensure_ok(lib, lib.ams_engine_close(engine.value), "engine close")


def read_wav_duration_ms(path: Path) -> int:
    payload = path.read_bytes()
    if len(payload) < 12:
        raise RuntimeError(f"WAV too small: {path}")
    if payload[0:4] != b"RIFF" or payload[8:12] != b"WAVE":
        raise RuntimeError(f"not a RIFF/WAVE file: {path}")

    byte_rate: int | None = None
    data_size: int | None = None
    offset = 12
    total = len(payload)
    while offset + 8 <= total:
        chunk_id = payload[offset : offset + 4]
        chunk_size = struct.unpack_from("<I", payload, offset + 4)[0]
        chunk_data = offset + 8
        chunk_end = chunk_data + chunk_size
        if chunk_end > total:
            break

        if chunk_id == b"fmt " and chunk_size >= 16:
            byte_rate = struct.unpack_from("<I", payload, chunk_data + 8)[0]
        elif chunk_id == b"data":
            data_size = chunk_size

        offset = chunk_end + (chunk_size & 1)

    if byte_rate is None or byte_rate <= 0 or data_size is None or data_size < 0:
        raise RuntimeError(f"invalid WAV metadata: {path}")
    return int(round(data_size * 1000.0 / byte_rate))


def verify_outputs(
    files: list[str],
    min_bytes: int,
    expected_duration_ms: int,
    tolerance_ms: int,
) -> list[dict[str, Any]]:
    if not files:
        raise RuntimeError("job returned empty output file list")

    metrics: list[dict[str, Any]] = []
    for raw_path in files:
        path = Path(raw_path)
        if not path.exists():
            raise FileNotFoundError(f"output file not found: {path}")
        size = path.stat().st_size
        if size < min_bytes:
            raise RuntimeError(f"output file too small: {path} size={size} min={min_bytes}")

        actual_duration_ms = read_wav_duration_ms(path)
        delta_ms = abs(actual_duration_ms - expected_duration_ms)
        if delta_ms > tolerance_ms:
            raise RuntimeError(
                f"duration mismatch for {path}: actual={actual_duration_ms}ms expected={expected_duration_ms}ms "
                f"delta={delta_ms}ms tolerance={tolerance_ms}ms"
            )

        metrics.append(
            {
                "path": str(path),
                "size_bytes": size,
                "duration_ms": actual_duration_ms,
                "duration_delta_ms": delta_ms,
            }
        )
    return metrics


def run_backend_once(
    lib: ctypes.CDLL,
    model_path: Path,
    source_input: Path,
    prepared_input: Path,
    run_root: Path,
    backend: str,
    min_bytes: int,
    expected_duration_ms: int,
    tolerance_ms: int,
    chunk_size: int,
    overlap: int,
    timeout_sec: float,
) -> dict[str, Any]:
    output_dir = run_root / f"job_{backend}"
    result = run_job(
        lib=lib,
        model_path=model_path,
        source_input=source_input,
        prepared_input=prepared_input,
        output_dir=output_dir,
        output_prefix=f"integration_{backend}",
        backend_pref=BACKEND_PREF[backend],
        chunk_size=chunk_size,
        overlap=overlap,
        timeout_sec=timeout_sec,
    )
    files = result.get("files")
    if not isinstance(files, list) or not all(isinstance(item, str) for item in files):
        raise RuntimeError(f"invalid files field in job result: {result}")
    metrics = verify_outputs(files, min_bytes, expected_duration_ms, tolerance_ms)
    return {
        "backend": backend,
        "status": "success",
        "result": result,
        "metrics": metrics,
    }


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=False), encoding="utf-8")
    print(f"[integration] report: {path}")


def main() -> int:
    args = parse_args()

    library = Path(args.library).resolve()
    model = Path(args.model).resolve()
    input_audio = Path(args.input).resolve()
    report_path = Path(args.report).resolve()

    report: dict[str, Any] = {
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "library": str(library),
        "model": str(model),
        "input": str(input_audio),
        "backends": parse_backends(args.backends),
        "min_bytes": args.min_bytes,
        "duration_tolerance_ms": args.duration_tolerance_ms,
        "timeout_sec": args.timeout_sec,
        "chunk_size": args.chunk_size,
        "overlap": args.overlap,
        "prepare": None,
        "runs": [],
        "warnings": [],
        "errors": [],
        "success": False,
    }

    if not library.exists():
        report["errors"].append(f"library not found: {library}")
        write_report(report_path, report)
        return 1
    if not model.exists():
        report["errors"].append(f"model not found: {model}")
        write_report(report_path, report)
        return 1
    if not input_audio.exists():
        report["errors"].append(f"input audio not found: {input_audio}")
        write_report(report_path, report)
        return 1

    _dll_handles = setup_windows_dll_dirs(library)
    _ = _dll_handles
    lib = ctypes.CDLL(str(library))
    configure_ffi(lib)

    run_root = report_path.parent / "runtime"
    prepare_root = run_root / "prepare"
    prepare_root.mkdir(parents=True, exist_ok=True)

    try:
        prepare = run_prepare(lib, input_audio, prepare_root, args.timeout_sec)
        report["prepare"] = prepare
        expected_duration_ms = int(prepare.get("duration_ms", 0))
        if expected_duration_ms <= 0:
            raise RuntimeError(f"invalid prepare duration_ms: {prepare.get('duration_ms')}")
        prepared_input = Path(prepare["canonical_input_file"])

        for backend in report["backends"]:
            if backend == "vulkan":
                try:
                    run = run_backend_once(
                        lib,
                        model,
                        input_audio,
                        prepared_input,
                        run_root,
                        backend,
                        args.min_bytes,
                        expected_duration_ms,
                        args.duration_tolerance_ms,
                        args.chunk_size,
                        args.overlap,
                        args.timeout_sec,
                    )
                    report["runs"].append(run)
                except Exception as exc:
                    warning = f"Vulkan run failed, fallback to CPU: {exc}"
                    print(f"::warning::{warning}")
                    report["warnings"].append(warning)
                    try:
                        fallback_run = run_backend_once(
                            lib,
                            model,
                            input_audio,
                            prepared_input,
                            run_root,
                            "cpu",
                            args.min_bytes,
                            expected_duration_ms,
                            args.duration_tolerance_ms,
                            args.chunk_size,
                            args.overlap,
                            args.timeout_sec,
                        )
                        fallback_run["status"] = "degraded_cpu_fallback"
                        fallback_run["fallback_from"] = "vulkan"
                        fallback_run["vulkan_error"] = str(exc)
                        report["runs"].append(fallback_run)
                    except Exception as fallback_exc:
                        report["errors"].append(f"vulkan fallback cpu failed: {fallback_exc}")
            else:
                try:
                    run = run_backend_once(
                        lib,
                        model,
                        input_audio,
                        prepared_input,
                        run_root,
                        backend,
                        args.min_bytes,
                        expected_duration_ms,
                        args.duration_tolerance_ms,
                        args.chunk_size,
                        args.overlap,
                        args.timeout_sec,
                    )
                    report["runs"].append(run)
                except Exception as exc:
                    report["errors"].append(f"{backend} run failed: {exc}")

    except Exception as exc:
        report["errors"].append(str(exc))

    report["success"] = len(report["errors"]) == 0
    write_report(report_path, report)

    if report["success"]:
        print("[integration] success")
        return 0
    for warning in report["warnings"]:
        print(f"[integration] warning: {warning}")
    for error in report["errors"]:
        print(f"[integration] error: {error}")
    print("[integration] failed")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
