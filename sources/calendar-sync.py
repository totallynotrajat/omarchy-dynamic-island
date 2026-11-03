#!/usr/bin/env python3
import sys
import os
import json
import re
import urllib.request
import urllib.error
from datetime import datetime, date, time, timedelta, timezone
from zoneinfo import ZoneInfo

CONFIG_FILE = os.path.expanduser("~/.config/omarchy/google-calendar.json")
CACHE_DIR = os.path.expanduser("~/.cache/omarchy/calendar")
CACHE_FILE = os.path.join(CACHE_DIR, "events.json")
ICS_CACHE_FILE = os.path.join(CACHE_DIR, "calendar.ics")

def get_local_timezone():
    try:
        return datetime.now().astimezone().tzinfo
    except Exception:
        return timezone.utc

LOCAL_TZ = get_local_timezone()

def unfold_ics(text):
    """Unfold lines that are wrapped with space or tab."""
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    unfolded = []
    for line in lines:
        if line.startswith(" ") or line.startswith("\t"):
            if unfolded:
                unfolded[-1] += line[1:]
        else:
            unfolded.append(line)
    return unfolded

def parse_ics_datetime(val, params, default_tz):
    # Formats: 20261103T103000Z or 20261103T103000 or 20261103
    val = val.strip()
    is_date_only = False
    
    # Check parameters for TZID or VALUE=DATE
    tz = default_tz
    for p in params:
        p_upper = p.upper()
        if p_upper.startswith("TZID="):
            tz_name = p.split("=", 1)[1].strip('"\'')
            try:
                tz = ZoneInfo(tz_name)
            except Exception:
                tz = default_tz
        elif p_upper == "VALUE=DATE":
            is_date_only = True

    if len(val) == 8 and val.isdigit():
        is_date_only = True
        y, m, d = int(val[:4]), int(val[4:6]), int(val[6:8])
        dt = datetime(y, m, d, 0, 0, 0, tzinfo=LOCAL_TZ)
        return dt, True
    
    if "T" in val:
        date_part, time_part = val.split("T", 1)
        y, m, d = int(date_part[:4]), int(date_part[4:6]), int(date_part[6:8])
        if time_part.endswith("Z"):
            time_clean = time_part[:-1]
            hh = int(time_clean[:2]) if len(time_clean) >= 2 else 0
            mm = int(time_clean[2:4]) if len(time_clean) >= 4 else 0
            ss = int(time_clean[4:6]) if len(time_clean) >= 6 else 0
            dt = datetime(y, m, d, hh, mm, ss, tzinfo=timezone.utc).astimezone(LOCAL_TZ)
            return dt, False
        else:
            hh = int(time_part[:2]) if len(time_part) >= 2 else 0
            mm = int(time_part[2:4]) if len(time_part) >= 4 else 0
            ss = int(time_part[4:6]) if len(time_part) >= 6 else 0
            dt = datetime(y, m, d, hh, mm, ss, tzinfo=tz).astimezone(LOCAL_TZ)
            return dt, False

    # Fallback
    try:
        y, m, d = int(val[:4]), int(val[4:6]), int(val[6:8])
        return datetime(y, m, d, 0, 0, 0, tzinfo=LOCAL_TZ), True
    except Exception:
        return datetime.now(LOCAL_TZ), False

