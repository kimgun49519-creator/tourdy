# TOURDY native iOS — first migration build

The compiled target is `Tourdy/NativeApp.swift`: SwiftUI screens, a system TabView and native Toggles. No web view, HTML, JavaScript runtime, remote fonts or website server is part of this target. Resources/places.json contains existing public domestic, world and space destinations.

## Run on a Mac

Open Tourdy.xcodeproj using Xcode 26+ and an iOS 26+ simulator or device. Choose your signing team. Keep the SAME bundle identifier as your previous install to retain its app container. Do not uninstall the old app. Source resource preparation, when working from Git, is `node scripts/build-ios.cjs` from the repository root; the downloadable ZIP already includes resources.

## Implemented in native Swift

- Create subjects, start/finish study, retain running timestamps across app reopening.
- Tasks with system switches, cumulative/per-subject statistics and session history.
- Completed study earns miles (6 minutes per mile, daily eight-hour cap, daily/streak bonuses).
- Domestic/world/space destinations, completion gates and space zone gates, paid journey reservation, balance deduction and arrival stamps.
- Cumulative 30-minute first reward only after session completion; domestic premium gift with origin selection, permanent dated ticket and three next destinations.
- Atomic Codable JSON writes in Application Support. Failed writes do not publish candidate state or consume rewards. Corrupt records block writes instead of resetting them.
- Native backup export through ShareLink; dark mode setting.

## Migration limits — not full feature parity

This is a new native implementation, not the complete web app feature set. Reservations/Pomodoro/rest timers, memo prompts, notifications/sounds/haptics, special/secret routes, world cabin classes beyond the prototype premium choice, maps, advanced planner/statistics, backup restore, and automatic migration/synchronization are not yet ported. Miles in this first native build are credited after completed sessions. Settings do not expose switches for unimplemented effects.

Web-wrapper localStorage is left untouched in the old WebKit data store. Native data uses a separate TourdyNative/state-v1.json. Old web records do NOT appear automatically; do not interpret the empty native screen as deletion. Export the old version before replacing it if you need a user-accessible backup. Native backup JSON is a different format.

## Validation

On Windows, destination generation and target/resource checks pass. **Swift compilation and native behavior have not been verified in Xcode.** Before release, compile on Mac; test rapid tab switching, rotation, VoiceOver, keyboard, dark mode, interrupted writes, running timer force-close/relaunch, midnight sessions, exactly 30 minutes at session end, one-time gift, paid arrival without duplicate charge, world/space locks and stamp persistence. Install and launch with airplane mode already enabled to verify first-launch offline behavior. No native platform runtime result is claimed by the Node tests.
