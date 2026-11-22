"""Departure melodies (発車メロディ) for MY駅: short original 8-bit tunes,
composed here note by note and synthesised (pulse-wave lead, triangle bass,
a soft echo), so there is no outside music or licence involved. The later
ones have their own voices: a music box ('bell'), a plucked koto ('pluck')
and festival drums ('drums': one letter per half beat, D = big drum,
k = rim click, . = nothing).

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
    # オルゴール: a music box winding down, C major.
    'orgel': dict(bpm=100, wave='bell', decay=3.2, lead=[
        ('G5', .5), ('E5', .5), ('C6', 1), ('B5', .5), ('G5', .5), ('A5', 1),
        ('F5', .5), ('A5', .5), ('C6', .5), ('A5', .5), ('G5', 1),
        ('E5', .5), ('G5', .5), ('D5', .5), ('E5', .5), ('F5', .5), ('D5', .5), ('C5', 2),
    ], bass=[('C3', 2), ('A2', 2), ('F2', 2), ('C3', 2), ('G2', 2), ('C3', 2)], bass_wave='bell'),
    # こと: a plucked koto in the old miyako-bushi scale (D E♭ G A B♭).
    'koto': dict(bpm=96, wave='pluck', decay=4.0, lead=[
        ('D5', 1), ('D#5', .5), ('D5', .5), ('A4', 1), ('A#4', .5), ('A4', .5),
        ('G4', 1), ('A4', .5), ('D5', .5), ('D#5', .5), ('G5', .5), ('A5', 1),
        ('G5', .5), ('D#5', .5), ('D5', 2),
    ], bass=[('D3', 2), ('A2', 2), ('G2', 2), ('D3', 2), ('A2', 1), ('D3', 2)], bass_wave='pluck'),
    # まつり: a summer festival flute over drums, A yo scale (A C D E G).
    'matsuri': dict(bpm=144, wave='pulse25', lead=[
        ('A5', .5), ('A5', .5), ('C6', .5), ('A5', .5), ('G5', .5), ('E5', .5), ('G5', 1),
        ('A5', .5), ('C6', .5), ('D6', .5), ('C6', .5), ('A5', .5), ('G5', .5), ('A5', 1),
        ('E6', .5), ('D6', .5), ('C6', .5), ('A5', .5), ('G5', .5), ('A5', .5), ('C6', .5), ('D6', .5),
        ('A5', 2),
    ], bass=[('A2', 2), ('E2', 2), ('A2', 2), ('E2', 2), ('D3', 2), ('E3', 2), ('A2', 2)],
        drums='D.kkD.k.D.kkD.k.D.kkD.k.DkDk'),
    # よる: the last train, slow and soft, F major.
    'yoru': dict(bpm=76, wave='bell', decay=2.2, lead=[
        ('A4', .5), ('C5', .5), ('E5', 1.5), ('D5', .5), ('C5', 1), ('A4', 1),
        ('G4', .5), ('A4', .5), ('C5', 2),
    ], bass=[('F2', 2), ('A2', 2), ('A#2', 2), ('F2', 2)]),
    # ピコ: an 8-bit game jingle, quick arpeggios in C major.
    'pico': dict(bpm=168, wave='pulse12', lead=[
        ('C5', .25), ('E5', .25), ('G5', .25), ('C6', .25), ('E5', .25), ('G5', .25), ('C6', .25), ('E6', .25),
        ('F5', .25), ('A5', .25), ('C6', .25), ('F6', .25), ('A5', .25), ('C6', .25), ('F6', .25), ('A6', .25),
        ('G5', .25), ('B5', .25), ('D6', .25), ('G6', .25), ('B5', .25), ('D6', .25), ('G6', .25), ('B6', .25),
        ('C6', .5), ('G5', .5), ('E6', .5), ('G6', .5), ('C7', 1.5),
    ], bass=[('C3', 2), ('F2', 2), ('G2', 2), ('C3', 3.5)], drums='k.k.k.k.k.k.D.D.D..'),
    # おに: the oni train rolling in, D minor with big drums.
    'oni': dict(bpm=132, wave='pulse25', lead=[
        ('D5', 1), ('F5', .5), ('A5', .5), ('G5', .5), ('F5', .5), ('E5', 1),
        ('D5', .5), ('A4', .5), ('D5', .5), ('F5', .5), ('A5', 1),
        ('A#5', .5), ('A5', .5), ('G5', .5), ('F5', .5), ('E5', .5), ('C#5', .5), ('D5', 2),
    ], bass=[('D3', 2), ('A#2', 2), ('G2', 2), ('A2', 2), ('A2', 2), ('D3', 2)],
        drums='D..DD.k.D..DD.k.D.DDD.kkD...'),
}


def osc(kind, phase):
    p = phase % 1.0
    if kind == 'pulse12':
        return 1.0 if p < 0.125 else -0.3
    if kind == 'pulse25':
        return 1.0 if p < 0.25 else -0.45
    if kind == 'triangle':
        return 4 * abs(p - 0.5) - 1
    if kind == 'bell':
        # A music-box comb: the note, its octave and a faint twelfth.
        return (math.sin(2 * math.pi * p) + 0.42 * math.sin(4 * math.pi * p) + 0.18 * math.sin(6 * math.pi * p)) / 1.3
    if kind == 'pluck':
        # A string: a bright saw softened by the note itself.
        return 0.55 * (2 * p - 1) + 0.6 * math.sin(2 * math.pi * p)
    return math.sin(2 * math.pi * p)


def render_voice(notes, bpm, kind, gain, out, vibrato=0.0, decay=0.0):
    beat = 60.0 / bpm
    t0 = 0.0
    for note, beats in notes:
        f = freq(note)
        length = beats * beat
        # A struck or plucked note ([decay]) rings on past its beat.
        n = int((length + 0.9 if decay else length) * RATE)
        start = int(t0 * RATE)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            if f:
                # Envelope: quick attack, gentle fall, short release at the end.
                if decay:
                    env = min(1.0, t / 0.003) * math.exp(-t * decay) * min(1.0, (length + 0.9 - t) / 0.05)
                else:
                    env = min(1.0, t / 0.006) * (0.55 + 0.45 * math.exp(-t * 5))
                    env *= min(1.0, (length - t) / 0.03)
                v = f * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.25))
                phase += v / RATE
                if start + i < len(out):
                    out[start + i] += gain * env * osc(kind, phase)
        t0 += length
    return t0


def render_drums(pattern, bpm, out):
    """Festival drums, one letter per half beat: D = the big drum (a low
    thud falling in pitch), k = a rim click (a short burst of noise)."""
    step = 30.0 / bpm
    seed = 12345
    for k, c in enumerate(pattern):
        start = int(k * step * RATE)
        if c == 'D':
            phase = 0.0
            for i in range(int(0.22 * RATE)):
                t = i / RATE
                phase += (58 + 70 * math.exp(-t * 22)) / RATE
                if start + i < len(out):
                    out[start + i] += 0.55 * math.exp(-t * 14) * math.sin(2 * math.pi * phase)
        elif c == 'k':
            for i in range(int(0.04 * RATE)):
                seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
                if start + i < len(out):
                    out[start + i] += 0.16 * math.exp(-i / RATE * 90) * (seed / 0x3FFFFFFF - 1)


def make(name, m):
    beats = sum(b for _, b in m['lead'])
    seconds = beats * 60.0 / m['bpm'] + 1.2  # room for the last note to ring
    buf = [0.0] * int(seconds * RATE)
    decay = m.get('decay', 0.0)
    render_voice(m['lead'], m['bpm'], m['wave'], 0.32, buf, vibrato=0.0 if decay else 0.006, decay=decay)
    bass = m.get('bass_wave', 'triangle')
    render_voice(m['bass'], m['bpm'], bass, 0.28, buf, decay=decay * 0.7 if bass != 'triangle' else 0.0)
    if 'drums' in m:
        render_drums(m['drums'], m['bpm'], buf)
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