def unescape_ics_text(text):
    if not text:
        return ""
    return text.replace("\\n", "\n").replace("\\N", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")

def extract_meet_url(description, location):
    combined = f"{description or ''} {location or ''}"
    # Google Meet
    m = re.search(r'https?://meet\.google\.com/[a-z0-9\-]+', combined)
    if m:
        return m.group(0)
    # Zoom
    m = re.search(r'https?://[a-zA-Z0-9\.\-]*zoom\.us/[j|my]/[a-zA-Z0-9\?\=\_\-]+', combined)
    if m:
        return m.group(0)
    # Teams
    m = re.search(r'https?://teams\.microsoft\.com/l/meetup-join/[a-zA-Z0-9\%\-\_\.\?\=\&]+', combined)
    if m:
        return m.group(0)
    # General URL in location if it starts with http
    if location and location.strip().startswith("http"):
        return location.strip().split()[0]
    return ""

def parse_ics(ics_content):
    lines = unfold_ics(ics_content)
    events_raw = []
    current = None
    
    for line in lines:
        if line == "BEGIN:VEVENT":
            current = {}
        elif line == "END:VEVENT":
            if current:
                events_raw.append(current)
            current = None
        elif current is not None:
            if ":" in line:
                prop_part, val = line.split(":", 1)
                prop_parts = prop_part.split(";")
                prop_name = prop_parts[0].upper()
                params = prop_parts[1:]
                if prop_name not in current:
                    current[prop_name] = []
                current[prop_name].append((params, val))

    now = datetime.now(LOCAL_TZ)
    window_start = now - timedelta(days=14)
    window_end = now + timedelta(days=90)
    
    parsed_events = []
    
    for ev in events_raw:
        # Ignore cancelled events
        if "STATUS" in ev:
            if any("CANCELLED" in v.upper() for _, v in ev["STATUS"]):
                continue
                
        summary = ""
        if "SUMMARY" in ev:
            summary = unescape_ics_text(ev["SUMMARY"][0][1])
            
        description = ""
        if "DESCRIPTION" in ev:
            description = unescape_ics_text(ev["DESCRIPTION"][0][1])
            
        location = ""
        if "LOCATION" in ev:
            location = unescape_ics_text(ev["LOCATION"][0][1])
            
        uid = ""
        if "UID" in ev:
            uid = ev["UID"][0][1]

        meet_url = extract_meet_url(description, location)

        if "DTSTART" not in ev:
            continue
            
        params, val = ev["DTSTART"][0]
        dtstart, is_all_day = parse_ics_datetime(val, params, LOCAL_TZ)
        
        dtend = None
        if "DTEND" in ev:
            end_params, end_val = ev["DTEND"][0]
            dtend, _ = parse_ics_datetime(end_val, end_params, LOCAL_TZ)
        elif "DURATION" in ev:
            dur_str = ev["DURATION"][0][1]
            dur = timedelta(hours=1)
            m = re.search(r'P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?', dur_str)
            if m:
                w = int(m.group(1) or 0)
                d = int(m.group(2) or 0)
                h = int(m.group(3) or 0)
                mn = int(m.group(4) or 0)
                s = int(m.group(5) or 0)
                dur = timedelta(weeks=w, days=d, hours=h, minutes=mn, seconds=s)
            dtend = dtstart + dur
        else:
            dtend = dtstart + (timedelta(days=1) if is_all_day else timedelta(hours=1))

        duration = dtend - dtstart
        
        # Check for RRULE
        rrule_str = ""
        if "RRULE" in ev:
            rrule_str = ev["RRULE"][0][1]

        # EXDATE
        exdates = set()
        if "EXDATE" in ev:
            for ex_params, ex_val in ev["EXDATE"]:
                for single_ex in ex_val.split(","):
                    ex_dt, _ = parse_ics_datetime(single_ex.strip(), ex_params, LOCAL_TZ)
                    exdates.add(ex_dt.strftime("%Y-%m-%d"))

        # Generate occurrences
        occurrences = []
        if not rrule_str:
            if window_start <= dtstart <= window_end:
                occurrences.append((dtstart, dtend))
        else:
            # Parse RRULE
            r_parts = dict(part.split("=", 1) for part in rrule_str.split(";") if "=" in part)
            freq = r_parts.get("FREQ", "").upper()
            interval = int(r_parts.get("INTERVAL", 1))
            count = int(r_parts.get("COUNT", 9999))
            until_dt = None
            if "UNTIL" in r_parts:
                until_dt, _ = parse_ics_datetime(r_parts["UNTIL"], [], LOCAL_TZ)

            byday = r_parts.get("BYDAY", "")
            day_map = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}

            cur = dtstart
            generated = 0
            
            if freq == "DAILY":
                while cur <= window_end and generated < count:
                    if until_dt and cur > until_dt:
                        break
                    if cur >= window_start:
                        occurrences.append((cur, cur + duration))
                    cur += timedelta(days=interval)
                    generated += 1
            elif freq == "WEEKLY":
                target_days = [day_map[d[-2:]] for d in byday.split(",") if d[-2:] in day_map] if byday else [cur.weekday()]
                # Step day by day through the range
                week_start_cur = cur - timedelta(days=cur.weekday())
                while week_start_cur <= window_end and generated < count:
                    for d_idx in sorted(target_days):
                        occ_dt = week_start_cur + timedelta(days=d_idx, hours=dtstart.hour, minutes=dtstart.minute, seconds=dtstart.second)
                        if occ_dt < dtstart:
                            continue
                        if until_dt and occ_dt > until_dt:
                            break
                        if occ_dt > window_end or generated >= count:
                            break
                        if occ_dt >= window_start:
                            occurrences.append((occ_dt, occ_dt + duration))
                        generated += 1
                    week_start_cur += timedelta(weeks=interval)
            elif freq == "MONTHLY":
                while cur <= window_end and generated < count:
                    if until_dt and cur > until_dt:
                        break
                    if cur >= window_start:
                        occurrences.append((cur, cur + duration))
                    # Advance one month
                    m = cur.month + interval
                    y = cur.year + (m - 1) // 12
                    m = ((m - 1) % 12) + 1
                    try:
                        cur = cur.replace(year=y, month=m)
                    except ValueError:
                        # Day doesn't exist (e.g. 31st in Feb)
                        cur = cur.replace(year=y, month=m, day=28)
                    generated += 1
            else:
                if window_start <= dtstart <= window_end:
                    occurrences.append((dtstart, dtend))

        for occ_start, occ_end in occurrences:
            date_key = occ_start.strftime("%Y-%m-%d")
            if date_key in exdates:
                continue

            time_str = "All Day" if is_all_day else f"{occ_start.strftime('%-I:%M %p')} - {occ_end.strftime('%-I:%M %p')}"
            
            parsed_events.append({
                "id": f"{uid}_{date_key}",
                "summary": summary or "(No Title)",
                "description": description,
                "location": location,
                "meetUrl": meet_url,
                "isAllDay": is_all_day,
                "dateKey": date_key,
                "startIso": occ_start.isoformat(),
                "endIso": occ_end.isoformat(),
                "startTimestamp": int(occ_start.timestamp()),
                "endTimestamp": int(occ_end.timestamp()),
                "timeString": time_str
            })

    # Sort events by start timestamp
    parsed_events.sort(key=lambda x: (x["startTimestamp"], x["summary"]))
    
    # Calculate upcoming / ongoing
    now_ts = int(now.timestamp())
    upcoming = None
    
    # 1. Check for ongoing event
    for ev in parsed_events:
        if not ev["isAllDay"] and ev["startTimestamp"] <= now_ts < ev["endTimestamp"]:
            mins_left = max(1, int((ev["endTimestamp"] - now_ts) / 60))
            upcoming = {
                "status": "ongoing",
                "title": ev["summary"],
                "timeString": ev["timeString"],
                "startsInText": "Ongoing",
                "badgeText": f"Ends in {mins_left}m",
                "minutesUntil": 0,
                "meetUrl": ev["meetUrl"],
                "location": ev["location"],
                "dateKey": ev["dateKey"],
                "startIso": ev["startIso"]
            }
            break

    # 2. Next upcoming event
    if not upcoming:
        for ev in parsed_events:
            if ev["startTimestamp"] > now_ts:
                diff_sec = ev["startTimestamp"] - now_ts
                mins_until = int(diff_sec / 60)
                
                if mins_until < 60:
                    starts_in = f"in {mins_until}m"
                elif mins_until < 1440:
                    hrs = mins_until // 60
                    rem_mins = mins_until % 60
                    starts_in = f"in {hrs}h {rem_mins}m" if rem_mins > 0 else f"in {hrs}h"
                else:
                    days_away = mins_until // 1440
                    starts_in = f"in {days_away}d"

                ev_date = datetime.fromtimestamp(ev["startTimestamp"], LOCAL_TZ).date()
                today_date = now.date()
                if ev_date == today_date:
                    badge = f"Today · {starts_in}"
                elif ev_date == today_date + timedelta(days=1):
                    badge = f"Tomorrow · {starts_in}"
                else:
                    badge = starts_in

                upcoming = {
                    "status": "upcoming",
                    "title": ev["summary"],
                    "timeString": ev["timeString"],
                    "startsInText": starts_in,
                    "badgeText": badge,
                    "minutesUntil": mins_until,
                    "meetUrl": ev["meetUrl"],
                    "location": ev["location"],
                    "dateKey": ev["dateKey"],
                    "startIso": ev["startIso"]
                }
                break

    dates_with_events = sorted(list(set(ev["dateKey"] for ev in parsed_events)))

    return {
        "connected": True,
        "lastSync": now.isoformat(),
        "upcoming": upcoming,
        "events": parsed_events,
        "datesWithEvents": dates_with_events,
        "error": None
    }

