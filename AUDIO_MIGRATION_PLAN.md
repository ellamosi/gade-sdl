# Audio Migration Plan

## 1. Add observability first
- Keep current pipeline.
- Add stable counters (not spam logs): producer samples, dropped blocks, busy/free queue occupancy, ring fill min/max.
- Goal: baseline latency/underrun behavior before refactor.

## 2. Decouple producer chunk size from frame size
- Introduce `Producer_Chunk_Samples` (small, e.g. 256 or 512 stereo samples).
- In `Generate`, call `Run_For` with chunk target, not `Samples_Frame`.
- Keep looping until frame finished for video correctness, but enqueue audio in chunk granularity.
- Expected win: lower buffering/latency without architectural change.

## 3. Replace pointer-block queues with sample-level source ring (SPSC)
- Add `Source_Sample_Ring : Protected_Cursor_Ring (Float_Frame or Stereo_Sample)`.
- Producer writes generated samples directly into source ring.
- Remove `Free_Queue`, `Busy_Queue`, `Frame_Buffers`, `Dummy_Buffer` usage from hot path.
- Keep existing output ring feeding callback unchanged initially.

## 4. Move resampler input to source ring
- Resampling task reads from source ring, writes to output ring.
- Keep PI controller based on output ring fill-level.
- Keep same `Max_Delta`, gains, clamp logic first; tune later only if needed.

## 5. Simplify callback path
- Callback only drains output ring and writes silence on shortage.
- Ensure no producer logic in callback thread.
- Keep callback O(1)/lock-minimal behavior.

## 6. Tighten shutdown/lifecycle
- Ensure task stop signal + drain semantics (avoid `abort` if possible later).
- Confirm source/output rings and task exit cleanly with current `Shutdown`.

## 7. Remove obsolete structures
- Delete old block types/access/queues:
  - `Video_Frame_Sample_Buffer` pool plumbing in `Audio.IO`
  - `Free_Frame_Buffer_Access`, `Busy_Frame_Buffer_Access` from pipeline path
- Keep compatibility aliases temporarily if needed, then prune.

## 8. Tune for latency and stability
- Tune:
  - `Desired_Callback_Frames` (1024 -> 512 once stable)
  - source/output ring capacities
  - PI gains
- Acceptance targets:
  - no persistent underruns
  - no drift buildup
  - no audible pitch wobble
  - lower end-to-end latency than baseline.

## 9. Add regression tests/checks
- Deterministic unit checks for:
  - resampler produces non-zero output from non-zero input
  - ring never deadlocks under steady load
  - callback consumes when data available
- Add a soak run script with counters/assertions (underrun rate threshold).

## Recommended implementation order
- `Step 2` -> `Step 4` (with old queues still present) -> `Step 3` (remove queues) -> `Step 7` cleanup.
