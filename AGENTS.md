# Working on Starpath

Starpath is an iPhone app that shows the real positions of the Sun, Moon and
planets along the zodiac, with time travel, chart wheels, a widget and a
Control Center control. iOS 18, Xcode 26. It has no package dependencies, makes
no network requests and collects no data.

## Layout

- `StarPath/` is the app. `AstronomyEngine.swift` computes the positions.
- `StarPathWidget/` is the widget extension. It has its own copy of
  `AstronomyEngine.swift`.
- `app-store-screenshots/` is a Next.js page that renders the App Store
  screenshots. It has its own `AGENTS.md`. Use pnpm.
- `skills/`, `.agents/skills/`, `.claude/skills/` and `.windsurf/skills/`
  hold the vendored `app-store-screenshots` skill (`skills-lock.json`).

## Build

There is no `project.yml`. `StarPath.xcodeproj` is the source of truth and is
in git. Edit it with Xcode, or with care by hand.

```bash
xcodebuild build -project StarPath.xcodeproj -scheme StarPath -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet
```

Run it on mz-mini with `remote-build '<command>'` from inside the clone. Do
not build Swift on the laptop. There is no CI workflow.

## Release

`scripts/appstore.sh vX.Y` archives, uploads to App Store Connect and tags.
`--dry-run` archives and validates only. It reads the App Store Connect API key
from `~/.cartogram-secrets` (not in git; shared with Cartogram, team-wide).
`scripts/upload-screenshots.sh` uploads the screenshots.

## Traps

- The widget has its own copy of `AstronomyEngine.swift`. A fix in one copy
  must go into the other, or the widget and the app disagree.
- `appstore.sh` bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
  `project.pbxproj` with `sed`, then runs `git add -A`, commits, tags and
  pushes `main` with tags. Start from a clean tree on `main`.
- Versions are two-part (`1.15`), and tags are `v`-prefixed. Only `v1.12` is
  tagged; 1.15 shipped without a tag.
- The app must make no network requests. The privacy page on
  michellzappa.com/apps/starpath says so.

## Writing

Docs, comments and commit messages use Simplified Technical English: active
voice, short sentences, one word for one thing. No em dashes in UI copy.