def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {"calendarUrls": [], "refreshMinutes": 15}
    try:
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    except Exception as e:
        return {"calendarUrls": [], "refreshMinutes": 15, "error": str(e)}

def save_config(cfg):
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)

def fetch_feed(url):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) OmarchyCalendar/1.0"}
    )
    with urllib.request.urlopen(req, timeout=12) as response:
        return response.read().decode("utf-8", errors="replace")

def run_sync(force_fetch=False):
    os.makedirs(CACHE_DIR, exist_ok=True)
    cfg = load_config()
    urls = cfg.get("calendarUrls", [])

    # If cache exists and not forcing fetch, check age
    now_ts = datetime.now().timestamp()
    cache_exists = os.path.exists(CACHE_FILE)
    ics_exists = os.path.exists(ICS_CACHE_FILE)
    
    if not force_fetch and cache_exists:
        try:
            mtime = os.path.getmtime(CACHE_FILE)
            refresh_sec = cfg.get("refreshMinutes", 15) * 60
            if (now_ts - mtime) < refresh_sec:
                with open(CACHE_FILE, "r") as f:
                    data = json.load(f)
                    # Recalculate upcoming relative to current instant
                    if data.get("events"):
                        raw_data = parse_ics_cached_events(data["events"])
                        data["upcoming"] = raw_data["upcoming"]
                    return data
        except Exception:
            pass

    if not urls:
        # Check if local ICS exists
        if ics_exists:
            with open(ICS_CACHE_FILE, "r") as f:
                content = f.read()
            res = parse_ics(content)
            with open(CACHE_FILE, "w") as f:
                json.dump(res, f, indent=2)
            return res

        res = {
            "connected": False,
            "lastSync": None,
            "upcoming": None,
            "events": [],
            "datesWithEvents": [],
            "error": "No Google Calendar URL configured"
        }
        with open(CACHE_FILE, "w") as f:
            json.dump(res, f, indent=2)
        return res

    combined_ics = ""
    fetch_error = None
    
    for url in urls:
        if not url.strip():
            continue
        try:
            if url.startswith("http://") or url.startswith("https://"):
                data = fetch_feed(url.strip())
            elif os.path.exists(url.strip()):
                with open(url.strip(), "r") as f:
                    data = f.read()
            else:
                continue
            combined_ics += "\n" + data
        except Exception as e:
            fetch_error = str(e)

    if not combined_ics.strip():
        if ics_exists:
            with open(ICS_CACHE_FILE, "r") as f:
                combined_ics = f.read()
        else:
            res = {
                "connected": True,
                "lastSync": None,
                "upcoming": None,
                "events": [],
                "datesWithEvents": [],
                "error": f"Failed to fetch calendar: {fetch_error}" if fetch_error else "Empty calendar data"
            }
            with open(CACHE_FILE, "w") as f:
                json.dump(res, f, indent=2)
            return res

    # Save to ICS cache
    try:
        with open(ICS_CACHE_FILE, "w") as f:
            f.write(combined_ics)
    except Exception:
        pass

    parsed = parse_ics(combined_ics)
    if fetch_error:
        parsed["error"] = f"Warning: {fetch_error} (used cache)"
    
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(parsed, f, indent=2)
    except Exception:
        pass

    return parsed

