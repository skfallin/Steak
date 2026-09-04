# Food search panel

The Add screen uses a continuous, resizable bottom panel. Drag the grabber or title to change its height; intermediate heights remain freely adjustable. Within 24 points of either endpoint, movement eases toward that anchor and release snaps to it. Pulling beyond an endpoint meets increasing resistance, capped below 12 points, then springs back on release. Tapping the header still expands or collapses it. Focusing search expands it, and result scrolling remains independent of panel resizing.

The background uses native iOS 26 Liquid Glass with `ConcentricRectangle`. Bottom corners follow the enclosing screen; top corners have a 28-point minimum. Only the glass background extends through the bottom container safe area, behind the native tab bar. The former opaque rectangle and outlined background are removed. Search controls retain the app's typography and adaptive palette.

`GestureState` tracks translation in global coordinates so moving the header does not change the gesture's coordinate origin. Contact updates have no animation; gesture reset and endpoint settling share a 0.3-second spring with a small bounce. Reduce Motion disables settling and programmatic animations. Lower overpull offsets the whole panel instead of shrinking its controls. The attraction range contracts for short available travel. Header and search-control heights scale with Dynamic Type; an accessibility adjustment changes expansion in 25-percent steps.

## Documentation

Checked Context7 and the installed Xcode 26.6 SDK (Swift 6, iOS deployment target 26.0):

- [Gesture callbacks and transient state](https://developer.apple.com/documentation/swiftui/adding-interactivity-with-gestures)
- [Drag translation](https://developer.apple.com/documentation/swiftui/draggesture/value/translation)
- [Gesture reset transaction](https://developer.apple.com/documentation/swiftui/gesturestate/init(resettransaction:))
- [Spring animation](https://developer.apple.com/documentation/swiftui/animation/spring(duration:bounce:blendduration:))
- [ConcentricRectangle](https://developer.apple.com/documentation/swiftui/concentricrectangle)
- [Custom Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

The installed SDK's `concentric(minimum:)` accepts `Edge.Corner.Style`; the minimum therefore uses `.fixed(Layout.largeCornerRadius)`.

## Verification — September 4, 2026

- Debug simulator build succeeded; `git diff --check` passed; Graphify updated.
- iPhone 17 Pro: a 190-point drag moved the header from y=659 to y=469 and retained 43-percent expansion. A subsequent 80-point drag moved it to y=389; a measurement during contact showed y=443.33 before release, confirming continuous updates.
- Isolated iPhone 17e review simulator: a 110-point drag moved the header from y=629 to y=519, retaining 25-percent expansion across subsequent observations.
- Releasing beyond either limit settles at the fully collapsed or expanded height.
- Search focus expands the panel; typing and submitting `eggs` returned live database results. Scrolling those results left the header at y=204 and 100-percent expansion.
- The manual-entry button opened the New food sheet; no food was saved.
- Light and dark appearance inspected, including the translucent background and rounded screen corners. The native tab bar remains visible.
- Software-keyboard geometry, physical camera input, rotation, and exhaustive VoiceOver/Dynamic Type coverage were not verified. The simulator used hardware text input.

No dependency, model, database, or networking changes.

## Magnetic anchors verification

- Debug simulator build and diff whitespace check passed.
- Executed checks against the extracted `SearchPanelAnchors` implementation for symmetric attraction, monotonic movement, bounded overpull, snapping at both ends, free intermediate positions, and zero/small travel.
- iPhone 17e: lower overpull moved the header from y=629 to y=635 during contact, then returned to y=629. Upper overpull moved it from y=204 to y=197.67, then returned to y=204.
- Releasing 20 points short of either endpoint snapped to 0 or 100-percent expansion.
