"""T-051a2 offline tests for scripts/stage_wind_step_play.py (no HTTP, synthetic TEST target)."""
import json
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import stage_wind_step_play as play  # noqa: E402

TARGET = {"schema": 1, "kind": "Robby isolated published test", "universeId": "111", "placeId": "222",
          "ownerUserId": "7738981129"}


def refused(fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except (ValueError, OSError, Exception):
        return True
    return False


def main():
    assert refused(play.stage, TARGET), "stage without explicit enablement"
    bad = dict(TARGET, universeId="10773761715")
    assert refused(play.stage, bad, enable_local_test=True), "production universe refused"
    result = play.stage(TARGET, enable_local_test=True)
    assert result["status"] == "LOCAL_PLAY_STAGE_ONLY" and result["publishReady"] is False
    manifest, pin, place = result["manifest"], result["manifestSha256"], result["place"]
    ok = play.verify(manifest, pin, place)
    assert ok["placeSha256"] == result["placeSha256"]
    with tempfile.TemporaryDirectory() as d:
        tampered = Path(d) / "t.rbxl"
        shutil.copy(place, tampered)
        with tampered.open("ab") as f:
            f.write(b"x")
        assert refused(play.verify, manifest, pin, tampered), "tampered bytes refused"
        assert refused(play.verify, manifest, "0" * 64, place), "wrong pin refused"
        edited = Path(d) / "m.json"
        data = json.loads(Path(manifest).read_text())
        data["publishReady"] = True
        raw = (json.dumps(data, sort_keys=True, indent=2) + "\n").encode()
        edited.write_bytes(raw)
        assert refused(play.verify, edited, play.sha(raw), place), "publishReady claim refused"
    print("wind-step-play-stage: PASS")


if __name__ == "__main__":
    main()
