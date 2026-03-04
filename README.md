# MusicDisplayKit

Swift port-in-progress of [OpenSheetMusicDisplay](https://github.com/opensheetmusicdisplay/opensheetmusicdisplay) (OSMD), using [VexFoundation](https://github.com/migueldeicaza/VexFoundation) for rendering.

See AUTHORS and LICENSE for the original authors of the code.

## SwiftUI Rendering Performance Guidance

When working on `VexScoreView` / `MusicDisplayLazyScoreView`, treat render data as a staged pipeline and cache only stable stages.

### Cache the Right Stages

Use these cache boundaries:

- `Score + LayoutOptions -> LaidOutScore`
- `LaidOutScore + RenderTarget -> VexRenderPlan`
- Lazy view only: `VexRenderPlan -> [PreparedLazySystemRender] + system index range + measure range by system` (pre-sliced row plans and visibility metadata)
- Lazy score + source `Score`: apply a viewport-driven `measureRange` window, and expand it as the visible systems approach the loaded range edge.

These values are deterministic for the same input and should be recomputed only when inputs change.

`LaidOutScore` now carries a `renderRevision` token. Use that revision
as the cache invalidation key for render-stage caches (`VexRenderPlan`,
lazy system slices) instead of deep `LaidOutScore` equality checks in
SwiftUI `body`.

### Do Not Cache `VexFactoryExecution`

`VexFactoryExecution` is single-use in practice. `Factory.draw()` drains and resets the factory queue, so reusing a cached execution can render blank content on subsequent redraws (for example, after scroll invalidation).

Draw-time rule:

- In each `VexCanvas` draw callback, create a fresh execution from a cached plan:
  `executeRenderPlan(plan) -> drawExecution(execution, on: context)`

### Keep Heavy Work Out of `body`

Avoid doing any of the following directly in SwiftUI `body` evaluation:

- music layout
- render-plan construction
- per-system plan slicing
- font bootstrap/loading

Compute these in cache objects keyed by input value equality, then make `body` mostly a lightweight selection layer.

For lazy system rendering specifically:

- precompute each system row's `VexRenderPlan` once in cache (`PreparedLazySystemRender`)
- precompute `availableSystemIndexRange` and `measureRangeBySystem`
- avoid per-row fallback `systemSlice` work inside `ForEach`

For geometry-driven relayout (`autoResize`), debounce width commits to
avoid layout thrash while users resize/split views.

### Partial Redraw Strategy for `VexCanvas`

`SwiftUI.Canvas` in this stack is callback-based and does not provide a dirty-rect incremental redraw API through `VexCanvas`.

Use coarse-grained partial redraw instead:

- split long scores into per-system canvases (`MusicDisplayLazyScoreView`)
- rely on `LazyVStack` materialization so only nearby rows are active
- avoid hard row clipping when system bounds are tight; only clip if row bounds include glyph overflow margins

This is the supported way to avoid redrawing the entire score on scroll.
Use monotonic visibility signals (for example, highest visible system seen)
for window expansion to avoid scroll flicker from rapid
`onAppear`/`onDisappear` churn.

When `MusicDisplayLazyScoreView` is fed a precomputed `LaidOutScore` (not
raw `Score`), skip visibility-window bookkeeping entirely. There is no
measure-window expansion path in that mode, so updating visibility state on
every row appearance just adds invalidation churn.

### Host-App SwiftUI Idiom

If a host app overlays playback cursors or selection UI on top of a score,
keep the score surface in its own `Equatable` subview keyed by
`laidOutScore.renderRevision`. This prevents high-frequency playback state
updates from re-diffing static score content.

### Font/Glyph Performance

Repeated default font loading can cause avoidable JSON decode and glyph cache churn. Keep default font setup idempotent and avoid resetting the music font stack unless it actually changes.

### Measuring Improvements

`VexFoundationRenderer` now publishes lightweight runtime counters:

- `VexRenderMetrics.reset()`
- `VexRenderMetrics.snapshot()`

The snapshot includes make/execute counts, total/average/max durations,
and total rendered element estimate. The renderer also emits signpost
intervals for `makeRenderPlan` and `executeRenderPlan` (when `OSLog`
is available), so Instruments can compare before/after behavior.

## Contributing

See `CONTRIBUTING.md` for setup, contribution checklist, and code style/testing guardrails.

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
