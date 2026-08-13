import { Gtk } from "ags/gtk4"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"

// fa-docker (f21f) — verified against nerd-fonts' own glyphnames.json
// before use, same reasoning as waybar/.config/waybar/config.jsonc's
// header comment on why PUA characters can't be typed/copied by hand.
// Substituted in via a script from the verified hex, not hand-typed —
// see the commit that introduced this file.
const DOCKER_ICON = ""

// Content only, no <window> of its own — mounted inside
// widget/Sidebar.tsx's single toggleable panel alongside MusicSection.
export default function DockerSection() {
  // sh -c, not the bare argv form: `docker ps -q | wc -l` needs a real
  // shell for the pipe — createPoll's string[] form execs argv
  // directly with no shell involved (confirmed by reading its source,
  // ags/time.ts), so this is passed as ["sh", "-c", "<full pipeline>"]
  // rather than a bare string. Same stderr-redirect reasoning as the
  // waybar custom/docker module this mirrors: a stopped/unreachable
  // daemon just yields an empty count instead of an error string.
  const count = createPoll(
    "0",
    10_000,
    ["sh", "-c", "docker ps -q 2>/dev/null | wc -l"],
    (stdout) => stdout.trim(),
  )

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <label label="DOCKER" cssClasses={["eyebrow"]} halign={Gtk.Align.START} />
      <button
        cssClasses={["card", "docker-card"]}
        tooltipText="Click to open lazydocker"
        onClicked={() =>
          execAsync(["kitty", "--hold", "-e", "lazydocker"]).catch((err) =>
            console.error("lazydocker launch failed:", err),
          )
        }
      >
        <box spacing={12}>
          <box cssClasses={["icon-chip"]} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
            <label label={DOCKER_ICON} cssClasses={["icon"]} />
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER} hexpand>
            <label label={count} cssClasses={["count"]} halign={Gtk.Align.START} />
            <label
              label="containers running"
              cssClasses={["subtext"]}
              halign={Gtk.Align.START}
            />
          </box>
        </box>
      </button>
    </box>
  )
}
