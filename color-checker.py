#!/usr/bin/env python3

import hashlib
import time
import os
import subprocess

# Function to calculate the md5 hash of a file
def md5sum(filepath):
    with open(filepath, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()

# Function to convert RGB values to hex
def rgb2hex(r, g, b):
    return '{:02x}{:02x}{:02x}'.format(r, g, b)

# Function to format RGB values for CSS
def num2css(r, g, b):
    return f'{r}, {g}, {b}'

# Function to replace a line in a file
def replace_line_in_file(filepath, search_term, new_line):
    with open(filepath, 'r') as file:
        lines = file.readlines()
    with open(filepath, 'w') as file:
        for line in lines:
            if search_term in line:
                file.write(new_line + '\n')
            else:
                file.write(line)

# Main loop to check for changes and update colors
def main():
    home = os.path.expanduser("~")
    color_file = os.path.join(home, ".config/castle-shell/accent-color")
    hypr_conf_file = os.path.join(home, ".config/hypr/custom/looks.conf")
    kitty_conf_file = os.path.join(home, ".config/kitty/kitty.conf")
    css_file = os.path.join(home, ".config/castle-shell/colors.css")
    rasi_file = os.path.join(home, ".config/castle-shell/colors.rasi")

    current_hash = md5sum(color_file)

    while True:
        time.sleep(0.25)
        new_hash = md5sum(color_file)
        if new_hash == current_hash:
            continue
        current_hash = new_hash

        # Read the RGB values from the color file
        with open(color_file, 'r') as f:
            lines = f.readlines()
        out_prime = list(map(int, lines[0].strip().split()))
        out_alt = list(map(int, lines[1].strip().split()))

        # Convert RGB values to hex and CSS formats
        hex_prime = rgb2hex(*out_prime)
        hex_alt = rgb2hex(*out_alt)
        css_prime = num2css(*out_prime)
        css_alt = num2css(*out_alt)

        print(f'Converted colors - Hex Prime: {hex_prime}, Hex Alt: {hex_alt}')
        print(f'CSS Prime: {css_prime}, CSS Alt: {css_alt}')

        # Update Hyprland configuration
        try:
            hypr_colors = {
                "col.active_border =": f'    col.active_border = rgba({hex_prime}a6)',
                "col.inactive_border =": f'    col.inactive_border = rgba({hex_alt}8c)',
                "bar_color =": f'    bar_color = rgba({hex_alt}8c)',
                "col.active =": f'    col.active = rgba({hex_prime}a6)',
                "col.inactive =": f'    col.inactive = rgba({hex_alt}8c)',
            }
            for key, value in hypr_colors.items():
                replace_line_in_file(hypr_conf_file, key, value)
            print(f'Updated Hyprland configuration')
        except Exception as e:
            print(f'Error updating Hyprland configuration: {e}')
            continue

        # Update Foot configuration
        try:
            replace_line_in_file(kitty_conf_file, "background #", f'background #{hex_alt}')
            print(f'Updated Kitty configuration')
        except Exception as e:
            print(f'Error updating Kitty configuration: {e}')
            continue

        # Generate CSS file
        css_content = f"""
@define-color primaryColor rgba({css_prime}, 0.5);
@define-color secondaryColor rgba({css_alt}, 0.35);
@define-color secondaryColorDark rgba({css_alt}, 0.45);
@define-color secondaryColorDarker rgba({css_alt}, 0.6);
@define-color textColor rgba(255, 255, 255, 1);
"""
        with open(css_file, 'w') as f:
            f.write(css_content)

        # Generate Rasi file
        rasi_content = f"""
* {{
    primaryColor: rgba({css_prime}, 0.5);
    secondaryColor: rgba({css_alt}, 0.35);
    secondaryColorDark: rgba({css_alt}, 0.45);
    secondaryColorDarker: rgba({css_alt}, 0.6);
    textColor: rgba(255, 255, 255, 1);
}}
"""
        with open(rasi_file, 'w') as f:
            f.write(rasi_content)

        # Restart services
        subprocess.run(["systemctl", "restart", "--user", "waybar-hyprland.service"])
        subprocess.run(["systemctl", "restart", "--user", "swaync.service"])

        # Print updated colors for debugging
        print(f'Primary CSS Color: rgba({css_prime}, 0.5)')
        print(f'Secondary CSS Color: rgba({css_alt}, 0.35)')
        print(f'Dark Secondary CSS Color: rgba({css_alt}, 0.45)')
        print(f'Darker Secondary CSS Color: rgba({css_alt}, 0.6)')
        print(f'Hyprland Primary Color: rgba({hex_prime}a6)')
        print(f'Hyprland Secondary Color: rgba({hex_alt}8c)')

if __name__ == "__main__":
    main()

