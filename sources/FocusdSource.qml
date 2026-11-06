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

  readonly property bool stopped: status === "stopped"
  readonly property bool running: status === "running"
  readonly property bool paused: status === "paused"
  // The daemon answered `focusd status`, so it is the Pomodoro engine.
  readonly property bool available: hasSessionData && !stopped
  // A session counts as live only once it has started: running, or paused
  // part way through. A fresh, untouched 25:00 is not an activity.
  // focusd's percentage is a whole number, so a session paused in its first
  // 1% still reads 0; one paused part way through a minute has started too.
  readonly property bool started: running || progress > 0 || (paused && remainingSeconds % 60 !== 0)
  readonly property bool active: available && started

  // A session ran out on its own (seen with only a moment left, then the
  // next one): `finished` and `next` are session keys.
  signal sessionFinished(string finished, string next)
  property string lastSession: ""
  property int lastRemaining: -1
  property bool lastRunning: false
  // Failed status calls in a row; one hiccup is not "the daemon is gone".
  property int failures: 0

  // focusd has no `start` subcommand: `--start [session]` starts one
  // (the current session when none is named), `resume` continues a pause.
  function start(session) {
    var s = String(session || "")
    Quickshell.execDetached(s ? ["focusd", "--start", s] : ["focusd", "--start"])
    pollSoon()
  }

  function toggle() {
    if (!available) return
    if (running) Quickshell.execDetached(["focusd", "pause"])
    else if (started) Quickshell.execDetached(["focusd", "resume"])
    else Quickshell.execDetached(["focusd", "--start"])
    pollSoon()
  }

  // Re-read the state right after a command instead of waiting a second.
  function pollSoon() { soonTimer.restart() }

  Timer { id: soonTimer; interval: 250; onTriggered: root.poll() }

  function skip() {
    if (!available) return
    Quickshell.execDetached(["focusd", "next"])
    pollSoon()
  }

  function reset() {
    if (!available) return
    Quickshell.execDetached(["focusd", "reset"])
    pollSoon()
  }

  function addMinutes(mins) {
    if (!available) return
    Quickshell.execDetached(["focusd", "--add-minutes", String(mins)])
    pollSoon()
  }

  function poll() {
    if (statusProc.running) return
    statusProc.collected = ""
    statusProc.running = true
  }

  Timer {
    id: pollTimer
    interval: root.running ? 1000 : 4000
    repeat: true
    running: true
    onTriggered: root.poll()
  }

  Process {
    id: statusProc
    property string collected: ""
    // Every focusd command, `status` too, starts the daemon if it is not
    // running; asking only while it runs keeps the island from starting it
    // (and from undoing a `focusd --stop-daemon`).
    command: ["sh", "-c", "pgrep -x focusd >/dev/null 2>&1 || exit 3; exec focusd status"]
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
          root.failures = 0
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

          if (root.lastSession !== "" && sKey !== root.lastSession && root.lastRunning
              && root.lastRemaining >= 0 && root.lastRemaining <= 3)
            root.sessionFinished(root.lastSession, sKey)
          root.lastSession = sKey
          root.lastRemaining = root.remainingSeconds
          root.lastRunning = root.running
        } catch (e) {
          // ignore malformed state
        }
      } else if (code === 3 || ++root.failures >= 3) {
        root.status = "stopped"
        root.lastSession = ""
      }
    }
  }

  Component.onCompleted: poll()
}
