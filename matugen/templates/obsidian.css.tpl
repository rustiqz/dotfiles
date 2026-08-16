## matugen/templates/obsidian.css.tpl -> themes/wallpaper/obsidian.css
##
## Same variable set as themes/tokyonight/obsidian.css, matugen
## expressions instead of literal hex - see that file for what each
## variable actually controls in Obsidian's UI. Chromatic slots beyond
## primary/error reuse the same hue-rotation recipe as
## matugen/templates/kitty.conf.tpl's ANSI colors and
## yazi-flavor.toml.tpl (green=135, yellow=50, magenta=300, cyan=190,
## all rotated from primary) so the wallpaper theme's headings/code
## colors stay as varied as TokyoNight's hand-picked ones instead of
## collapsing to a single accent everywhere.

.theme-dark {
  --background-primary: {{ colors.background.default.hex }};
  --background-primary-alt: {{ colors.surface_container_lowest.default.hex }};
  --background-secondary: {{ colors.surface_container.default.hex }};
  --background-secondary-alt: {{ colors.surface_container_lowest.default.hex }};
  --background-modifier-border: {{ colors.outline_variant.default.hex }};
  --background-modifier-hover: {{ colors.surface_container_high.default.hex }};
  --background-modifier-active-hover: {{ colors.surface_container_high.default.hex }};
  --background-modifier-border-hover: {{ colors.outline.default.hex }};
  --background-modifier-border-focus: {{ colors.primary.default.hex }};

  --text-normal: {{ colors.on_background.default.hex }};
  --text-muted: {{ colors.on_surface_variant.default.hex }};
  --text-faint: {{ colors.outline.default.hex }};
  --text-accent: {{ colors.primary.default.hex }};
  --text-accent-hover: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};
  --text-error: {{ colors.error.default.hex }};
  --text-on-accent: {{ colors.on_primary.default.hex }};
  --text-selection: {{ colors.primary.default.hex }}40;

  --interactive-normal: {{ colors.surface_container.default.hex }};
  --interactive-hover: {{ colors.surface_container_high.default.hex }};
  --interactive-accent: {{ colors.primary.default.hex }};
  --interactive-accent-hover: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};

  --divider-color: {{ colors.outline_variant.default.hex }};

  --h1-color: {{ colors.primary.default.hex }};
  --h2-color: {{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }};
  --h3-color: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};
  --h4-color: {{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }};
  --h5-color: {{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }};
  --h6-color: {{ colors.on_surface_variant.default.hex }};

  --link-color: {{ colors.primary.default.hex }};
  --link-color-hover: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};
  --link-unresolved-color: {{ colors.error.default.hex }};

  --code-normal: {{ colors.on_background.default.hex }};
  --code-background: {{ colors.surface_container_lowest.default.hex }};
  --code-property: {{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }};
  --code-string: {{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }};
  --code-comment: {{ colors.outline.default.hex }};
  --code-function: {{ colors.primary.default.hex }};
  --code-keyword: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};
  --code-value: {{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }};

  --tag-color: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};
  --tag-background: {{ colors.surface_container.default.hex }};
  --blockquote-border-color: {{ colors.primary.default.hex }};

  --checkbox-color: {{ colors.primary.default.hex }};
  --checkbox-color-hover: {{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }};
}
