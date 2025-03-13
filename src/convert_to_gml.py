import os
import json
import shutil
import logging
import re
import math

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger(__name__)

# Project structure
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GML_DIR = os.path.join(PROJECT_ROOT, "GML")
TEXTURE_SHEETS_DIR = os.path.join(PROJECT_ROOT, "Assets", "Texture Sheets")

# Ensure GML folder exists
os.makedirs(GML_DIR, exist_ok=True)

PADDING = 1  # 1px padding on all sides

# Template for GameMaker `.yy` font file
GMFONT_TEMPLATE = {
  "$GMFont":"",
  "%Name":"Font1",
  "AntiAlias":1,
  "applyKerning":0,
  "ascender":0,
  "ascenderOffset":0,
  "bold":False,
  "canGenerateBitmap":True,
  "charset":0,
  "first":0,
  "fontName":"Arial",
  "glyphOperations":0,
  "glyphs":{},
  "hinting":0,
  "includeTTF":False,
  "interpreter":0,
  "italic":False,
  "kerningPairs":[],
  "last":0,
  "lineHeight":0,
  "maintainGms1Font":False,
  "name":"",
  "parent":{
    "name":"EmojiFonts",
    "path":"EmojiFonts.yyp",
  },
  "pointRounding":0,
  "ranges":[],
  "regenerateBitmap":False,
  "resourceType":"GMFont",
  "resourceVersion":"2.0",
  "sampleText":"",
  "sdfSpread":8,
  "size":12.0,
  "styleName":"Regular",
  "textureGroupId":{
    "name":"Default",
    "path":"texturegroups/Default",
  },
  "TTFName":"",
  "usesSDF":False,
}

def to_camel_case(name):
    """Converts a string to CamelCase, removing `_`, `-`, and spaces."""
    words = re.split(r"[_\-\s]+", name)
    return "".join(word.capitalize() for word in words)

# Store the order and resources
resource_order = []
resources = {}

def generate_gml_fonts():
    """Generate GML font folders, `.yy` font files, and GameMaker resource files."""
    order_counter = 1  # Track the order of resources
    resources_list = []  # Store all font resources

    for lite in [False, True]:  # Full and Lite versions
        lite_tag = "Lite" if lite else "Full"
        base_dir = os.path.join(TEXTURE_SHEETS_DIR, lite_tag)

        if not os.path.exists(base_dir):
            log.warning(f"Missing texture sheets directory: {base_dir}")
            continue

        for category in os.listdir(base_dir):
            category_path = os.path.join(base_dir, category)
            if not os.path.isdir(category_path):
                continue  # Skip non-directory entries

            normalized_category = to_camel_case(category)  # Convert to CamelCase

            for size in [16, 24, 32, 48, 64]:  # Texture sizes
                folder_name = f"fnt{normalized_category}_{lite_tag}_{size}"
                font_folder = os.path.join(GML_DIR, folder_name)
                os.makedirs(font_folder, exist_ok=True)

                # Copy the texture sheet
                texture_file = os.path.join(category_path, f"{category}_{size}.png")
                if os.path.exists(texture_file):
                    shutil.copy(texture_file, os.path.join(font_folder, f"{folder_name}.png"))
                    log.info(f"Copied {texture_file} to {font_folder}")
                else:
                    log.warning(f"Missing texture file: {texture_file}")
                    continue

                # Load metadata from the same category folder
                metadata_file = os.path.join(category_path, "metadata.json")
                if not os.path.exists(metadata_file):
                    log.warning(f"Metadata file missing: {metadata_file}")
                    continue
                
                with open(metadata_file, "r", encoding="utf-8") as f:
                    metadata = json.load(f)

                # Determine number of columns dynamically (square layout)
                glyph_count = len(metadata)
                columns = math.ceil(math.sqrt(glyph_count))  # Favor a square layout

                # Generate `.yy` font file
                yy_data = GMFONT_TEMPLATE.copy()
                yy_data["%Name"] = folder_name
                yy_data["name"] = folder_name
                yy_data["fontName"] = normalized_category  # CamelCase font name
                yy_data["size"] = size  # Assign texture size to font size

                # Build glyphs mapping (keys must be integers, not strings)
                yy_data["glyphs"] = {
                    ord(char[0]) if len(char) > 1 else ord(char): {  # Store first Unicode point
                        "character": ord(char[0]) if len(char) > 1 else ord(char),
                        "h": size + (PADDING * 2),  # Add padding to height
                        "offset": 0,
                        "shift": size,  # Keep shift the same as actual glyph size
                        "w": size + (PADDING * 2),  # Add padding to width
                        "x": (metadata[char] % columns) * (size + (PADDING * 2)),  # Adjust x-pos with padding
                        "y": (metadata[char] // columns) * (size + (PADDING * 2))  # Adjust y-pos with padding
                    }
                    for char in metadata
                }

                # Step 1: Extract all unique Unicode codepoints
                unicode_points = sorted(set(yy_data["glyphs"].keys()))

                # Step 2: Generate contiguous ranges
                ranges = []
                start = unicode_points[0]
                prev = start

                for code in unicode_points[1:]:
                    if code != prev + 1:  # If not contiguous, save the previous range
                        ranges.append({"lower": start, "upper": prev})
                        start = code
                    prev = code

                # Step 3: Add the last range
                ranges.append({"lower": start, "upper": prev})

                # Step 4: Ensure the missing glyph (▯) is included
                if not any(r["lower"] <= 9647 <= r["upper"] for r in ranges):
                    ranges.append({"lower": 9647, "upper": 9647})  # GameMaker's default missing character

                # Step 5: Assign the ranges to the `.yy` data
                yy_data["ranges"] = ranges

                # Write `.yy` file
                yy_file = os.path.join(font_folder, f"{folder_name}.yy")
                with open(yy_file, "w", encoding="utf-8") as f:
                    json.dump(yy_data, f, ensure_ascii=False, indent=4)

                log.info(f"Generated {yy_file}")

                # Add to resource_order.json
                resource_order.append({
                    "name": folder_name,
                    "order": order_counter,
                    "path": f"fonts/{folder_name}/{folder_name}.yy"
                })

                # Add to resources.json
                resources_list.append({
                    "id": {
                        "name": folder_name,
                        "path": f"fonts/{folder_name}/{folder_name}.yy"
                    }
                })

                order_counter += 1  # Increment order for the next resource

    # Save resource_order.json
    resource_order_path = os.path.join(GML_DIR, "resource_order.json")
    with open(resource_order_path, "w", encoding="utf-8") as f:
        json.dump(resource_order, f, ensure_ascii=False, indent=4)
    log.info(f"Generated {resource_order_path}")

    # Save resources.json (with all fonts)
    resources_path = os.path.join(GML_DIR, "resources.json")
    with open(resources_path, "w", encoding="utf-8") as f:
        json.dump(resources_list, f, ensure_ascii=False, indent=4)
    log.info(f"Generated {resources_path}")


if __name__ == "__main__":
    generate_gml_fonts()
