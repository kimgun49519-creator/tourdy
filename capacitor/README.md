# TOURDY iOS — original app

This is the original HTML/CSS/JavaScript TOURDY inside Capacitor. The separate
`ios/` SwiftUI prototype is not this app and must not be substituted for it.

## Prepare

On a Mac with Node 22+, pnpm 10, and Xcode installed, run from the repository root:

```
pnpm install --frozen-lockfile
node scripts/build-capacitor.cjs
node node_modules/@capacitor/cli/bin/capacitor sync ios
node scripts/prepare-capacitor-ios.cjs
```

Open `capacitor/ios/App/App.xcodeproj`, select scheme App, choose your signing
team and connected iPhone, then Run. Repeat preparation after web source changes.
Xcode needs internet for its initial Swift package resolution; app assets are
bundled and the installed app does not need a web server to start.

## Records and migration

Records live in Application Support/TourdyShared/records-v1.json. The original
state JSON is retained inside an atomic envelope with previous-good/damaged
snapshots. File writes are serialized and checked for concurrent changes. Ticket
redemption, travel arrival and backup restoration publish only after a successful
file commit. An unreadable envelope is not replaced with an empty record.

Do not delete the old app before exporting a JSON backup. Safari, an earlier
file-URL wrapper, and this Capacitor origin do not share localStorage. Import the
original app's backup through Settings. A reinstall can remove the app container;
file storage is not an external backup or device sync.

## Notifications and current limits

Timer alarms are local notifications derived from saved timer endpoints and
cycle settings. Permission is requested from Settings. Pausing or changing a
timer updates pending alarms. iOS may suspend JavaScript in the background;
elapsed time, travel arrivals and stamps are reconciled on reopening. Exact
background travel-arrival alarms, widgets, Live Activities, and device sync are
not implemented by this wrapper. A floating native SwiftUI navigation bar uses
Apple Liquid Glass on iOS 26+, with a material fallback on older iOS versions.
The existing web navigation stays authoritative: native taps request the original
tab switch and selection is updated only from the resulting web state. Revisions
prevent stale updates from replacing a newer selection. The native bar hides
while a modal or the keyboard is open. Home uses a house, tasks a check box,
dashboard a custom three-panel mark, travel an airplane and settings a gear.

Special routes now depart by tapping the entire available gold-bordered card.
Unavailable cards are not focusable departure controls, and departure rechecks
season, starting city, active route and current journey before changing state.

Automated JavaScript checks and the Original TOURDY iOS workflow validate this
target separately from the archived SwiftUI prototype. Physical-device offline
and notification tests remain necessary before release.
