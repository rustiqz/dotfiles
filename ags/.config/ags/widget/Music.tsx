import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, With } from "ags"
import Mpris from "gi://AstalMpris"

// fa-music/fa-play/fa-pause/fa-step_forward/fa-step_backward — verified
// against nerd-fonts' own glyphnames.json before use, same reasoning as
// waybar/.config/waybar/config.jsonc's header comment. Substituted in
// via a script from verified hex, not hand-typed.
const MUSIC_ICON = ""
const PLAY_ICON = ""
const PAUSE_ICON = ""
const NEXT_ICON = ""
const PREV_ICON = ""

// Content only, no <window> of its own — mounted inside
// widget/Sidebar.tsx's single toggleable panel alongside DockerSection.
export default function MusicSection() {
  const mpris = Mpris.get_default()

  // astal-mpris has no "currently active player" convenience (that's
  // playerctld's job, which waybar's mpris module uses instead) — just
  // a flat player list. Taking the first one is a reasonable stand-in
  // for "the one player" in the common single-source case (Spotify OR
  // a YouTube Music tab, not both at once).
  const players = createBinding(mpris, "players")
  const player = createComputed(() => players()[0] ?? null)

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <label label="NOW PLAYING" cssClasses={["eyebrow"]} halign={Gtk.Align.START} />
      <With value={player}>
        {(p) => {
          if (!p) {
            return (
              <box cssClasses={["card", "music-card", "empty"]}>
                <label label="Nothing playing" cssClasses={["subtext"]} hexpand halign={Gtk.Align.CENTER} />
              </box>
            )
          }

          const title = createBinding(p, "title")
          const artist = createBinding(p, "artist")
          // Plain string path, not Gio.File.new_for_path(...): despite
          // Gtk.Image's own GObject "file" property being typed
          // `Gio.File | null`, AGS's JSX <image file={...}> prop wants
          // the raw path string and converts it internally — passing
          // an actual Gio.File object throws "Wrong type GObject_Object;
          // string expected" at runtime (confirmed by testing).
          const coverPath = createBinding(p, "cover_art")
          const hasCover = createComputed(() => coverPath() !== "")
          const status = createBinding(p, "playback_status")
          const isPlaying = createComputed(() => status() === Mpris.PlaybackStatus.PLAYING)
          const playIcon = createComputed(() => (isPlaying() ? PAUSE_ICON : PLAY_ICON))
          const position = createBinding(p, "position")
          const length = createBinding(p, "length")
          // length is -1/0 before metadata loads — guard against
          // dividing by that instead of showing a NaN-driven slider.
          const progress = createComputed(() => {
            const len = length()
            return len > 0 ? position() / len : 0
          })

          return (
            <box
              cssClasses={createComputed(() => [
                "card",
                "music-card",
                ...(isPlaying() ? ["playing"] : []),
              ])}
              orientation={Gtk.Orientation.VERTICAL}
              spacing={12}
            >
              <box spacing={12}>
                <image
                  file={coverPath}
                  pixelSize={52}
                  cssClasses={["cover"]}
                  visible={hasCover}
                />
                <box
                  cssClasses={["icon-chip", "cover-fallback"]}
                  halign={Gtk.Align.CENTER}
                  valign={Gtk.Align.CENTER}
                  visible={createComputed(() => !hasCover())}
                >
                  <label label={MUSIC_ICON} cssClasses={["icon"]} />
                </box>
                <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER} hexpand>
                  <label
                    label={title}
                    cssClasses={["title"]}
                    halign={Gtk.Align.START}
                    ellipsize={3}
                    maxWidthChars={20}
                  />
                  <label
                    label={artist}
                    cssClasses={["artist"]}
                    halign={Gtk.Align.START}
                    ellipsize={3}
                    maxWidthChars={20}
                  />
                </box>
              </box>

              <slider
                value={progress}
                min={0}
                max={1}
                hexpand
                onChangeValue={({ value }) => {
                  const len = length()
                  if (len > 0) p.position = value * len
                }}
              />

              <box halign={Gtk.Align.CENTER} spacing={16}>
                <button
                  cssClasses={["transport"]}
                  onClicked={() => p.previous()}
                  sensitive={createBinding(p, "can_go_previous")}
                >
                  <label label={PREV_ICON} />
                </button>
                <button cssClasses={["transport", "play"]} onClicked={() => p.play_pause()}>
                  <label label={playIcon} />
                </button>
                <button
                  cssClasses={["transport"]}
                  onClicked={() => p.next()}
                  sensitive={createBinding(p, "can_go_next")}
                >
                  <label label={NEXT_ICON} />
                </button>
              </box>
            </box>
          )
        }}
      </With>
    </box>
  )
}
