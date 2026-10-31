# Tiên Môn Premium — Final Reference

## 0. Non-negotiable authority rule
The user's vision is authoritative. Implement it; do not redesign it.

Do not reinterpret, simplify, replace, or "improve" the supplied visual concept. The newest user-supplied Premium assets always win. Existing Tiên Môn assets already in the repository are historical/reference-only unless the user explicitly approves one for Premium runtime use.

## 1. Product identity
Tiên Môn Premium is a separate visual subsystem/engine, not merely another preset in the current Theme Engine.

It owns its own:
- persistent background/scene engine
- live-wallpaper motion system
- Liquid Glass system
- animation system
- button/control styling
- layout rules
- app renderer
- widget renderer/art strategy
- Premium assets and visual state rules

It may consume DemoF3 schedule/exam/day/week/sync/notification state through adapters. The production data model must not dictate the Premium visual implementation.

## 2. App background: source and geometry
Canonical app sources are eight 2K portrait PNGs at 1440x2560.

Rules:
- treat each image as a complete painting, never as a texture
- preserve composition and aspect ratio
- uniform scale only (`scaleX == scaleY`)
- never stretch/squash
- never crop important content
- never zoom merely to fill the screen
- no global blur
- no global recolor
- no heavy full-screen dark overlay
- use proportional fit and scene-aware ambient extension for unusual device ratios rather than distorting the painting
- local Liquid Glass blur is allowed only behind the glass element

## 3. Persistent live wallpaper
The current Tiên Môn background is one persistent global world behind the whole Premium app.

Required shell shape:

```text
TienMonPremiumShell
├── PersistentTimeBackground
├── PersistentAmbientMotion
└── Foreground/Page Content
```

Navigating between Lịch học, Lịch thi, Ngày, Tuần, Notification Center, or later Premium pages must not recreate/reload/reset the background or its motion.

No black/white flash. No visible image reload. No motion restart on page navigation.

### Ambient motion character
This is a live wallpaper, but calm and contemplative rather than busy.

A scene should feel like one panoramic painting breathing very slowly:
- very slow mist/cloud drift
- sparse petals/leaves with long quiet rhythms
- extremely subtle water shimmer/flow
- gentle light/haze movement
- optional near-imperceptible parallax when appropriate

Motion must be soft, slow, relaxing, continuous, and non-demanding. It must never feel game-like, frantic, particle-heavy, or like a short obvious loop. The base painting's time-of-day, palette and composition may not be changed by the motion layer.

## 4. App scene schedule
Use local device time.

| Scene | Time |
|---|---|
| 1 | 04:30–07:00 |
| 2 | 07:00–10:00 |
| 3 | 10:00–16:00 |
| 4 | 16:00–17:00 |
| 5 | 17:00–18:30 |
| 6 | 18:30–21:00 |
| 7 | 21:00–02:30 |
| 8 | 02:30–04:30 |

At an actual boundary, preload the next scene and crossfade for exactly about 3 seconds. Foreground/page state must not reload.

Demo controls must support direct scene 1–8 selection plus `Prev`, `Next`, and `Auto` (real-time resolver).

## 5. Liquid Glass
The background is the main character. Liquid Glass exists to keep content readable without hiding the world.

Required qualities:
- transparent/semi-transparent glass
- moderate local blur
- clear thin luminous border
- subtle highlight/refraction
- soft shadow
- no giant milky-white opaque panels
- no opaque black cards
- cards should reveal more background than modal/sheet surfaces
- selected state may brighten/refine the glass rather than turning into an unrelated solid color

Notification Center is a glass sheet that slides upward from the bottom, with a clearly visible glass border. Its body must be sufficiently opaque/tinted to conceal the underlying schedule content where the old interaction logic relies on a covering sheet; underlying text/cards must not visibly bleed through.

Centralize glass parameters so blur, tint, opacity, border alpha, highlight, shadow and radius can be tuned coherently.

