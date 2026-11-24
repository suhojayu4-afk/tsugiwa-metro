"""Kana -> romaji / hangul spelling (the same rules as tools/build_rail.py)."""
import re

# ---------- kana spelling ----------
_K2H = {chr(c): chr(c - 0x60) for c in range(0x30A1, 0x30F7)}


def hira(s):
    return ''.join(_K2H.get(c, c) for c in s)


# Hangul for Japanese kana (Korean standard: unaspirated at the start of a word, aspirated inside; long vowels not written).
_V = {'a': 'ㅏ', 'i': 'ㅣ', 'u': 'ㅜ', 'e': 'ㅔ', 'o': 'ㅗ', 'ya': 'ㅑ', 'yu': 'ㅠ', 'yo': 'ㅛ', 'wa': 'ㅘ'}
_ROMA = {}
for row, cons in (('あいうえお', ''), ('かきくけこ', 'k'), ('さしすせそ', 's'), ('たちつてと', 't'), ('なにぬねの', 'n'),
                  ('はひふへほ', 'h'), ('まみむめも', 'm'), ('らりるれろ', 'r'), ('がぎぐげご', 'g'), ('ざじずぜぞ', 'z'),
                  ('だぢづでど', 'd'), ('ばびぶべぼ', 'b'), ('ぱぴぷぺぽ', 'p')):
    for ch, v in zip(row, 'aiueo'):
        _ROMA[ch] = cons + v
_ROMA.update({'し': 'shi', 'ち': 'chi', 'つ': 'tsu', 'ふ': 'fu', 'じ': 'ji', 'ぢ': 'ji', 'づ': 'zu', 'や': 'ya', 'ゆ': 'yu',
              'よ': 'yo', 'わ': 'wa', 'を': 'o', 'ゐ': 'i', 'ゑ': 'e', 'ゔ': 'vu'})
_SMALL = {'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o'}


def syllables(h):
    """Kana -> list of romaji syllables ('n' for ん, 'Q' for っ, '-' for a long mark)."""
    out, i = [], 0
    while i < len(h):
        c = h[i]
        nxt = h[i + 1] if i + 1 < len(h) else ''
        if c == 'ん':
            out.append('N')
        elif c == 'っ':
            out.append('Q')
        elif c == 'ー':
            out.append('-')
        elif c in _ROMA:
            r = _ROMA[c]
            if nxt in _SMALL:
                s = _SMALL[nxt]
                if s.startswith('y'):
                    r = r[:-1] + s[1] if r in ('shi', 'chi', 'ji') else r[:-1] + s
                else:
                    r = r[:-1] + s
                i += 1
            out.append(r)
        elif c in (' ', '・', '　'):
            out.append(' ')
        i += 1
    return out


def romaji(h):
    syl, out = syllables(hira(h)), ''
    for i, s in enumerate(syl):
        nxt = syl[i + 1] if i + 1 < len(syl) else ''
        if s == 'N':
            out += 'n'
        elif s == 'Q':
            out += ('t' if nxt.startswith('ch') else nxt[:1]) if nxt and nxt[0] not in 'aiueo' else ''
        elif s == '-':
            continue
        elif s in ('u', 'o') and out and out[-1] in 'o' and s == 'u':
            continue  # とう -> to
        elif s == 'u' and out.endswith('u'):
            continue  # ゅう -> yu
        else:
            out += s
    out = out.replace('ou', 'o').replace('oo', 'o').replace('uu', 'u')
    return ' '.join(w.capitalize() for w in out.split(' ') if w)


_INIT = {'': 'ㅇ', 'k': 'ㄱ', 'g': 'ㄱ', 's': 'ㅅ', 'sh': 'ㅅ', 'z': 'ㅈ', 'j': 'ㅈ', 't': 'ㄷ', 'd': 'ㄷ', 'ch': 'ㅈ',
         'ts': 'ㅆ', 'n': 'ㄴ', 'h': 'ㅎ', 'f': 'ㅎ', 'b': 'ㅂ', 'p': 'ㅍ', 'm': 'ㅁ', 'r': 'ㄹ', 'y': 'ㅇ', 'w': 'ㅇ'}
_MID = {'k': 'ㅋ', 't': 'ㅌ', 'ch': 'ㅊ'}   # aspirated inside a word
_CHO = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ'
_JUNG = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ'
_JONG = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ',
         'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']


def _block(cho, jung, jong=''):
    return chr(0xAC00 + (_CHO.index(cho) * 21 + _JUNG.index(jung)) * 28 + _JONG.index(jong))


def hangul(h):
    syl = syllables(hira(h))
    out, start, prev_vowel = [], True, ''
    for s in syl:
        if s == ' ':
            out.append(' ')
            start = True
            continue
        if s == 'N' or s == 'Q':
            if out and out[-1] != ' ':
                code = ord(out[-1]) - 0xAC00
                if 0 <= code < 11172 and code % 28 == 0:
                    out[-1] = chr(ord(out[-1]) + _JONG.index('ㄴ' if s == 'N' else 'ㅅ'))
            continue
        if s == '-':
            continue
        m = re.match(r'^(ts|sh|ch|[kgszjtdnhfbpmrywv]?)(y?)([aiueo])$', s)
        if not m:
            continue
        cons, y, v = m.groups()
        if cons == 'y':
            cons, y = '', 'y'
        # Long vowels are not written: おう / おお / うう.
        if cons == '' and not y and ((v == 'u' and prev_vowel in ('o', 'u')) or (v == 'o' and prev_vowel == 'o')):
            continue
        vowel = {'a': 'ㅏ', 'i': 'ㅣ', 'u': 'ㅜ', 'e': 'ㅔ', 'o': 'ㅗ'}[v]
        if (y or cons == 'sh') and v in 'auo':
            vowel = {'a': 'ㅑ', 'u': 'ㅠ', 'o': 'ㅛ'}[v]      # きょ 쿄, しゃ 샤 (じゃ 자, ちゅ 추 stay plain)
        if cons in ('s', 'z', 'ts') and v == 'u':
            vowel = 'ㅡ'                                     # す 스, ず 즈, つ 쓰
        if cons == 'w' and v == 'a':
            vowel = 'ㅘ'
        cho = _INIT[cons] if start or cons not in _MID else _MID[cons]
        out.append(_block(cho, vowel))
        start, prev_vowel = False, v
    return ''.join(out).strip()
