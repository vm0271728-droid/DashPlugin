from pathlib import Path
import math
import random
import struct
import wave
import zlib
import binascii

root = Path(__file__).resolve().parent
assets = root / "Assets"
sfx = root / "Audio" / "SFX"
assets.mkdir(parents=True, exist_ok=True)
sfx.mkdir(parents=True, exist_ok=True)

W = H = 64
TILE = 16
pixels = bytearray(W * H * 4)
palette = [
    ((121, 83, 55), (90, 58, 39)),
    ((92, 145, 57), (63, 111, 39)),
    ((100, 151, 63), (112, 82, 52)),
    ((121, 121, 121), (88, 88, 88)),
    ((218, 199, 139), (188, 169, 112)),
    ((133, 93, 53), (92, 61, 35)),
    ((155, 112, 63), (102, 73, 42)),
    ((71, 125, 53), (42, 91, 36)),
    ((104, 104, 104), (70, 70, 70)),
    ((94, 94, 94), (37, 37, 37)),
    ((112, 105, 99), (173, 123, 91)),
    ((180, 126, 72), (139, 91, 50)),
    ((193, 226, 231), (145, 194, 204)),
    ((58, 119, 196), (36, 91, 164)),
    ((74, 72, 69), (38, 37, 36)),
    ((132, 126, 119), (92, 88, 84)),
]

rng = random.Random(0x51A7B10C)
for tile, (base, dark) in enumerate(palette):
    tx = (tile % 4) * TILE
    ty = (tile // 4) * TILE
    for y in range(TILE):
        for x in range(TILE):
            checker = ((x * 7 + y * 11 + tile * 5) % 17) < 5
            noise = rng.randint(-13, 13)
            src = dark if checker else base
            r = max(0, min(255, src[0] + noise))
            g = max(0, min(255, src[1] + noise))
            b = max(0, min(255, src[2] + noise))
            a = 190 if tile in (7, 12, 13) else 255
            i = ((ty + y) * W + (tx + x)) * 4
            pixels[i:i + 4] = bytes((r, g, b, a))

def put(x: int, y: int, rgba: tuple[int, int, int, int]) -> None:
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 4
        pixels[i:i + 4] = bytes(rgba)

ox, oy = 2 * TILE, 0
for x in range(TILE):
    depth = 3 + ((x * 5 + 3) % 4)
    for y in range(depth):
        put(ox + x, oy + y, (73 + (x % 3) * 8, 125 + (x % 4) * 5, 44, 255))

ox, oy = 2 * TILE, TILE
for radius in (2, 5, 7):
    for n in range(80):
        angle = n / 80 * math.tau
        x = int(ox + 7.5 + math.cos(angle) * radius)
        y = int(oy + 7.5 + math.sin(angle) * radius)
        put(x, y, (98, 67, 38, 255))

for tile, color in [(9, (42, 42, 42, 255)), (10, (195, 132, 94, 255))]:
    ox, oy = (tile % 4) * TILE, (tile // 4) * TILE
    rr = random.Random(tile * 999)
    for _ in range(21):
        x, y = rr.randrange(2, 14), rr.randrange(2, 14)
        put(ox + x, oy + y, color)
        if rr.random() < 0.45:
            put(ox + x + 1, oy + y, color)

ox, oy = 3 * TILE, 2 * TILE
for y in (3, 8, 13):
    for x in range(TILE):
        put(ox + x, oy + y, (116, 73, 41, 255))

ox, oy = TILE, 3 * TILE
for y in (4, 10):
    for x in range(TILE):
        if (x + y) % 3:
            put(ox + x, oy + y, (81, 145, 215, 190))

def png_chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", binascii.crc32(tag + data) & 0xFFFFFFFF)
    )

raw = b"".join(b"\x00" + pixels[y * W * 4:(y + 1) * W * 4] for y in range(H))
png = (
    b"\x89PNG\r\n\x1a\n"
    + png_chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
    + png_chunk(b"IDAT", zlib.compress(raw, 9))
    + png_chunk(b"IEND", b"")
)
(assets / "block_atlas.png").write_bytes(png)

RATE = 22050

def make_wav(name: str, duration: float, tone: float, noise: float, decay: float, seed: int) -> None:
    rr = random.Random(seed)
    n = int(RATE * duration)
    frames = bytearray()
    for i in range(n):
        t = i / RATE
        env = max(0.0, 1.0 - t / duration) ** decay
        value = math.sin(math.tau * tone * t) * 0.35 + (rr.random() * 2 - 1) * noise
        value += math.sin(math.tau * (tone * 0.49) * t) * 0.12
        sample = int(max(-1.0, min(1.0, value * env)) * 32767)
        frames += struct.pack("<h", sample)
    with wave.open(str(sfx / name), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(RATE)
        wf.writeframes(frames)

make_wav("break_soft.wav", 0.18, 92, 0.52, 1.3, 1)
make_wav("break_stone.wav", 0.16, 146, 0.65, 1.0, 2)
make_wav("place.wav", 0.10, 112, 0.42, 1.8, 3)
make_wav("step_grass.wav", 0.085, 80, 0.36, 1.5, 4)
make_wav("step_stone.wav", 0.075, 180, 0.30, 1.4, 5)
make_wav("ui_click.wav", 0.045, 660, 0.03, 2.4, 6)

print(assets / "block_atlas.png")
for path in sorted(sfx.glob("*.wav")):
    print(path)
