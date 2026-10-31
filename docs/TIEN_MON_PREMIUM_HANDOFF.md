# Tiên Môn Premium handoff

## Continuation checkpoint

- Branch: `tienmon_preinumtheme`
- Recovered source/history baseline for this continuation: `17c2b5c0925c06dcaede8c8e866e08fd12f8f8fe`
- Previous functional layout/ambient checkpoint preserved: `3312d89b22adbab83bd61728a8b551541c57c202`
- New functional checkpoint: `9b155bc3233e7782a83ddb60a048dd7a4c7e31b6`
- Scope remained limited to Tiên Môn Premium visual/runtime polish. No APK build, Flutter bootstrap retry, QLĐT/database integration, production sync work, native-widget production work, wallpaper replacement, or card redesign was performed.

## Status

- **Layout production adaptation: DONE (static implementation)**
  - Main page keeps DemoF3 production geometry: `22/26/22/18` page padding, production-style title/icon grouping, notification then calendar controls, full-width `Theo ngày` / `Theo tuần` selector, and production-like date/week navigation spacing.
  - Day date label now mirrors DemoF3 production wording (`Thứ ..., d tháng m`) instead of numeric-only harness text.
  - Premium subject-card visual and existing card transitions/glow remain unchanged.
  - FAB keeps production `right: 22`, `bottom: 28` placement and full FAB size.

- **Week layout: DONE**
  - Uses the production row model rather than a vertical stack of large cards.
  - Each day row is 86 high, left day column 79 wide, subject items 135 wide in a horizontal list.
  - Empty days retain the row and render `Không có lịch học` on the right.

- **Debug/Test controls: DONE**
  - Scene 1-8, scene navigation, Auto, Study/Exam, widget previews, sync states, and animation test controls remain inside the scrollable Liquid Glass `Tùy chọn` sheet.
  - Main page remains free of debug rows.

- **Fullscreen background extension: DONE (static implementation)**
  - Authoritative 1440x2560 artwork remains `BoxFit.contain`: no crop, stretch, zoom, or composition change.
  - Overflow uses per-scene edge-color continuation plus local radial glow and lower mist rather than a flat band.

- **Ambient live wallpaper: POLISHED (static implementation)**
  - Keeps eight scene-aware profiles, layered mist/haze, localized light breathing, procedural petal/leaf silhouettes, lower-region water shimmer, and top-left to bottom-right flower/leaf travel.
  - Ambient animation now derives motion from monotonic `lastElapsedDuration` instead of reset-prone normalized loop progress. This prevents visible jumps when the 72-second controller repeat boundary is crossed.
  - Mist layers now use independent long periods (roughly 118/153/201 seconds before scene speed scaling), preserving slow depth without synchronized resets.
  - Haze breathing, light breathing, shimmer wave motion, and particle travel use independent elapsed-time periods.
  - Particle wrap remains hidden by lifecycle fade; the dominant path stays top-left -> bottom-right with soft sway/rotation.
  - Foreground Day/Week/date/Study-Exam/options rebuilds do not recreate the persistent ambient controller.

- **Scene scheduling: DONE**
  - Removed 20-second polling.
  - Added `TienMonPremiumContract.nextAppSceneBoundaryAfter(...)` for exact one-shot local scheduling at 02:30, 04:30, 07:00, 10:00, 16:00, 17:00, 18:30, and 21:00.
  - Manual scene selection cancels the auto timer; returning to Auto immediately resolves the current scene and schedules the next exact boundary.
  - Selecting the currently visible scene while Auto is active now still updates the Auto/manual state correctly.

- **Runtime: NOT TESTED**
  - Per user request, no Flutter environment retry and no APK build were run in this continuation.

## Validation completed without Flutter

- `python3 tools/tien_mon_premium/validate_static.py` -> PASS
- `git diff --check` -> PASS
- Static validator now also rejects `Timer.periodic` scene polling and requires monotonic elapsed-time ambient motion.
- Contract tests were extended for exact next-scene-boundary calculation, including cross-midnight scheduling.

## Files changed in `9b155bc`

- `lib/features/giao_dien/tien_mon_premium/background/tien_mon_background.dart`
- `lib/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart`
- `lib/tien_mon_premium_demo.dart`
- `test/tien_mon_premium_contract_test.dart`
- `tools/tien_mon_premium/validate_static.py`

## First runtime checks for the user build

1. Compare the main page against DemoF3 production for header, selector, date navigation, Day density, Week row density, and FAB position.
2. Watch each scene for 3-10 seconds: mist/light movement should be visible without dominating the UI; petals/leaves should drift top-left to bottom-right; shimmer should remain local to the lower water region.
3. Keep a scene open beyond the old 72-second loop point and verify mist/light/particles do not visibly jump backward.
4. Switch Day/Week, dates, Study/Exam, notifications, and Options repeatedly and verify ambient phase does not restart.
5. Confirm artwork remains fully visible without crop/stretch and the top/bottom extension no longer reads as a flat rectangle.
6. In Auto mode, verify a scene change occurs at the exact next configured time boundary rather than up to ~20 seconds late.
