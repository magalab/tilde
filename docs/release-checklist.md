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
- [x] Release architecture is documented: the current artifact target is
  Apple Silicon (`arm64`) only; Intel and Universal artifacts are out of scope.

## Product-owner inputs

- [x] Select and add the Tilde project license (MIT).
- [x] Set the app Bundle ID to `tech.lury.tilde` and the Quick Look extension
  Bundle ID to `tech.lury.tilde.quicklook`.
- [x] Confirm marketing version 0.3.0 and build number 8.
- [x] Provide and review the final App Icon.
- [ ] Select a Developer ID certificate/team for direct distribution.

## Signed candidate

- [ ] Archive a Release build with hardened runtime enabled.
- [ ] Verify the signed app and nested extension with `codesign --deep --strict`.
- [ ] Compare signed entitlements with the accepted sandbox model.
- [ ] Bundle exact third-party acknowledgements and expose them from About.
- [ ] Package DMG with `scripts/build-dmg.sh Release`.
- [ ] Submit the DMG for notarization and staple the accepted ticket (direct
  Developer ID distribution; App Store submission is out of scope).
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
