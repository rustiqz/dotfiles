/* matugen/templates/rofi.rasi.tpl -> themes/wallpaper/rofi.rasi
 *
 * Same @name rasi variables as themes/tokyonight/rofi.rasi — config.rasi
 * only ever references these by name, no hex of its own.
 */
* {
  background:         {{ colors.background.default.hex }};
  background-alt:      {{ colors.surface_container.default.hex }};
  foreground:         {{ colors.on_background.default.hex }};
  selected:           {{ colors.surface_container_highest.default.hex }};
  accent:             {{ colors.primary.default.hex }};
}
