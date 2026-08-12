# matugen/templates/kitty.conf.tpl -> themes/wallpaper/kitty.conf
#
# Material You roles for the structural slots (fg/bg/selection/tabs/
# borders), same pattern as themes/tokyonight/kitty.conf's own choices.
#
# The 16 ANSI colors are NOT extracted from the image directly —
# matugen's base16 backend was tested against this machine's own
# generated wallpaper and degenerated to near-monochrome (confirmed:
# base08-0f, which should be red/orange/yellow/green/cyan/blue/magenta/
# brown, all came back within a few hex digits of pure background gray)
# because the source image simply doesn't have 16 distinguishable
# regions of color. Raw extraction is inherently unreliable for
# low-chroma wallpapers — pywal has the same well-known limitation.
#
# Instead, all 6 chromatic ANSI slots are synthesized by hue-rotating
# `primary` to fixed target hues (red/yellow/green/cyan/blue/magenta on
# the HSL wheel), except red, which uses the real `error` role directly
# since Material You's error role is already semantically "red/alert."
# This guarantees 6 visually distinct, adequately-saturated colors
# every time, regardless of how muted the wallpaper itself is, and
# keeps them tonally related (same source hue family) rather than
# arbitrary.
foreground              {{ colors.on_background.default.hex }}
background              {{ colors.background.default.hex }}
selection_foreground    {{ colors.on_primary_container.default.hex }}
selection_background    {{ colors.primary_container.default.hex }}
url_color                {{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }}
cursor                  {{ colors.on_background.default.hex }}
cursor_text_color       {{ colors.background.default.hex }}

# Tabs
active_tab_foreground   {{ colors.on_primary.default.hex }}
active_tab_background   {{ colors.primary.default.hex }}
inactive_tab_foreground {{ colors.on_surface_variant.default.hex }}
inactive_tab_background {{ colors.surface_container.default.hex }}
tab_bar_background      {{ colors.surface_container_lowest.default.hex }}

# Window borders
active_border_color     {{ colors.primary.default.hex }}
inactive_border_color   {{ colors.outline_variant.default.hex }}

# black
color0  {{ colors.surface_container_lowest.default.hex }}
color8  {{ colors.outline.default.hex }}

# red — real `error` role, not synthesized (Material You's error is
# already semantically red)
color1  {{ colors.error.default.hex }}
color9  {{ colors.error.default.hex }}

# green (hue 135)
color2  {{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}
color10 {{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}

# yellow (hue 50)
color3  {{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}
color11 {{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}

# blue (hue 250)
color4  {{ colors.primary.default.hex | to_color | set_hue: 250 | format: "hex" }}
color12 {{ colors.primary.default.hex | to_color | set_hue: 250 | format: "hex" }}

# magenta (hue 300)
color5  {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}
color13 {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}

# cyan (hue 190) — same expression as url_color above, so links in the
# terminal visually match the cyan ANSI slot
color6  {{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }}
color14 {{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }}

# white
color7  {{ colors.on_surface_variant.default.hex }}
color15 {{ colors.on_background.default.hex }}