def parse_ics_cached_events(events):
    now = datetime.now(LOCAL_TZ)
    now_ts = int(now.timestamp())
    upcoming = None
    
    for ev in events:
        if not ev.get("isAllDay") and ev["startTimestamp"] <= now_ts < ev["endTimestamp"]:
            mins_left = max(1, int((ev["endTimestamp"] - now_ts) / 60))
            upcoming = {
                "status": "ongoing",
                "title": ev["summary"],
                "timeString": ev["timeString"],
                "startsInText": "Ongoing",
                "badgeText": f"Ends in {mins_left}m",
                "minutesUntil": 0,
                "meetUrl": ev.get("meetUrl", ""),
                "location": ev.get("location", ""),
                "dateKey": ev["dateKey"],
                "startIso": ev["startIso"]
            }
            break

    if not upcoming:
        for ev in events:
            if ev["startTimestamp"] > now_ts:
                diff_sec = ev["startTimestamp"] - now_ts
                mins_until = int(diff_sec / 60)
                if mins_until < 60:
                    starts_in = f"in {mins_until}m"
                elif mins_until < 1440:
                    hrs = mins_until // 60
                    rem_mins = mins_until % 60
                    starts_in = f"in {hrs}h {rem_mins}m" if rem_mins > 0 else f"in {hrs}h"
                else:
                    days_away = mins_until // 1440
                    starts_in = f"in {days_away}d"

                ev_date = datetime.fromtimestamp(ev["startTimestamp"], LOCAL_TZ).date()
                today_date = now.date()
                if ev_date == today_date:
                    badge = f"Today · {starts_in}"
                elif ev_date == today_date + timedelta(days=1):
                    badge = f"Tomorrow · {starts_in}"
                else:
                    badge = starts_in

                upcoming = {
                    "status": "upcoming",
                    "title": ev["summary"],
                    "timeString": ev["timeString"],
                    "startsInText": starts_in,
                    "badgeText": badge,
                    "minutesUntil": mins_until,
                    "meetUrl": ev.get("meetUrl", ""),
                    "location": ev.get("location", ""),
                    "dateKey": ev["dateKey"],
                    "startIso": ev["startIso"]
                }
                break

    return {"upcoming": upcoming}

if __name__ == "__main__":
    force = "--fetch" in sys.argv or "--force" in sys.argv
    if "--add-url" in sys.argv:
        idx = sys.argv.index("--add-url")
        if idx + 1 < len(sys.argv):
            new_url = sys.argv[idx + 1]
            cfg = load_config()
            urls = cfg.get("calendarUrls", [])
            if new_url not in urls:
                urls.append(new_url)
                cfg["calendarUrls"] = urls
                save_config(cfg)
            force = True

    result = run_sync(force_fetch=force)
    print(json.dumps(result))
