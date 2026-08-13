import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import DockerSection from "./Docker"
import MusicSection from "./Music"

// Single toggleable panel (bound to $mod+grave -> `uwsm app -- ags
// toggle sidebar`, hypr/keybinds.conf) holding every desktop widget —
// started with Docker status + now-playing, room to add more without
// a new window per widget. Full-height right edge, floating on top
// rather than reserving space (exclusivity NORMAL, not EXCLUSIVE) —
// windows keep their full width even while it's open; the panel just
// overlays. visible starts false: opens on demand, doesn't eat screen
// real estate sitting there permanently (the whole reason this replaced
// the original always-on floating-card design).
export default function Sidebar(gdkmonitor: Gdk.Monitor) {
  const { TOP, BOTTOM, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible={false}
      name="sidebar"
      class="Sidebar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={TOP | BOTTOM | RIGHT}
      application={app}
    >
      {/* vexpand: without it the box only sizes to its two cards'
          natural height, leaving the rest of the (TOP|BOTTOM-anchored,
          full-height) window transparent below them instead of a
          continuous sidebar surface — confirmed by testing, the .sidebar
          background-color simply had no box area left to paint outside
          the cards themselves. valign=START keeps the cards pinned to
          the top of that now-expanded box rather than centering in the
          leftover vertical space. */}
      <box
        orientation={Gtk.Orientation.VERTICAL}
        cssClasses={["sidebar"]}
        spacing={12}
        vexpand
        valign={Gtk.Align.START}
      >
        <DockerSection />
        <MusicSection />
      </box>
    </window>
  )
}
