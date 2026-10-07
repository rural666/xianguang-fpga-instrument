"""Build the small bitmap ROMs used by the hardware HDMI renderer."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
assets = root / "assets"
assets.mkdir(exist_ok=True)

font = ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", 13)
rows = []
for code in range(128):
    tile = Image.new("L", (8, 16), 0)
    draw = ImageDraw.Draw(tile)
    if 32 <= code < 127:
        draw.text((0, -1), chr(code), font=font, fill=255, stroke_width=0)
    for y in range(16):
        bits = 0
        for x in range(8):
            bits = (bits << 1) | (tile.getpixel((x, y)) >= 90)
        rows.append(bits)
(assets / "font8x16.hex").write_text("\n".join(f"{x:02x}" for x in rows) + "\n", encoding="ascii")

text = [" " * 80 for _ in range(23)]
def put(y, x, value):
    line = list(text[y])
    for i, ch in enumerate(value):
        if x + i < 80:
            line[x + i] = ch
    text[y] = "".join(line)

put(1, 3, "XIAN GUANG / FPGA PERFORMANCE SYSTEM")
put(1, 60, "HDMI 720P60")
put(2, 13, "XIANGUANG")
put(3, 13, "FPGA INSTRUMENT")
put(3, 64, "LIVE")
put(6, 4, "PERFORMANCE / 12 VOICES")
put(13, 4, "PLAY  A W S E D F T G Y H U J")
put(16, 3, "01 / SOFT PIANO")
put(16, 31, "VOL 100%")
put(16, 45, "OCT 04")
put(16, 58, "POSE OFF")
put(16, 70, "SPACE ON")
put(19, 10, "C")
put(19, 19, "D")
put(19, 29, "E")
put(19, 38, "F")
put(19, 48, "G")
put(19, 57, "A")
put(19, 66, "B")
put(18, 17, "W")
put(18, 26, "E")
put(18, 45, "T")
put(18, 54, "Y")
put(18, 63, "U")
put(21, 4, "A W S E D F T G Y H U J  /  1-8 TIMBRE  /  F2 DEMO  /  F5 RESET")
(assets / "scene_text.hex").write_text("\n".join(f"{ord(ch):02x}" for line in text for ch in line) + "\n", encoding="ascii")

labels = [
    "SOFT PIANO", "BRIGHT PIANO", "PURE SINE", "TRIANGLE",
    "ORGAN", "REED", "SOFT SQUARE", "SOFT SAW",
]
(assets / "timbre_text.hex").write_text(
    "\n".join(f"{ord(ch):02x}" for line in labels for ch in line.ljust(16)) + "\n", encoding="ascii")

zh_font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 30)
logo = Image.new("L", (64, 32), 0)
ImageDraw.Draw(logo).text((0, -4), "弦光", font=zh_font, fill=255)
words = []
for y in range(32):
    for start in range(0, 64, 8):
        value = 0
        for x in range(start, start + 8):
            value = (value << 1) | (logo.getpixel((x, y)) > 95)
        words.append(value)
(assets / "brand64x32.hex").write_text("\n".join(f"{x:02x}" for x in words) + "\n", encoding="ascii")
logo.save(assets / "brand_reference.png")
print("Generated font, text, timbre and Chinese title ROMs")
