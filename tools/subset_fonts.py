"""Trims the Korean pixel font to what the app asks of it.

Galmuri11 is the app's second font: Japanese text is drawn with DotGothic16
and Galmuri11 is asked only for what DotGothic16 lacks (Hangul, some signs).
Its 6,400 kanji that DotGothic16 also has are never used, and are most of the
file. This drops exactly those and keeps everything else (Hangul, kana, Latin,
signs, and the few kanji DotGothic16 does not have). The SIL Open Font Licence
allows modified versions; Galmuri declares no reserved font name.

Run on the full font from https://github.com/quiple/galmuri (it is not kept
in the repo once trimmed):
  python tools/subset_fonts.py path/to/Galmuri11.ttf
  -> assets/fonts/Galmuri11.ttf
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    src = sys.argv[1]
    font = TTFont(src)
    have = font.getBestCmap()
    first = set(TTFont(os.path.join(ROOT, 'assets/fonts/DotGothic16-Regular.ttf')).getBestCmap())
    keep = [c for c in have if not (0x4E00 <= c <= 0x9FFF and c in first)]
    opt = subset.Options()
    opt.layout_features = ['*']
    opt.name_IDs = ['*']
    opt.notdef_outline = True
    opt.glyph_names = False
    opt.hinting = True
    s = subset.Subsetter(opt)
    s.populate(unicodes=keep)
    s.subset(font)
    out = os.path.join(ROOT, 'assets/fonts/Galmuri11.ttf')
    font.save(out)
    print(len(have), '->', len(keep), 'characters;', os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    main()
