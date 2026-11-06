# Dynamic Island for Omarchy

A notch for Omarchy that behaves like [Boring Notch](https://github.com/TheBoredTeam/boring.notch)
on the Mac. At rest it is simply Omarchy's bar clock. When something is going on
(music, a timer, a recording) it grows wings on either side of the clock, and
hovering it opens a panel with your player, calendar, Pomodoro, ports and shelf.
It is drawn in your theme's bar colors and font and follows theme changes.

It is a native Omarchy shell plugin (Quickshell QML running inside
`omarchy-shell`), so it adds no extra process, and every data source is live:
MPRIS, PipeWire and UPower through Quickshell's services, sysfs for the
backlight, `gpu-screen-recorder` for recording, and `focusd` for Pomodoro.

## How it behaves

The notch is one shape that only ever grows: sideways into wings at bar
height, or downwards into the open panel. Its outline is Boring Notch's: a
flat top flush with the screen edge, small concave "ears" flaring into the bar
and rounded bottom corners (6/14px closed, 19/24px open).

| State | Looks like |
|---|---|
| Idle | Omarchy's clock, nothing else. The notch paints nothing of its own, so the bar (clear, glassy or opaque) shows through, with the clock in the bar's font and text color: it is indistinguishable from the bar clock |
| Live activity | Wings either side of the clock. Music: cover on the left, equalizer on the right. Pomodoro or a timer: a progress ring and the time left. Recording: a red dot and the running time. Also the microphone or camera in use, a meeting about to start, the stopwatch, and script activities |
| Sneak peek | Volume, brightness or keyboard light: the glyph and name on the left, a level bar and percent on the right, for 1.5s |
| Expanding | A charger plugged in, low battery, a timer or Pomodoro session ending, a track change, a toast: a wide strip at bar height for a few seconds |
| Notification | A banner dropping out of the notch, with the sender's buttons |
| Open | A 640px panel: tabs on the left of the header, the clock in the middle, recording and battery on the right; the tab below |

Only one closed state shows at a time, in that order of priority
(notification, then HUDs, then the most important live activity).

Anything other than idle is **frosted glass**, as Raycast and macOS draw it:
the bar's color, see-through, over a blur of what is behind, with a soft
sheen and a hairline rim. The blur is Hyprland's: the island adds
`~/.local/state/omarchy/toggles/hypr/dynamic-island-glass.lua` (the same
mechanism as Omarchy's Glassy bar), which turns on Hyprland's blur with
Omarchy's glass settings for the island alone. Windows stay unblurred unless
Glassy windows are on. `"glass": false` removes the file and makes the notch
solid.

**Tabs** in the open notch:

* **Home**: the player (cover with a soft glow, title, artist, scrubber,
  shuffle / previous / play / next / repeat, and "Play on" to switch the
  audio output) beside a strip of days with the chosen day's events
* **Calendar**: a month grid in the style of Omarchy's clock calendar (ISO
  week numbers, today outlined), the chosen day's agenda, and a button that
  adds a calendar link from the clipboard
* **Focus**: Pomodoro (start / pause, skip, reset, +5 minutes, the round's
  sessions, and today's focus time, goal, sessions and streak from focusd),
  quick 5 / 15 / 25 minute timers and a stopwatch
* **Ports**: listening ports, the app behind each, open in the browser or stop
* **Shelf**: files to keep at hand until you take them off (they stay while
  the shell runs). Drag a file onto the notch to open it
* **Inbox** (while notifications are waiting): everything you missed

**Mouse:**

* **Hover** opens the notch after 0.15s; moving off it closes it (after
  0.1s). A HUD, toast or notification never opens under the pointer, so it
  can be read or clicked.
* **Click** opens it at once, on the tab of what is showing (a running
  timer opens Focus, a meeting opens Calendar).
* **Scroll down** on the notch opens it; **scroll up** closes it.
* **Right-click** the clock to cycle its format, as on Omarchy's bar.
* **Middle-click**: play/pause.

Opening springs out with a slight overshoot; closing settles without one. The
notch never takes keyboard focus from the app you are in.

**Pomodoro** uses the `focusd` daemon when it
is running (`focusd --daemon`), so the island, focusd's TUI and waybar-style
status all share one session, cycle, daily goal and streak. The island never
starts the daemon itself. Without it the island runs its own 25 / 5 / 15
cycle. focusd caps "+5 minutes" at the session's length.

## Notifications

The island is also your notification daemon. On first run it disables
Omarchy's own `omarchy.notifications` service (only one program can receive
notifications), and it answers the same `omarchy-shell notifications ...`
commands, so Omarchy's keybinds and scripts keep working:

| | |
|---|---|
| ![A notification banner with Reply and Mark as Read buttons](assets/notification.webp) | ![The inbox with three missed notifications and Clear all](assets/inbox.webp) |
| A notification with its actions | Everything you missed, in the inbox |

* **New notification**: it drops out of the island as a banner with the app
  icon, title and body, plus the sender's buttons if it has any. Hovering
  keeps it up.
* **Click a notification**: runs the sender's action and focuses the app's
  window. Right-click or the × clears it without opening it.
* **Not clicked**: when the banner's time runs out the notification is not
  lost. It waits in the Inbox tab, which appears (with a dot) while anything
  is waiting. The inbox survives shell restarts.
* **Inbox**: open the Inbox tab (or press `SUPER+SHIFT+ALT+,`) to see everything
  waiting. Click a row to open that app, × on a row to clear it, or
  **× Clear all** at the bottom.
* **Do not disturb** (`SUPER+CTRL+,`): nothing pops up, and everything still
  goes to the inbox.
* `SUPER+,` clears the newest, `SUPER+SHIFT+,` clears everything,
  `SUPER+ALT+,` opens the newest.

Omarchy's own quick feedback toasts ("Theme changed" and similar) show as
banners but don't pile up in the inbox.

To go back to Omarchy's notifications, set `"notifications": false` in the
island's settings. Disabling or removing the plugin also hands
notifications back automatically.

## Install

```bash
omarchy plugin add https://github.com/Arjun010011/omarchy-dynamic-island --enable
```

Or from a checkout:

```bash
./dev-install.sh
omarchy-shell shell rescanPlugins
omarchy plugin enable omarchy-dynamic-island
```

## Settings

Settings live in the plugin's entry in `~/.config/omarchy/shell.json`. On
first start the island fills that entry with every setting below at its
default, so you only change values; any you set yourself are kept. Changes
apply as soon as you save the file.

```json
"plugins": [
  { "id": "omarchy-dynamic-island", "glassOpacity": 0.7, "scale": 1.1 }
]
```

| Key | Default | Meaning |
|---|---|---|
| `background` | `"theme"` | `"theme"` uses the bar's colors; `"black"` is solid true black (no glass) |
| `glass` | `true` | Frosted glass while anything is showing (Hyprland blur, see above); `false` for a solid notch |
| `glassOpacity` | `0.62` | How much of the bar's color the glass carries (0.35–1); higher reads better over busy backgrounds |
| `openOnHover` | `true` | Open when the pointer rests on the notch |
| `fitBarSpacer` | `true` | Keep the bar's center spacer as wide as the closed notch, so the icons either side sit an equal, normal gap from it (wider while a live activity shows). Only a center section that is a single `omarchy.spacer` is changed |
| `hoverDelay` | `150` | How long the pointer rests before it opens, in ms (0–2000) |
| `clockFormat` | `"dddd HH:mm"` | Qt date format for the clock (`ww` = ISO week). Right-click the clock to walk Omarchy's clock formats (with and without AM/PM and seconds, date, week, ISO), as on the bar clock |
| `clockFormatAlt` | `"d MMMM 'W'ww yyyy"` | An extra format added to the right-click ring, like the bar clock's `formatAlt` |
| `scale` | `1` | Size multiplier (0.6–2) for everything but the clock, which follows the bar |
| `reserveSpace` | `false` | Keep a strip free across the top. `false` lets windows fill the top of the screen under the bar |
| `keybind` | `"SUPER + ALT + I"` | Key that toggles `reserveSpace`. The island adds it to `~/.config/hypr/bindings.lua` (skipped if the key is already taken) and removes it on uninstall; `false` for none |
| `monitor` | `"primary"` | `"primary"`, `"focused"`, or a monitor name like `"eDP-1"` |
| `layer` | `"overlay"` | `"top"` lets fullscreen windows cover it |
| `mediaLingerSeconds` | `30` | How long a paused track stays as a live activity |
| `visualizerColor` | `"accent"` | `"artwork"` colors the equalizer and artist from the album cover |
| `calendars` | `[]` | iCalendar links or files, e.g. `["https://…/basic.ics", "~/cal.ics"]` |
| `calendarLeadMinutes` | `15` | How early a meeting becomes a live activity |
| `holidays` | `"auto"` | Public holidays: `"auto"` (from the timezone), `"off"`, or a country code |
| `timerSound` | `true` | Play the alarm sound when a timer or Pomodoro session ends |
| `bluetooth`, `camera`, `calendar` | `true` | Turn those off (`calendar: false` also hides the Home tab's calendar column) |
| `notifications` | `true` | Show notifications in the notch (replaces Omarchy's notification popups) |
| `inbox` | `true` | Keep missed notifications in the Inbox tab |
| `osd` | `true` | Show Omarchy's on-screen popups (volume, brightness, mic, …) in the notch instead of at the bottom |
| `volume`, `brightness`, `charging`, `trackChange`, `recording`, `mic` | `true` | Turn individual activities off |

The island also replaces Omarchy's on-screen display: the popups at the
bottom of the screen for volume, brightness, microphone mute, keyboard
backlight, audio output, touchpad, power actions and downloads. It turns off
Omarchy's `omarchy.osd` plugin and answers the same `omarchy osd` calls, so
every key and script that popped the OSD now shows in the island. Set
`"osd": false` to go back to Omarchy's popups.

## Uninstalling

Disabling or removing the plugin gives back everything it took over: Omarchy's
notifications and on-screen display are switched back on, its keybinding
is removed from `bindings.lua`, and its glass file is removed from
`~/.local/state/omarchy/toggles/hypr` (Hyprland reloads, and blur goes back to
how it was). The plugin checks a
few seconds after it unloads, so a shell restart doesn't trigger this.

## Calendar

Open the Calendar tab, click a meeting's live activity, or run
`omarchy-shell dynamic-island calendar` (bind it to a key if you like).

It shows the month with ISO week numbers, today outlined and a dot on every
day that has something on it; click a day to see its events, scroll to step
months, and click an event to open its meeting link (Meet, Zoom, Teams). Copy
a calendar link and press **Paste link** to add it (added links are kept in
`~/.config/omarchy/dynamic-island/calendars.json`). Scripts can do the same with
`omarchy-shell dynamic-island addCalendar <link>` / `removeCalendar <link>`.

**Holidays** are on out of the box: the island picks your country from the
system timezone and shows its public holidays and festivals (from Google's
holiday calendars) as all-day entries, with today's festival next to the
date. The `"holidays"` setting picks another country or turns them off:
`"auto"`, `"off"`, or a country code like `"IN"`.

Any calendar that can give you an `.ics` link works:

* **Google Calendar**: Settings → your calendar → Integrate calendar → **"Secret
  address in iCal format"**. The "Public address" only works if the calendar
  is public (otherwise Google answers 404). Each calendar, and each Google
  account (personal, work), has its own secret address. Google refreshes these
  feeds on its own schedule, so a brand-new event can take a few hours to appear
* **iCloud**: share the calendar as a public calendar (a `webcal://` link works)
* **Outlook**: Settings → Shared calendars → Publish a calendar → ICS link
* **Nextcloud and Fastmail**: the calendar's export or subscription link

Local `.ics` files also work. Feeds are re-read every 15 minutes. Daily,
weekly, monthly and yearly repeats (birthdays) are understood; times with a
time zone are read as local time. To add one, copy its link and click "Paste
link" in the Calendar tab (the island never takes the keyboard).

## Scripting

```bash
omarchy-shell dynamic-island toast "Build finished" "0 errors" "󰄬" green
omarchy-shell dynamic-island toggle        # open / close; bind it to a key
omarchy-shell dynamic-island view focus    # open on a tab: home calendar focus ports shelf inbox
omarchy-shell dynamic-island pomodoro      # start a Pomodoro and open the Focus tab
omarchy-shell dynamic-island reserveSpace toggle   # on | off | toggle: windows below the island or under it
omarchy-shell dynamic-island state         # JSON snapshot
omarchy-shell dynamic-island demo media    # preview: media paused recording mic volume brightness
                                           # charging lowbattery notification notification-actions
                                           # inbox track toast expanded timer stopwatch activity
                                           # calendar calendar-view camera device outputs off
```

Timers, the stopwatch, and live activities for your own scripts:

```bash
omarchy-shell dynamic-island timer 10m "Tea"       # also 90s, 1h30m, 10:00, or plain minutes
omarchy-shell dynamic-island timerToggle           # pause / resume (the Pomodoro when no timer runs)
omarchy-shell dynamic-island timerCancel
omarchy-shell dynamic-island stopwatch toggle      # start | pause | toggle | reset

# Start or update a live activity (all fields optional):
omarchy-shell dynamic-island activity backup \
  '{"title":"Backing up","subtitle":"~/Projects","icon":"󰁯","progress":0.4,"value":"4/10","color":"green","ttl":600}'
# End it, optionally with a closing message:
omarchy-shell dynamic-island endActivity backup "Backup complete"
```

`ttl` (seconds) ends an activity by itself if the script dies without ending
it.

A toast's color can be `accent`, `green`, `orange`, `red`, `foreground` or a hex
value.

For example, to have a long command tell you when it's done:

```bash
make && omarchy-shell dynamic-island toast "make" "done" "󰄬" green \
     || omarchy-shell dynamic-island toast "make" "failed" "󰅚" red
```

## Development

`dev-install.sh` copies the working tree into
`~/.config/omarchy/plugins/omarchy-dynamic-island` and validates it.
Quickshell reads plugin files once when the shell starts, so run
`omarchy restart shell` after every change.

Files:

* `Island.qml`: state machine, data sources, window and IPC
* `IslandModel.js`: pure logic (notch modes, priorities, tabs, formatting, player choice)
* `views/`: the clock, the wings (`WingLive`, `WingHud`), the header (`NotchTabs`,
  `NotchStatus`), one file per tab, and shared pieces

## License

MIT
