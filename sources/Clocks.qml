import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Timer and stopwatch live activities.
// Integrated with Focusd (bibek.focusd) as a first-class Pomodoro engine
// while maintaining fallback wall-clock timers and stopwatch.
Item {
  id: clocks

  property var island: null
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/clocks.json"

  property double now: Date.now()

  // ---- Focusd Pomodoro Integration
  FocusdSource {
    id: focusd
  }

  readonly property var focusdSource: focusd
  readonly property bool isFocusd: focusd.active
  readonly property string focusSession: focusd.session
  readonly property string focusSessionLabel: focusd.sessionLabel
  readonly property string focusNextSessionLabel: focusd.nextSessionLabel
  readonly property string focusRemainingText: focusd.remainingText
  readonly property int currentStreak: focusd.currentStreak
  readonly property string dailyGoal: focusd.dailyGoal
  readonly property int sessionsToday: focusd.sessionsToday
  readonly property string focusedToday: focusd.focusedToday
  readonly property int completedSessions: focusd.completedSessions
  readonly property int workSessionsBeforeLongBreak: focusd.workSessionsBeforeLongBreak
  readonly property bool hasSessionData: focusd.hasSessionData

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
  readonly property bool timerActive: focusd.active || rawTimerActive
  readonly property bool timerPaused: focusd.active ? focusd.paused : rawTimerPaused
  readonly property real timerProgress: focusd.active ? focusd.progress : rawTimerProgress
  readonly property double timerLeft: focusd.active ? (focusd.remainingSeconds * 1000) : rawTimerLeft
  readonly property string timerLabel: focusd.active ? focusd.sessionLabel : (rawTimerLabel || "Timer")

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
    // If standard pomodoro interval (25m) or requested label is Pomodoro, route to focusd
    if (sec === 1500 || String(label || "").toLowerCase().indexOf("pomo") !== -1 || String(label || "").toLowerCase().indexOf("focus") !== -1) {
      focusd.start()
      return
    }

    var ms = Math.max(1, sec) * 1000
    now = Date.now()
    rawTimerTotal = ms
    rawTimerEnd = now + ms
    rawTimerPaused = false
    rawTimerLeftPaused = 0
    rawTimerLabel = String(label || "")
    save()
  }

  function toggleTimer() {
    if (focusd.active) {
      focusd.toggle()
      return
    }
    if (!rawTimerActive) return
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

  function addToTimer(seconds) {
    if (focusd.active) {
      focusd.addMinutes(Math.max(1, Math.round(seconds / 60)))
      return
    }
    if (!rawTimerActive) return
    var ms = seconds * 1000
    if (rawTimerPaused) rawTimerLeftPaused += ms
    else rawTimerEnd += ms
    rawTimerTotal += ms
    save()
  }

  function cancelTimer() {
    if (focusd.active) {
      focusd.reset()
    }
    rawTimerEnd = 0
    rawTimerPaused = false
    rawTimerLeftPaused = 0
    rawTimerTotal = 0
    rawTimerLabel = ""
    save()
  }

  function skipFocusd() {
    focusd.skip()
  }

  function startFocusd() {
    focusd.start()
  }

  function resetFocusd() {
    focusd.reset()
  }

  function addMinutesFocusd(mins) {
    focusd.addMinutes(mins)
  }

  function timerFinished() {
    var label = rawTimerLabel
    cancelTimer()
    if (!island) return
    island.toast({
      title: label || "Timer",
      body: "Time's up",
      icon: "󰀠",
      color: "accent",
      duration: 12000
    })
    if (island.setting("timerSound", true) !== false)
      Quickshell.execDetached(["sh", "-c",
        "for i in 1 2 3; do pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null " +
        "|| paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; done"])
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
      clocks.stopwatchStart = Number(s.stopwatchStart) || 0
      clocks.stopwatchBanked = Number(s.stopwatchBanked) || 0
      clocks.stopwatchRunning = s.stopwatchRunning === true
      if (clocks.rawTimerEnd > 0 && !clocks.rawTimerPaused && clocks.rawTimerEnd <= clocks.now) clocks.timerFinished()
    }
    onLoadFailed: clocks.restored = true
  }
}
