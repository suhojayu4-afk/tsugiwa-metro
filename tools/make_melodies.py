"""Departure melodies (発車メロディ) for MY駅: short original 8-bit tunes,
composed here note by note and synthesised (pulse-wave lead, triangle bass,
a soft echo), so there is no outside music or licence involved.

  assets/sounds/melody_{id}.wav  (22.05 kHz, 16-bit mono, 5-8 s)

  python tools/make_melodies.py
"""
import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sounds')
RATE = 22050

NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def freq(note):
    """'A4' → 440 Hz; None = rest."""
    if note is None:
        return 0.0
    name, octave = note[:-1], int(note[-1])
    n = NAMES.index(name) + 12 * (octave + 1)
    return 440.0 * 2 ** ((n - 69) / 12)


# Each tune: tempo, lead [(note, beats)], bass [(note, beats)], lead wave.
MELODIES = {
    # さくら: the free one. Gentle, C major, ends at home.
    'sakura': dict(bpm=120, wave='pulse25', lead=[
        ('E5', .5), ('G5', .5), ('A5', 1), ('G5', .5), ('E5', .5), ('D5', 1),
        ('C5', .5), ('D5', .5), ('E5', .5), ('G5', .5), ('A5', .5), ('C6', .5), ('D6', 1),
        ('C6', .5), ('A5', .5), ('G5', .5), ('A5', .5), ('C6', 2),
    ], bass=[('C3', 2), ('A2', 2), ('F2', 2), ('G2', 2), ('F2', 1), ('G2', 1), ('C3', 2)]),
    # かぜ: quick and bright, D major, for busy mornings.
    'kaze': dict(bpm=150, wave='pulse12', lead=[
        ('D5', .5), ('F#5', .5), ('A5', .5), ('D6', .5), ('C#6', .5), ('A5', .5), ('F#5', .5), ('A5', .5),
        ('B5', .5), ('G5', .5), ('E5', .5), ('G5', .5), ('A5', 1), (None, .5), ('A5', .5),
        ('F#5', .5), ('A5', .5), ('D6', .5), ('E6', .5), ('F#6', 1), ('E6', .5), ('C#6', .5),
        ('D6', 2),
    ], bass=[('D3', 2), ('A2', 2), ('G2', 2), ('A2', 2), ('D3', 2), ('A2', 2), ('D3', 2)]),
    # ほし: calm night tune, A minor drifting home to C.
    'hoshi': dict(bpm=92, wave='triangle', lead=[
        ('A4', .5), ('C5', .5), ('E5', .5), ('G5', 1.5), ('F5', .5), ('E5', .5), ('D5', 1),
        ('E5', .5), ('G5', .5), ('C6', 1), ('B5', 1), ('C6', 2),
    ], bass=[('A2', 2), ('F2', 2), ('C3', 2), ('G2', 1), ('C3', 2)]),
    # うみ: a little waltz by the sea, G major in 3/4.
    'umi': dict(bpm=138, wave='pulse25', lead=[
        ('G5', 1), ('B5', .5), ('D6', .5), ('B5', 1), ('A5', 1), ('F#5', .5), ('A5', .5), ('D6', 1),
        ('G5', 1), ('B5', .5), ('D6', .5), ('G6', 1), ('F#6', 1), ('E6', .5), ('D6', .5), ('A5', 1),
        ('G5', 3),
    ], bass=[('G2', 3), ('D3', 3), ('G2', 3), ('D3', 3), ('G2', 3)]),
}


def osc(kind, phase):
    p = phase % 1.0
    if kind == 'pulse12':
        return 1.0 if p < 0.125 else -0.3
    if kind == 'pulse25':
        return 1.0 if p < 0.25 else -0.45
    if kind == 'triangle':
        return 4 * abs(p - 0.5) - 1
    return math.sin(2 * math.pi * p)


def render_voice(notes, bpm, kind, gain, out, vibrato=0.0):
    beat = 60.0 / bpm
    t0 = 0.0
    for note, beats in notes:
        f = freq(note)
        length = beats * beat
        n = int(length * RATE)
        start = int(t0 * RATE)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            if f:
                # Envelope: quick attack, gentle fall, short release at the end.
                env = min(1.0, t / 0.006) * (0.55 + 0.45 * math.exp(-t * 5))
                env *= min(1.0, (length - t) / 0.03)
                v = f * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.25))
                phase += v / RATE
                out[start + i] += gain * env * osc(kind, phase)
        t0 += length
    return t0


def make(name, m):
    beats = sum(b for _, b in m['lead'])
    seconds = beats * 60.0 / m['bpm'] + 1.2  # room for the last note to ring
    buf = [0.0] * int(seconds * RATE)
    render_voice(m['lead'], m['bpm'], m['wave'], 0.32, buf, vibrato=0.006)
    render_voice(m['bass'], m['bpm'], 'triangle', 0.28, buf)
    # A soft echo, like a station hall.
    d = int(0.19 * RATE)
    for i in range(len(buf) - 1, d - 1, -1):
        buf[i] += 0.28 * buf[i - d]
    # Fade the tail and normalise.
    tail = int(0.6 * RATE)
    for i in range(tail):
        buf[-tail + i] *= 1 - i / tail
    peak = max(abs(x) for x in buf) or 1.0
    frames = b''.join(struct.pack('<h', int(x / peak * 0.85 * 32767)) for x in buf)
    path = os.path.join(OUT, f'melody_{name}.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f'{path}: {seconds:.1f} s')


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, m in MELODIES.items():
        make(name, m)


if __name__ == '__main__':
    main()
