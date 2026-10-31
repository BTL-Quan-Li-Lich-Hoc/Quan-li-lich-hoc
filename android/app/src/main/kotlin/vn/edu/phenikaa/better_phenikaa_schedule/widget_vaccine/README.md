# ThemeVaccine

> Launcher thích tự do diễn giải kích thước. Còn widget thì vẫn phải ra đúng
> thiết kế.

This directory contains only widget host size and render geometry adaptation.
The reference widget XML, themes, actions, schedule data, sync, and notifications
remain the baseline.

## Geometry

- `WidgetHostSizeResolver` reads each widget instance's options. Android 12+
  exact sizes remain the source for the small widget's size-specific layouts.
  When only legacy ranges are available, portrait uses the narrow/tall pair and
  landscape uses the wide/short pair. Transient bitmaps use the closest exact
  size for the current orientation.
- `WidgetGeometry` derives the 4×2 panel height from the host width using the
  reference panel's 320:124 ratio, clamps it to 104–156dp, and caps it at the
  host height. Extra two-row host height remains outside the panel. When the
  host is taller than the panel, an adaptive layout anchors it at the top so
  the gap after the small widget stays faithful to the reference.

## Compatibility, tracked separately

The existing refresh cover, collection token, pending selection, theme
transition generation, and per-widget state in `ScheduleWidgetProvider` remain
unchanged. Ghost layers, stale children and rebind races require separate
launcher observations and tests. Geometry passing does not establish that
those compatibility cases pass.

Android 11 and older cannot set the 4×2 panel height through the Android 12
`RemoteViews` size API. They select a fixed 104/124/140/156dp layout closest
to the calculated height. The original reference XML remains untouched.
Each launcher still needs a screenshot and interaction check before visual
parity can be marked as passing.
