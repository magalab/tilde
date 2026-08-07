# Release checklist

## Automated local gate

- [x] Swift 6 package builds.
- [x] Unit and integration tests pass with `swift test`.
- [x] Ad-hoc app and embedded Quick Look extension build and verify with
  `scripts/verify-host.sh Debug`.
- [x] App and extension sandbox entitlements are checked by the verification
  script.
- [x] Quick Look registers only `net.daringfireball.markdown`.
- [x] 10 KiB–100 MiB performance matrix and SLOs are recorded.
- [x] Dependency pins and license families are audited.

## Product-owner inputs

- [ ] Select and add the Tilde project license.
- [ ] Confirm final reverse-DNS Bundle ID, marketing version, and build number.
- [ ] Provide and review the final App Icon.
- [ ] Select distribution channel (Developer ID direct distribution or Mac App
  Store) and the corresponding signing team/profile.

## Signed candidate

- [ ] Archive a Release build with hardened runtime enabled.
- [ ] Verify the signed app and nested extension with `codesign --deep --strict`.
- [ ] Compare signed entitlements with the accepted sandbox model.
- [ ] Bundle exact third-party acknowledgements and expose them from About.
- [ ] Package DMG with `scripts/build-dmg.sh Release`.
- [ ] Submit for notarization and staple the accepted ticket when using
  Developer ID distribution (notarize the DMG, not the `.app`).
- [ ] Validate Gatekeeper from a downloaded/quarantined artifact.

## Manual matrix

- [ ] macOS 15 and latest stable macOS.
- [ ] Light, Dark, and increased-contrast appearances.
- [ ] Multiple documents/windows, multiple monitors, full screen, and Split
  View.
- [ ] VoiceOver and Full Keyboard Access: open, edit, Find, Go to Line, preview,
  save, conflict recovery, and status announcements.
- [ ] Chinese/Japanese IME, Emoji, combining characters, Undo/Redo, and selection
  restoration.
- [ ] Autosave, Versions, Revert, Save failure, external modify/delete/read-only,
  sleep/wake, and abrupt termination recovery.
- [ ] Finder Quick Look while the app is closed and offline, including local
  image denial/fallback and over-budget Markdown.
- [ ] Clean-machine install, upgrade, logout/login registration, and uninstall.
- [ ] 50/100 MiB interactive scroll, selection, Find, and memory-pressure smoke.
- [ ] Capture Time Profiler, Allocations, and Hangs traces for the signed Release
  candidate and compare against `docs/performance-baseline.md`.
