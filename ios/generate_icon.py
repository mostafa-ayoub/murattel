from PIL import Image, ImageDraw
import math

size = 1024
img = Image.new('RGBA', (size, size), (11, 15, 20, 255))
draw = ImageDraw.Draw(img)
cx, cy = size // 2, size // 2

# Subtle radial glow
for r in range(450, 0, -1):
    t = 1 - r / 450
    br = int(30 * t)
    c = (11 + br, 15 + br, 20 + br // 2)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)

# Outer decorative ring (dashed effect)
ring_r = 340
for angle in range(0, 360, 4):
    if (angle // 4) % 2 == 0:
        rad = math.radians(angle)
        x1 = cx + int(ring_r * math.cos(rad))
        y1 = cy + int(ring_r * math.sin(rad))
        rad2 = math.radians(angle + 2)
        x2 = cx + int(ring_r * math.cos(rad2))
        y2 = cy + int(ring_r * math.sin(rad2))
        draw.line([(x1, y1), (x2, y2)], fill=(201, 169, 74, 60), width=2)

# Gold crescent moon - large and centered
moon_r = 260
draw.ellipse([cx - moon_r, cy - moon_r, cx + moon_r, cy + moon_r], fill=(201, 169, 74))

# Cut out to make crescent shape
cut_r = 220
cut_offset_x = 110
cut_offset_y = -20
draw.ellipse([cx - cut_r + cut_offset_x, cy - cut_r + cut_offset_y, 
              cx + cut_r + cut_offset_x, cy + cut_r + cut_offset_y], 
             fill=(19, 25, 32))

# Inner glow on the crescent
for g in range(8, 0, -1):
    brightness = int(15 * (1 - g / 8))
    draw.ellipse([cx - moon_r + g, cy - moon_r + g, cx + moon_r - g, cy + moon_r - g], 
                 outline=(201 + brightness, 169 + brightness, 74 + brightness))

# Small star dots
import random
random.seed(42)
for _ in range(8):
    sx = random.randint(80, size - 80)
    sy = random.randint(80, size - 80)
    dist = math.sqrt((sx - cx)**2 + (sy - cy)**2)
    if dist > 370:
        s = random.randint(2, 5)
        draw.ellipse([sx-s, sy-s, sx+s, sy+s], fill=(201, 169, 74, 120))

# Convert to RGB (no alpha for app icon)
final = Image.new('RGB', (size, size), (11, 15, 20))
final.paste(img, mask=img.split()[3])
final.save('/Users/moustafaayoub/Desktop/Новая папка 3/MurattelXcode/icon_1024.png', 'PNG')
print("Icon created!")
