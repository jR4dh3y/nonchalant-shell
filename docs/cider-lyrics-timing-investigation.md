# Cider lyric timing investigation

Date: 2026-10-18. Branch: `investigate/cider-lyrics-timing`, based on
`fix/left-bar-surface-colors` at `925d0ab8`.

## Finding

The supplied screenshot shows the shell emphasizing the next lyric while Cider
still emphasizes the preceding lyric. The mismatch is visible. The investigation
identifies different clock semantics that can reproduce it; it does not establish
an exact audible offset from the screenshot.

The shell selects and fills lyrics against the raw Quickshell MPRIS position.
Cider's installed lyric renderer uses a separate clock corrected for audio-output
latency. The shell does not apply that correction. This is a supported explanation
for an earlier shell transition, rather than evidence of incorrect TTML parsing.

## Code paths

- `modules/services/LyricsService.qml`: `lead` is zero; `place()` reads
  `MprisController.activePlayer.position` and selects the latest cue whose start
  is at or before that position. The 33 ms timer samples this getter; it does not
  add another extrapolated clock.
- `modules/components/LyricsView.qml`: line and word progress use the same
  playback position. When word timestamps are absent, character fill is spread
  across the line duration; that fill is an estimate, not measured word timing.
- Upstream [Quickshell MprisPlayer documentation](https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Mpris/MprisPlayer/)
  confirms that reading `position` returns the advancing position even when
  reactive notifications are emitted manually.
- Installed Cider package version: `4.0.9.1`.
- `/usr/lib/cider/resources/spa/assets/vLyricProgress-BDpCgqjn.js`: the renderer
  anchors a high-resolution clock to the player and subtracts `H`, derived from
  WebAudio `outputLatency` (falling back to `baseLatency`) plus optional native
  host render latency. The WebAudio contribution is capped at 300 ms, the host
  contribution at 800 ms, and the combined correction at one second.
- `/usr/lib/cider/resources/spa/assets/ImmersiveMetadata-Bs0sgkKw.js`: lyric
  selection consumes that corrected clock and subtracts the configured lyric
  offset, with an additional adjustment for AirPlay.
- Cider's configured `lyrics.timeOffset` was zero. Its actual live WebAudio and
  native-host latency values were not exposed by the sampled public endpoints.

## Live observations

Two normal-playback samples each collected 240 paired observations over about
24 seconds, on the same recording. A separate, read-only Quickshell MPRIS probe
used offscreen rendering and private HOME/XDG paths. It imported no shell
services, changed no playback state, and used the existing session bus only to
observe Cider. No compositor socket was addressed.

Quickshell position minus Cider's raw MPRIS position, after correcting sample
times:

- First sample: median -6.7 ms, range -21.9 to +10.7 ms.
- Second sample: median -10.1 ms, range -29.5 to +8.8 ms.

The fresh Quickshell probe introduced no sustained positive lead. These samples
do not expose the running shell instance's older clock anchor or Cider's rendered
lyric clock.

Cider's v1 now-playing and v2 playback snapshot/time endpoints returned stepped
times, with only 27 and 31 distinct positions respectively in 240 observations.
Their apparent lag behind MPRIS had medians around 456 and 472 ms. Those values
describe endpoint update granularity; they must not be reported as the measured
lyric or audio delay.

An initial sample reached a track's end: the API position stayed at 239.019 s
while MPRIS continued advancing with status Playing. This is a separate observed
end/stall clock failure, not the normal-playback offset estimate.

## Screenshot recording and controlled reproduction

Apple's exact single recording `1821924042` and album recording `1810796705`
returned identical relevant TTML cue times:

- Previous cue: 93.852–96.839 s.
- Next cue: 96.976–100.944 s.
- Following cue: 101.252–105.270 s.

The cues do not overlap. The screenshot's shell progress reads 1:37, consistent
with selecting the next cue at a raw position near 97 s.

Executing the production `place()` body and installed Cider clock function with
a controlled raw position of 97 s gives:

- With zero output correction, both clocks are 97 s and select the next cue.
- With an assumed 300 ms correction, the shell remains at 97 s while Cider's
  lyric clock is 96.7 s, still inside the previous cue.

This reproduces the observed direction with unchanged cue timestamps. The 300 ms
value is a controlled input, not a measurement of this user's audio path.
Cider's selected provider, cached lyric variant, and display transition at the
instant of the screenshot were not independently observed.

## Validation and next step

All 32 existing parser/provider unit tests passed. The existing isolated Cider
runtime test passed its word-progress, seek, pause, interlude, and player-switch
checks on a private D-Bus session with offscreen rendering.

No lyric timing code or user configuration changed. Before choosing a correction,
measure or expose Cider's actual latency-compensated lyric clock. A universal
fixed delay would conceal differences between audio outputs, playback stalls,
and lyric providers rather than establish a shared timing contract.

Raw live samples and probe logs were saved under
`/tmp/nonchalant-cider-live-wet6snwa` and
`/tmp/nonchalant-cider-live-fsjol3el`; the initial end-of-track sample is under
`/tmp/nonchalant-cider-clock-rqkey4mb`. These are temporary local artifacts and
contain no authentication headers or account tokens.
