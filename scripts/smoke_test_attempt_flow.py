#!/usr/bin/env python3

import argparse
import json
import mimetypes
import os
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


def request_json(method, url, body=None, headers=None):
    data = None
    all_headers = {"Content-Type": "application/json"}
    if headers:
        all_headers.update(headers)
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=all_headers, method=method)
    with urllib.request.urlopen(req) as resp:
        payload = resp.read()
    return json.loads(payload.decode("utf-8"))


def upload_binary(method, url, file_path, headers=None, auth_header=None):
    with open(file_path, "rb") as fh:
        data = fh.read()
    all_headers = dict(headers or {})
    if auth_header and url.startswith(auth_header["base_url"]):
        all_headers["Authorization"] = auth_header["value"]
    req = urllib.request.Request(url, data=data, headers=all_headers, method=method)
    with urllib.request.urlopen(req) as resp:
        payload = resp.read()
    if not payload:
        return {}
    decoded = json.loads(payload.decode("utf-8"))
    return decoded.get("data", {})


def infer_mime_type(file_path):
    guessed, _ = mimetypes.guess_type(file_path)
    if guessed:
        normalized = guessed.lower()
        if normalized in {"audio/mp4a-latm", "audio/x-m4a"}:
            return "audio/m4a"
        if normalized in {"audio/x-wav", "audio/wave", "audio/vnd.wave"}:
            return "audio/wav"
        return normalized
    return "audio/mp4"


def create_dummy_audio_file():
    fd, path = tempfile.mkstemp(prefix="czech-go-smoke-", suffix=".m4a")
    os.close(fd)
    with open(path, "wb") as fh:
        fh.write(b"czech-go-system-smoke-audio")
    return path


def poll_attempt(base_url, attempt_id, auth_headers, timeout_sec, interval_sec):
    deadline = time.time() + timeout_sec
    last_payload = None
    last_status = None
    while time.time() < deadline:
        payload = request_json("GET", f"{base_url}/v1/attempts/{attempt_id}", headers=auth_headers)
        last_payload = payload["data"]
        status = last_payload.get("status", "")
        if status != last_status:
            print(f"[poll] attempt={attempt_id} status={status}", file=sys.stderr, flush=True)
            last_status = status
        if status in {"completed", "failed"}:
            return last_payload
        time.sleep(interval_sec)
    raise TimeoutError(f"attempt {attempt_id} did not finish within {timeout_sec}s")


def is_same_origin(upload_url, base_url):
    upload = urllib.parse.urlparse(upload_url)
    base = urllib.parse.urlparse(base_url)
    return (upload.scheme, upload.netloc) == (base.scheme, base.netloc)


