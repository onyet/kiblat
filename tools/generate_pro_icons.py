import os
import math
from PIL import Image, ImageDraw, ImageFont

# Path of the Android resource directory
res_dir = "/Users/onyet/Onyet_Apps/kiblat/android/app/src/main/res"

# Standard fonts available on macOS
system_fonts = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
]

def get_font(size):
    for path in system_fonts:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_pro_badge(img_path, out_path, is_adaptive_foreground=False):
    if not os.path.exists(img_path):
        return False
    
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    draw = ImageDraw.Draw(img)
    
    # Calculate badge parameters based on image size
    # For adaptive foreground, the logo might be centered and we place the badge
    # inside the safe viewport zone (radius ~0.33 * w) to avoid clipping.
    if is_adaptive_foreground:
        # Top-right inside the safe circle zone (centered at w/2, h/2 with radius 0.33*w)
        # Position is (w/2 + r * cos(45deg), h/2 - r * sin(45deg))
        # r = 0.32 * w => offset = 0.226 * w
        cx = int(w * 0.70)
        cy = int(h * 0.30)
        radius = int(w * 0.12)
    else:
        # For legacy legacy full icons, we can place it near the top-right corner
        cx = int(w * 0.82)
        cy = int(h * 0.18)
        radius = int(w * 0.14)
        
    # Draw gold circular badge background with thin dark border
    gold_color = (212, 175, 55, 255) # #D4AF37 Gold
    dark_border_color = (40, 30, 10, 255)
    
    # Draw shadow / outer border
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=gold_color, outline=dark_border_color, width=max(1, int(w * 0.015)))
    
    # Draw text "PRO"
    text = "PRO"
    # Find font size that fits the badge
    font_size = int(radius * 0.9)
    font = get_font(font_size)
    
    # Measure text to center it
    try:
        # Pillow 10.0.0+ has getbbox
        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
    except AttributeError:
        # Older Pillow fallback
        tw, th = draw.textsize(text, font=font)
        
    tx = cx - tw / 2
    ty = cy - th / 2 - (th * 0.1) # slight adjustment for baseline
    
    draw.text((tx, ty), text, fill=(255, 255, 255, 255), font=font)
    
    img.save(out_path, "PNG")
    print(f"Generated Pro badge icon: {out_path} ({w}x{h})")
    return True

def generate_all_icons():
    # Process mipmap folders
    for folder_name in os.listdir(res_dir):
        if not folder_name.startswith("mipmap-"):
            continue
        
        folder_path = os.path.join(res_dir, folder_name)
        if not os.path.isdir(folder_path):
            continue
            
        # 1. Legacy Launcher Icon
        legacy_src = os.path.join(folder_path, "ic_launcher.png")
        legacy_out = os.path.join(folder_path, "ic_launcher_pro.png")
        draw_pro_badge(legacy_src, legacy_out, is_adaptive_foreground=False)
        
        # 2. Adaptive Launcher Foreground
        fg_src = os.path.join(folder_path, "ic_launcher_foreground.png")
        fg_out = os.path.join(folder_path, "ic_launcher_foreground_pro.png")
        draw_pro_badge(fg_src, fg_out, is_adaptive_foreground=True)
        
        # 3. Adaptive Monochrome Launcher (optional but good to have if monochromatic is used)
        mono_src = os.path.join(folder_path, "ic_launcher_monochrome.png")
        mono_out = os.path.join(folder_path, "ic_launcher_monochrome_pro.png")
        draw_pro_badge(mono_src, mono_out, is_adaptive_foreground=True)

    # 4. Generate Adaptive XML file for PRO icon
    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    if os.path.exists(anydpi_dir):
        xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@mipmap/ic_launcher_background"/>
  <foreground android:drawable="@mipmap/ic_launcher_foreground_pro"/>
  <monochrome android:drawable="@mipmap/ic_launcher_monochrome_pro"/>
</adaptive-icon>
"""
        xml_path = os.path.join(anydpi_dir, "ic_launcher_pro.xml")
        with open(xml_path, "w") as f:
            f.write(xml_content)
        print(f"Generated adaptive XML: {xml_path}")

if __name__ == "__main__":
    generate_all_icons()
