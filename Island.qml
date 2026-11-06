import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import "views"
import "sources"
import "IslandModel.js" as Model

// Dynamic Island for Omarchy.
//
// A keep-loaded panel plugin: the shell mounts it at startup and it draws its
// own layer-shell strip across the top of one monitor. Only the island (and
// the split bubble) take input; everything else in the strip is click-through.
//
// Data flows one way: live sources (MPRIS, PipeWire, UPower, backlight,
// gpu-screen-recorder) feed plain properties on this root, those resolve to a
// single `view` name, and the shape springs to that view's size while the
// matching content fades in.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "omarchy-dynamic-island"

  // ------------------------------------------------------------------
  // Settings: this plugin's entry in ~/.config/omarchy/shell.json plugins[]
  // ------------------------------------------------------------------
  property var settings: ({})

  function setting(key, fallback) {
    var v = settings ? settings[key] : undefined
    return v === undefined || v === null ? fallback : v
  }

  readonly property bool blackBackground: setting("background", "theme") === "black"
  readonly property real scaleFactor: Math.max(0.6, Math.min(2, Number(setting("scale", 1)) || 1))
  readonly property bool reserveSpace: setting("reserveSpace", false) === true
  readonly property string monitorSetting: String(setting("monitor", "primary"))
  // Boring Notch: hovering the closed notch opens it after a short wait.
  readonly property bool openOnHover: setting("openOnHover", true) !== false
  readonly property int hoverDelay: {
    var v = Number(setting("hoverDelay", 150))
    return isNaN(v) ? 150 : Math.max(0, Math.min(2000, v))
  }
  // The clock is Omarchy's bar clock: the same format setting, the same
  // alternate, and right-click walks the same ring in the same order
  // (Omarchy's clock presets, then the alternate and the current format if
  // they are something else). Day and month names follow the Omarchy
  // language, and a format with seconds ticks every second.
  readonly property string clockFormat: String(setting("clockFormat", "dddd HH:mm"))
  readonly property string clockFormatAlt: String(setting("clockFormatAlt", "d MMMM 'W'ww yyyy"))
  readonly property var clockFormats: Model.clockFormatRing(clockFormat, clockFormatAlt)
  property string activeClockFormat: clockFormat
  onClockFormatChanged: activeClockFormat = clockFormat
  readonly property bool clockShowsSeconds: Model.clockNeedsSeconds(activeClockFormat)
  readonly property var clockLocale: Qt.locale(I18n.formatLocale)

  readonly property string formattedClockText: {
    var date = idleClock.date
    // The ISO week goes in as a literal, its digits localized like the rest.
    var week = Model.pad2(Model.isoWeek(date.getFullYear(), date.getMonth(), date.getDate()))
    week = week.split("").map(function(digit) { return I18n.formatNumber(digit) }).join("")
    return date.toLocaleString(clockLocale, activeClockFormat.replace(/ww/g, week))
  }

  function cycleClockFormat() {
    var idx = clockFormats.indexOf(activeClockFormat)
    var next = clockFormats[(idx + 1) % clockFormats.length]
    if (!next || next === activeClockFormat) return
    activeClockFormat = next
    saveSettings({ clockFormat: next })
  }

  readonly property bool showVolume: setting("volume", true) !== false
  readonly property bool showBrightness: setting("brightness", true) !== false
  readonly property bool showCharging: setting("charging", true) !== false
  readonly property bool showTrackChange: setting("trackChange", true) !== false
  readonly property bool showRecording: setting("recording", true) !== false
  readonly property bool showMic: setting("mic", true) !== false
  readonly property bool artworkTint: setting("visualizerColor", "accent") === "artwork"
  readonly property int mediaLingerMs: Math.max(0, Number(setting("mediaLingerSeconds", 30))) * 1000

  property var disabledPlugins: []
  property bool configLoaded: false
  // How Omarchy's bar paints its background: opaque, glassy or none.
  property string barLook: "opaque"
  // The bar's center section, where the spacer the notch sits on lives.
  property var barCenter: []

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var cfg = Model.parseConfig(text())
      root.settings = Model.entryFor(cfg, root.pluginId)
      root.disabledPlugins = Array.isArray(cfg.disabledPlugins) ? cfg.disabledPlugins : []
      var bar = cfg && cfg.bar ? cfg.bar : {}
      root.barLook = String(bar.background || (bar.transparent === true ? "none" : "opaque"))
      root.barCenter = bar.layout && Array.isArray(bar.layout.center) ? bar.layout.center : []
      root.configLoaded = true
    }
    onLoadFailed: {
      root.settings = ({})
      root.configLoaded = true
    }
  }

  // ------------------------------------------------------------------
  // Theme. The notch is part of Omarchy's bar: at rest it is painted
  // exactly as the bar is (clear, glassy or opaque) with the clock in the
  // bar's font and text color, so it is just the bar clock. Anything
  // happening fills it with the bar's own background color, solid.
  // ------------------------------------------------------------------
  property var themeColors: ({})

  FileView {
    id: themeColorsFile
    path: Color.currentThemePath + "/colors.toml"
    onLoaded: root.themeColors = Model.parseColors(text())
  }

  Connections {
    target: Color
    function onBackgroundChanged() { themeColorsFile.reload(); barTextProbe.restart() }
    function onAccentChanged() { themeColorsFile.reload() }
  }

  readonly property color barBackground: Color.bar.background
  readonly property color surface: blackBackground ? "#000000"
    : Qt.rgba(barBackground.r, barBackground.g, barBackground.b, 1)
  readonly property color fg: blackBackground ? "#f5f5f7" : Color.bar.text
  readonly property color fgDim: Util.alpha(fg, 0.6)
  readonly property color accentColor: Color.accent
  readonly property color urgentColor: Color.urgent
  // colors.toml names its palette (green, orange...); older themes use color0-15
  readonly property color greenColor: themeColors.color2 || themeColors.green || accentColor
  readonly property color orangeColor: themeColors.color3 || themeColors.orange || urgentColor

  // Frosted glass, as Raycast and macOS draw it: anything going on fills the
  // notch with the bar's color, see-through, over a blur of what is behind
  // (Hyprland does the blur; see syncGlass). "glass": false makes it solid.
  readonly property bool glassOn: !blackBackground && setting("glass", true) !== false
  readonly property real glassOpacity: {
    var v = Number(setting("glassOpacity", 0.62))
    return isNaN(v) ? 0.62 : Math.max(0.35, Math.min(1, v))
  }
  readonly property real activeAlpha: glassOn ? glassOpacity : 1

  // At rest the notch paints nothing: Omarchy's bar draws its background
  // (opaque, glassy or clear) right across the screen, under the island, so
  // anything painted here would double it. The bar shows through instead.
  readonly property real restingAlpha: 0
  // A clear bar picks its text color against the wallpaper; the island asks
  // the same helper, so the resting clock matches the bar beside it.
  property color clearBarText: Color.bar.text

  Process {
    id: barTextProc
    command: ["omarchy-bar-text-color", "top", String(root.barHeight),
              Model.hexColor(Color.bar.text), Model.hexColor(Color.background)]
    stdout: SplitParser {
      onRead: function(line) {
        var v = String(line || "").trim()
        if (/^#[0-9A-Fa-f]{6}$/.test(v)) root.clearBarText = v
      }
    }
  }

  Timer {
    id: barTextProbe
    interval: 300
    running: true
    onTriggered: if (root.barLook === "none" && !barTextProc.running) barTextProc.running = true
  }

  // The wallpaper changes with the theme (and on its own); both land here.
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme"
    watchChanges: true
    printErrors: false
    onFileChanged: barTextProbe.restart()
  }
  onBarLookChanged: barTextProbe.restart()

  // Compatibility with views that shade their own fades.
  readonly property color surfaceTop: surface
  readonly property color surfaceBottom: surface
  function bodyAt(t) { return surface }

  // Everything in the theme's font, like the rest of Omarchy.
  readonly property string fontFamily: Style.font.family
  readonly property string textFamily: Style.font.family

  function s(px) { return Math.round(Style.space(px) * scaleFactor) }
  function f(px) { return Math.max(6, Math.round(px * Style.fontScale * scaleFactor)) }

  // The bar's thickness on this screen: the closed notch is exactly as tall.
  readonly property int barHeight: {
    var b = shell && shell.bar ? shell.bar : null
    var h = b && typeof b.barSizeFor === "function" && win.screen ? b.barSizeFor(win.screen.name) : (b ? b.barSize : 0)
    return h > 0 ? h : Style.bar.sizeHorizontal
  }
  readonly property int clockPixelSize: Style.font.body
  // At rest over a clear bar the clock takes the bar's wallpaper-aware text
  // color; once the notch fills in, the bar's text color on its background.
  readonly property color clockColor: (mode === "idle" && !hovered && barLook === "none") ? clearBarText : fg

  // Device pixel grid (1.25 on a 125% display).
  readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1
  function snap(v) { return Math.round(v * dpr) / dpr }

  // Nothing announces itself for the first moments after (re)load, so the
  // initial volume/brightness/battery reads do not pop HUDs.
  property bool ready: false
  Timer { interval: 2500; running: true; onTriggered: root.ready = true }

  // ------------------------------------------------------------------
  // Media (MPRIS)
  // ------------------------------------------------------------------
  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string currentPlayerKey: ""
  property int playerTick: 0
  readonly property var player: { playerTick; return Model.pickPlayer(players, currentPlayerKey) }

  // Remember what is on screen so the choice survives a pause. Deferred so
  // the write does not land inside the evaluation of `player` itself.
  onPlayerChanged: Qt.callLater(function() {
    if (root.player) root.currentPlayerKey = Model.playerKey(root.player)
  })

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() {
        // A player that starts playing takes over the island, unless it is
        // only a poorer copy of a song another player already shows.
        if (modelData.isPlaying && Model.candidates(root.players).indexOf(modelData) !== -1)
          root.currentPlayerKey = Model.playerKey(modelData)
        root.playerTick++
      }
      function onTrackTitleChanged() { root.playerTick++ }
      function onTrackArtistChanged() { root.playerTick++ }
    }
  }

  // Demo data (IPC `demo`) stands in for live sources so every state can be
  // previewed without a player running.
  property var demo: null
  // What a demo started, so `demo off` stops only that and never the
  // user's own timer or stopwatch.
  property bool demoTimer: false
  property bool demoStopwatch: false
  readonly property var demoMedia: demo && demo.media ? demo.media : null
  readonly property bool demoOwnsMedia: !!demo && demo.media !== undefined

  readonly property bool hasMedia: demoOwnsMedia ? demoMedia !== null : player !== null
  readonly property bool mediaPlaying: demoMedia ? demoMedia.playing === true : (player ? player.isPlaying : false)
  readonly property string mediaTitle: demoMedia ? demoMedia.title : (player ? (player.trackTitle || "") : "")
  readonly property string mediaArtist: demoMedia ? demoMedia.artist : (player ? (player.trackArtist || "") : "")
  readonly property string mediaArt: demoMedia ? (demoMedia.art || "") : (player ? (player.trackArtUrl || "") : "")
  readonly property real mediaLength: demoMedia ? demoMedia.length
    : (player && player.lengthSupported ? player.length : 0)
  readonly property bool mediaCanSeek: !demoMedia && !!player && player.canSeek && player.positionSupported
  readonly property bool mediaCanNext: demoMedia ? true : (!!player && player.canGoNext)
  readonly property bool mediaCanPrevious: demoMedia ? true : (!!player && player.canGoPrevious)
  property real mediaPosition: 0

  // Keep the activity up for a while after pausing, like iOS does, so a
  // quick pause does not make the island collapse and re-open.
  property bool mediaLinger: false
  onMediaPlayingChanged: {
    if (!mediaPlaying && hasMedia && mediaLingerMs > 0) {
      mediaLinger = true
      lingerTimer.restart()
    }
  }
  Timer { id: lingerTimer; interval: root.mediaLingerMs; onTriggered: root.mediaLinger = false }

  // MPRIS position is not pushed; poll it while something shows it.
  Timer {
    interval: 500
    repeat: true
    running: root.hasMedia && root.mode === "open" && root.tab === "home"
    triggeredOnStart: true
    onTriggered: {
      if (root.demoMedia) {
        if (root.demoMedia.playing) root.mediaPosition = (root.mediaPosition + 0.5) % Math.max(1, root.mediaLength)
      } else if (root.player && root.player.positionSupported) {
        root.player.positionChanged()
        root.mediaPosition = root.player.position
      }
    }
  }

  function updateDemo(mutator) {
    var next = JSON.parse(JSON.stringify(root.demo || {}))
    mutator(next)
    root.demo = next
  }

  function mediaToggle() {
    if (demoMedia) updateDemo(function(d) { d.media.playing = !d.media.playing })
    else if (player && player.canTogglePlaying) player.togglePlaying()
  }

  function mediaNext() {
    if (demoMedia) root.mediaPosition = 0
    else if (player && player.canGoNext) player.next()
  }

  function mediaPrevious() {
    if (demoMedia) root.mediaPosition = 0
    else if (player && player.canGoPrevious) player.previous()
  }

  function mediaSeek(fraction) {
    if (!mediaCanSeek || mediaLength <= 0) return
    var target = Math.max(0, Math.min(1, fraction)) * mediaLength
    player.position = target
    mediaPosition = target
  }

  // Track change → brief now-playing card. Debounced because players send
  // title and artist as separate updates.
  readonly property string trackSignature: mediaTitle + "\u0001" + mediaArtist
  property string shownTrack: ""
  onTrackSignatureChanged: trackDebounce.restart()

  Timer {
    id: trackDebounce
    interval: 450
    onTriggered: {
      var sig = root.trackSignature
      if (sig === root.shownTrack) return
      root.shownTrack = sig
      if (root.ready && root.showTrackChange && root.mediaPlaying && root.mediaTitle !== "" && !root.userExpanded)
        root.showHud({ layout: "track", duration: 3200 })
    }
  }

  // ------------------------------------------------------------------
  // Audio (PipeWire): output volume HUD and microphone privacy activity
  // ------------------------------------------------------------------
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  onVolumeChanged: volumeHud()
  onMutedChanged: volumeHud()

  function volumeHud() {
    if (!ready || !showVolume || !sink) return
    showHud({
      key: "volume",
      layout: "progress",
      icon: Model.volumeIcon(volume, muted),
      value: muted ? 0 : volume,
      valueText: muted ? "Mute" : Math.round(volume * 100) + "%",
      color: muted ? fgDim : fg,
      duration: 1500
    })
  }

  function adjustVolume(delta) {
    if (!sink || !sink.audio || delta === 0) return
    sink.audio.muted = false
    sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (delta > 0 ? 0.05 : -0.05)))
  }

  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property bool micActive: {
    for (var i = 0; i < pwNodes.length; i++)
      if (Model.isMicStream(pwNodes[i])) return true
    return false
  }

  // ------------------------------------------------------------------
  // Power (UPower): charging and low-battery HUDs
  // ------------------------------------------------------------------
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!(battery && battery.isPresent)
  readonly property real batteryLevel: hasBattery ? Model.clamp01(battery.percentage) : 0
  readonly property bool charging: hasBattery && battery.state !== UPowerDeviceState.Discharging
    && battery.state !== UPowerDeviceState.Empty && battery.state !== UPowerDeviceState.Unknown

  onChargingChanged: {
    if (!ready || !showCharging || !charging) return
    showHud({
      key: "power",
      layout: "label",
      label: "Charging",
      icon: Model.batteryIcon(batteryLevel, true),
      valueText: Model.percentText(batteryLevel),
      color: greenColor,
      duration: 2600
    })
  }

  property real lastBatteryLevel: -1
  onBatteryLevelChanged: {
    var previous = lastBatteryLevel
    lastBatteryLevel = batteryLevel
    if (!ready || !showCharging || charging || previous < 0) return
    var crossed = (previous > 0.2 && batteryLevel <= 0.2) || (previous > 0.1 && batteryLevel <= 0.1)
    if (!crossed) return
    showHud({
      key: "power",
      layout: "label",
      label: "Low Battery",
      icon: Model.batteryIcon(batteryLevel, false),
      valueText: Model.percentText(batteryLevel),
      color: urgentColor,
      duration: 3500
    })
  }

  // ------------------------------------------------------------------
  // Backlight: sysfs does not notify, so poll the one small file.
  // ------------------------------------------------------------------
  property string backlightDir: ""
  property int brightnessMax: 0
  property real brightness: -1

  Process {
    id: backlightProbe
    running: true
    command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && echo \"$d\" && cat \"$d/max_brightness\" && break; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        if (lines.length < 2) return
        root.brightnessMax = parseInt(lines[1], 10) || 0
        root.backlightDir = lines[0]
      }
    }
  }

  FileView {
    id: brightnessFile
    path: root.backlightDir ? root.backlightDir + "/brightness" : ""
    blockLoading: true
  }

  Timer {
    interval: 350
    repeat: true
    running: root.backlightDir !== "" && root.brightnessMax > 0 && root.showBrightness
    onTriggered: {
      brightnessFile.reload()
      var raw = parseInt(brightnessFile.text(), 10)
      if (isNaN(raw)) return
      var level = Model.clamp01(raw / root.brightnessMax)
      var previous = root.brightness
      root.brightness = level
      if (previous < 0 || Math.abs(level - previous) < 0.001 || !root.ready) return
      root.showHud({
        key: "brightness",
        layout: "progress",
        icon: Model.brightnessIcon(level),
        value: level,
        valueText: Math.round(level * 100) + "%",
        color: root.fg,
        duration: 1500
      })
    }
  }

  // ------------------------------------------------------------------
  // Screen recording (gpu-screen-recorder, which Omarchy's capture uses)
  // ------------------------------------------------------------------
  property bool recording: false
  property int recordingElapsed: 0

  Process {
    id: recordingProbe
    command: ["sh", "-c", "p=$(pgrep -of '^gpu-screen-recorder') && ps -o etimes= -p \"$p\""]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.demo && root.demo.recording !== undefined) return
        var elapsed = parseInt(String(text || "").trim(), 10)
        root.recording = !isNaN(elapsed)
        if (!isNaN(elapsed)) root.recordingElapsed = elapsed
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.showRecording
    triggeredOnStart: true
    onTriggered: if (!recordingProbe.running) recordingProbe.running = true
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.recordingActivity
    onTriggered: root.recordingElapsed++
  }

  // Same command the bar's recording indicator runs.
  function stopRecording() {
    if (demo && demo.recording !== undefined) {
      updateDemo(function(d) { d.recording = false })
      collapse()
      return
    }
    Quickshell.execDetached(["omarchy-capture-screenrecording", "--stop-recording"])
    collapse()
    recordingRecheck.restart()
  }

  Timer {
    id: recordingRecheck
    interval: 900
    onTriggered: if (!recordingProbe.running) recordingProbe.running = true
  }

  // ------------------------------------------------------------------
  // Takeovers: the island replaces Omarchy's notification service and its
  // on-screen display (the volume, brightness, microphone, keyboard light,
  // power and download popups at the bottom of the screen).
  //
  // Only one program can own each, so on first run the island disables the
  // Omarchy plugin (leaving a marker so it knows it did), and does the job
  // itself once that plugin has let go. Setting "notifications": false or
  // "osd": false, or disabling/removing this plugin, gives the job back.
  // ------------------------------------------------------------------
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island"
  readonly property bool wantsNotifications: setting("notifications", true) !== false
  readonly property bool wantsOsd: setting("osd", true) !== false
  readonly property bool omarchyNotificationsOff: disabledPlugins.indexOf("omarchy.notifications") !== -1
  readonly property bool omarchyOsdOff: disabledPlugins.indexOf("omarchy.osd") !== -1
  property bool notificationsReady: false
  property bool osdReady: false
  property var takeoverRequested: ({})

  onWantsNotificationsChanged: syncTakeovers()
  onOmarchyNotificationsOffChanged: syncTakeovers()
  onWantsOsdChanged: syncTakeovers()
  onOmarchyOsdOffChanged: syncTakeovers()
  onConfigLoadedChanged: {
    syncTakeovers()
    fillDefaultSettings()
    syncKeybind()
    syncGlass()
  }

  function syncTakeovers() {
    if (!configLoaded) return
    syncTakeover("notifications", wantsNotifications, omarchyNotificationsOff)
    syncTakeover("osd", wantsOsd, omarchyOsdOff)
    if (!(wantsNotifications && omarchyNotificationsOff)) notificationsReady = false
    if (!(wantsOsd && omarchyOsdOff)) osdReady = false
    takeoverReadyTimer.restart()
  }

  // `name` is both the Omarchy plugin (omarchy.<name>) and the marker file.
  function syncTakeover(name, wants, off) {
    if (wants === off || takeoverRequested[name]) return
    takeoverRequested[name] = true
    var args = ["sh", stateDir + "/" + name + "-takeover", "omarchy." + name]
    if (wants)
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\" && \"$OMARCHY_PATH/bin/omarchy-plugin-disable\" \"$2\""].concat(args))
    else
      // Only hand back what this plugin took.
      Quickshell.execDetached(["sh", "-c",
        "[ -f \"$1\" ] && \"$OMARCHY_PATH/bin/omarchy-plugin-enable\" \"$2\" && rm -f \"$1\""].concat(args))
  }

  // Give Omarchy's plugins a moment to let go after a reload.
  Timer {
    id: takeoverReadyTimer
    interval: 1500
    onTriggered: {
      root.notificationsReady = root.wantsNotifications && root.omarchyNotificationsOff
      root.osdReady = root.wantsOsd && root.omarchyOsdOff
    }
  }

  // ------------------------------------------------------------------
  // Settings in place: every setting the island's entry in shell.json lacks
  // is written there with its default, so people change values instead of
  // looking keys up. Values already there are never touched.
  // ------------------------------------------------------------------
  // shell.json is only ever written by Omarchy's shell (in-process, atomic):
  // this merges `changes` into the plugin's current entry and hands the whole
  // entry to shell.updateEntryInline, which replaces it.
  function saveSettings(changes) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    var next = {}
    for (var k in settings) if (k !== "id") next[k] = settings[k]
    for (var c in changes) next[c] = changes[c]
    return shell.updateEntryInline(pluginId, next)
  }

  onShellChanged: fillDefaultSettings()

  function fillDefaultSettings() {
    if (!configLoaded) return
    var missing = Model.missingSettings(settings)
    if (missing.length === 0) return
    var changes = {}
    for (var i = 0; i < missing.length; i++) changes[missing[i]] = Model.defaultSettings[missing[i]]
    saveSettings(changes)
  }

  // ------------------------------------------------------------------
  // Keybinding: the "keybind" setting (SUPER + ALT + I) toggles
  // reserveSpace. It lives in a marked block in ~/.config/hypr/bindings.lua.
  // A key something else already uses is left alone, "keybind": false
  // drops it, and disabling/removing the plugin removes the block.
  // ------------------------------------------------------------------
  readonly property string bindingsFile: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"
  readonly property string keybind: {
    var k = setting("keybind", Model.defaultSettings.keybind)
    return k === false ? "" : String(k).trim()
  }
  // Shell snippets for the file in $1 and plugin id $2. Edits are written to
  // a new file beside it and renamed over it, and a bindings.lua that is a
  // symlink or not a regular file is left alone.
  readonly property string bindingsGuard: "[ -f \"$1\" ] && [ ! -L \"$1\" ] || exit 0; "
  // Replace the file with stdin, atomically.
  readonly property string bindingsReplace:
    "t=$(mktemp \"$1.island.XXXXXX\") || exit 1; cat > \"$t\" && chmod --reference=\"$1\" \"$t\" " +
    "&& mv -f \"$t\" \"$1\" || rm -f \"$t\"; "
  readonly property string removeBindingsBlock:
    bindingsGuard +
    "grep -qxF -e \"-- BEGIN $2\" \"$1\" || exit 0; " +
    "sed \"/^-- BEGIN $2\\$/,/^-- END $2\\$/d\" \"$1\" | { " + bindingsReplace + "}; true"

  onKeybindChanged: syncKeybind()

  function syncKeybind() {
    if (!configLoaded) return
    var parsed = Model.parseKeybind(keybind)
    if (!parsed) {
      Quickshell.execDetached(["sh", "-c", removeBindingsBlock, "sh", bindingsFile, pluginId])
      return
    }
    var bind = "o.bind(\"" + keybind + "\", \"Toggle island reserved space\", " +
               "\"omarchy-shell dynamic-island reserveSpace toggle\")"
    var block = [
      "-- BEGIN " + pluginId,
      "-- Added by the " + pluginId + " plugin and removed with it. Change the key",
      "-- with \"keybind\" in its entry in ~/.config/omarchy/shell.json.",
      bind,
      "-- END " + pluginId
    ].join("\n")
    // $1 file, $2 id, $3 block, $4 bind line, $5 mask, $6 key. Only check for
    // a clash when our block doesn't already hold this key, since Hyprland
    // lists our own binding too.
    Quickshell.execDetached(["sh", "-c",
      bindingsGuard +
      "[ \"$(sed -n \"/^-- BEGIN $2\\$/,/^-- END $2\\$/p\" \"$1\")\" = \"$3\" ] && exit 0; " +
      "if ! grep -qxF -e \"$4\" \"$1\" && hyprctl binds -j 2>/dev/null | jq -e --argjson m \"$5\" --arg k \"$6\" " +
      "'any(.[]; .modmask == $m and (.key | ascii_downcase) == ($k | ascii_downcase))' >/dev/null; then " +
      "  (" + removeBindingsBlock + "); exit 0; fi; " +
      "{ sed \"/^-- BEGIN $2\\$/,/^-- END $2\\$/d\" \"$1\" | sed -e :a -e '/^\\n*$/{$d;N;ba' -e '}'; " +
      "echo; printf '%s\\n' \"$3\"; } | { " + bindingsReplace + "}",
      "sh", bindingsFile, pluginId, block, bind, String(parsed.mask), parsed.key])
  }

  // ------------------------------------------------------------------
  // Glass: Hyprland blurs behind the island the way it does behind the
  // Glassy bar, from a toggle file in Omarchy's toggles folder (which
  // Hyprland reads). It is written while "glass" is on and removed when it
  // is turned off or the plugin goes, and Hyprland reloads only on a change.
  // ------------------------------------------------------------------
  readonly property string glassToggleFile:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) +
    "/omarchy/toggles/hypr/dynamic-island-glass.lua"
  readonly property string glassRule: [
    "-- Added by the " + pluginId + " plugin and removed with it (or with \"glass\": false",
    "-- in its entry in ~/.config/omarchy/shell.json): frosted glass behind the",
    "-- island, like the Glassy bar.",
    "-- Hyprland only blurs anything while blur is on, so it is turned on with",
    "-- Omarchy's glass settings, and windows are kept out of it unless Glassy",
    "-- windows are on too: only the island frosts.",
    "require(\"default.hypr.glass\")()",
    "",
    "local paths = require(\"default.hypr.paths\")",
    "local glassy = io.open(paths.state_home .. \"/omarchy/toggles/hypr/window-glassy.lua\", \"r\")",
    "if glassy then",
    "  glassy:close()",
    "else",
    "  o.window({ class = \".*\" }, { no_blur = true })",
    "end",
    "",
    "hl.layer_rule({",
    "  match = { namespace = \"^dynamic-island$\" },",
    "  blur = true,",
    "  ignore_alpha = 0.3,",
    "})"
  ].join("\n")
  readonly property string hyprReload:
    "{ \"$OMARCHY_PATH/bin/omarchy-restart-hyprctl\" 2>/dev/null || hyprctl reload >/dev/null 2>&1; }; "
  readonly property string removeGlassRule:
    "[ -f \"$1\" ] || exit 0; rm -f \"$1\" && " + hyprReload + "true"

  onGlassOnChanged: syncGlass()

  function syncGlass() {
    if (!configLoaded) return
    if (!glassOn) {
      Quickshell.execDetached(["sh", "-c", removeGlassRule, "sh", glassToggleFile])
      return
    }
    // $1 file, $2 contents. Written beside it and renamed over it, so
    // Hyprland never reads half a file.
    Quickshell.execDetached(["sh", "-c",
      "[ -L \"$1\" ] && exit 0; [ -f \"$1\" ] && [ \"$(cat \"$1\")\" = \"$2\" ] && exit 0; " +
      "mkdir -p \"$(dirname \"$1\")\" || exit 0; " +
      "t=$(mktemp \"$1.XXXXXX\") || exit 0; " +
      "printf '%s\\n' \"$2\" > \"$t\" && mv -f \"$t\" \"$1\" || { rm -f \"$t\"; exit 0; }; " + hyprReload,
      "sh", glassToggleFile, glassRule])
  }

  // ------------------------------------------------------------------
  // Room in the bar. The notch sits on the bar's center section, an
  // omarchy.spacer the bar centers on the screen with the other center icons
  // hanging off both its edges. Keeping that spacer exactly as wide as the
  // closed notch puts those icons the bar's usual gap from it, the same on
  // both sides: tight around the clock at rest, wider while a live
  // activity's wings show (so they never cover an icon). Brief things (a
  // HUD, the open panel) float over the bar and move nothing. Growing is
  // applied at once, shrinking a moment later, so icons don't hop back and
  // forth. Only a center section that is just one spacer is touched;
  // "fitBarSpacer": false leaves it alone.
  // ------------------------------------------------------------------
  readonly property bool fitBarSpacer: setting("fitBarSpacer", true) !== false
  readonly property real liveWingWidth: live === "" ? 0
    : (live === "media" ? barHeight - s(10) + s(14) : s(Model.wingWidths[live] || 50))
  readonly property int barRoom: Math.ceil(live === "" ? clockWidth : clockWidth + 2 * liveWingWidth + 2 * earClosed)
  readonly property var barSpacer: barCenter.length === 1 && barCenter[0]
    && String(barCenter[0].id || "") === "omarchy.spacer" ? barCenter[0] : null

  onBarRoomChanged: {
    var current = barSpacer ? Number(barSpacer.size) || 0 : 0
    barRoomTimer.interval = barRoom >= current ? 60 : 1500
    barRoomTimer.restart()
  }
  onBarSpacerChanged: barRoomTimer.restart()
  onFitBarSpacerChanged: barRoomTimer.restart()

  Timer {
    id: barRoomTimer
    interval: 60
    onTriggered: root.syncBarRoom()
  }

  function syncBarRoom() {
    if (!configLoaded || !fitBarSpacer || !barSpacer || barRoom <= 0) return
    if (Number(barSpacer.size) === barRoom) return
    // Through `omarchy bar set`, so the shell itself writes the change (a
    // panel plugin may not edit the bar's layout directly).
    Quickshell.execDetached(["sh", "-c",
      "\"$OMARCHY_PATH/bin/omarchy-bar\" set omarchy.spacer size \"$1\" --json --section center --index 0 >/dev/null 2>&1",
      "sh", String(barRoom)])
  }

  // The shell destroys this object on reloads and restarts too, so only act
  // if, a few seconds later, the plugin is really gone from shell.json. Then
  // hand back everything the island took over and remove its keybinding.
  // The shell can be mid-reload right then, so re-enabling is retried, and a
  // marker goes once its plugin is no longer listed as disabled.
  Component.onDestruction: Quickshell.execDetached(["sh", "-c",
    "sleep 4; c=\"$HOME/.config/omarchy/shell.json\"; " +
    "jq -e --arg id \"$1\" '.plugins[]? | select(.id == $id)' \"$c\" >/dev/null 2>&1 && exit 0; " +
    "for t in notifications osd; do " +
    "  [ -f \"$2/$t-takeover\" ] || continue; " +
    "  for try in 1 2 3; do \"$OMARCHY_PATH/bin/omarchy-plugin-enable\" \"omarchy.$t\" >/dev/null 2>&1 && break; sleep 2; done; " +
    "  sleep 1; jq -e --arg p \"omarchy.$t\" '(.disabledPlugins // []) | index($p)' \"$c\" >/dev/null 2>&1 " +
    "    || rm -f \"$2/$t-takeover\"; " +
    "done; " +
    "(set -- \"$4\"; " + removeGlassRule + "); " +
    "set -- \"$3\" \"$1\"; " + removeBindingsBlock,
    "sh", pluginId, stateDir, bindingsFile, glassToggleFile])

  // Omarchy's `omarchy osd` and every script that calls it land here while
  // the island owns the OSD. Volume comes from PipeWire already, so its
  // popups are dropped; the rest show as island HUDs.
  function showOsd(payloadJson) {
    var payload
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { return }
    var next = Model.osdHud(payload, { volume: showVolume && !sink, brightness: showBrightness })
    if (!next) return
    next.color = next.dim ? fgDim : fg
    showHud(next)
  }

  IpcHandler {
    target: "osd"
    enabled: root.osdReady
    function show(payloadJson: string): string { root.showOsd(payloadJson); return "ok" }
    function close(): string {
      if (root.hud && ["osd", "volume", "brightness"].indexOf(root.hud.key) !== -1) root.hud = null
      return "ok"
    }
    function state(): string { return root.hud ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  Notifications {
    id: notifications
    island: root
    active: root.notificationsReady
  }

  readonly property var notification: notifications.current
  readonly property int notificationsPending: notifications.pending
  readonly property var inbox: notifications.inbox
  readonly property bool showInbox: setting("inbox", true) !== false

  function notificationOpen(key) {
    notifications.open(key)
    if (inboxOpen && inbox.length === 0) collapse()
  }

  function notificationDismiss(key) {
    notifications.dismiss(key)
    if (inboxOpen && inbox.length === 0) collapse()
  }

  function notificationAction(key, id) { notifications.invokeAction(key, id) }

  function notificationClearAll() {
    notifications.clearAll()
    collapse()
  }

  // An icon URL that will actually load, or "" for the glyph fallback.
  // Quickshell hands appIcon over as image://icon/<name> even when the theme
  // has no such icon (which renders as a magenta checkerboard), so theme
  // names are checked before use.
  function themedIcon(name) {
    var n = String(name || "")
    if (!n) return ""
    if (n.charAt(0) === "/") return "file://" + n
    return Quickshell.iconPath(n, true) || ""
  }

  function notificationIcon(entry) {
    if (!entry || entry.glyph) return ""
    var image = String(entry.image || "")
    if (image) {
      if (image.charAt(0) === "/") return "file://" + image
      if (image.indexOf("image://icon/") === 0) return themedIcon(image.substring(13))
      return image
    }
    var icon = String(entry.appIcon || "")
    if (icon.indexOf("image://icon/") === 0) icon = icon.substring(13)
    if (icon.indexOf("file://") === 0 || (icon.indexOf("://") !== -1 && icon.indexOf("image://icon/") !== 0)) return icon
    var themed = themedIcon(icon)
    if (themed) return themed
    var desktop = entry.desktopEntry ? DesktopEntries.byId(entry.desktopEntry) : null
    if (!desktop && entry.app) desktop = DesktopEntries.heuristicLookup(entry.app)
    return desktop && desktop.icon ? themedIcon(desktop.icon) : ""
  }

  // ------------------------------------------------------------------
  // Timer, stopwatch, Bluetooth devices, calendar, script activities
  // ------------------------------------------------------------------
  Clocks { id: clockSource; island: root }
  Devices { island: root }
  Calendar { id: calendarSource; island: root }
  Activities { id: activitySource; island: root }

  readonly property var clocks: clockSource
  readonly property var calendar: calendarSource
  readonly property var activity: activitySource.current

  function endActivity(id) { activitySource.end(id, "") }

  // Calendar links can also live in this plugin's shell.json entry
  // ("calendars"); the settings watcher picks the change up.
  function editCalendars(op, link) {
    var url = String(link)
    var list = (Array.isArray(settings.calendars) ? settings.calendars : []).filter(function(x) { return x !== url })
    if (op === "add") list.push(url)
    saveSettings({ calendars: list })
  }

  function addCalendar(link) {
    var l = String(link || "").trim()
    if (!l) return
    // Saved in the island's own file; the result (event count, or what went
    // wrong) is reported once the new link has actually been fetched.
    calendarSource.add(l)
  }

  function removeCalendar(link) { calendarSource.remove(link) }

  // "Paste" button: add whatever link is on the clipboard.
  Process {
    id: clipboardRead
    // Only the first 4 KiB: a link, not whatever else is on the clipboard.
    command: ["sh", "-c", "wl-paste --no-newline --type text 2>/dev/null | head -c 4096"]
    stdout: StdioCollector {
      onStreamFinished: {
        var link = String(text || "").trim().split(/\s+/)[0] || ""
        if (/^(https?|webcal):\/\//i.test(link) || /\.ics$/i.test(link)) {
          root.addCalendar(link)
          root.calendarAdding = false
        } else {
          root.showHud({ key: "calendar", layout: "label", label: "No calendar link copied", icon: "󰃭",
                         valueText: "", color: root.orangeColor, duration: 2200 })
        }
      }
    }
  }

  function addCalendarFromClipboard() {
    if (!clipboardRead.running) clipboardRead.running = true
  }

  function openLink(url) {
    Quickshell.execDetached(["xdg-open", String(url)])
    collapse()
  }

  // ------------------------------------------------------------------
  // Camera in use: any process holding a /dev/video* device open.
  // ------------------------------------------------------------------
  property bool cameraActive: false

  Process {
    id: cameraProbe
    command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -print -quit 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.demo && root.demo.camera !== undefined) return
        root.cameraActive = String(text || "").trim() !== ""
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.setting("camera", true) !== false
    triggeredOnStart: true
    onTriggered: if (!cameraProbe.running) cameraProbe.running = true
  }

  // ------------------------------------------------------------------
  // Media tint: the theme accent, or (visualizerColor: "artwork") the most
  // vivid color of the cover, like iOS. It colors the equalizer and glow.
  // ------------------------------------------------------------------
  ColorQuantizer {
    id: quantizer
    source: root.artworkTint && root.mediaArt ? root.mediaArt : ""
    depth: 3
    rescaleSize: 64
  }

  readonly property color mediaTint: {
    if (!artworkTint) return accentColor
    var best = null
    var bestScore = 0
    var colors = quantizer.colors || []
    for (var i = 0; i < colors.length; i++) {
      var c = colors[i]
      if (c.hsvValue < 0.35) continue
      var score = c.hsvSaturation * c.hsvValue
      if (score > bestScore) { best = c; bestScore = score }
    }
    return best && bestScore > 0.12 ? Qt.hsva(best.hsvHue, Math.max(0.45, best.hsvSaturation), Math.max(0.75, best.hsvValue), 1) : accentColor
  }

  // ------------------------------------------------------------------
  // Audio outputs ("Play on")
  // ------------------------------------------------------------------
  readonly property var audioOutputs: pwNodes.filter(function(n) { return n && n.isSink && !n.isStream && n.audio })

  function outputGlyph(node) {
    if (!node) return "󰓃"
    var id = (String(node.name || "") + " " + String(node.description || "")).toLowerCase()
    if (id.indexOf("bluez") !== -1 || id.indexOf("headphone") !== -1 || id.indexOf("headset") !== -1) return "󰋋"
    if (id.indexOf("hdmi") !== -1 || id.indexOf("displayport") !== -1) return "󰡁"
    return "󰓃"
  }

  // Output names usually share a long card prefix ("Raptor Lake-P/U/H cAVS
  // Speaker", "... HDMI / DisplayPort 1 Output"); drop the shared words.
  function outputLabel(node) {
    var name = String(node && (node.description || node.nickname || node.name) || "")
    var first = name.split(" ")[0]
    // Compare only against outputs from the same card (same first word), so
    // a Bluetooth headset in the list doesn't stop the trimming.
    var group = audioOutputs.map(function(n) { return String(n.description || n.nickname || n.name || "") })
      .filter(function(a) { return a.split(" ")[0] === first })
    if (group.length < 2) return name
    var words = name.split(" ")
    var common = 0
    while (common < words.length - 1 && group.every(function(a) {
      var w = a.split(" ")
      return w.length > common + 1 && w[common] === words[common]
    })) common++
    return words.slice(common).join(" ") || name
  }

  function selectOutput(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    closeOutputs()
    showHud({
      key: "output", layout: "label",
      label: outputLabel(node),
      icon: outputGlyph(node), valueText: "Playing on", color: accentColor, duration: 1800
    })
  }

  // ------------------------------------------------------------------
  // The clock and the width it needs.
  // ------------------------------------------------------------------
  SystemClock {
    id: idleClock
    precision: root.clockShowsSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }

  TextMetrics {
    id: clockMetrics
    font.family: root.fontFamily
    font.pixelSize: root.clockPixelSize
    text: root.formattedClockText
  }

  // Omarchy's bar clock pads its label by 8.75 spacing units either side.
  readonly property real clockWidth: Math.ceil(clockMetrics.advanceWidth) + 2 * Style.spaceReal(8.75)

  function formatElapsed(seconds) { return Model.formatTime(seconds) }
  function formatStopwatch(ms) {
    var sec = Math.max(0, ms) / 1000
    return sec < 3600 ? Model.formatClock(sec, true) : Model.formatTime(sec)
  }

  readonly property string batteryGlyph: Model.batteryIcon(batteryLevel, charging)
  readonly property string batteryPercentText: Model.percentText(batteryLevel)

  // Bring the playing app's window forward (cover click, like Boring Notch).
  function raisePlayer() {
    if (player && player.canRaise) player.raise()
    collapse()
  }

  // ------------------------------------------------------------------
  // State (Boring Notch model, see IslandModel.notchMode)
  // ------------------------------------------------------------------
  readonly property bool recordingActivity: showRecording
    && (demo && demo.recording !== undefined ? demo.recording === true : recording)
  readonly property bool mediaActivity: hasMedia && (mediaPlaying || mediaLinger || (demoMedia !== null))
  readonly property bool micActivity: showMic && (demo && demo.mic !== undefined ? demo.mic === true : micActive)
  readonly property bool inboxActivity: wantsNotifications && showInbox && inbox.length > 0
  readonly property bool timerActivity: clockSource.timerActive
  readonly property bool stopwatchActivity: clockSource.stopwatchActive
  readonly property bool scriptActivity: activitySource.current !== null
  readonly property bool calendarActivity: setting("calendar", true) !== false && calendarSource.soon

  readonly property var liveList: Model.liveActivities({
    recording: recordingActivity,
    timer: timerActivity,
    media: mediaActivity,
    mic: micActivity || (setting("camera", true) !== false && cameraActive),
    activity: scriptActivity,
    calendar: calendarActivity,
    stopwatch: stopwatchActivity
  })
  readonly property string live: liveList.length > 0 ? liveList[0] : ""
  // Kept for the IPC state dump and older callers.
  readonly property string primary: live
  readonly property string secondary: liveList.length > 1 ? liveList[1] : ""

  property bool userExpanded: false
  // The Shelf's files, kept here so they outlast the notch closing.
  property var shelfItems: []
  property string tab: "home"
  property bool outputsOpen: false
  property var hud: null
  // True from a collapse until the shape has settled closed: it closes
  // without overshoot (Boring Notch's critically damped close).
  property bool collapsing: false
  Timer { id: collapsingTimer; interval: 300; onTriggered: root.collapsing = false }

  readonly property bool hovered: islandHover.hovered

  readonly property string mode: Model.notchMode({
    open: userExpanded,
    notification: notification !== null,
    hud: hud,
    live: live !== ""
  })
  // `view` names what is on screen, for the IPC state and older views.
  readonly property string view: mode === "open" ? "open-" + tab : (mode === "live" ? live : mode)
  readonly property bool isIdleState: mode === "idle"
  // Kept for views that still ask (never true: the notch takes no keyboard).
  readonly property bool calendarTyping: false
  property bool calendarAdding: false
  readonly property bool inboxOpen: userExpanded && tab === "inbox"
  readonly property bool calendarOpen: userExpanded && tab === "calendar"

  // ---- geometry (unscaled targets; the window animates towards them)
  readonly property real earClosed: s(6)
  readonly property real earOpen: s(19)
  readonly property real cornerClosed: s(14)
  readonly property real cornerOpen: s(24)

  readonly property real wingWidth: {
    if (mode === "live") return live === "media" ? barHeight - s(10) + s(14) : s(Model.wingWidths[live] || 50)
    if (mode === "sneak") return s(Model.wingWidths.sneak)
    if (mode === "expand") return s(Model.wingWidths.expand)
    return 0
  }

  readonly property real openWidth: s(640)
  readonly property real openHeight: barHeight + s(178)
  readonly property real notificationHeight: barHeight + s(notification && notification.actions && notification.actions.length > 0 ? 118 : 80)

  // Target body size (between the ears) and corner radii for the mode.
  readonly property var target: {
    var ear = earClosed, corner = cornerClosed
    var w = clockWidth + 2 * wingWidth
    var h = barHeight
    if (mode === "open") { w = openWidth - 2 * earOpen; h = openHeight; ear = earOpen; corner = cornerOpen }
    else if (mode === "notification") { w = s(420); h = notificationHeight; ear = earOpen; corner = cornerOpen }
    return { w: w, h: h, ear: ear, corner: corner }
  }

  function showHud(next) {
    hud = next
    hudTimer.interval = Math.max(600, Number(next.duration) || 1600)
    hudTimer.restart()
  }

  Timer { id: hudTimer; onTriggered: root.hud = null }

  readonly property var tabIds: Model.visibleTabs({ inbox: wantsNotifications && showInbox && inbox.length > 0 }).map(function(t) { return t.id })

  onTabIdsChanged: if (tabIds.indexOf(tab) === -1) selectTab("home")

  function selectTab(name) {
    if (tabIds.indexOf(name) === -1) name = "home"
    if (name !== "home") outputsOpen = false
    tab = name
  }

  // Open the notch, on `name`'s tab if given. Opened without the pointer on
  // it (keybind, IPC, a click that then leaves), it closes on its own.
  function expand(name) {
    if (name) selectTab(name)
    else if (!userExpanded) selectTab(live ? Model.tabForActivity(live) : "home")
    hud = null
    collapsing = false
    userExpanded = true
    hoverOpenTimer.stop()
    if (!hovered) {
      leaveTimer.interval = 6000
      leaveTimer.restart()
    }
  }

  // Set when the notch closes with the pointer on it (scroll up, the
  // keybind, IPC): hover-open waits until the pointer has been off the notch
  // for a moment. (A notch shrinking under a still pointer reads as a leave
  // until it moves again, so a plain leave cannot end the hold.)
  property bool hoverOpenHeld: false
  Timer { id: holdRelease; interval: 1500; onTriggered: root.hoverOpenHeld = false }

  function collapse() {
    if (!userExpanded) return
    hoverOpenHeld = hovered
    if (hovered) holdRelease.stop()
    hoverOpenTimer.stop()
    collapsing = true
    collapsingTimer.restart()
    userExpanded = false
    outputsOpen = false
    leaveTimer.stop()
  }

  function toggleExpanded() {
    if (userExpanded) collapse()
    else expand("")
  }

  function openInbox() { expand("inbox") }
  function openCalendar() {
    if (userExpanded && tab === "calendar") collapse()
    else expand("calendar")
  }
  function openOutputs() { selectTab("home"); outputsOpen = true }
  function closeOutputs() { outputsOpen = false }

  // Hover opens a resting or live notch after a moment; transient things
  // (a HUD, a banner) never open under the pointer, so they can be read.
  Timer {
    id: hoverOpenTimer
    interval: root.hoverDelay
    onTriggered: {
      if (root.hovered && !root.hoverOpenHeld && !root.userExpanded && (root.mode === "idle" || root.mode === "live"))
        root.expand("")
    }
  }

  // Leaving closes it (Boring Notch closes 100ms after the pointer leaves).
  Timer {
    id: leaveTimer
    interval: 100
    onTriggered: if (!root.hovered) root.collapse()
  }

  onHoveredChanged: {
    if (hovered) {
      holdRelease.stop()
      leaveTimer.stop()
      if (openOnHover && !userExpanded && !hoverOpenHeld) hoverOpenTimer.restart()
    } else {
      if (hoverOpenHeld) holdRelease.restart()
      hoverOpenTimer.stop()
      if (userExpanded) {
        leaveTimer.interval = 100
        leaveTimer.restart()
      }
    }
  }

  // A closed notch's state can change under a resting pointer (a HUD ends):
  // pick hover-open back up then.
  onModeChanged: if (hovered && openOnHover && !hoverOpenHeld && (mode === "idle" || mode === "live")) hoverOpenTimer.restart()

  // `onClock`: the click landed on the clock (the middle of the top row).
  function islandClicked(button, onClock) {
    if (button === Qt.MiddleButton) {
      if (hasMedia) mediaToggle()
      return
    }
    // Right-clicking the clock walks its formats, open or closed (hover
    // opens the notch before a right click could land on a closed one).
    if (button === Qt.RightButton) {
      if (onClock) cycleClockFormat()
      return
    }
    if (userExpanded) return
    // A finished timer or a track change opens to what it was about.
    if (hud && hud.tab) { var t = hud.tab; hud = null; expand(t); return }
    if (hud && hud.layout === "track") { hud = null; expand("home"); return }
    expand("")
  }

  // Two-finger swipe (scroll): down opens, up closes.
  property real swipe: 0
  Timer { id: swipeReset; interval: 250; onTriggered: root.swipe = 0 }

  function handleWheel(dy) {
    swipe += dy
    swipeReset.restart()
    if (!userExpanded && swipe <= -120) { swipe = 0; expand("") }
    else if (userExpanded && swipe >= 120) { swipe = 0; collapse() }
  }

  // ------------------------------------------------------------------
  // Shell contract + IPC
  // ------------------------------------------------------------------
  readonly property bool opened: userExpanded

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) {}
    if (payload && payload.title) toast(payload)
    else expand()
  }

  function close() { collapse() }
  function toggle() { toggleExpanded() }

  function toneFor(name) {
    var n = String(name || "")
    if (n === "" || n === "accent") return accentColor
    if (n === "green" || n === "success") return greenColor
    if (n === "orange" || n === "yellow" || n === "warning") return orangeColor
    if (n === "red" || n === "urgent" || n === "error") return urgentColor
    if (n === "foreground") return fg
    return n
  }

  function toast(payload) {
    showHud({
      key: "toast",
      layout: "toast",
      title: String(payload.title || ""),
      body: String(payload.body || ""),
      icon: String(payload.icon || ""),
      color: toneFor(payload.color),
      tab: String(payload.tab || ""),
      duration: Number(payload.duration) || 4000
    })
  }

  readonly property string demoCoverPath: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/demo-cover.png"
  property bool demoCoverReady: false
  Process {
    running: true
    command: ["test", "-f", root.demoCoverPath]
    onExited: function(code) { root.demoCoverReady = code === 0 }
  }

  function runDemo(kind) {
    // Switching demo data swaps the "current track"; that is not a real track
    // change, so mark it as already shown before the debounce looks at it.
    Qt.callLater(function() { root.shownTrack = root.trackSignature })
    // A demo cover if one has been made (the showcase does), else the
    // current wallpaper stands in for album art.
    var art = demoCoverReady ? demoCoverPath : Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    var media = { playing: true, title: "Midnight City", artist: "M83", art: "file://" + art, length: 243 }
    if (kind === "off") {
      demo = null; hud = null; collapse(); recordingProbe.running = true; cameraProbe.running = true
      if (demoTimer) clocks.cancelTimer()
      if (demoStopwatch) clocks.resetStopwatch()
      demoTimer = false; demoStopwatch = false
      activitySource.end("demo", ""); calendarSource.refresh()
    } else if (kind === "media") {
      demo = { media: media }; mediaPosition = 71
    } else if (kind === "paused") {
      media.playing = false; demo = { media: media }; mediaPosition = 71
    } else if (kind === "recording") {
      demo = { recording: true }; recordingElapsed = 42
    } else if (kind === "mic") {
      demo = { mic: true }
    } else if (kind === "split") {
      demo = { media: media, recording: true }; recordingElapsed = 42; mediaPosition = 71
    } else if (kind === "expanded") {
      demo = { media: media }; mediaPosition = 71; expand()
    } else if (kind === "recording-expanded") {
      demo = { media: media, recording: true }; recordingElapsed = 42; mediaPosition = 71; expand()
    } else if (kind === "idle-expanded") {
      demo = { media: null, recording: false, mic: false }; expand()
    } else if (kind === "volume" || kind.indexOf("volume:") === 0) {
      var vol = kind.indexOf(":") > 0 ? Math.max(0, Math.min(100, parseInt(kind.split(":")[1], 10) || 0)) / 100 : 0.62
      showHud({ key: "volume", layout: "progress", icon: Model.volumeIcon(vol, false), value: vol, valueText: Math.round(vol * 100) + "%", color: fg, duration: 1600 })
    } else if (kind === "brightness") {
      showHud({ key: "brightness", layout: "progress", icon: Model.brightnessIcon(0.8), value: 0.8, valueText: "80%", color: fg, duration: 2500 })
    } else if (kind === "charging") {
      showHud({ layout: "label", label: "Charging", icon: Model.batteryIcon(0.8, true), valueText: "80%", color: greenColor, duration: 3000 })
    } else if (kind === "lowbattery") {
      showHud({ layout: "label", label: "Low Battery", icon: Model.batteryIcon(0.1, false), valueText: "10%", color: urgentColor, duration: 3000 })
    } else if (kind === "track") {
      demo = { media: media }; mediaPosition = 0; showHud({ layout: "track", duration: 3200 })
    } else if (kind === "notification" || kind === "notification-actions") {
      notifications.inject({
        app: "Slack", appIcon: "slack", summary: "Design review",
        body: "Can you share the island screenshots before standup?",
        actions: kind === "notification-actions" ? [{ id: "reply", text: "Reply" }, { id: "read", text: "Mark as Read" }] : []
      })
    } else if (kind === "inbox") {
      var samples = [
        { app: "Slack", appIcon: "slack", summary: "Design review", body: "Can you share the island screenshots?" },
        { app: "Chromium", appIcon: "chromium", summary: "GitHub", body: "Pull request #42 was merged" },
        { app: "omarchy-update", glyph: "󰚰", summary: "Update available", body: "Omarchy 4.0.5 is ready to install" }
      ]
      for (var i = 0; i < samples.length; i++) {
        notifications.inject(samples[i])
        notifications.retire(notifications.current.key)
      }
      openInbox()
    } else if (kind === "timer") {
      if (clocks.rawTimerActive && !demoTimer) return
      clocks.startTimer(272, "Tea"); demoTimer = true
    } else if (kind === "stopwatch") {
      if (clocks.stopwatchActive && !demoStopwatch) return
      clocks.resetStopwatch(); clocks.toggleStopwatch(); demoStopwatch = true
    } else if (kind === "activity") {
      activitySource.update("demo", { title: "Building omarchy-dynamic-island", subtitle: "Compiling views · 14 of 22", icon: "󰏗", progress: 0.64, color: "green", ttl: 60 })
    } else if (kind === "calendar") {
      calendarSource.demo()
    } else if (kind === "calendar-view") {
      calendarSource.demo(); openCalendar()
    } else if (kind === "camera") {
      demo = { camera: true }; cameraActive = true
    } else if (kind === "device") {
      showHud({ key: "device", layout: "label", label: "WH-1000XM5", icon: Model.deviceGlyph("audio-headset"), valueText: "82%", color: greenColor, duration: 3000 })
    } else if (kind === "outputs") {
      demo = { media: media }; mediaPosition = 71; openOutputs()
    } else if (kind === "toast") {
      toast({ title: "Build finished", body: "omarchy-dynamic-island · 0 errors", icon: "󰄬", color: "green" })
    } else {
      return "unknown demo: " + kind
    }
    return "ok"
  }

  // Save "reserveSpace" in this plugin's shell.json entry; the settings
  // watcher above applies it.
  function setReserveSpace(next) {
    saveSettings({ reserveSpace: next })
    showHud({
      key: "reserveSpace", layout: "label",
      label: next ? "Space kept for the island" : "Windows fill the top",
      icon: next ? "󰊔" : "󰊓", valueText: "", color: fg, duration: 1600
    })
  }

  IpcHandler {
    target: "dynamic-island"

    // Open on a tab: home | calendar | focus | ports | shelf | inbox
    // (older names: media, timer, pomodoro, stopwatch).
    function view(name: string): string {
      var n = String(name || "")
      var alias = { media: "home", timer: "focus", pomodoro: "focus", stopwatch: "focus" }
      root.expand(alias[n] || n)
      return "ok"
    }

    function expand(): string { root.expand(""); return "ok" }
    // on | off | toggle: keep a strip free for the island, or let windows
    // fill the top of the screen under it.
    function reserveSpace(mode: string): string {
      if (["on", "off", "toggle"].indexOf(mode) === -1) return "usage: reserveSpace on|off|toggle"
      var next = mode === "toggle" ? !root.reserveSpace : mode === "on"
      root.setReserveSpace(next)
      return next ? "on" : "off"
    }
    function collapse(): string { root.collapse(); return "ok" }
    function toggle(): string { root.toggleExpanded(); return "ok" }
    function toast(title: string, body: string, icon: string, color: string): string {
      root.toast({ title: title, body: body, icon: icon, color: color })
      return "ok"
    }
    function show(payloadJson: string): string { root.open(payloadJson); return "ok" }
    function demo(kind: string): string { return root.runDemo(kind) }

    // Timer: "25m", "90s", "1h30m", "10:00", or plain minutes.
    function timer(duration: string, label: string): string {
      var seconds = Model.parseDuration(duration)
      if (seconds <= 0) return "bad duration: " + duration
      root.clocks.startTimer(seconds, label)
      return "ok"
    }
    function timerToggle(): string { root.clocks.toggleTimer(); return "ok" }
    function timerCancel(): string { root.clocks.cancelTimer(); return "ok" }
    // Stopwatch: start | pause | toggle | reset
    function stopwatch(action: string): string {
      var a = String(action || "toggle")
      if (a === "reset") root.clocks.resetStopwatch()
      else if (a === "start" && !root.clocks.stopwatchRunning) root.clocks.toggleStopwatch()
      else if (a === "pause" && root.clocks.stopwatchRunning) root.clocks.toggleStopwatch()
      else if (a === "toggle") root.clocks.toggleStopwatch()
      return "ok"
    }
    // Live activity for scripts; payload is JSON (see Activities.qml).
    function activity(id: string, payloadJson: string): string {
      var payload = {}
      try { payload = JSON.parse(payloadJson || "{}") } catch (e) { return "bad json" }
      return activitySource.update(id, payload)
    }
    function endActivity(id: string, message: string): string { return activitySource.end(id, message) }
    function activities(): string { return JSON.stringify(activitySource.list()) }
    function refreshCalendar(): string { calendarSource.refresh(); return "ok" }
    function calendar(): string { root.openCalendar(); return "ok" }
    function pomodoro(): string { root.clocks.startPomodoro(); root.expand("focus"); return "ok" }
    function addCalendar(link: string): string { root.addCalendar(link); return "ok" }
    function removeCalendar(link: string): string { root.removeCalendar(link); return "ok" }
    function addCalendarFromClipboard(): string { root.addCalendarFromClipboard(); return "ok" }
    function state(): string {
      return JSON.stringify({
        view: root.view,
        mode: root.mode,
        hovered: root.hovered,
        tab: root.tab,
        primary: root.primary,
        secondary: root.secondary,
        expanded: root.userExpanded,
        hud: root.hud ? root.hud.layout : null,
        media: { has: root.hasMedia, playing: root.mediaPlaying, title: root.mediaTitle },
        recording: root.recordingActivity,
        mic: root.micActivity,
        battery: root.hasBattery ? Math.round(root.batteryLevel * 100) : null,
        brightness: root.brightness,
        timer: root.clocks.timerActive ? Math.ceil(root.clocks.timerLeft / 1000) : null,
        stopwatch: root.clocks.stopwatchActive ? Math.round(root.clocks.stopwatchElapsed / 100) / 10 : null,
        activity: root.activity ? root.activity.id : null,
        nextEvent: root.calendar.next ? root.calendar.next.title : null,
        camera: root.cameraActive,
        outputs: root.audioOutputs.length,
        calendarTyping: root.calendarTyping,
        calendar: {
          sources: root.calendar.sources.length,
          status: root.calendar.sources.map(function(l) { return root.calendar.statusOf(l) || "pending" }),
          upcoming: root.calendar.events.length,
          justAdded: root.calendar.justAdded !== ""
        },
        notifications: {
          serving: root.notificationsReady,
          omarchyDisabled: root.omarchyNotificationsOff,
          showing: root.notification ? root.notification.summary : null,
          pending: root.notificationsPending,
          inbox: root.inbox.length,
          dnd: notifications.doNotDisturb
        },
        screen: win.screen ? win.screen.name : null
      })
    }
    function ping(): string { return "ok" }
  }

  // ------------------------------------------------------------------
  // Window
  // ------------------------------------------------------------------
  readonly property var targetScreen: {
    // Qt supplies an unnamed placeholder when the last output disappears;
    // Hyprland can also briefly expose its FALLBACK output during reconnect.
    var screens = Quickshell.screens.filter(function(screen) {
      return screen.name !== "" && screen.name !== "FALLBACK"
    })
    if (screens.length === 0) return null
    var wanted = monitorSetting
    if (wanted === "focused" && Hyprland.focusedMonitor) wanted = Hyprland.focusedMonitor.name
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === wanted) return screens[i]
    return screens[0]
  }

  PanelWindow {
    id: win

    screen: root.targetScreen
    visible: screenRecovery.ready

    ScreenRecovery {
      id: screenRecovery
      window: win
      targetScreen: root.targetScreen
    }
    anchors { top: true; left: true; right: true }
    // Tall enough for the open notch and its shadow; only the notch itself
    // takes input, the rest of the strip is click-through.
    implicitHeight: root.openHeight + root.s(40)
    color: "transparent"

    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: root.setting("layer", "overlay") === "top" ? WlrLayer.Top : WlrLayer.Overlay
    // The notch never takes the keyboard from the app you are in.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Sit at y = 0, inside the bar. Reserving space is the separate
    // `reserver` window's job (binding exclusiveZone here would flip the
    // exclusion mode back and stack the notch under the bar).
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: hitbox }

    Item {
      id: stage
      anchors.fill: parent

      // The window only takes input inside the notch (its mask), so hovering
      // the stage is hovering the notch.
      HoverHandler { id: islandHover }

      // Boring Notch's springs, tuned snappy: opening overshoots a touch,
      // closing settles without one and a little faster. Everything else
      // (wings, HUDs) moves on the opening curve.
      readonly property int moveMs: Style.duration(root.collapsing ? 260 : 340)
      readonly property int moveEasing: root.collapsing ? Easing.OutCubic : Easing.OutBack

      property real w: root.target.w
      property real h: root.target.h
      property real ear: root.target.ear
      property real corner: root.target.corner

      Behavior on w { NumberAnimation { duration: stage.moveMs; easing.type: stage.moveEasing; easing.overshoot: 0.6 } }
      Behavior on h { NumberAnimation { duration: stage.moveMs; easing.type: stage.moveEasing; easing.overshoot: 0.6 } }
      Behavior on ear { NumberAnimation { duration: stage.moveMs; easing.type: Easing.OutCubic } }
      Behavior on corner { NumberAnimation { duration: stage.moveMs; easing.type: Easing.OutCubic } }

      // Body (between the ears) and the whole outline, on the pixel grid.
      readonly property real bodyW: root.snap(Math.max(0, w))
      readonly property real bodyH: root.snap(Math.max(1, h))
      readonly property real edgeL: root.snap((width - bodyW) / 2 - ear)
      readonly property real edgeR: edgeL + bodyW + 2 * ear

      // At rest the body is painted like the bar; with anything going on,
      // or under the pointer, it turns to frosted glass (or solid, with
      // "glass": false).
      readonly property real fill: root.mode === "idle" && !root.hovered ? root.restingAlpha : root.activeAlpha
      property real fillAnimated: fill
      Behavior on fillAnimated { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
      readonly property color bodyColor: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, fillAnimated)
      // How far the glass is up: 0 at rest, 1 once it has filled in. The
      // sheen and the rim follow it, so the resting notch stays just the bar.
      readonly property real glassTarget: root.glassOn && fill > root.restingAlpha ? 1 : 0
      property real glassAmount: glassTarget
      Behavior on glassAmount { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

      // ---- the outline: Boring Notch's NotchShape. Quadratic "ears" turn
      // out into the screen edge at the top; quadratic corners round the
      // bottom. One path, so there is no seam anywhere.
      Item {
        id: bodyLayer
        anchors.fill: parent
        // Shadow only while open, like Boring Notch.
        layer.enabled: root.mode === "open" || root.mode === "notification"
        layer.effect: MultiEffect {
          shadowEnabled: true
          // Kept faint enough to stay under Hyprland's blur threshold, so the
          // shadow never frosts what is around the notch.
          shadowColor: Qt.rgba(0, 0, 0, root.glassOn ? 0.4 : 0.55)
          shadowBlur: 0.6
          shadowVerticalOffset: 2
          autoPaddingEnabled: true
        }

        Shape {
          id: notchShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          visible: stage.fillAnimated > 0.002

          readonly property real t: Math.min(stage.ear, stage.bodyH / 2)
          readonly property real b: Math.max(0, Math.min(stage.corner, stage.bodyH - t, stage.bodyW / 2))
          readonly property real l: stage.edgeL
          readonly property real r: stage.edgeR
          readonly property real hh: stage.bodyH

          // The tint: the bar's color, see-through when glass is on (Hyprland
          // blurs what is behind it).
          NotchOutline {
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: stage.bodyColor
            l: notchShape.l; r: notchShape.r; t: notchShape.t; b: notchShape.b; hh: notchShape.hh
          }

          // Sheen: light falling on the glass from the screen edge, gone a
          // little way down. Only while the glass is up, never at rest.
          NotchOutline {
            strokeColor: "transparent"
            strokeWidth: 0
            l: notchShape.l; r: notchShape.r; t: notchShape.t; b: notchShape.b; hh: notchShape.hh
            fillGradient: LinearGradient {
              x1: 0; y1: 0
              x2: 0; y2: Math.max(1, notchShape.hh)
              GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07 * stage.glassAmount) }
              GradientStop { position: Math.min(0.9, root.barHeight * 1.6 / Math.max(1, notchShape.hh)); color: Qt.rgba(1, 1, 1, 0.02 * stage.glassAmount) }
              GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.035 * stage.glassAmount) }
            }
          }

          // Rim: a hairline catching the light along the sides and bottom,
          // the edge Raycast and macOS glass draw. Open at the top, where
          // the notch meets the screen edge.
          NotchOutline {
            closed: false
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 1, 1, 0.16 * stage.glassAmount)
            strokeWidth: 1 / root.dpr
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            l: notchShape.l; r: notchShape.r; t: notchShape.t; b: notchShape.b; hh: notchShape.hh
          }
        }
      }

      // What takes input: the whole outline, ears included.
      Item {
        id: hitbox
        // Opening, it takes the full open size at once, so a quick move
        // down into the panel never outruns the growing shape.
        readonly property bool opening: root.mode === "open" || root.mode === "notification"
        readonly property real fullW: root.target.w + 2 * root.target.ear
        x: opening ? Math.min(stage.edgeL, root.snap((stage.width - fullW) / 2)) : stage.edgeL
        y: 0
        width: opening ? Math.max(stage.edgeR - stage.edgeL, fullW) : Math.max(1, stage.edgeR - stage.edgeL)
        height: opening ? Math.max(stage.bodyH, root.target.h) : stage.bodyH

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: root.userExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor
          onClicked: function(mouse) {
            var centre = width / 2
            var onClock = mouse.y <= root.barHeight
              && Math.abs(mouse.x - centre) <= root.clockWidth / 2
            root.islandClicked(mouse.button, onClock)
          }
          onWheel: function(wheel) { root.handleWheel(wheel.inverted ? -wheel.angleDelta.y : wheel.angleDelta.y) }
        }

        // Dragging a file onto the notch opens the Shelf to drop it on.
        DropArea {
          anchors.fill: parent
          onEntered: function(drag) {
            drag.accepted = false
            if (!root.userExpanded || root.tab !== "shelf") root.expand("shelf")
          }
        }
      }

      // Content: clipped to the body. A plain clipping Item (no layer), so
      // text stays sharp at fractional scaling.
      Item {
        id: island
        x: stage.edgeL + notchShape.t
        y: 0
        width: stage.bodyW
        height: stage.bodyH
        clip: true

        // Where the top row's three zones are: wings or header either side
        // of the clock, which never moves.
        readonly property real clockX: root.snap((width - root.clockWidth) / 2)
        readonly property real sideW: Math.max(0, (width - root.clockWidth) / 2)

        NotchClock {
          x: island.clockX
          y: 0
          width: root.clockWidth
          height: root.barHeight
          island: root
        }

        // ---- closed: live activity wings
        Item {
          id: liveWings
          readonly property bool on: root.mode === "live"
          anchors.fill: parent
          opacity: on ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Style.duration(liveWings.on ? 160 : 80) } }

          WingLive {
            x: 0
            width: island.sideW
            height: root.barHeight
            island: root
            kind: root.live
            leading: true
          }

          WingLive {
            x: island.clockX + root.clockWidth
            width: island.sideW
            height: root.barHeight
            island: root
            kind: root.live
            leading: false
          }
        }

        // ---- closed: sneak peek / expanding strip
        Item {
          id: hudWings
          readonly property bool on: root.mode === "sneak" || root.mode === "expand"
          anchors.fill: parent
          opacity: on ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Style.duration(hudWings.on ? 160 : 80) } }

          WingHud {
            x: 0
            width: island.sideW
            height: root.barHeight
            island: root
            leading: true
          }

          WingHud {
            x: island.clockX + root.clockWidth
            width: island.sideW
            height: root.barHeight
            island: root
            leading: false
          }
        }

        // ---- open: tabs | clock | status
        Item {
          id: header
          readonly property bool on: root.mode === "open"
          anchors.fill: parent
          opacity: on ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Style.duration(header.on ? 180 : 70) } }

          NotchTabs {
            x: root.s(12)
            width: island.sideW - root.s(12)
            height: root.barHeight
            island: root
            anchors.top: parent.top
            anchors.topMargin: Math.round((root.barHeight - height) / 2)
          }

          NotchStatus {
            x: island.clockX + root.clockWidth
            width: island.sideW - root.s(12)
            height: root.barHeight
            island: root
          }
        }

        // ---- open: the tab
        Item {
          id: body
          x: root.s(12)
          y: root.barHeight + root.s(4)
          width: root.openWidth - 2 * root.earOpen - root.s(24)
          height: root.openHeight - y - root.s(14)

          TabSlot {
            active: root.mode === "open" && root.tab === "home"
            content: Component { HomeTab { island: root } }
          }

          TabSlot {
            active: root.mode === "open" && root.tab === "calendar"
            content: Component { CalendarTab { island: root } }
          }

          TabSlot {
            active: root.mode === "open" && root.tab === "focus"
            content: Component { FocusTab { island: root } }
          }

          TabSlot {
            active: root.mode === "open" && root.tab === "ports"
            content: Component { PortsView { island: root } }
          }

          TabSlot {
            active: root.mode === "open" && root.tab === "shelf"
            content: Component { ShelfView { island: root } }
          }

          TabSlot {
            active: root.mode === "open" && root.tab === "inbox"
            content: Component { InboxView { island: root } }
          }
        }

        // ---- a notification dropping out of the notch
        TabSlot {
          active: root.mode === "notification"
          x: 0
          y: root.barHeight
          width: island.width
          height: root.notificationHeight - root.barHeight
          content: Component { NotificationView { island: root } }
        }
      }
    }
  }

  // reserveSpace: a separate, invisible, click-through strip that only holds
  // the exclusive zone, so the island window itself can ignore exclusion and
  // stay flush with the screen edge. It must be on Overlay: Hyprland lays out
  // exclusive zones layer by layer, and on Bottom it would claim y = 0 ahead
  // of the bar (Top) and push the bar down. On Overlay it lands under the
  // bar, so tiled windows start below both.
  PanelWindow {
    id: reserver
    screen: root.targetScreen
    visible: root.reserveSpace && screenRecovery.ready
    anchors { top: true; left: true; right: true }
    implicitHeight: 1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "dynamic-island-reserve"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.barHeight
  }
}
