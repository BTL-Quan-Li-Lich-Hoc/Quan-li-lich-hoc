# Tiên Môn Premium module

Implement the standalone Premium visual engine here.

Rules:
- independent from ordinary AppThemeId/ThemeTokens rendering
- use adapter contracts for schedule/exam/sync/notification data
- keep background + ambient motion persistent above route/page changes
- use canonical timing/assets from `TienMonPremiumContract`
- no production QLĐT/database integration in this branch phase
- no old Tiên Môn runtime asset unless explicitly approved by the user

Recommended internal split:
- `background/` persistent scene resolver, preload, 3s crossfade, ambient motion
- `glass/` shared Liquid Glass tokens/components
- `motion/` calm animation primitives
- `schedule/` day/week + study/exam visual surfaces
- `notification/` Premium sheet
- `widgets/` Premium widget preview/render contracts
- `demo/` fake-data adapters and test controls
