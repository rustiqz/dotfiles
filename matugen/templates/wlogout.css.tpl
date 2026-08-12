/* matugen/templates/wlogout.css.tpl -> themes/wallpaper/wlogout.css
 *
 * Same @define-color GTK3 syntax as themes/tokyonight/wlogout.css.
 * bg uses plain `background` (not a darker surface tier like waybar's
 * bg) — matches tokyonight's original intent of the power menu reading
 * "as the same surface as the rest of the desktop," not a separately
 * styled panel.
 */
@define-color bg {{ colors.background.default.hex }};
@define-color fg {{ colors.on_background.default.hex }};
@define-color border {{ colors.outline_variant.default.hex }};
@define-color accent {{ colors.primary.default.hex }};
@define-color hover {{ colors.surface_container_highest.default.hex }};
