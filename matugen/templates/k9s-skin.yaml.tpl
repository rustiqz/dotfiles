## matugen/templates/k9s-skin.yaml.tpl -> themes/wallpaper/k9s-skin.yaml
##
## Mirrors themes/tokyonight/k9s-skin.yaml slot for slot, so switching
## between tokyonight and wallpaper never changes *which* semantic role
## a k9s element reads as - only the actual color. Same relationship
## yazi-flavor.toml.tpl has to the vendored TokyoNight flavor.
##
## Chromatic slots use the same hue-rotation recipe as
## kitty.conf.tpl's ANSI colors (green=135, yellow=50, magenta=300,
## cyan=190, teal=165, all rotated from primary) rather than
## tertiary/secondary directly. Same reason as yazi: the pod-status
## colors below are a full small palette that has to stay mutually
## distinguishable (green Running vs yellow Pending vs red
## CrashLoopBackOff is the entire point of the view), and matugen's
## own scheme roles collapse toward each other on low-chroma
## wallpapers - which is exactly the failure that made the base16
## backend unusable for the terminal palette.
##
## bgColor stays the literal string `default` throughout, not a
## generated color: it means "the terminal's own background", so k9s
## inherits whatever kitty is currently themed to - which under
## `theme wallpaper` is itself generated from the same image, so the
## two agree without this template having to restate the color.
##
## No comments inside the YAML content below, matching
## qt-colors.conf.tpl's and yazi-flavor.toml.tpl's convention -
## reasoning lives up here instead.

foreground:    &fg        "{{ colors.on_surface.default.hex }}"
foreground_dk: &fg_dark   "{{ colors.on_surface_variant.default.hex }}"
background_dk: &bg_dark   "{{ colors.surface_container_low.default.hex }}"
highlight:     &highlight "{{ colors.surface_container_high.default.hex }}"
selection:     &selection "{{ colors.surface_container_highest.default.hex }}"
comment:       &comment   "{{ colors.outline.default.hex }}"
surface:       &surface   "{{ colors.surface_variant.default.hex }}"
crust:         &crust     "{{ colors.surface_container_lowest.default.hex }}"
blue:          &blue      "{{ colors.primary.default.hex }}"
cyan:          &cyan      "{{ colors.primary.default.hex | to_color | set_hue: 190 | format: "hex" }}"
teal:          &teal      "{{ colors.primary.default.hex | to_color | set_hue: 165 | format: "hex" }}"
green:         &green     "{{ colors.primary.default.hex | to_color | set_hue: 135 | format: "hex" }}"
yellow:        &yellow    "{{ colors.primary.default.hex | to_color | set_hue: 50 | format: "hex" }}"
red:           &red       "{{ colors.error.default.hex }}"
magenta:       &magenta   "{{ colors.primary.default.hex | to_color | set_hue: 300 | format: "hex" }}"

k9s:
  body:
    fgColor: *fg
    bgColor: default
    logoColor: *blue
  prompt:
    fgColor: *fg
    bgColor: *bg_dark
    suggestColor: *comment
  info:
    fgColor: *blue
    sectionColor: *fg
  dialog:
    fgColor: *fg
    bgColor: default
    buttonFgColor: *crust
    buttonBgColor: *blue
    buttonFocusFgColor: *crust
    buttonFocusBgColor: *magenta
    labelFgColor: *yellow
    fieldFgColor: *fg
  frame:
    border:
      fgColor: *highlight
      focusColor: *blue
    menu:
      fgColor: *fg_dark
      keyColor: *blue
      numKeyColor: *magenta
    crumbs:
      fgColor: *crust
      bgColor: *surface
      activeColor: *blue
    status:
      newColor: *cyan
      modifyColor: *blue
      addColor: *green
      errorColor: *red
      pendingColor: *yellow
      highlightColor: *teal
      killColor: *magenta
      completedColor: *comment
    title:
      fgColor: *fg
      highlightColor: *magenta
      counterColor: *cyan
      filterColor: *green
  views:
    charts:
      bgColor: default
      defaultDialColors:
        - *green
        - *red
      defaultChartColors:
        - *green
        - *red
    table:
      fgColor: *fg_dark
      bgColor: default
      cursorFgColor: *crust
      cursorBgColor: *blue
      markColor: *yellow
      header:
        fgColor: *magenta
        bgColor: default
        sorterColor: *teal
    xray:
      fgColor: *fg_dark
      bgColor: default
      cursorColor: *selection
      graphicColor: *cyan
      showIcons: false
    yaml:
      keyColor: *blue
      colonColor: *comment
      valueColor: *fg
    logs:
      fgColor: *fg
      bgColor: default
      indicator:
        fgColor: *blue
        bgColor: *bg_dark
        toggleOnColor: *green
        toggleOffColor: *comment
