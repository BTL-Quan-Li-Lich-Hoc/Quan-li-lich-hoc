# Experimental integrated branch — 2026-10-31

This test branch is based on main and does not modify main, develop, or contributor branches.

Included:
- Khánh: raw QLĐT document validation, WebView (browser login only)
- Huy: JSON parser, timetable queries
- Dương/main: SharedPreferences local cache and repository
- Đạo: timetable/exam screens, schedule coordinator, widget service/bridge and Android widget reference files

Integration changes:
- Replace placeholder timetable/exam screens with real screens wired to LocalScheduleStore.
- Open QLĐT login WebView from the existing login route.
- Add parser -> offline cache -> coordinator integration test.
- Run branch-specific GitHub Actions validation.

Not implemented and NOT claimed:
- QLĐT authenticated API import, session-to-parser wiring
- Android widget visibility/function on physical Android phone (native receivers now registered in bootstrap; device verification pending)
- Drift/SQLite implementation; current working cache uses SharedPreferences
- Automated refresh from QLĐT

CI workflow is an assessment aid; consult each step's actual conclusion.

Follow-up: bootstrap now copies native widget sources/XML and registers Android receivers; the app publishes the offline-cache timeline to the widget bridge on startup. APK build is the minimum validation, not proof of device widget behavior.
