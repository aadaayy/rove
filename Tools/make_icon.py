"""Draws Rove's app icon: a white map pin at the end of a dotted route, on teal.
Run: python3 Tools/make_icon.py (needs Pillow)."""
from PIL import Image, ImageDraw, ImageFilter
import math

S = 1024
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, bottom = (24, 170, 150), (10, 105, 112)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))

# Pin: a circle and the two lines from its tip that just touch the circle.
cx, cy, r = 600, 390, 185
tip = (cx, cy + r * 2.05)
dist = tip[1] - cy
half = math.asin(r / dist)
left, right = (cx - r * math.cos(half), cy + r * math.sin(half)), (cx + r * math.cos(half), cy + r * math.sin(half))

# Dotted route arriving at the pin's tip.
points = []
for i in range(0, 101):
    t = i / 100
    x = 170 + (tip[0] - 60 - 170) * t
    y = 820 + (tip[1] + 10 - 820) * t + 110 * math.sin(t * math.pi)
    points.append((x, y))
for i in range(0, len(points), 10):
    x, y = points[i]
    d.ellipse([x - 17, y - 17, x + 17, y + 17], fill=(255, 255, 255))

shadow = Image.new("L", (S, S), 0)
sd = ImageDraw.Draw(shadow)
off = 26
sd.ellipse([cx - r, cy - r + off, cx + r, cy + r + off], fill=110)
sd.polygon([(left[0], left[1] + off), (right[0], right[1] + off), (tip[0], tip[1] + off)], fill=110)
shadow = shadow.filter(ImageFilter.GaussianBlur(28))
img.paste((0, 60, 60), (0, 0), shadow)
d = ImageDraw.Draw(img)
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255))
d.polygon([left, right, tip], fill=(255, 255, 255))
d.ellipse([cx - 72, cy - 72, cx + 72, cy + 72], fill=(17, 136, 122))
img.save("Rove/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
