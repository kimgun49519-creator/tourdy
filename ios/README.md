# TOURDY iOS prototype

This is a separate iPhone/iPad application shell, not a complete SwiftUI rewrite.
The existing timer, travel, stamps and reward rules run from bundled files in a persistent WKWebView. Every visible app switch is overlaid with a system SwiftUI Toggle, sharing the original handlers and saved state. iOS 26+ and the current Apple SDK provide the system switch appearance; this project does not draw a CSS imitation of Liquid Glass.

## Open on a Mac

1. From the repository root run `node scripts/build-ios.cjs` after changing web sources.
2. Open `ios/Tourdy.xcodeproj` in Xcode 26 or later.
3. Select the Tourdy target, choose your signing team and replace `com.example.tourdy` with your bundle identifier.
4. Choose an iOS 26+ simulator or connected iPhone/iPad and Run.

No package installation, website server or network access is needed for app content. Generated Web resources are ignored in Git and must be prepared before opening/building. The application uses WKWebsiteDataStore.default local storage; Safari/PWA records are separate and are not imported automatically.

## Status and limitations

- Source and resource checks were performed on Windows. **No Xcode build, simulator launch, device validation or App Store submission has been performed.**
- The native switches overlay web controls. Scrolling, Dynamic Type, VoiceOver, rotation, sheets and touch targeting require device QA. This is an initial integration, not a fully native settings screen.
- Browser push is disabled; native local notifications, background completion alerts, PiP integration, file import/export, app icons and distribution configuration need further iOS work. Bundling alone does not make those features work.
- OS suspension stops screen updates. Elapsed time is derived from timestamps on resume; no continuous background execution is promised.
- Local storage durability on actual devices, updates and force termination must be validated before release. No cross-device synchronization is implemented.

## Required device checks

Install, enable airplane mode before the first launch, then create a subject, start/end study, redeem the cumulative 30-minute ticket after session end, complete a paid domestic journey, collect a stamp, terminate and reopen. Verify balances, routes and stamps are retained without duplicates. Repeat world/space journeys with valid unlock progress; check failed saves without record loss. Test every switch, rotation, Reduce Transparency, light/dark mode and VoiceOver on iPhone and iPad. Validate export/import and notifications separately once implemented.
