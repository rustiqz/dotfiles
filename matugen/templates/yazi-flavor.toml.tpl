## matugen/templates/yazi-flavor.toml.tpl -> themes/wallpaper/yazi-flavor/flavor.toml
##
## Reproduces themes/tokyonight/yazi-flavor/flavor.toml's exact
## structure (which slot gets "the red one" vs "the green one" etc.),
## just with matugen expressions instead of literal hex - so switching
## between tokyonight and wallpaper never changes *which* semantic role
## a UI element reads as, only the actual color. Faithful to upstream's
## own slot choices even where they read a little odd (title_warn uses
## the red/error slot, title_error uses the yellow slot in the source
## flavor this was vendored from) - not this template's place to
## "correct" that, only to recolor it.
##
## Chromatic slots beyond primary/error use the same hue-rotation
## recipe as matugen/templates/kitty.conf.tpl's ANSI colors (green=135,
## yellow=50, magenta=300, cyan=190, all rotated from primary) rather
## than tertiary/secondary directly - yazi needs a full small palette
## (red/green/yellow/magenta/cyan) the same way a terminal's ANSI set
## does, not just one extra accent the way waybar's single "warning"
## slot did, so the same synthesis approach applies here for the same
## reason it did there.
##
## No comments inside the actual TOML content below, matching
## qt-colors.conf.tpl's own convention - reasoning lives here instead.

[mgr]
cwd = { fg = "{{ colors.primary.default.hex }}" }

find_keyword  = { fg = "{{ colors.error.default.hex }}", bold = true, italic = true, underline = true }
find_position = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}", bg = "reset", bold = true, italic = true }

marker_copied   = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
marker_cut      = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}", bg = "{{ colors.error.default.hex }}" }
marker_marked   = { fg = "{{ colors.primary.default.hex }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }}" }
marker_selected = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}" }

count_copied   = { fg = "{{ colors.background.default.hex }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
count_cut      = { fg = "{{ colors.background.default.hex }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}" }
count_selected = { fg = "{{ colors.background.default.hex }}", bg = "{{ colors.primary.default.hex }}" }

border_symbol = "│"
border_style  = { fg = "{{ colors.outline_variant.default.hex }}" }


[tabs]
active   = { fg = "{{ colors.on_primary.default.hex }}", bg = "{{ colors.primary.default.hex }}", bold = true }
inactive = { fg = "{{ colors.primary.default.hex }}", bg = "{{ colors.surface_container.default.hex }}" }


[mode]

normal_main = { fg = "{{ colors.on_primary.default.hex }}", bg = "{{ colors.primary.default.hex }}", bold = true }
normal_alt  = { fg = "{{ colors.primary.default.hex }}", bg = "{{ colors.surface_container.default.hex }}" }

select_main = { fg = "{{ colors.background.default.hex }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}", bold = true }
select_alt  = { fg = "{{ colors.primary.default.hex }}", bg = "{{ colors.surface_container.default.hex }}" }

unset_main = { fg = "{{ colors.background.default.hex }}", bg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}", bold = true }
unset_alt  = { fg = "{{ colors.primary.default.hex }}", bg = "{{ colors.surface_container.default.hex }}" }


[status]
overall = { fg = "{{ colors.primary.default.hex }}" }
sep_left  = { open = "", close = "" }
sep_right = { open = "", close = "" }

progress_label = { fg = "{{ colors.on_primary.default.hex }}", bold = true }
progress_normal = { fg = "{{ colors.primary.default.hex }}", bg = "{{ colors.surface_container.default.hex }}" }
progress_error = { fg = "{{ colors.error.default.hex }}", bg = "{{ colors.surface_container.default.hex }}" }

perm_sep   = { fg = "{{ colors.primary.default.hex }}" }
perm_type  = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
perm_read  = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}" }
perm_write = { fg = "{{ colors.error.default.hex }}" }
perm_exec  = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" }


[pick]
border = { fg = "{{ colors.primary.default.hex }}" }
active = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}", bold = true }
inactive = {}


[input]
border   = { fg = "{{ colors.primary.default.hex }}" }
title    = {}
value    = {}
selected = { reversed = true }


[cmp]
border = { fg = "{{ colors.primary.default.hex }}" }


[tasks]
border  = { fg = "{{ colors.primary.default.hex }}" }
title   = {}
hovered = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}", underline = true }


[which]
mask            = { bg = "{{ colors.outline_variant.default.hex }}" }
cand            = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
rest            = { fg = "{{ colors.on_surface_variant.default.hex }}" }
desc            = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" }
separator       = "  "
separator_style = { fg = "{{ colors.outline.default.hex }}" }


[help]
on      = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
run     = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" }
hovered = { reversed = true, bold = true }
footer  = { fg = "{{ colors.background.default.hex }}", bg = "{{ colors.on_surface_variant.default.hex }}" }


[spot]
border   = { fg = "{{ colors.primary.default.hex }}" }
title    = { fg = "{{ colors.primary.default.hex }}" }
tbl_col  = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
tbl_cell = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}", bg = "{{ colors.surface_container.default.hex }}" }


[notify]
title_info  = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" }
title_warn  = { fg = "{{ colors.error.default.hex }}" }
title_error = { fg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}" }


[filetype]

rules = [
	{ mime = "image/*", fg = "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}" },

	{ mime = "video/*", fg = "{{ colors.error.default.hex }}" },
	{ mime = "audio/*", fg = "{{ colors.error.default.hex }}" },

	{ mime = "application/zip",             fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },
	{ mime = "application/x-tar",           fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },
	{ mime = "application/x-bzip*",         fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },
	{ mime = "application/x-bzip2",         fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },
	{ mime = "application/x-7z-compressed", fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },
	{ mime = "application/x-rar",           fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },
	{ mime = "application/x-xz",            fg = "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}" },

	{ mime = "application/doc",        fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" },
	{ mime = "application/epub+zip",   fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" },
	{ mime = "application/pdf",        fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" },
	{ mime = "application/rtf",        fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" },
	{ mime = "application/vnd.*",      fg = "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}" },

  { mime = "*", is = "orphan", fg = "{{ colors.on_error_container.default.hex }}", bg = "{{ colors.error_container.default.hex }}" },
  { mime = "application/*exec*", fg = "{{ colors.error.default.hex }}" },

	{ url = "*", fg = "{{ colors.on_background.default.hex }}" },
	{ url = "*/", fg = "{{ colors.primary.default.hex }}" },
]
