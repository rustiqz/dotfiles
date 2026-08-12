/* matugen/templates/swaync.css.tpl -> themes/wallpaper/swaync.css
 *
 * Redeclares the same :root custom properties style.css's structural
 * rules already read from (GTK4 supports :root/var(), unlike waybar's
 * GTK3 — see themes/tokyonight/waybar.css) — same mechanism as
 * themes/tokyonight/swaync.css and themes/f1/swaync.css, just
 * generated instead of hand-written.
 *
 * Three different decimal shapes below aren't a typo: --noti-bg is a
 * bare "R, G, B" triplet with no rgb()/rgba() wrapper (the stock
 * style.css itself wraps it, e.g. `rgba(var(--noti-bg), var(--noti-bg-
 * alpha))`), while the others are fully self-contained rgb()/rgba()
 * strings. Matched exactly against what themes/tokyonight/swaync.css
 * already uses for each variable.
 */

:root {
  --cc-bg: {{ colors.background.default.hex_alpha | to_color | set_alpha: 0.92 | format: "rgba" }};
  --noti-border-color: {{ colors.outline_variant.default.hex_alpha | to_color | set_alpha: 0.6 | format: "rgba" }};
  --noti-bg: {{ colors.surface_container.default.red }}, {{ colors.surface_container.default.green }}, {{ colors.surface_container.default.blue }};
  --noti-bg-alpha: 0.92;
  --noti-bg-darker: {{ colors.surface_container_lowest.default.rgb }};
  --noti-bg-hover: {{ colors.surface_container_high.default.rgb }};
  --noti-bg-focus: {{ colors.surface_container_highest.default.hex_alpha | to_color | set_alpha: 0.6 | format: "rgba" }};
  --noti-close-bg: {{ colors.surface_container_high.default.rgb }};
  --noti-close-bg-hover: {{ colors.error.default.rgb }};
  --text-color: {{ colors.on_background.default.rgb }};
  --text-color-disabled: {{ colors.on_surface_variant.default.rgb }};
  --bg-selected: {{ colors.primary.default.rgb }};
}

* {
  font-family: "JetBrainsMono Nerd Font", monospace;
}

.notification-row .notification-background .notification.critical {
  border-left: 3px solid {{ colors.error.default.hex }};
}

.widget-title {
  border-bottom: 2px solid {{ colors.primary.default.hex }};
  padding-bottom: 8px;
}

.widget-dnd switch:checked {
  background-color: {{ colors.primary.default.hex }};
}

.widget-dnd switch:checked slider {
  background-color: {{ colors.background.default.hex }};
}
