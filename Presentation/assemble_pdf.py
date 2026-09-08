#!/usr/bin/env python3
"""Assemble a directory of full-bleed slide PNGs into one PDF.

Used internally by export_pdf.mjs; requires PyMuPDF (`pip install pymupdf`).

Usage:
    python3 assemble_pdf.py <png_dir> <output.pdf> <slide_width_px> <slide_height_px>
"""
import sys
import glob
import os

import fitz  # PyMuPDF


def main():
    png_dir, out_path, width_px, height_px = sys.argv[1:5]
    width_px, height_px = int(width_px), int(height_px)

    pngs = sorted(glob.glob(os.path.join(png_dir, "slide-*.png")))
    if not pngs:
        raise SystemExit(f"No slide-*.png files found in {png_dir}")

    # Page size in PDF points (1pt = 1/72in) from the deck's native pixel
    # canvas at 96 px/in, so one output page == one on-screen slide 1:1.
    page_w, page_h = width_px / 96 * 72, height_px / 96 * 72

    doc = fitz.open()
    for png in pngs:
        page = doc.new_page(width=page_w, height=page_h)
        page.insert_image(fitz.Rect(0, 0, page_w, page_h), filename=png)
    doc.save(out_path, garbage=4, deflate=True)
    print(f"Wrote {out_path} ({len(pngs)} pages, {os.path.getsize(out_path)} bytes)")


if __name__ == "__main__":
    main()
