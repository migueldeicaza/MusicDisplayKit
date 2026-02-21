# MusicDisplayKit

SwiftPM port-in-progress of OpenSheetMusicDisplay (OSMD), using `VexFoundation` for rendering.

## Running Tests

Run the full suite:

```bash
swift test
```

Run rendering golden tests only:

```bash
swift test --filter renderingGolden
```

## Updating Rendering Goldens (`UPDATE_GOLDENS`)

Rendering goldens are stored at:

`Tests/MusicDisplayKitTests/Fixtures/Goldens`

To regenerate all rendering golden PNGs:

```bash
UPDATE_GOLDENS=1 swift test --filter renderingGolden
```

To regenerate a specific golden test (example):

```bash
UPDATE_GOLDENS=1 swift test --filter renderingGoldenOSMDVoiceAlignmentFixture
```

When a golden comparison fails, diff artifacts are written to:

`./.build/golden-artifacts`

Typical workflow:

1. Run `swift test --filter renderingGolden`.
2. If expected visual changes were made, regenerate with `UPDATE_GOLDENS=1`.
3. Re-run `swift test --filter renderingGolden` to confirm clean comparisons.
