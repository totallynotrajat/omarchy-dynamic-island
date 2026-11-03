import QtQuick
import Quickshell
import Quickshell.Io

// Deep Module Adapter for the focusd Pomodoro daemon (bibek.focusd).
// Communicates with the focusd binary via CLI/IPC to track sessions,
// streaks, goals, progress, and cycle history.
Item {
  id: root

  property string status: "stopped" // "running", "paused", "stopped"
  property string session: "work"   // "work", "short-break", "long-break"
  property string sessionLabel: "Work"
  property string nextSessionLabel: "Short Break"
  property string remainingText: "25:00"
  property int remainingSeconds: 1500
  property real progress: 0.0

  property int sessionsToday: 0
  property string focusedToday: "0s"
  property string dailyGoal: "0s"
  property int currentStreak: 0
  property int workSessionsBeforeLongBreak: 4
  property int completedSessions: 0
  property bool hasSessionData: false

  readonly property bool running: status === "running"
  readonly property bool paused: status === "paused"
  readonly property bool stopped: status === "stopped"
  readonly property bool active: !stopped && (running || paused)

  function start() {
    Quickshell.execDetached(["focusd", "start"])
    pollTimer.restart()
  }

  function toggle() {
    if (stopped) {
      start()
    } else {
      Quickshell.execDetached(["focusd", "toggle"])
      pollTimer.restart()
    }
  }

  function skip() {
    if (!stopped) {
      Quickshell.execDetached(["focusd", "next"])
      pollTimer.restart()
    }
  }

  function reset() {
    if (!stopped) {
      Quickshell.execDetached(["focusd", "reset"])
      pollTimer.restart()
    }
  }

  function addMinutes(mins) {
    if (!stopped) {
      Quickshell.execDetached(["focusd", "--add-minutes", String(mins)])
      pollTimer.restart()
    }
  }

  function poll() {
    if (statusProc.running) return
    statusProc.collected = ""
    statusProc.running = true
  }

  Timer {
    id: pollTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.poll()
  }

  Process {
    id: statusProc
    property string collected: ""
    command: ["focusd", "status"]
    stdout: SplitParser {
      onRead: function(data) {
        statusProc.collected += data + "\n"
      }
    }
    onExited: function(code) {
      if (code === 0 && statusProc.collected.trim() !== "") {
        try {
          var state = JSON.parse(statusProc.collected.trim())
          var classes = state.class || []
          var alt = String(state.alt || "work")
          root.status = classes.indexOf("paused") !== -1 ? "paused" : "running"
          var sKey = alt.replace(/-paused$/, "")
          root.session = sKey
          root.sessionLabel = sKey === "short-break" ? "Short Break" : (sKey === "long-break" ? "Long Break" : "Work")
          root.nextSessionLabel = String(state.next_session || (sKey === "work" ? "Short Break" : "Work"))
          root.remainingText = String(state.text || "25:00")
          root.progress = Math.max(0, Math.min(1, (Number(state.percentage) || 0) / 100))
          root.sessionsToday = Number(state.sessions_today) || 0
          root.focusedToday = String(state.focused_today || "")
          root.dailyGoal = String(state.daily_goal || "")
          root.currentStreak = Number(state.current_streak) || 0
          root.workSessionsBeforeLongBreak = Math.max(1, Number(state.work_sessions_before_long_break) || 4)
          root.completedSessions = Number(state.completed_sessions) || 0
          root.hasSessionData = true

          var parts = root.remainingText.split(":")
          if (parts.length === 2) {
            root.remainingSeconds = (Number(parts[0]) || 0) * 60 + (Number(parts[1]) || 0)
          }
        } catch (e) {
          // ignore malformed state
        }
      } else {
        root.status = "stopped"
      }
    }
  }

  Component.onCompleted: poll()
}
