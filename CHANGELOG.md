# Changelog

## Version 1.3 implementation - 2026-07-14

- Added optional M15 bullish engulfing filter
- Added optional M15 bearish engulfing filter
- Added MT4 reference SL based on confirmed ZigZag swing
- Added MT4 reference TP based on configurable risk/reward ratio
- Added FT-compatible internal swing detection
- Added FT-compatible SL/TP indicator buffers
- Preserved Version 1.2 revised entry logic
- Preserved FT incremental calculation
- No EA or automated trading functions added

## V1.3 FT compatibility revision - 2026-07-12

- Removed chart object based SL/TP drawing.
- Removed standard ZigZag iCustom dependency.
- Added internal swing high/low detection.
- Added SL/TP indicator buffers.
- Preserved engulfing filter.
- Preserved V1.2 entry logic.
- Preserved incremental calculation.

## V1.3 - 2026-07-12

- Added optional M15 bullish and bearish engulfing filters.
- Added confirmed ZigZag swing detection.
- Added reference SL line.
- Added reference TP line using default RR 1:2.
- Added protection against unconfirmed ZigZag points.
- Added latest-signal-only reference line management.
- No automated trading functions added.
- Existing V1.2 entry logic preserved.

## V1.2.3 - 2026-07-11

- Added signal-time price position check against H4 200EMA.
- Preserved confirmed H4 trend filter.
- Prevented BUY signals below H4 200EMA and SELL signals above H4 200EMA.
- No other logic changes.

## V1.2.2 - 2026-07-10

- Added incremental recalculation for Forex Tester.
- Added `ShowEMALines` option.
- Reduced repeated full historical scans.
- No logic changes.

## V1.2.1 revised - 2026-07-10

- Removed repeated `iMA()` calls from slope functions.
- Added `H4TrendCache` for the Forex Tester indicator.
- Reduced repeated `iBarShift()` calls by reusing the current H4 block.
- Optimized the FT indicator loop.
- No logic changes.

## V1.2.1 - 2026-07-10

- Performance optimization only.
- No logic changes.
- Reduced repeated EMA calculations in the Forex Tester indicator.
- Added H4 200EMA trend cache for repeated H4 bars.
- Reduced unnecessary H4 lookup work by using early continuation-style filtering.

## Forex Tester H4 filter - 2026-07-10

Forex Tester version:
- Added H4 200EMA trend filter to FT indicator
- Kept FT version separate from MT4 production indicator

## Forex Tester M15 V1.1 logic check - 2026-07-10

- Ported M15-only V1.1-style arrow logic into `M15_Alert_Indicator_FT.mq4`.
- Kept the three EMA display buffers for Forex Tester visibility checks.
- Added 20EMA / 75EMA slope checks.
- Added 20EMA or 75EMA touch checks with bullish / bearish candle confirmation.
- Added one-arrow-per-pullback / retracement suppression.
- Kept H4, London session, news, alerts, comments, and object drawing out of the FT version.

## Forex Tester display verification - 2026-07-10

Added Forex Tester display verification indicator:
- Created `M15_Alert_Indicator_FT.mq4`
- Added simple EMA display buffers
- Added temporary arrow logic for FT visibility check
- Removed alerts and unsupported functions for FT compatibility

## Repository structure reorganized - 2026-07-10

- Moved M15_Alert_Indicator into dedicated indicator folder.
- Added experts directory for future EA development.
- Added include directory for shared logic.
- Added backtest directory.
- Added documentation subdirectories.
- Added tools and images directories.
- Preserved existing releases.

## Repository renamed - 2026-07-10

- Repository renamed from `EA_challenge` to `Project-REI`.
- README project name updated to Project REI.
- Existing Git history, branches, README, CHANGELOG, and issues are intended to be preserved through the GitHub repository rename flow.

## V1.2 revised - 2026-07-09

- Entry signal quality improved.
- London session filter refined.
- Tokyo range filter removed from core conditions.
- H4 reversal pattern filter removed from core conditions.
- Branch strategy introduced for future SL/TP/EA development.
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
## V1.3 performance revision

- Added incremental MT4 calculation
- Removed repeated full historical scans on every tick
- Moved reference SL/TP calculation outside the historical signal loop
- Added latest-signal-only ZigZag calculation
- Prevented repeated reference object recreation
- Disabled signal debug logs by default
- Preserved all V1.3 trading logic
## V1.3 EMA touch revision

- Changed pullback touch condition from 20EMA or 75EMA to 75EMA only.
- Excluded shallow 20EMA rebounds from BUY and SELL signal candidates.
- Applied the same 75EMA-only touch rule to current-candle alerts.
- Preserved EMA alignment, EMA slope, engulfing filter, London/news filters, reference SL/TP, ZigZag, RR 1:2, arrow drawing, and performance optimization logic.
