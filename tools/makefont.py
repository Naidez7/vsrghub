# Makes an Etterna bitmap font (doubleres, logical 24px like Til Death's Common Normal) from a
# TTF/WOFF file: python3 tools/makefont.py <font file> <out dir> <name> [logical px] [line spacing]
# (a larger logical size, e.g. 48, makes a sharper copy for big text: drawn at half the zoom)
# Optional: CHARS=<characters> COLS=<n> in the environment for a font of only those characters.
import sys, math, os
from PIL import Image, ImageDraw, ImageFont
src, outdir, name = sys.argv[1], sys.argv[2], sys.argv[3]
LOGICAL = int(sys.argv[4]) if len(sys.argv) > 4 else 24
SPACING = float(sys.argv[5]) if len(sys.argv) > 5 else 1.3
SRC = LOGICAL * 2
font = ImageFont.truetype(src, SRC)
chars = [chr(c) for c in range(32, 127)] + [chr(c) for c in range(160, 256)]
if os.environ.get("CHARS"):
    chars = list(dict.fromkeys(os.environ["CHARS"]))
COLS = int(os.environ.get("COLS", "16"))
rows = math.ceil(len(chars) / COLS)
asc, desc = font.getmetrics()
adv = {c: font.getlength(c) for c in chars}
maxw = 0
for c in chars:
    l, t, r, b = font.getbbox(c)
    maxw = max(maxw, r - l, adv[c])
pad = 8
cw = int(math.ceil(maxw + pad * 2))
cw += cw % 2
ch = asc + desc + pad * 2
ch += ch % 2
img = Image.new("RGBA", (cw * COLS, ch * rows), (255, 255, 255, 0))
d = ImageDraw.Draw(img)
widths = []
for i, c in enumerate(chars):
    col, row = i % COLS, i // COLS
    a = adv[c]
    # the logical advance rounded to the nearest whole unit (rounding every letter up made text
    # spread out unevenly), and the letter centred on its true advance in its cell: Etterna centres
    # each cell on its rounded advance, so the rounding is shared out on both sides of the letter
    widths.append(max(1, int(round(a / 2))) if a > 0 else 0)
    x = col * cw + (cw - a) / 2
    y = row * ch + pad
    d.text((x, y), c, font=font, fill=(255, 255, 255, 255))
os.makedirs(outdir, exist_ok=True)
img.save(os.path.join(outdir, f"{name} [main] {COLS}x{rows} (doubleres).png"))
baseline = (pad + asc) // 2
capl, capt, capr, capb = font.getbbox("H")
top = (pad + capt) // 2
lines = ["[common]", f"Baseline={baseline}", f"Top={top}", f"LineSpacing={int(round(LOGICAL * SPACING))}",
         "DrawExtraPixelsLeft=1", "DrawExtraPixelsRight=1", "AdvanceExtraPixels=0", "", "[main]",
         "import=bokutachinogothic2bold/doubleres/24px"]
for r in range(rows):
    lines.append(f"Line {r}=" + "".join(chars[r * COLS:(r + 1) * COLS]))
lines.append("")
for i, w in enumerate(widths):
    lines.append(f"{i}={w}")
open(os.path.join(outdir, f"{name}.ini"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(name, img.size, "cap", (capb - capt) / 2, "cell", cw, ch, "baseline", baseline, "top", top)
