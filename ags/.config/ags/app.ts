import app from "ags/gtk4/app"
import style from "./style.scss"
import Sidebar from "./widget/Sidebar"

app.start({
  css: style,
  main() {
    app.get_monitors().map(Sidebar)
  },
})
