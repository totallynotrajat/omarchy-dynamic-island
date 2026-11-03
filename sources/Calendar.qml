import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Next meeting from iCalendar feeds and Google Calendar sync (tnr.clock adapter).
// Integrates local Google Calendar cache (~/.cache/omarchy/calendar/events.json)
// with upstream .ics link parser.
Item {
  id: calendar

  property var island: null
  // Links written by hand into shell.json's "calendars" setting...
  readonly property var configured: {
    var v = island ? island.setting("calendars", []) : []
    return Array.isArray(v) ? v.map(function(x) { return String(x) }) : (v ? [String(v)] : [])
  }
  // ...plus links added from the calendar view, which live in the island's own file.
  property var added: []

  // ---- holidays: the country's public holiday calendar, on by default.
  property string detectedCountry: ""
  property string holidayChoice: "auto"
  readonly property string holidayCountry: {
    var c = holidayChoice === "auto" ? String(island ? island.setting("holidays", "auto") : "auto") : holidayChoice
    if (c === "auto") c = detectedCountry
    return c === "off" ? "" : String(c || "").toUpperCase()
  }
  readonly property string holidayLink: Model.holidayUrl(holidayCountry)
  readonly property string holidayName: { var h = Model.holidayCalendar(holidayCountry); return h ? h.name : "" }

  function setHolidays(code) {
    holidayChoice = String(code || "auto")
    prefsFile.setText(JSON.stringify({ holidays: holidayChoice }, null, 2) + "\n")
  }

  // Timezone -> ISO country (Asia/Kolkata -> IN) via tzdata's zone.tab.
  Process {
    running: true
    command: ["sh", "-c", "tz=$(timedatectl show -p Timezone --value 2>/dev/null || readlink /etc/localtime | sed 's#.*zoneinfo/##'); " +
                          "awk -v tz=\"$tz\" '$3==tz{print $1; exit}' /usr/share/zoneinfo/zone.tab 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: calendar.detectedCountry = String(text || "").trim() }
  }

  FileView {
    id: prefsFile
    path: calendar.addedDir + "/prefs.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try { var p = JSON.parse(text() || "{}"); if (p.holidays) calendar.holidayChoice = String(p.holidays) } catch (e) {}
    }
  }

  readonly property var sources: {
    var out = []
    function add(l) {
      var s = String(l || "").trim()
      if (s && out.indexOf(s) === -1) out.push(s)
    }
    if (holidayLink) add(holidayLink)
    for (var i = 0; i < configured.length; i++) add(configured[i])
    for (var j = 0; j < added.length; j++) add(added[j])
    return out
  }

  readonly property string addedDir: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island"
  readonly property string addedPath: addedDir + "/calendars.json"

  function add(link) {
    var l = String(link || "").trim()
    if (!l) return
    var next = added.slice()
    if (next.indexOf(l) === -1) next.push(l)
    added = next
    justAdded = l
    addedFile.setText(JSON.stringify(added, null, 2) + "\n")
  }

  function remove(link) {
    var l = String(link || "").trim()
    added = added.filter(function(x) { return x !== l })
    addedFile.setText(JSON.stringify(added, null, 2) + "\n")
    if (status[l]) {
      var s = Object.assign({}, status)
      delete s[l]
      status = s
    }
  }

  FileView {
    id: addedFile
    path: calendar.addedPath
    printErrors: false
    atomicWrites: true
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text() || "[]")
        if (Array.isArray(list)) calendar.added = list.map(function(x) { return String(x) })
      } catch (e) {}
    }
  }
  readonly property int leadMinutes: island ? Math.max(1, Number(island.setting("calendarLeadMinutes", 15)) || 15) : 15

  property var events: []
  property double now: Date.now()
  property string raw: ""
  property int version: 0

  // ---- Google Calendar Sync Adapter (tnr.clock) ----
  property var googleCalendarData: ({ connected: false, events: [], datesWithEvents: [], upcoming: null, error: null })
  property var googleEvents: []
  readonly property var datesWithEvents: (googleCalendarData && googleCalendarData.datesWithEvents) ? googleCalendarData.datesWithEvents : []
  readonly property bool googleConnected: !!(googleCalendarData && googleCalendarData.connected)
  readonly property bool googleSyncing: syncProc.running

  function parseGoogleCalendar(jsonText) {
    if (!jsonText || String(jsonText).trim() === "") return
    try {
      var data = JSON.parse(String(jsonText).trim())
      googleCalendarData = data
      var list = []
      var rawList = data.events || []
      for (var i = 0; i < rawList.length; i++) {
        var ev = rawList[i]
        list.push({
          title: ev.summary || "Event",
          start: ev.startTimestamp ? ev.startTimestamp * 1000 : new Date(ev.startIso).getTime(),
          end: ev.endTimestamp ? ev.endTimestamp * 1000 : new Date(ev.endIso).getTime(),
          allDay: ev.isAllDay === true,
          url: ev.meetUrl || "",
          location: ev.location || "",
          description: ev.description || "",
          timeString: ev.timeString || "",
          status: ev.status || "confirmed"
        })
      }
      googleEvents = list
      version++
    } catch (e) {
      // ignore parse errors
    }
  }

  function resyncGoogle() {
    if (syncProc.running) return
    syncProc.running = true
  }

  Process {
    id: syncProc
    command: ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/omarchy-dynamic-island/sources/calendar-sync.py"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          calendar.parseGoogleCalendar(text)
        }
      }
    }
  }

  FileView {
    id: googleCacheFile
    path: Quickshell.env("HOME") + "/.cache/omarchy/calendar/events.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: calendar.parseGoogleCalendar(text())
  }

  Timer {
    interval: 5 * 60000
    repeat: true
    running: true
    onTriggered: calendar.resyncGoogle()
  }

  // Combined month events: ICS feeds + Google Calendar
  function month(year, monthIndex) {
    version
    var from = new Date(year, monthIndex, 1).getTime() - 7 * 86400000
    var to = new Date(year, monthIndex + 1, 1).getTime() + 14 * 86400000
    var baseMap = raw ? Model.eventsByDay(Model.parseIcs(raw, from, to, true)) : {}
    for (var i = 0; i < googleEvents.length; i++) {
      var ge = googleEvents[i]
      if (ge.start >= from && ge.start <= to) {
        var k = Model.dayKey(ge.start)
        if (!baseMap[k]) baseMap[k] = []
        baseMap[k].push(ge)
      }
    }
    return baseMap
  }

  // Next upcoming event across all calendars
  readonly property var next: {
    version
    now
    var combined = (events || []).concat(googleEvents || [])
    combined.sort(function(a, b) { return a.start - b.start })
    for (var i = 0; i < combined.length; i++) {
      var e = combined[i]
      if (e.end > now) return e
    }
    return null
  }

  // Today's all-day events
  readonly property var todayAllDay: {
    version
    var d = new Date(now)
    var from = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    var list = raw ? Model.parseIcs(raw, from, from + 86400000 - 1, true) : []
    var all = list.filter(function(e) { return e.allDay }).map(function(e) { return e.title })
    for (var i = 0; i < googleEvents.length; i++) {
      var ge = googleEvents[i]
      if (ge.allDay && ge.start >= from && ge.start < from + 86400000) all.push(ge.title)
    }
    return all
  }

  readonly property bool soon: next !== null && next.start - now <= leadMinutes * 60000
    && now - next.start < 5 * 60000
  readonly property string countdown: next ? Model.untilText(next.start, now) : ""

  property string announced: ""

  Timer {
    interval: 20000
    repeat: true
    running: calendar.events.length > 0 || calendar.googleEvents.length > 0
    triggeredOnStart: true
    onTriggered: {
      calendar.now = Date.now()
      var ev = calendar.next
      if (ev && ev.start <= calendar.now && calendar.now - ev.start < 60000) {
        var key = ev.title + "@" + ev.start
        if (calendar.announced !== key && calendar.island) {
          calendar.announced = key
          calendar.island.toast({ title: ev.title || "Event", body: "Starting now", icon: "󰃭", color: "accent", duration: 8000 })
        }
      }
    }
  }

  // Fetch ICS sources
  readonly property string fetchScript:
    'max=4194304; { i=0; for u in "$@"; do s="${u/#\\~/$HOME}"; t=$(mktemp); h=$(mktemp); st=ok; ' +
    'case "$s" in webcal://*) s="https://${s#webcal://}" ;; esac; ' +
    'case "$s" in ' +
    'http://*|https://*) curl -sL --max-time 20 --max-filesize "$max" -D "$h" -o - "$s" 2>/dev/null ' +
    '    | head -c $((max + 1)) > "$t"; rc=${PIPESTATUS[0]}; ' +
    '  code=$(awk \'/^HTTP\\//{c=$2} END{print c+0}\' "$h"); ' +
    '  if [ "$rc" = 63 ] || [ "$(wc -c < "$t")" -gt "$max" ]; then st="too large"; ' +
    '  elif [ "$code" = 0 ]; then st=unreachable; elif [ "$code" != 200 ]; then st="HTTP $code"; fi ;; ' +
    '*) if [ ! -f "$s" ]; then st="file not found"; ' +
    '  elif [ "$(wc -c < "$s")" -gt "$max" ]; then st="too large"; ' +
    '  else head -c "$max" "$s" > "$t"; fi ;; ' +
    'esac; ' +
    '[ "$st" = ok ] && ! grep -q "BEGIN:VCALENDAR" "$t" && st="not a calendar"; ' +
    'echo "@@ISLAND-SOURCE $i $st"; [ "$st" = ok ] && cat "$t"; echo; rm -f "$t" "$h"; i=$((i+1)); done; } ' +
    '| head -c 16777216'

  property var status: ({})
  property string justAdded: ""
  property var lastResult: null
  Timer { id: resultTimer; interval: 7000; onTriggered: calendar.lastResult = null }

  function statusOf(link) { return status[String(link)] || "" }

  Process {
    id: fetch
    stdout: StdioCollector {
      onStreamFinished: {
        var from = Date.now() - 3600000
        var map = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = /^@@ISLAND-SOURCE (\d+) (.*)$/.exec(lines[i].replace(/\r$/, ""))
          if (m && calendar.fetchedSources[+m[1]] !== undefined) map[calendar.fetchedSources[+m[1]]] = m[2]
        }
        calendar.status = map
        calendar.raw = text
        calendar.events = Model.parseIcs(text, from, from + 8 * 86400000)
        calendar.now = Date.now()
        calendar.version++
        calendar.reportAdded()
        if (calendar.refetch) {
          calendar.refetch = false
          Qt.callLater(calendar.refresh)
        }
      }
    }
  }

  function refresh() {
    resyncGoogle()
    if (sources.length === 0) { events = []; raw = ""; version++; return }
    if (fetch.running) { refetch = true; return }
    fetchedSources = sources.slice()
    fetch.command = ["bash", "-c", fetchScript, "bash"].concat(fetchedSources)
    fetch.running = true
  }

  property var fetchedSources: []
  property bool refetch: false

  function reportAdded() {
    var link = justAdded
    if (!link || !island) return
    var st = statusOf(link)
    if (!st) return
    justAdded = ""
    if (st === "ok") {
      var count = Model.parseIcs(raw, Date.now() - 30 * 86400000, Date.now() + 60 * 86400000, true).length
      lastResult = { ok: true, text: "󰄬  Calendar added · " + count + (count === 1 ? " event" : " events") + " around now" }
      resultTimer.restart()
      island.showHud({ key: "calendar", layout: "label", label: "Calendar added", icon: "󰃭",
                       valueText: count + (count === 1 ? " event" : " events"), color: island.greenColor, duration: 2600 })
    } else {
      var google = link.indexOf("calendar.google.com") !== -1 && link.indexOf("/public/") !== -1 && st === "HTTP 404"
      lastResult = { ok: false, text: google
        ? "󰀦  Google refused the public address (404). Use \"Secret address in iCal format\"."
        : "󰀦  That link didn't work: " + st }
      resultTimer.restart()
      island.showHud({ key: "calendar", layout: "label",
                       label: google ? "Use Google's secret iCal address" : "Calendar link didn't work",
                       icon: "󰃮", valueText: google ? "404" : st, color: island.urgentColor, duration: 5000 })
    }
  }

  onSourcesChanged: refresh()

  Timer {
    interval: 15 * 60000
    repeat: true
    running: calendar.sources.length > 0
    onTriggered: calendar.refresh()
  }

  Component.onCompleted: {
    resyncGoogle()
  }
}
