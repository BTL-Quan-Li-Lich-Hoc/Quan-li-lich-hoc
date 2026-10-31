# Interaction upgrade

Implemented for the Better Phenikaa App test shell:

- Calendar icon on the timetable screen opens an animated calendar sheet.
- Tapping the centered date navigator opens the same calendar selector.
- Horizontal swipe keeps one-day navigation and the schedule body now slides/fades between dates.
- The floating control menu expands along a quarter-circle arc with staggered scale/translate/fade animation.
- The floating action button rotates/transitions between grid and close states.

## Web QLĐT constraint

The static GitHub Pages build cannot directly read an authenticated QLĐT session from `qldtbeta.phenikaa-uni.edu.vn` because browser same-origin/CORS and Microsoft SSO cookies are scoped to the official origins. Real Android login continues through the in-app WebView. A real web-login bridge needs either official web OAuth/API support from QLĐT or a trusted companion/extension mechanism; it must not collect or proxy student passwords through an untrusted third party.
