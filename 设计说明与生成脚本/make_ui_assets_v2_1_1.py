"""Build monochrome masks and labels for the single-row 640x480 piano."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent / "fpga_source" / "assets"
FONTS = Path(r"C:\Windows\Fonts")

def text(draw, xy, value, name, size):
    draw.text(xy, value, font=ImageFont.truetype(str(FONTS / name), size), fill=255)

def save_mask(img, path):
    out = []
    for y in range(img.height):
        for x in range(0, img.width, 8):
            out.append(f"{sum((0x80 >> b) for b in range(8) if img.getpixel((x+b,y)) >= 100):02X}")
    path.write_text("\n".join(out) + "\n", encoding="ascii")

top = Image.new("L", (640, 128), 0)
d = ImageDraw.Draw(top)
text(d, (32, 14), "弦光", "STSONG.TTF", 22)
text(d, (90, 24), "X I A N   G U A N G", "BOD_R.TTF", 10)
text(d, (330, 21), "双 八 度  /  实 时 演 奏", "simsun.ttc", 11)
text(d, (32, 51), "音色", "simsun.ttc", 12)
text(d, (126, 53), "轻触切换", "simsun.ttc", 10)
text(d, (338, 51), "音量", "simsun.ttc", 12)
text(d, (460, 51), "八度", "simsun.ttc", 12)
text(d, (552, 51), "速度", "simsun.ttc", 12)
text(d, (305, 82), "-", "simsun.ttc", 18)
text(d, (412, 82), "+", "simsun.ttc", 18)
text(d, (444, 82), "-", "simsun.ttc", 18)
text(d, (511, 82), "+", "simsun.ttc", 18)
save_mask(top, ROOT / "ui_top_640x128.hex")
top.save(ROOT / "ui_top_preview.png")

titles = Image.new("L", (224, 40 * 8), 0)
d = ImageDraw.Draw(titles)
names = ["柔和钢琴", "明亮钢琴", "纯净正弦", "柔和三角", "暖色弦音", "复古风琴", "空灵笛音", "明亮合成"]
for i, name in enumerate(names):
    text(d, (0, i*40-3), name, "STSONG.TTF", 36)
save_mask(titles, ROOT / "ui_timbres_224x320.hex")

grid = [[" " for _ in range(80)] for _ in range(30)]
def write(row, col, value):
    for i, ch in enumerate(value):
        if 0 <= col+i < 80:
            grid[row][col+i] = ch

write(3, 9, "01")
write(7, 4, "TOUCH / KEYBOARD")
write(8, 4, "SONG 01")
write(8, 16, "TWINKLE")
for i, (name, key) in enumerate(zip(["C","D","E","F","G","A","B"]*2, "ZXCVBNMQWERTYU")):
    write(24, 6+5*i, name+("4" if i<7 else "5"))
    write(25, 7+5*i, key)
for x, name, key in zip([68,108,188,228,268,348,388,468,508,548], ["C#","D#","F#","G#","A#"]*2, "SDGHJ23567"):
    write(19, x//8+1, name)
    write(20, x//8+1, key)
for col, label in zip([5,18,27,38,49,61,71], ["PREV","PLAY","NEXT","REC","BEAT","-5","+5"]):
    write(28, col, label)
(ROOT / "scene_text.hex").write_text("\n".join(f"{ord(ch):02X}" for row in grid for ch in row)+"\n", encoding="ascii")
print("Generated single-row UI masks and key labels")
