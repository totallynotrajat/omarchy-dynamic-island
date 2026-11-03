import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Timer, Stopwatch, and Pomodoro engine.
// Supports native Pomodoro cycles (Work 25m, Short Break 5m, Long Break 15m)
// and integrates with the focusd daemon when actively running.
Item {
  id: clocks

  property var island: null
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/clocks.json"

  property double now: Date.now()

  // ---- Focusd Daemon Source (only active when running or progress > 0)
  FocusdSource {
    id: focusd
  }

  readonly property var focusdSource: focusd
  readonly property bool isFocusd: focusd.active

  // ---- Built-in Pomodoro Tracking
  property int pomodoroCompleted: 0
  property int pomodoroTarget: 4
  property string pomodoroPhase: "work" // "work", "short-break", "long-break"

  // ---- Standard Wall-Clock Fallback Timer
  property double rawTimerEnd: 0          // epoch ms while running
  property double rawTimerLeftPaused: 0   // ms left while paused
  property double rawTimerTotal: 0        // ms, for the progress ring
  property bool rawTimerPaused: false
  property string rawTimerLabel: ""

  readonly property bool rawTimerActive: rawTimerEnd > 0 || rawTimerPaused
  readonly property double rawTimerLeft: rawTimerPaused ? rawTimerLeftPaused : Math.max(0, rawTimerEnd - now)
  readonly property real rawTimerProgress: rawTimerTotal > 0 ? Math.max(0, Math.min(1, 1 - rawTimerLeft / rawTimerTotal)) : 0

  // Unified timer interface consumed by Island.qml & compact/expanded views
  // ONLY true when a timer is genuinely active or running
  readonly property bool timerActive: isFocusd || rawTimerActive
  readonly property bool timerPaused: isFocusd ? focusd.paused : rawTimerPaused
  readonly property real timerProgress: isFocusd ? focusd.progress : rawTimerProgress
  readonly property double phaseDuration: (pomodoroPhase === "short-break" ? 5 : (pomodoroPhase === "long-break" ? 15 : 25)) * 60000
  readonly property double timerLeft: isFocusd ? (focusd.remainingSeconds * 1000) : (rawTimerActive ? rawTimerLeft : phaseDuration)
  readonly property string timerLabel: isFocusd ? focusd.sessionLabel : (rawTimerLabel || (pomodoroPhase === "short-break" ? "Short Break" : (pomodoroPhase === "long-break" ? "Long Break" : "Pomodoro")))

  // Any focus or break label ("Pomodoro", "Focus", "Deep Work",
  // "Short Break", ...) belongs to the Pomodoro cycle; anything else is a
  // plain kitchen timer.
  function isBreakLabel(label) { return /break/i.test(String(label || "")) }
  function isWorkLabel(label) { return /pomodoro|work|focus/i.test(String(label || "")) }

  readonly property bool isPomodoro: timerActive && (isFocusd || isWorkLabel(rawTimerLabel) || isBreakLabel(rawTimerLabel))
  readonly property bool isBreak: isFocusd ? focusd.session !== "work"
    : (rawTimerActive ? isBreakLabel(rawTimerLabel) : pomodoroPhase !== "work")
  readonly property string timeDisplay: Model.formatClock(Math.ceil(timerLeft / 1000))
  readonly property int completedSessions: isFocusd ? focusd.completedSessions : pomodoroCompleted

  // ---- stopwatch
  property double stopwatchStart: 0    // epoch ms of the current run
  property double stopwatchBanked: 0   // ms from earlier runs
  property bool stopwatchRunning: false

  readonly property bool stopwatchActive: stopwatchRunning || stopwatchBanked > 0
  readonly property double stopwatchElapsed: stopwatchBanked + (stopwatchRunning ? now - stopwatchStart : 0)

  Timer {
    interval: clocks.stopwatchRunning ? 100 : 250
    repeat: true
    running: (clocks.rawTimerActive && !clocks.rawTimerPaused) || clocks.stopwatchRunning
    onTriggered: {
      clocks.now = Date.now()
      if (clocks.rawTimerActive && !clocks.rawTimerPaused && clocks.rawTimerEnd <= clocks.now) clocks.timerFinished()
    }
  }

  function startTimer(seconds, label) {
    var sec = Number(seconds) || 1500
    var lbl = String(label || "Timer")

    // If focusd is present and label indicates pomodoro, try starting focusd
    if (isFocusd && (lbl.toLowerCase().indexOf("pomo") !== -1 || lbl.toLowerCase().indexOf("focus") !== -1)) {
      focusd.start()
      pomodoroPhase = "work"
      return
    }

    if (isBreakLabel(lbl)) pomodoroPhase = /long/i.test(lbl) ? "long-break" : "short-break"
    else if (isWorkLabel(lbl)) pomodoroPhase = "work"

    var ms = Math.max(1, sec) * 1000
    now = Date.now()
    rawTimerTotal = ms
    rawTimerEnd = now + ms
    rawTimerPaused = false
    rawTimerLeftPaused = 0
    rawTimerLabel = lbl
    save()
  }

  function startPomodoro() {
    startTimer(25 * 60, "Pomodoro")
  }

  function toggleTimer() {
    if (isFocusd) {
      focusd.toggle()
      return
    }
    if (!rawTimerActive) {
      if (pomodoroPhase === "short-break") {
        startTimer(5 * 60, "Short Break")
      } else if (pomodoroPhase === "long-break") {
        startTimer(15 * 60, "Long Break")
      } else {
        startPomodoro()
      }
      return
    }
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

  function skipPomodoro() {
    if (isFocusd) {
      focusd.skip()
      return
    }
    if (!isBreak) {
      pomodoroCompleted++
      if (pomodoroCompleted % 4 === 0) {
        pomodoroPhase = "long-break"
        startTimer(15 * 60, "Long Break")
      } else {
        pomodoroPhase = "short-break"
        startTimer(5 * 60, "Short Break")
      }
    } else {
      pomodoroPhase = "work"
      startTimer(25 * 60, "Pomodoro")
    }
  }

  function dismissActive() {
    if (stopwatchActive) resetStopwatch()
    else resetPomodoro()
  }

  function resetPomodoro() {
    if (isFocusd) {
      focusd.reset()
    }
    pomodoroPhase = "work"
    cancelTimer()
  }

  function addToTimer(seconds) {
    if (isFocusd) {
      focusd.addMinutes(Math.max(1, Math.round(seconds / 60)))
      return
    }
    if (!rawTimerActive) {
      startPomodoro()
      return
    }
    var ms = seconds * 1000
    if (rawTimerPaused) rawTimerLeftPaused += ms
    else rawTimerEnd += ms
    rawTimerTotal += ms
    save()
  }

  function cancelTimer() {
    if (isFocusd) {
      focusd.reset()
    }
    rawTimerEnd = 0
    rawTimerPaused = false
    rawTimerLeftPaused = 0
    rawTimerTotal = 0
    rawTimerLabel = ""
    save()
  }

  function timerFinished() {
    var label = rawTimerLabel || "Timer"
    if (isBreakLabel(label)) {
      pomodoroPhase = "work"
      cancelTimer()
      if (island) {
        island.toast({
          title: "Break over",
          body: "Focus · 25m",
          icon: "",
          color: "accent",
          duration: 12000
        })
      }
    } else if (isWorkLabel(label)) {
      pomodoroCompleted++
      var isLong = pomodoroCompleted % 4 === 0
      pomodoroPhase = isLong ? "long-break" : "short-break"
      cancelTimer()
      if (island) {
        island.toast({
          title: "Focus complete",
          body: isLong ? "Long break · 15m" : "Short break · 5m",
          icon: "",
          color: "green",
          duration: 12000
        })
      }
    } else {
      cancelTimer()
      if (island) {
        island.toast({
          title: label,
          body: "Done",
          icon: "󰀠",
          color: "accent",
          duration: 12000
        })
      }
    }

    if (island && island.setting("timerSound", true) !== false) {
      Quickshell.execDetached(["sh", "-c",
        "for i in 1 2 3; do pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null " +
        "|| paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; done"])
    }
  }

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

  // ---- persistence
  property bool restored: false

  function save() {
    if (!restored) return
    stateFile.setText(JSON.stringify({
      timerEnd: rawTimerEnd, timerLeftPaused: rawTimerLeftPaused, timerTotal: rawTimerTotal,
      timerPaused: rawTimerPaused, timerLabel: rawTimerLabel,
      pomodoroCompleted: pomodoroCompleted, pomodoroPhase: pomodoroPhase,
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
      clocks.rawTimerEnd = Number(s.timerEnd) || 0
      clocks.rawTimerLeftPaused = Number(s.timerLeftPaused) || 0
      clocks.rawTimerTotal = Number(s.timerTotal) || 0
      clocks.rawTimerPaused = s.timerPaused === true
      clocks.rawTimerLabel = String(s.timerLabel || "")
      clocks.pomodoroCompleted = Number(s.pomodoroCompleted) || 0
      clocks.pomodoroPhase = String(s.pomodoroPhase || "work")
      clocks.stopwatchStart = Number(s.stopwatchStart) || 0
      clocks.stopwatchBanked = Number(s.stopwatchBanked) || 0
      clocks.stopwatchRunning = s.stopwatchRunning === true
      if (clocks.rawTimerEnd > 0 && !clocks.rawTimerPaused && clocks.rawTimerEnd <= clocks.now) clocks.timerFinished()
    }
    onLoadFailed: clocks.restored = true
  }
}
