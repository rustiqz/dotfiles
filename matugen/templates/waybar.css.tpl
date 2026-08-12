/* matugen/templates/waybar.css.tpl -> themes/wallpaper/waybar.css
 *
 * Same @define-color GTK3 syntax as themes/tokyonight/waybar.css (see
 * that file for why: waybar links libgtk-3.so.0, which has no :root/
 * custom-property support). Material You roles mapped onto the same
 * slot names style.css already reads from, so no changes needed there.
 *
 * bg uses surface_container_lowest, not plain background: matches
 * tokyonight's own choice of "one shade darker than main bg" for the
 * bar to read as a distinct strip — Material's tonal surface ladder
 * puts *_lowest as the darkest tier in dark mode, same direction.
 */
@define-color bg {{ colors.surface_container_lowest.default.hex }};
@define-color fg {{ colors.on_background.default.hex }};
@define-color border {{ colors.outline_variant.default.hex }};
@define-color muted {{ colors.on_surface_variant.default.hex }};
@define-color accent {{ colors.primary.default.hex }};
@define-color warning {{ colors.tertiary.default.hex }};
@define-color critical {{ colors.error.default.hex }};
@define-color menu_bg {{ colors.surface_container.default.hex }};
@define-color menu_hover {{ colors.surface_container_highest.default.hex }};
