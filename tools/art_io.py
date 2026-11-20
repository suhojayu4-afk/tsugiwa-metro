"""Saving the app's pictures. The app's scene, train, people, widget and
other art is lossless WebP (assets/art/**/*.webp): pixel-identical to the
PNG it replaced, but much smaller. A plain PIL save of a .webp would be
lossy, so every tool that writes app art goes through save_art.

  from art_io import save_art
  save_art(im, 'assets/art/scenes/tokyo_day.webp')
"""
import os


def save_art(im, path, **png_options):
    """Saves [im] at [path]: lossless WebP for .webp (exact=True keeps even
    the colour of fully transparent pixels), else PIL's usual save."""
    if os.fspath(path).lower().endswith('.webp'):
        if im.mode not in ('RGB', 'RGBA'):
            im = im.convert('RGBA')
        im.save(path, 'WEBP', lossless=True, quality=100, method=6, exact=True)
    else:
        im.save(path, **png_options)
