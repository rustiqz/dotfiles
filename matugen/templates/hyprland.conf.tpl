# matugen/templates/hyprland.conf.tpl -> themes/wallpaper/hyprland.conf
#
# Same split as themes/tokyonight/hyprland.conf: Hyprland's own
# compositor properties want hyprlang's native hex-packed rgb()/rgba()
# (no commas, alpha as trailing hex digits), hyprlock wants CSS-style
# comma-separated decimal rgba(). Both format families come straight
# out of matugen's own filters — no manual hex math needed for either.
#
# The `format: "rgba"` filter already returns the whole `rgba(...)`
# wrapper itself (confirmed by testing — wrapping it again produced
# `rgba(rgba(...))`), so hyprlock's lines below do NOT add their own
# rgba() around the expression.

# --- Hyprland compositor (look.conf) ---------------------------------------
$border_active = rgb({{ colors.primary.default.hex_stripped }})
$border_inactive = rgb({{ colors.outline_variant.default.hex_stripped }})
$shadow_color = rgba({{ colors.shadow.default.hex_alpha | to_color | set_alpha: 0.67 | format: "hex_alpha_stripped" }})

# --- hyprlock ----------------------------------------------------------------
# lock_success has no Material You equivalent (no native "success"
# role) — synthesized the same way as kitty.conf.tpl's green ANSI slot
# (primary hue-rotated to 135), so it stays a recognizable "green" no
# matter how muted the source wallpaper is.
$lock_bg = {{ colors.background.default.hex_alpha | to_color | set_alpha: 0.85 | format: "rgba" }}
$lock_accent = {{ colors.primary.default.hex_alpha | to_color | set_alpha: 0.9 | format: "rgba" }}
$lock_accent_dim = {{ colors.primary.default.hex_alpha | to_color | set_alpha: 0.3 | format: "rgba" }}
$lock_success = {{ colors.primary.default.hex_alpha | to_color | set_hue: 135 | set_alpha: 0.9 | format: "rgba" }}
$lock_error = {{ colors.error.default.hex_alpha | to_color | set_alpha: 0.9 | format: "rgba" }}
$lock_fg = rgb({{ colors.on_background.default.red }}, {{ colors.on_background.default.green }}, {{ colors.on_background.default.blue }})
