# Changelog

## V1.0 rebuild - 2026-07-08

- Added full historical backtest scanning on every `OnCalculate()` run.
- Clears BUY/SELL arrow buffers before each historical scan.
- Scans from older candles to newer candles so only the first 75EMA touch after each EMA alignment is marked.
- Added chart `Comment()` output for `HistoricalBars`, scanned bars, BUY arrow count, and SELL arrow count.
- Changed indicator property colors to standard MT4 color constants for safer compilation.
- Replaced corrupted comment lines in the arrow-state logic so `if` statements remain executable code.
- Limited BUY/SELL arrows to the first 75EMA touch after each M15 EMA alignment trend starts.
- Added trend-state flags to prevent repeated arrows during the same EMA alignment.
- Reset BUY/SELL signal flags when the relevant M15 EMA alignment breaks.
- Applied the same one-signal-per-alignment rule to current-candle alerts.
- Added optional debug EMA lines for M15 20EMA, 75EMA, and 200EMA using the same EMA calculation as signal logic.
- Added `ShowDebugEMALines` input to turn the debug EMA lines on or off.
- Stopped processing when the chart timeframe is not M15.
- Added debug output for EMA alignment comparisons when arrows are written to buffers.
- Changed H4 trend filtering to use the confirmed H4 candle corresponding to each M15 candle.
- Replaced fixed current H4 `shift=1` checks with `IsH4BuyTrendForM15Shift()` and `IsH4SellTrendForM15Shift()`.
- Added debug output for H4 shift, confirmed H4 shift, H4 close, and H4 200EMA.
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
