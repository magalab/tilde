# Dependency license audit

Audited against `Package.resolved` on 2026-08-07. Re-run this audit whenever a
pin changes.

| Package | Resolved revision/version | License | Distribution action |
|---|---|---|---|
| Textual | `01b51875a5406eefc95f52a058cb059e7bc94dc4` | MIT | Include copyright and MIT text |
| swift-markdown | `27b7fc1a19068bcea3d2072db0ce86360d1400ed` | Apache-2.0 | Include license and `NOTICE.txt` |
| swift-cmark | `7898f1b3e4befeecee56cb4a3bc8eebd2cb63219` (`gfm`) | BSD-2-Clause-style | Include copyright and license text |
| swift-concurrency-extras | 1.4.1 / `5fa253428866f2360c3754e88537f700ed2656b5` | MIT | Include copyright and MIT text |
| swiftui-math | 0.1.0 / `0b5c2cfaaec8d6193db206f675048eeb5ce95f71` | MIT; bundled upstream notices apply | Include its license and bundled notices |
| BeautifulMermaid | `6a23a29e91af8f5b3e9fc09945332ca193bd69ec` | MIT | Include copyright and MIT text |
| elk-swift | 1.0.2 / `32f8042e3509a4819f00ff9cd46e829ec2b26da0` | EPL-2.0 | Include EPL-2.0 text and original ELK notices |

`SnapshotTesting` appears in Textual's upstream third-party audit but is not in
this app's resolved shipping dependency graph.

Before distribution, copy the exact license texts and required notices from
the resolved checkouts into the app's acknowledgements resource and expose them
from About Tilde. The Tilde project itself currently has no selected license;
that is a release blocker rather than a license choice to infer in code.
