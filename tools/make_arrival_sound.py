"""The sound of the train pulling in, matched to the banner's arrival
animation (lib/core/pixel/pixel_scene.dart: 4.6 s, running down the line
until 0.86 of it, then settling): a soft rumble that grows as it nears,
the "tatan" of the wheels over each rail joint (the same joints the train
bumps on in the picture, so they slow down as it brakes), a gentle brake
whine and a quiet "pshh" of air when it stops.

Kept quiet on purpose (peak about -14 dBFS, well under the melodies) so it
never startles anyone; the departure melody follows it.

  assets/sounds/arrive.wav  (22.05 kHz, 16-bit mono)

  python tools/make_arrival_sound.py
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sounds', 'arrive.wav')
RATE = 22050

# Same timeline as the animation.
DURATION = 4.6
TRAVEL_END = 0.86
FAR = 1 / 0.07          # SceneArt.trainFarScale
JOINTS = 2.4            # joints per unit of distance (pixel_scene.dart)
PEAK = 0.2              # about -14 dBFS


def travel(t):
    return min(1.0, (t / DURATION) / TRAVEL_END)


def distance(t):
    p = travel(t)
    return 1 + (FAR - 1) * (1 - p) ** 2


def main():
    random.seed(7)
    n = int((DURATION + 1.2) * RATE)
    buf = [0.0] * n

    # Rumble: low-passed noise, louder as the train comes closer.
    lp = lp2 = 0.0
    for i in range(n):
        t = i / RATE
        near = 1 / distance(t)
        moving = 1.0 if travel(t) < 1 else max(0.0, 1 - (t - DURATION * TRAVEL_END) / 0.5)
        lp += (random.uniform(-1, 1) - lp) * 0.02
        lp2 += (lp - lp2) * 0.05
        buf[i] += lp2 * 9 * near * moving * min(1.0, t / 0.8)

    # Wheels over the rail joints: "ta-tan" (front and back bogie).
    def knock(at, gain):
        start = int(at * RATE)
        f = 0.0
        for k in range(int(0.07 * RATE)):
            if start + k >= n:
                break
            env = math.exp(-k / RATE * 70)
            f += (random.uniform(-1, 1) - f) * 0.25
            thump = math.sin(2 * math.pi * 95 * k / RATE)
            buf[start + k] += gain * env * (0.6 * f + 0.5 * thump)

    prev = math.floor(distance(0) * JOINTS)
    step = 1 / RATE * 4
    t = 0.0
    while t < DURATION * TRAVEL_END:
        j = math.floor(distance(t) * JOINTS)
        if j != prev:
            near = 1 / distance(t)
            speed = (distance(t) - distance(t + 0.05)) / 0.05   # distance units per second
            gap = min(0.16, 0.5 / max(speed, 0.5))               # second bogie follows
            knock(t, 0.55 * near)
            knock(t + gap, 0.45 * near)
            prev = j
        t += step

    # Brake whine: soft, rising a little in pitch, only over the last stretch.
    b0, b1 = DURATION * 0.66, DURATION * TRAVEL_END + 0.12
    phase = 0.0
    for i in range(int(b0 * RATE), int(b1 * RATE)):
        t = i / RATE
        u = (t - b0) / (b1 - b0)
        env = max(0.0, math.sin(math.pi * u)) ** 1.5
        f = 1850 + 260 * u + 18 * math.sin(2 * math.pi * 6 * t)
        phase += f / RATE
        buf[i] += 0.09 * env * math.sin(2 * math.pi * phase)

    # A quiet "pshh" of air when it has stopped.
    a0 = int((DURATION * TRAVEL_END + 0.25) * RATE)
    hp = prev_x = 0.0
    for k in range(int(0.9 * RATE)):
        if a0 + k >= n:
            break
        x = random.uniform(-1, 1)
        hp = 0.85 * (hp + x - prev_x)
        prev_x = x
        env = min(1.0, k / RATE / 0.04) * math.exp(-k / RATE * 3.2)
        buf[a0 + k] += 0.12 * env * hp

    # Fade in and out, then set the (quiet) level.
    for i in range(int(0.3 * RATE)):
        buf[i] *= i / (0.3 * RATE)
        buf[-1 - i] *= i / (0.3 * RATE)
    peak = max(abs(x) for x in buf) or 1.0
    frames = b''.join(struct.pack('<h', int(x / peak * PEAK * 32767)) for x in buf)
    with wave.open(OUT, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f'{OUT}: {n / RATE:.1f} s')


if __name__ == '__main__':
    main()
