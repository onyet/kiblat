import os
from PIL import Image

logo_path = "/Users/onyet/Onyet_Apps/kiblat/assets/images/logo.png"
output_path = "/Users/onyet/Onyet_Apps/kiblat/assets/images/logo_padded.png"

if not os.path.exists(logo_path):
    print(f"Error: logo not found at {logo_path}")
    exit(1)

try:
    # Open original logo
    img = Image.open(logo_path).convert("RGBA")
    w, h = img.size
    print(f"Original logo size: {w}x{h}")
    
    # We want to create a new canvas where the logo occupies about 45% of the size in the center.
    # This creates a perfect padding for Android 12 native splash.
    canvas_size = int(max(w, h) * 2.2) # Pad with transparency
    
    # Create transparent canvas
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # Center position
    offset_x = (canvas_size - w) // 2
    offset_y = (canvas_size - h) // 2
    
    # Paste logo in the center
    canvas.paste(img, (offset_x, offset_y), mask=img)
    
    # Save the padded logo
    canvas.save(output_path, "PNG")
    print(f"Successfully generated padded logo at {output_path} (size: {canvas_size}x{canvas_size})")
except Exception as e:
    print(f"Error generating padded logo: {e}")
