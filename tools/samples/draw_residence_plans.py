"""Draw the two block plans the residence sample imports as floorplan pages.

The sample's room layout was taken from a reference plan whose own title block
forbids republishing it, so this script draws a NEW picture from room
positions alone: one outline and one name per room, a scale bar, and nothing
of the reference's linework, furniture, dimensions or title block. That is what
lets the sample, its PDF and its screenshots be public.

Geometry lives in apps/rackpal/tool/samples/residence_geometry.json, which the
Dart builder reads too, so a pin and the room it sits in cannot drift apart.

Run from the repository root:
    python tools/samples/draw_residence_plans.py
"""

import json
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
SAMPLES = ROOT / "apps" / "rackpal" / "tool" / "samples"
FONT = ROOT / "apps" / "rackpal" / "assets" / "fonts" / "Jost-Regular.ttf"
FONT_MEDIUM = ROOT / "apps" / "rackpal" / "assets" / "fonts" / "Jost-Medium.ttf"

INK = (40, 40, 40)
OUTDOOR = (150, 150, 150)
FILL_OUTDOOR = (246, 246, 243)


def main() -> None:
    geometry = json.loads((SAMPLES / "residence_geometry.json").read_text())
    scale = geometry["pxPerMetre"]
    house = geometry["houseWidthMetres"]
    ou, ov = geometry["originMetres"]
    margin = geometry["marginPx"]
    width, height = geometry["sizePx"]
    (bar_x0, bar_y), (bar_x1, _) = geometry["scaleBarPx"]

    # Front of the house to the right, so a landscape sheet prints it large.
    # The Dart builder applies the same transform to every pin and outline.
    def px(point):
        x, y = point
        return (
            round(margin + (y - ou) * scale),
            round(margin + (house - x - ov) * scale),
        )

    code = ImageFont.truetype(str(FONT), 20)
    title = ImageFont.truetype(str(FONT_MEDIUM), 40)
    small = ImageFont.truetype(str(FONT), 20)

    for page in geometry["pages"]:
        image = Image.new("RGB", (width, height), "white")
        draw = ImageDraw.Draw(image)
        rooms = page["rooms"]
        # Outdoor spaces first so interior walls draw over their edges.
        ordered = sorted(rooms, key=lambda r: 0 if r.get("outdoor") else 1)
        for room in ordered:
            points = [px(p) for p in room["poly"]]
            if room.get("outdoor"):
                draw.polygon(points, fill=FILL_OUTDOOR)
                _dashed(draw, points + [points[0]], OUTDOOR, 3)
            elif room.get("void"):
                _dashed(draw, points + [points[0]], OUTDOOR, 3)
                a, b, c, d = points[0], points[1], points[2], points[3]
                draw.line([a, c], fill=OUTDOOR, width=2)
                draw.line([b, d], fill=OUTDOOR, width=2)
            else:
                draw.polygon(points, outline=INK, width=8)
        for room in rooms:
            points = [px(p) for p in room["poly"]]
            if "labelAt" in room:
                cx, cy = px(room["labelAt"])
                room_width = room["labelWidth"] * scale
            else:
                xs = [p[0] for p in points]
                ys = [p[1] for p in points]
                # Near the top of the room, so a pin at its centre (a
                # ceiling speaker, an access point) never covers the name.
                cx, cy = (min(xs) + max(xs)) // 2, min(ys) + 48
                room_width = max(xs) - min(xs)
            colour = OUTDOOR if room.get("outdoor") or room.get("void") else INK
            lines, font = _fit(draw, room.get("label", room["name"].upper()), room_width - 24)
            block = len(lines) * (font.size + 4)
            top = cy - block / 2 - 10
            for i, line in enumerate(lines):
                _centred(draw, (cx, top + i * (font.size + 4) + font.size / 2), line, font, colour)
            _centred(draw, (cx, top + block + 12), room["code"], code, OUTDOOR)

        # Scale bar: five metres, so a calibration can be checked by eye.
        x0 = bar_x0
        x1 = bar_x1
        draw.line([(x0, bar_y), (x1, bar_y)], fill=INK, width=6)
        for metre in range(6):
            tick = x0 + metre * scale
            draw.line([(tick, bar_y - 12), (tick, bar_y + 12)], fill=INK, width=3)
        draw.text((x0, bar_y + 18), "0", font=small, fill=INK)
        draw.text((x1 - 34, bar_y + 18), "5 m", font=small, fill=INK)
        draw.text((x1 + 60, bar_y - 26), page["title"], font=title, fill=INK)
        draw.text(
            (x1 + 60, bar_y + 20),
            "Block plan drawn for the RackPal sample project. Not to be built from.",
            font=small,
            fill=OUTDOOR,
        )
        out = SAMPLES / f"plan_{page['key'].lower()}.png"
        image.save(out, optimize=True)
        print(f"written {out.relative_to(ROOT)} {image.size}")


def _fit(draw, text, width):
    """The largest font, on one to three lines, that fits [width]."""
    words = text.split(" ")
    for lines_wanted in (1, 2, 3):
        if lines_wanted > len(words):
            break
        lines = _split(words, lines_wanted)
        for size in range(26, 13, -1):
            font = ImageFont.truetype(str(FONT), size)
            if all(_width(draw, line, font) <= width for line in lines):
                return lines, font
    return [text], ImageFont.truetype(str(FONT), 14)


def _split(words, n):
    if n == 1:
        return [" ".join(words)]
    per = -(-len(words) // n)
    return [" ".join(words[i:i + per]) for i in range(0, len(words), per)]


def _width(draw, text, font):
    left, _, right, _ = draw.textbbox((0, 0), text, font=font)
    return right - left


def _centred(draw, at, text, font, fill):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    draw.text(
        (at[0] - (right - left) / 2 - left, at[1] - (bottom - top) / 2 - top),
        text,
        font=font,
        fill=fill,
    )


def _dashed(draw, points, fill, width, dash=14, gap=10):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        length = ((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5
        if length == 0:
            continue
        step = dash + gap
        n = int(length // step) + 1
        for i in range(n):
            s = i * step / length
            e = min((i * step + dash) / length, 1.0)
            draw.line(
                [(x0 + (x1 - x0) * s, y0 + (y1 - y0) * s),
                 (x0 + (x1 - x0) * e, y0 + (y1 - y0) * e)],
                fill=fill,
                width=width,
            )


if __name__ == "__main__":
    main()
