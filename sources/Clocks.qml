import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Pomodoro, kitchen timer and stopwatch.
//
// Pomodoro runs on the focusd daemon when it answers (it keeps the cycle,
// the daily goal and the streak); without it, the island runs its own
// 25 / 5 / 15 cycle. The kitchen timer (the 5/15/25 minute buttons and the
// `timer` IPC) is separate, so a quick timer never disturbs a focus session.
//
// What the notch shows as a live activity is `timerActive`: the kitchen
// timer while it runs, else a Pomodoro session that has actually started.
// An untouched 25:00 is never shown.
Item {
  id: clocks

  property var island: null
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/clocks.json"

  property double now: Date.now()

  FocusdSource {
    id: focusd
    // focusd ran a session out (not a skip): say so, as the built-in
    // cycle does.
    onSessionFinished: function(finished, next) {
      var wasWork = finished === "work"
      clocks.announce(wasWork ? "Focus complete" : "Break over",
                      next === "long-break" ? "Long break next" : (next === "short-break" ? "Short break next" : "Focus next"),
                      wasWork ? "green" : "accent")
    }
  }
  readonly property var focusdSource: focusd
  readonly property bool usesFocusd: focusd.available

  // ------------------------------------------------------------------
  // Built-in Pomodoro (only when focusd is not running)
  // ------------------------------------------------------------------
  property string pomoPhase: "work"      // work | short-break | long-break
  property int pomoCompleted: 0          // work sessions finished this cycle run
  readonly property int pomoTarget: usesFocusd ? focusd.workSessionsBeforeLongBreak : 4
  property double pomoEnd: 0             // epoch ms while running
  property double pomoLeftPaused: 0      // ms left while paused
  property bool pomoPausedFlag: false

  function phaseMinutes(phase) { return phase === "short-break" ? 5 : (phase === "long-break" ? 15 : 25) }
  readonly property double pomoTotal: phaseMinutes(pomoPhase) * 60000
  readonly property bool builtinPomoActive: pomoEnd > 0 || pomoPausedFlag
  readonly property double builtinPomoLeft: pomoPausedFlag ? pomoLeftPaused
    : (pomoEnd > 0 ? Math.max(0, pomoEnd - now) : pomoTotal)

  // ---- Pomodoro, whichever engine runs it
  readonly property bool pomoActive: usesFocusd ? focusd.active : builtinPomoActive
  readonly property bool pomoRunning: usesFocusd ? focusd.running : (pomoEnd > 0 && !pomoPausedFlag)
  readonly property bool pomoPaused: pomoActive && !pomoRunning
  readonly property string pomoSession: usesFocusd ? focusd.session : pomoPhase
  readonly property bool pomoBreak: pomoSession !== "work"
  readonly property int pomoLeftSeconds: usesFocusd ? focusd.remainingSeconds : Math.ceil(builtinPomoLeft / 1000)
  readonly property real pomoProgress: usesFocusd ? focusd.progress
    : (pomoTotal > 0 ? Math.max(0, Math.min(1, 1 - builtinPomoLeft / pomoTotal)) : 0)
  // Work sessions done in the current round of `pomoTarget`.
  // focusd counts a work session as completed only once the next one
  // starts, so during its break it is one behind; a long break follows a
  // full round, so it shows every one done.
  readonly property int pomoCycleDone: {
    var target = Math.max(1, pomoTarget)
    if (pomoSession === "long-break") return target
    if (usesFocusd) return (focusd.completedSessions + (pomoBreak ? 1 : 0)) % target
    return pomoCompleted % 4
  }
  readonly property string pomoLabel: pomoSession === "short-break" ? "Short break"
    : (pomoSession === "long-break" ? "Long break" : "Focus")
  readonly property string nextLabel: usesFocusd ? focusd.nextSessionLabel
    : (pomoBreak ? "Focus" : ((pomoCompleted + 1) % 4 === 0 ? "Long Break" : "Short Break"))

  function pomoToggle() {
    if (usesFocusd) {
      if (!focusd.active) focusd.start("")
      else focusd.toggle()
      return
    }
    now = Date.now()
    if (!builtinPomoActive) {
      pomoEnd = now + pomoTotal
    } else if (pomoPausedFlag) {
      pomoEnd = now + pomoLeftPaused
      pomoPausedFlag = false
    } else {
      pomoLeftPaused = Math.max(0, pomoEnd - now)
      pomoEnd = 0
      pomoPausedFlag = true
    }
    save()
  }

  function pomoStart() {
    if (usesFocusd) { if (!focusd.running) pomoToggle(); return }
    if (!pomoRunning) pomoToggle()
  }

  function pomoSkip() {
    if (usesFocusd) { focusd.skip(); return }
    advancePhase(false)
  }

  function pomoReset() {
    if (usesFocusd) { focusd.reset(); return }
    pomoEnd = 0
    pomoPausedFlag = false
    pomoLeftPaused = 0
    pomoPhase = "work"
    save()
  }

  function pomoAddMinutes(mins) {
    if (usesFocusd) { focusd.addMinutes(mins); return }
    if (!builtinPomoActive) return
    var ms = mins * 60000
    if (pomoPausedFlag) pomoLeftPaused += ms
    else pomoEnd += ms
    save()
  }

  // Ends the current built-in phase and starts the next one (`finished`:
  // it ran out, so announce it).
  function advancePhase(finished) {
    var wasWork = pomoPhase === "work"
    if (wasWork) pomoCompleted++
    pomoPhase = wasWork ? (pomoCompleted % 4 === 0 ? "long-break" : "short-break") : "work"
    pomoPausedFlag = false
    pomoLeftPaused = 0
    // A finished phase waits for a click to start the next one; a skipped
    // one starts it straight away.
    pomoEnd = finished ? 0 : Date.now() + pomoTotal
    save()
    if (finished) announce(wasWork ? "Focus complete" : "Break over",
                           wasWork ? (pomoPhase === "long-break" ? "Long break · 15m" : "Short break · 5m") : "Focus · 25m",
                           wasWork ? "green" : "accent")
  }

  // ------------------------------------------------------------------
  // Kitchen timer
  // ------------------------------------------------------------------
  property double rawTimerEnd: 0
  property double rawTimerLeftPaused: 0
  property double rawTimerTotal: 0
  property bool rawTimerPaused: false
  property string rawTimerLabel: ""

  readonly property bool rawTimerActive: rawTimerEnd > 0 || rawTimerPaused
  readonly property double rawTimerLeft: rawTimerPaused ? rawTimerLeftPaused : Math.max(0, rawTimerEnd - now)
  readonly property real rawTimerProgress: rawTimerTotal > 0 ? Math.max(0, Math.min(1, 1 - rawTimerLeft / rawTimerTotal)) : 0

  function startTimer(seconds, label) {
    var lbl = String(label || "Timer")
    // `pomodoro` IPC and older callers: a focus label means a Pomodoro.
    if (/^(pomodoro|focus)$/i.test(lbl.trim())) { pomoStart(); return }
    var ms = Math.max(1, Number(seconds) || 60) * 1000
    now = Date.now()
    rawTimerTotal = ms
    rawTimerEnd = now + ms
    rawTimerPaused = false
    rawTimerLeftPaused = 0
    rawTimerLabel = lbl
    save()
  }

  function startPomodoro() { pomoStart() }

  function toggleTimer() {
    if (!rawTimerActive) { pomoToggle(); return }
    now = Date.now()
    if (rawTimerPaused) {
      rawTimerEnd = now + rawTimerLeftPaused
      rawTimerPaused = false
    } else {
      rawTimerLeftPaused = Math.max(0, rawTimerEnd - now)
      rawTimerEnd = 0
      rawTimerPaused = true
    }
    save()
  }

  function cancelTimer() {
    rawTimerEnd = 0
    rawTimerPaused = false
    rawTimerLeftPaused = 0
    rawTimerTotal = 0
    rawTimerLabel = ""
    save()
  }

  function addToTimer(seconds) {
    if (!rawTimerActive) { pomoAddMinutes(Math.max(1, Math.round(seconds / 60))); return }
    var ms = seconds * 1000
    if (rawTimerPaused) rawTimerLeftPaused += ms
    else rawTimerEnd += ms
    rawTimerTotal += ms
    save()
  }

  // ------------------------------------------------------------------
  // What the notch shows: the kitchen timer first, else the Pomodoro.
  // ------------------------------------------------------------------
  readonly property bool timerActive: rawTimerActive || pomoActive
  readonly property bool showingRaw: rawTimerActive
  readonly property bool timerPaused: showingRaw ? rawTimerPaused : pomoPaused
  readonly property real timerProgress: showingRaw ? rawTimerProgress : pomoProgress
  readonly property double timerLeft: showingRaw ? rawTimerLeft : pomoLeftSeconds * 1000
  readonly property string timerLabel: showingRaw ? rawTimerLabel : pomoLabel
  readonly property bool isPomodoro: !showingRaw && pomoActive
  readonly property bool isBreak: isPomodoro && pomoBreak
  readonly property string timeDisplay: Model.formatClock(Math.ceil(timerLeft / 1000))
  readonly property int completedSessions: pomoCycleDone

  // ------------------------------------------------------------------
  // Stopwatch
  // ------------------------------------------------------------------
  property double stopwatchStart: 0
  property double stopwatchBanked: 0
  property bool stopwatchRunning: false

  readonly property bool stopwatchActive: stopwatchRunning || stopwatchBanked > 0
  readonly property double stopwatchElapsed: stopwatchBanked + (stopwatchRunning ? now - stopwatchStart : 0)

  function toggleStopwatch() {
    now = Date.now()
    if (stopwatchRunning) {
      stopwatchBanked += now - stopwatchStart
      stopwatchRunning = false
    } else {
      stopwatchStart = now
      stopwatchRunning = true
    }
    save()
  }

  function resetStopwatch() {
    stopwatchRunning = false
    stopwatchBanked = 0
    stopwatchStart = 0
    save()
  }

  function dismissActive() {
    if (rawTimerActive) cancelTimer()
    else if (stopwatchActive) resetStopwatch()
    else pomoReset()
  }

  // ------------------------------------------------------------------
  // Ticking
  // ------------------------------------------------------------------
  Timer {
    interval: clocks.stopwatchRunning ? 100 : 250
    repeat: true
    running: (clocks.rawTimerActive && !clocks.rawTimerPaused) || clocks.stopwatchRunning
      || (!clocks.usesFocusd && clocks.pomoEnd > 0)
    onTriggered: {
      clocks.now = Date.now()
      if (clocks.rawTimerActive && !clocks.rawTimerPaused && clocks.rawTimerEnd <= clocks.now) clocks.rawTimerFinished()
      if (!clocks.usesFocusd && clocks.pomoEnd > 0 && clocks.pomoEnd <= clocks.now) {
        // Only a session seen running out is announced; one that ended
        // long ago (focusd was the engine meanwhile) just clears.
        if (clocks.now - clocks.pomoEnd < 5000) clocks.advancePhase(true)
        else { clocks.pomoEnd = 0; clocks.save() }
      }
    }
  }

  function rawTimerFinished() {
    var label = rawTimerLabel || "Timer"
    cancelTimer()
    announce(label, "Done", "accent")
  }

  function announce(title, body, color) {
    if (island) island.toast({ title: title, body: body, icon: "󰔛", color: color, duration: 6000, tab: "focus" })
    if (island && island.setting("timerSound", true) !== false) {
      Quickshell.execDetached(["sh", "-c",
        "for i in 1 2; do pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null " +
        "|| paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; done"])
    }
  }

  // ------------------------------------------------------------------
  // Persistence
  // ------------------------------------------------------------------
  property bool restored: false

  function save() {
    if (!restored) return
    stateFile.setText(JSON.stringify({
      timerEnd: rawTimerEnd, timerLeftPaused: rawTimerLeftPaused, timerTotal: rawTimerTotal,
      timerPaused: rawTimerPaused, timerLabel: rawTimerLabel,
      pomoPhase: pomoPhase, pomoCompleted: pomoCompleted, pomoEnd: pomoEnd,
      pomoLeftPaused: pomoLeftPaused, pomoPaused: pomoPausedFlag,
      stopwatchStart: stopwatchStart, stopwatchBanked: stopwatchBanked, stopwatchRunning: stopwatchRunning
    }) + "\n")
  }

  FileView {
    id: stateFile
    path: clocks.statePath
    printErrors: false
    atomicWrites: true
    onLoaded: {
      if (clocks.restored) return
      clocks.restored = true
      var s = {}
      try { s = JSON.parse(text() || "{}") } catch (e) { s = {} }
      clocks.now = Date.now()
      // Older files kept Pomodoros in the kitchen timer; drop those.
      var legacyPomo = /^(pomodoro|focus|break|short break|long break)$/i.test(String(s.timerLabel || "").trim())
      clocks.rawTimerEnd = legacyPomo ? 0 : (Number(s.timerEnd) || 0)
      clocks.rawTimerLeftPaused = legacyPomo ? 0 : (Number(s.timerLeftPaused) || 0)
      clocks.rawTimerTotal = legacyPomo ? 0 : (Number(s.timerTotal) || 0)
      clocks.rawTimerPaused = !legacyPomo && s.timerPaused === true
      clocks.rawTimerLabel = legacyPomo ? "" : String(s.timerLabel || "")
      clocks.pomoPhase = ["work", "short-break", "long-break"].indexOf(s.pomoPhase) !== -1 ? s.pomoPhase : "work"
      clocks.pomoCompleted = Number(s.pomoCompleted) || 0
      clocks.pomoEnd = Number(s.pomoEnd) || 0
      clocks.pomoLeftPaused = Number(s.pomoLeftPaused) || 0
      clocks.pomoPausedFlag = s.pomoPaused === true
      clocks.stopwatchStart = Number(s.stopwatchStart) || 0
      clocks.stopwatchBanked = Number(s.stopwatchBanked) || 0
      clocks.stopwatchRunning = s.stopwatchRunning === true
      // A timer that ran out while the shell was down is simply over.
      if (clocks.rawTimerEnd > 0 && !clocks.rawTimerPaused && clocks.rawTimerEnd <= clocks.now) clocks.cancelTimer()
      if (clocks.pomoEnd > 0 && clocks.pomoEnd <= clocks.now) { clocks.pomoEnd = 0; clocks.save() }
    }
    onLoadFailed: clocks.restored = true
  }
}
