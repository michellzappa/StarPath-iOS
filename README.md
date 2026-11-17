# Starpath

A live chart of the real sky along the zodiac, for iPhone. It shows where the Sun, Moon and planets are right now, and you can scroll through time to watch them move. There are no horoscopes or predictions.

[App Store](https://apps.apple.com/app/id6759219160) · [Page](https://www.michellzappa.com/apps/starpath) · [Privacy](https://www.michellzappa.com/apps/starpath/privacy) · [Support](https://www.michellzappa.com/apps/starpath/support)

## What it does

- Positions of the Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus and Neptune along the ecliptic
- Time travel by day, month or year, with drift curves for each planet
- A linear chart plus geocentric and heliocentric wheels
- The current moon phase
- A home screen widget and a Control Center control

Every calculation runs on the phone. The app makes no network requests and collects no data.

## Building

Open `StarPath.xcodeproj` in Xcode 26 or later and set your own development team. The app targets iOS 18. It has no package dependencies.

- `StarPath/` is the app. `AstronomyEngine.swift` computes the positions.
- `StarPathWidget/` is the widget extension. It carries its own copy of the engine.
- `scripts/appstore.sh` archives and uploads a release. It reads App Store Connect API credentials from `~/.cartogram-secrets`, which is not in this repo.
- `app-store-screenshots/` is a Next.js page that renders the App Store screenshots.

## Issues

Bug reports and questions go in [GitHub issues](https://github.com/michellzappa/StarPath-iOS/issues). Say which version you run, what you did and what happened.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md).
