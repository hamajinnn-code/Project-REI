# Changelog

## V1.2 revised - 2026-07-09

- Removed the Tokyo range filter from core BUY/SELL signal conditions.
- Removed the H4 reversal candlestick filter from core BUY/SELL signal conditions.
- Updated the London session filter to support JST-based judgment.
- Added summer/winter London session input settings.
- Kept the manual news avoid filter as an optional filter with default OFF.
- Updated chart `Comment()` output for the revised V1.2 filter set.

## V1.2 - 2026-07-09

- Added London session filter.
- Added manual news avoid filter.
- Added Tokyo range filter.
- Added H4 reversal candlestick filter.
- Added ON/OFF inputs for all V1.2 filters.
- Added H4 engulfing and pin bar reversal checks.
- Added V1.2 debug `Comment()` fields for filter status and current Tokyo range.
- Added `releases/V1.2/M15_Alert_Indicator.mq4`.

## V1.1 - 2026-07-09

- Added `SlopeLookback` input with default value `5`.
- Added M15 20EMA and 75EMA slope filters.
- Changed touch logic from 75EMA-only to 20EMA or 75EMA pullback touch.
- Added bullish confirmed candle requirement for BUY arrows.
- Added bearish confirmed candle requirement for SELL arrows.
- Changed duplicate prevention to one arrow per pullback/retracement.
- BUY suppression now resets only after price clearly closes and stays above 20EMA.
- SELL suppression now resets only after price clearly closes and stays below 20EMA.
- Updated current-candle alerts to use V1.1 pullback touch and slope conditions.
- Added `releases/V1.1/M15_Alert_Indicator.mq4`.

## V1.0 rebuild - 2026-07-08

- Increased default `HistoricalBars` to 5000 for deeper historical review.
- Limited actual scan depth to `Bars - 300` and an internal 20000-bar safety cap.
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
