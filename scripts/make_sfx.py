# /// script
# dependencies = ["numpy", "scipy"]
# ///
"""T-053a4b (D-381, D-389): build the Crescent Cut sounds.
Tonal "moon" layers are cut from Gemini Lyria clips (build/sfx/raw/{ring,chime,hum}.mp3, made by
scripts/lyria_tone.sh); air whoosh, slice transient and ground thud are synthesised here (numpy).
Writes assets/sfx/sfx-crescent-<sound>-<v>.ogg (2-3 variants each) + build/sfx/preview.ogg (all, in order).
Deterministic (fixed seeds). Usage: uv run scripts/make_sfx.py"""
import os, subprocess, numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
RAW, OUT = "build/sfx/raw", "assets/sfx"


def load(name: str) -> np.ndarray:
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", f"{RAW}/{name}.mp3", "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(pcm, dtype=np.float32).astype(np.float64)


def onsets(x: np.ndarray, n: int, length: float) -> list[int]:
    """Start samples of the n strongest attacks (RMS jump, 10 ms hop), spaced at least `length` apart."""
    hop = SR // 100
    env = np.sqrt(np.convolve(x * x, np.ones(hop) / hop, "same"))[::hop]
    jump = np.maximum(0, env[3:] - env[:-3])
    picks: list[int] = []
    for i in np.argsort(-jump):
        s = int(i) * hop
        if s + int(length * SR) < len(x) and all(abs(s - p) > length * SR for p in picks):
            picks.append(max(0, s - hop))
        if len(picks) == n:
            break
    return sorted(picks)


def env(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(0, t - attack) / decay)


def band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return sosfilt(butter(2, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def sweep_noise(dur: float, f0: float, f1: float, seed: int) -> np.ndarray:
    """Noise through a band-pass whose centre glides f0 -> f1 (block-wise), the classic air whoosh."""
    rng = np.random.default_rng(seed)
    n, blk = int(dur * SR), 512
    x, y = rng.standard_normal(n), np.zeros(n)
    for i in range(0, n, blk):
        f = f0 * (f1 / f0) ** (i / n)
        y[i:i + blk] = band(x[max(0, i - 2048):i + blk], f * 0.6, min(f * 1.6, SR / 2 - 100))[-len(x[i:i + blk]):]
    return y


def fit(x: np.ndarray, dur: float, fade: float = 0.03) -> np.ndarray:
    n = int(dur * SR)
    x = np.pad(x, (0, max(0, n - len(x))))[:n].copy()
    f = int(fade * SR)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def norm(x: np.ndarray, peak: float = 0.89) -> np.ndarray:
    return x * (peak / max(1e-9, np.max(np.abs(x))))


def tone_slice(src: np.ndarray, start: int, dur: float, attack: float, decay: float) -> np.ndarray:
    s = src[start:start + int(dur * SR)]
    s = sosfilt(butter(2, 300, "highpass", fs=SR, output="sos"), s)
    return norm(s * env(len(s), attack, decay))


def cast(ring: np.ndarray, starts: list[int], v: int) -> np.ndarray:
    dur = 0.7
    w = sweep_noise(0.35, 500 + 150 * v, 3500 + 500 * v, seed=10 + v) * env(int(0.35 * SR), 0.12, 0.08)
    tone = tone_slice(ring, starts[v % len(starts)], dur, 0.01, 0.25)
    return norm(fit(0.9 * norm(w), dur) + 0.55 * np.roll(fit(tone, dur), int(0.06 * SR)))


def hit(chime: np.ndarray, starts: list[int], v: int) -> np.ndarray:
    dur = 0.5
    rng = np.random.default_rng(20 + v)
    click = band(rng.standard_normal(int(0.04 * SR)), 2500, 9000) * env(int(0.04 * SR), 0.001, 0.008)
    slice_ = sweep_noise(0.12, 6000, 2000, seed=30 + v) * env(int(0.12 * SR), 0.002, 0.04)
    tone = tone_slice(chime, starts[v % len(starts)], dur, 0.003, 0.18)
    return norm(fit(norm(click), dur) + 0.7 * fit(norm(slice_), dur) + 0.6 * fit(tone, dur))


def thud(v: int) -> np.ndarray:
    dur = 0.45
    t = np.arange(int(dur * SR)) / SR
    f = 55 + 25 * v + 90 * np.exp(-t / 0.03)  # pitch drop
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.002, 0.12)
    rng = np.random.default_rng(40 + v)
    grit = band(rng.standard_normal(len(t)), 150, 1200) * env(len(t), 0.001, 0.05)
    crack = band(rng.standard_normal(len(t)), 2000, 7000) * env(len(t), 0.0005, 0.01)
    return norm(norm(body) + 0.45 * norm(grit) + 0.25 * norm(crack))


def hum(src: np.ndarray, v: int) -> np.ndarray:
    """Seamless 2 s loop from the steadiest part of the Lyria drone (crossfaded ends)."""
    dur, xf = 2.0, 0.25
    n, k = int(dur * SR), int(xf * SR)
    start = int((3 + 4 * v) * SR)
    s = sosfilt(butter(2, [200, 6000], "bandpass", fs=SR, output="sos"), src[start:start + n + k])
    loop = s[:n].copy()
    ramp = np.linspace(0, 1, k)
    loop[:k] = s[:k] * ramp + s[n:n + k] * (1 - ramp)
    return norm(loop, 0.6)


def write(name: str, x: np.ndarray) -> None:
    path = f"{OUT}/{name}.ogg" if not name.startswith("build") else name
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f64le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "6", path], input=x.astype(np.float64).tobytes(), check=True)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    ring, chime, drone = load("ring"), load("chime"), load("hum")
    rs, cs = onsets(ring, 3, 0.8), onsets(chime, 3, 0.6)
    sounds = {}
    for v in range(3):
        sounds[f"sfx-crescent-cast-{v + 1}"] = cast(ring, rs, v)
        sounds[f"sfx-crescent-hit-{v + 1}"] = hit(chime, cs, v)
        sounds[f"sfx-crescent-thud-{v + 1}"] = thud(v)
    for v in range(2):
        sounds[f"sfx-crescent-hum-{v + 1}"] = hum(drone, v)
    gap = np.zeros(int(0.4 * SR))
    for name, x in sounds.items():
        write(name, x)
    order = sorted(sounds)
    write("build/sfx/preview.ogg", np.concatenate([np.concatenate([sounds[k], gap]) for k in order]))
    print("WROTE", len(sounds), "sounds; preview order:", " ".join(k.replace("sfx-crescent-", "") for k in order))


main()
