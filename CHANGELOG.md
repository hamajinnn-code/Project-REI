# Changelog

## V1.0 rebuild - 2026-07-08

- Switched V1.0 arrow drawing from `ObjectCreate()` objects to indicator buffers.
- Added `BuyArrowBuffer` and `SellArrowBuffer` with `SetIndexBuffer()`.
- Cleared arrow buffers with `EMPTY_VALUE` before each signal check.
- Wrote buffer values only when `IsBuySignal(shift)` or `IsSellSignal(shift)` returns true.
- Rebuilt `M15_Alert_Indicator.mq4` as a simple V1.0 indicator.
- Recreated arrow drawing, historical scanning, and current alert logic.
- Unified all arrow decisions through `IsBuySignal(shift)` and `IsSellSignal(shift)`.
- Enforced fixed M15 EMA alignment checks: 20EMA / 75EMA / 200EMA.
- Added debug `Print()` output immediately before arrow drawing.
- Kept SL/TP, lot calculation, and automated trading out of V1.0.

## V1.0 - 2026-07-08

- Added `M15_Alert_Indicator.mq4`.
- Added H4 200EMA trend direction filter.
- Added M15 20EMA / 75EMA / 200EMA alignment filter.
- Added 75EMA touch-only signal logic.
- Added current-candle alert logic.
- Added confirmed-candle arrow drawing.
- Excluded SL/TP lines, lot calculation, and automated trading from V1.0.
