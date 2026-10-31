# QLĐT diagnostics (opt in)

> Đo cho ra lỗi thì đo. Đo cho vui rồi bê dữ liệu thật lên Git thì thôi.

The normal app and release APK build with `QLDT_DIAGNOSTICS=false`. In that
mode, the timing recorder is not created, no timing data is persisted, and the
copy-diagnostics action is hidden. The login, retry, timeout, verification and
schedule-saving paths remain available.

For a temporary diagnostic build, pass
`--dart-define=QLDT_DIAGNOSTICS=true` to `flutter run` or
`flutter build apk --release`. The timing and redacted failure readers live
in this directory; keep diagnostic builds separate from public APKs.

The request callback timing hooks in `tracuu_api.dart` were removed from the
normal build. Reapply the timing-only patch from commit `215895c` when a
per-request breakdown is needed again. The diagnostic data schema and report
exporter remain here for that purpose.
