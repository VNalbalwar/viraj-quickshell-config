#!/usr/bin/env python3
"""Upcoming events from an iCal feed, as JSON, for the control center's Calendar page.
The feed address (e.g. Google Calendar -> Settings -> "Secret address in iCal format", or a local .ics path)
goes in ~/.config/qs-calendar.url. Handles all-day events and simple DAILY/WEEKLY/MONTHLY/YEARLY repeats."""
import datetime as dt
import json
import os
import re
import sys
import urllib.request

CFG = os.path.expanduser("~/.config/qs-calendar.url")
DAYS = 45


def read():
    try:
        src = open(CFG).read().strip()
    except OSError:
        print(json.dumps({"configured": False, "events": []}))
        sys.exit(0)
    if src.startswith(("http://", "https://", "file://")):
        text = urllib.request.urlopen(src, timeout=10).read().decode("utf-8", "replace")
    else:
        text = open(os.path.expanduser(src), encoding="utf-8", errors="replace").read()
    return re.sub(r"\r?\n[ \t]", "", text)                  # unfold long lines


def parse_dt(value, params):
    v = value.strip()
    if "VALUE=DATE" in params or len(v) == 8:
        return dt.datetime.strptime(v[:8], "%Y%m%d"), True
    d = dt.datetime.strptime(v.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
    if v.endswith("Z"):                                    # UTC -> local time
        d = d.replace(tzinfo=dt.timezone.utc).astimezone().replace(tzinfo=None)
    return d, False


def main():
    text = read()
    now = dt.datetime.now()
    horizon = now + dt.timedelta(days=DAYS)
    out = []
    for block in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", text, re.S):
        props = {}
        for line in block.strip().splitlines():
            if ":" not in line:
                continue
            key, _, val = line.partition(":")
            name, _, params = key.partition(";")
            props.setdefault(name.upper(), (val, params))
        if "DTSTART" not in props:
            continue
        try:
            start, allday = parse_dt(*props["DTSTART"])
        except ValueError:
            continue
        title = props.get("SUMMARY", ("(no title)", ""))[0].replace("\\,", ",").replace("\\n", " ")
        starts = [start]
        rr = props.get("RRULE", ("", ""))[0]
        if rr:
            r = dict(p.split("=", 1) for p in rr.split(";") if "=" in p)
            step = {"DAILY": dt.timedelta(days=1), "WEEKLY": dt.timedelta(weeks=1)}.get(r.get("FREQ"))
            interval = int(r.get("INTERVAL", 1))
            until = None
            if "UNTIL" in r:
                try:
                    until = parse_dt(r["UNTIL"], "")[0]
                except ValueError:
                    pass
            cur, n = start, 0
            while cur < horizon and n < 400:
                if r.get("FREQ") in ("DAILY", "WEEKLY"):
                    cur = cur + step * interval
                elif r.get("FREQ") == "MONTHLY":
                    m = cur.month - 1 + interval
                    try:
                        cur = cur.replace(year=cur.year + m // 12, month=m % 12 + 1)
                    except ValueError:
                        break
                elif r.get("FREQ") == "YEARLY":
                    try:
                        cur = cur.replace(year=cur.year + interval)
                    except ValueError:
                        break
                else:
                    break
                n += 1
                if until and cur > until:
                    break
                if "COUNT" in r and n >= int(r["COUNT"]) - 1:
                    starts.append(cur)
                    break
                starts.append(cur)
        for s in starts:
            end_of_day = s + dt.timedelta(days=1) if allday else s
            if now - dt.timedelta(hours=1) <= end_of_day and s <= horizon:
                out.append({"title": title, "start": s.isoformat(), "allDay": allday})
    out.sort(key=lambda e: e["start"])
    print(json.dumps({"configured": True, "events": out[:30]}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:                                  # a bad feed must never break the page
        print(json.dumps({"configured": True, "events": [], "error": str(e)}))
