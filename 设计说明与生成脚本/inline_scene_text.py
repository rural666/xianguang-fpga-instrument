"""Replace the sparse 80x30 ASCII grid with a small Verilog case statement."""
from pathlib import Path
import re

root = Path(__file__).parent
rtl = root / "fpga_source" / "rtl" / "studio_scene.v"
data = [int(s, 16) for s in (root / "fpga_source" / "assets" /
                              "scene_text.hex").read_text().splitlines()]
assert len(data) == 80 * 30
lines = ["        dynamic_char=8'h20;", "        case({tile_y,tile_x})"]
for pos, value in enumerate(data):
    if value != 32:
        row, col = divmod(pos, 80)
        lines.append(f"            12'd{row * 128 + col}:dynamic_char=8'h{value:02X};")
lines += ["            default:;", "        endcase"]
source = rtl.read_text(encoding="utf-8")
source = source.replace("    reg [7:0] text_rom[0:2399];\n", "")
source = source.replace('        $readmemh("assets/scene_text.hex",text_rom);\n', "")
placeholder = "        dynamic_char=text_rom[tile_addr<2400?tile_addr:0];"
if placeholder in source:
    source = source.replace(placeholder, "\n".join(lines))
else:
    source, count = re.subn(
        r"        dynamic_char=8'h20;\n        case\(\{tile_y,tile_x\}\).*?        endcase",
        lambda _: "\n".join(lines), source, count=1, flags=re.S,
    )
    assert count == 1, "Could not locate the static label table"
assert "case({tile_y,tile_x})" in source
rtl.write_text(source, encoding="utf-8")
print(f"Inlined {len(lines)-3} text cells")