## 6. Foreground animation rules
- Ngày ↔ Tuần: Liquid Glass segmented selector slides between states; old content fades out/new content fades in (~220ms)
- Next/previous day or week: schedule region slides lightly in the navigation direction with a subtle fade (~220–250ms)
- Lịch học ↔ Lịch thi: direct fade (~200–250ms), no whole-page slide
- Notification Center: glass sheet slides from bottom (~280–320ms)
- Current/active subject: very soft slow breathing glow, long cycle (~2.5–4s)
- When a new day/week's cards appear: cascade top-to-bottom; stagger around 50ms (acceptable 40–70ms), still quick and understated
- Buttons/icons: keep ripple interaction plus brightness/opacity state change; do not scale the button
- Easing: calm cubic/ease-in-out behavior; no bounce/spring spectacle
- Background scene crossfade: 3s

All foreground transitions happen above the persistent live wallpaper.

## 7. Font contract
Primary Premium font: `FzCoTrang`.

Hard rule: any missing/unsupported glyph, tofu box, or glyph that may render as a square must never be rendered with `FzCoTrang`.

The supplied font maps `•`, `·`, `–`, and `—` to the missing-glyph/tofu shape. Use a Unicode-capable fallback font for those characters and any future unsupported glyph. Do not rewrite product text merely to accommodate the font. Prefer per-glyph/font fallback. No square/tofu glyph may appear in any Premium UI state.

## 8. Big / overview widget
The overview widget has its own Premium renderer and may use the supplied scene artwork because it does not use the problematic small-widget stack strategy.

Widget background schedule:
- 05:00 -> morning (`wid_sang.png`)
- 16:30 -> afternoon (`wid_chieu.png`)
- 18:30 -> night (`w_toi.png`)
- night remains through 04:59

Widget backgrounds are static per scene; do not attempt continuous live wallpaper motion in RemoteViews.

Preserve DemoF3 interaction/data concepts for later adapter integration:
- three vertical icons left: calendar, sync/reload, bell; no labels/separators
- study/exam views
- timeline/cards
- `<` / `>` navigation without circular wrap
- current-subject indicator
- reload spinning/loading state, short success tick, failure icon
- exam mode and no-exam empty state

For the standalone Premium demo/harness, use fake/stub state and expose `Sáng / Chiều / Tối` controls for renderer testing.

Android widget glass is a visual simulation using bitmap/gradient/highlight/border techniques, not real BackdropFilter.

## 9. Small widget
Do not use a full scenic background image.

Reuse the existing Theme Engine/widget engine's stable redraw approach to prevent layer-stack artifacts. Premium supplies its own palette/art direction:
- stable full-coverage gradient/background color strategy
- dark green/deep blue -> jade -> silver family as appropriate
- restrained gold/jade accents
- decoration can favor the left side, but must not obscure schedule/time text
- redraw must be idempotent from a clean frame and fully cover the prior frame

Do not introduce decorative animation that risks bringing back the Xiaomi/layer-stack defect. Production gesture/date logic is a later integration task.

## 10. Quality/performance principle
Optimize implementation; never simplify the visual experience.

Permitted optimization includes caching, preloading, avoiding repeated decode, correct texture sizing, minimizing overdraw, lifecycle management, rendering only moving layers, and disposing resources correctly.

Do not optimize by lowering the visible experience: no Premium Lite, no automatic removal of glass, motion, quality, cascade, glow, or resolution. There is no device capability gate in this phase. The Premium visual contract is fixed.

## 11. Demo acceptance harness
The standalone demo should let the user verify without waiting for real time:
- app scenes 1–8
- Prev / Next / Auto
- background crossfade
- persistent motion surviving page/content changes
- Day / Week
- previous/next day/week
- study / exam
- active subject glow
- card cascade
- Notification Center sheet
- sync loading/success/failure visual states
- big widget morning/afternoon/night states
- small widget Premium palette/redraw appearance

Use fake data behind an adapter boundary. Visual components must not depend directly on a hard-coded fake model so production schedule data can later replace it cleanly.

## 12. What Work must not spend time on
Do not integrate QLĐT login, semester parsing, schedule sync, database migration, actual notification scheduling, or production theme selection. Do not merge Premium into the ordinary AppThemeId/ThemeTokens flow. Leave explicit integration hooks for later chat work.