def main():
    parser = argparse.ArgumentParser(description="Smoke test the production learner attempt flow.")
    parser.add_argument("--base-url", required=True, help="API base URL, for example https://apicz.hadoo.eu")
    parser.add_argument("--exercise-id", default="exercise-uloha1-weather", help="Exercise ID to use")
    parser.add_argument("--email", default="learner@example.com", help="Learner login email")
    parser.add_argument("--password", default="demo123", help="Learner login password")
    parser.add_argument("--audio-file", default="", help="Path to an audio file. If omitted, a tiny dummy file is created.")
    parser.add_argument("--duration-ms", type=int, default=25000, help="Reported duration for upload-complete")
    parser.add_argument("--sample-rate-hz", type=int, default=0, help="Reported sample rate. Leave as 0 when unknown.")
    parser.add_argument("--channels", type=int, default=1, help="Reported channel count. Use 0 to omit it when unknown.")
    parser.add_argument("--timeout-sec", type=int, default=0, help="Polling timeout. Use 0 to auto-pick 20s for local or 180s for cloud.")
    parser.add_argument("--poll-interval-sec", type=float, default=1.0, help="Polling interval")
    parser.add_argument("--mime-type", default="", help="Override the uploaded MIME type")
    parser.add_argument(
        "--require-real-transcript",
        action="store_true",
        help="Fail if the completed attempt reports a synthetic transcript instead of a real provider transcript.",
    )
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    created_dummy = False
    audio_file = args.audio_file
    if not audio_file:
        audio_file = create_dummy_audio_file()
        created_dummy = True

    try:
        file_size = os.path.getsize(audio_file)
        mime_type = args.mime_type or infer_mime_type(audio_file)

        login = request_json(
            "POST",
            f"{base_url}/v1/auth/login",
            body={"email": args.email, "password": args.password},
        )
        token = login["data"]["access_token"]
        auth_headers = {"Authorization": f"Bearer {token}"}

        attempt_resp = request_json(
            "POST",
            f"{base_url}/v1/attempts",
            body={
                "exercise_id": args.exercise_id,
                "client_platform": "smoke-test",
                "app_version": "smoke-1",
            },
            headers=auth_headers,
        )
        attempt = attempt_resp["data"]["attempt"]
        attempt_id = attempt["id"]
        print(f"[attempt] created attempt_id={attempt_id}", file=sys.stderr, flush=True)

        request_json(
            "POST",
            f"{base_url}/v1/attempts/{attempt_id}/recording-started",
            body={"recording_started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
            headers=auth_headers,
        )

        upload_target_resp = request_json(
            "POST",
            f"{base_url}/v1/attempts/{attempt_id}/upload-url",
            body={
                "mime_type": mime_type,
                "file_size_bytes": file_size,
                "duration_ms": args.duration_ms,
            },
            headers=auth_headers,
        )
        upload = upload_target_resp["data"]["upload"]
        cloud_upload = not is_same_origin(upload["url"], base_url)
        if cloud_upload and created_dummy:
            raise ValueError(
                "The upload target points to cloud storage, so the smoke test needs a real audio file. "
                "Pass --audio-file /absolute/path/to/sample.m4a."
            )
        timeout_sec = args.timeout_sec or (180 if cloud_upload else 20)
        print(
            f"[upload] mode={'cloud' if cloud_upload else 'local'} mime_type={mime_type} storage_key={upload.get('storage_key', '')}",
            file=sys.stderr,
            flush=True,
        )

        binary_result = upload_binary(
            upload["method"],
            upload["url"],
            audio_file,
            headers=upload.get("headers", {}),
            auth_header={"base_url": base_url, "value": f"Bearer {token}"},
        )

        upload_complete_body = {
            "storage_key": upload.get("storage_key", ""),
            "mime_type": mime_type,
            "duration_ms": args.duration_ms,
            "file_size_bytes": file_size,
            "stored_file_path": binary_result.get("stored_file_path", ""),
        }
        if args.sample_rate_hz > 0:
            upload_complete_body["sample_rate_hz"] = args.sample_rate_hz
        if args.channels > 0:
            upload_complete_body["channels"] = args.channels

        request_json(
            "POST",
            f"{base_url}/v1/attempts/{attempt_id}/upload-complete",
            body=upload_complete_body,
            headers=auth_headers,
        )
        print(f"[upload] complete attempt_id={attempt_id}", file=sys.stderr, flush=True)

        final_attempt = poll_attempt(
            base_url,
            attempt_id,
            auth_headers,
            timeout_sec=timeout_sec,
            interval_sec=args.poll_interval_sec,
        )

        summary = {
            "attempt_id": attempt_id,
            "status": final_attempt.get("status"),
            "failure_code": final_attempt.get("failure_code"),
            "readiness_level": final_attempt.get("readiness_level"),
            "upload_mode": "cloud" if cloud_upload else "local",
            "audio_storage_key": (final_attempt.get("audio") or {}).get("storage_key"),
            "transcript_provider": (final_attempt.get("transcript") or {}).get("provider"),
            "transcript_is_synthetic": (final_attempt.get("transcript") or {}).get("is_synthetic"),
            "transcript_preview": ((final_attempt.get("transcript") or {}).get("full_text") or "")[:120],
            "feedback_summary": ((final_attempt.get("feedback") or {}).get("overall_summary") or "")[:120],
        }
        print(json.dumps(summary, ensure_ascii=True, indent=2))

        if final_attempt.get("status") != "completed":
            print("Smoke test finished but the attempt did not complete successfully.", file=sys.stderr)
            sys.exit(1)
        if args.require_real_transcript and ((final_attempt.get("transcript") or {}).get("is_synthetic") is True):
            print(
                "Smoke test completed, but the backend still returned a synthetic transcript. "
                "Check TRANSCRIBER_PROVIDER, ATTEMPT_UPLOAD_PROVIDER, and REQUIRE_REAL_TRANSCRIPT.",
                file=sys.stderr,
            )
            sys.exit(1)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP {exc.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
    finally:
        if created_dummy and os.path.exists(audio_file):
            os.remove(audio_file)


if __name__ == "__main__":
    main()
