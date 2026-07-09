# EA_challenge

MT4 / MQL4 indicator project for testing a simple H4 trend and M15 pullback alert system.

## Indicator

- Name: `M15_Alert_Indicator`
- File: `indicators/M15_Alert_Indicator.mq4`
- Platform: MetaTrader 4
- Main timeframe: M15
- Higher timeframe: H4
- Current version: V1.2 revised

## V1.2 Revised Scope

V1.2 revised keeps the V1.1 entry logic and uses only lightweight session/news filters. It still only displays arrows and alerts. It does not add SL/TP lines, lot calculation, or EA execution.

BUY conditions:

- H4 confirmed close is above H4 200EMA.
- M15 EMA alignment is `20EMA > 75EMA > 200EMA`.
- M15 20EMA and 75EMA are both rising.
- Price touches 20EMA or 75EMA.
- The confirmed M15 candle is bullish.
- Only one BUY arrow is shown for the same pullback until price clearly returns above 20EMA.

SELL conditions:

- H4 confirmed close is below H4 200EMA.
- M15 EMA alignment is `20EMA < 75EMA < 200EMA`.
- M15 20EMA and 75EMA are both falling.
- Price touches 20EMA or 75EMA.
- The confirmed M15 candle is bearish.
- Only one SELL arrow is shown for the same pullback until price clearly returns below 20EMA.

Active V1.2 revised filters:

- London session filter. It can be judged by converted JST time or by broker server time.
- Summer/winter London session presets for JST mode.
- Manual news avoid filter using `NewsTimes`. This is optional and defaults to OFF.

Removed from core signal conditions:

- Tokyo range filter.
- H4 reversal candle filter.

## Backtest Scan

- `HistoricalBars` default is `5000`.
- Actual scan depth is limited to `Bars - 300`.
- Internal safety cap is `20000` bars.
- The indicator scans old candles to new candles so pullback state is handled correctly.
- Chart `Comment()` displays `HistoricalBars`, scanned bars, BUY arrows, and SELL arrows.

## Folder Structure

```text
EA_challenge/
|- README.md
|- CHANGELOG.md
|- .gitignore
|- docs/
|- indicators/
|  `- M15_Alert_Indicator.mq4
`- releases/
   |- V1.0/
   |- V1.1/
   `- V1.2/
```

## Future Plan

After arrows and alerts are stable, the next phase can add SL/TP planning, risk logic, presets, and EA migration.
