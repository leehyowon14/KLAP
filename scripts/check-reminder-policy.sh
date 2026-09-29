#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
python3 - "$scratch/main.swift" <<'PY'
from pathlib import Path
import sys
source=(Path('.build')/('cli-'+Path('Bridge/core-ref').read_text().strip())/'bridges/macos/Sources/ReminderBridge/main.swift').read_text()
functions=source[source.index('func applyDueDate('):source.index('let listName = request')]
Path(sys.argv[1]).write_text('import EventKit\n'+functions+'''
let reminder = EKReminder(eventStore: EKEventStore())
let due = Date().addingTimeInterval(3 * 86400)
reminder.startDateComponents = Calendar.current.dateComponents([.year,.month,.day],from:Date())
applyDueDate(due,to:reminder)
precondition(reminder.startDateComponents == nil)
precondition(reminder.dueDateComponents?.day == Calendar.current.component(.day,from:due))
applyAlarm(due,beforeMinutes:5,to:reminder)
precondition(abs(reminder.alarms![0].absoluteDate!.timeIntervalSince(due) + 86400) < 1)
applyAlarm(Date().addingTimeInterval(3600),beforeMinutes:1440,to:reminder)
precondition(reminder.alarms?.isEmpty != false)
applyAlarm(Date().addingTimeInterval(-3600),beforeMinutes:1440,to:reminder)
precondition(reminder.alarms?.isEmpty != false)
print("Reminder policy: 5 checks passed (no store writes)")
''')
PY
swift "$scratch/main.swift"
