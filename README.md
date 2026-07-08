# EA_challenge

MT4 / MQL4向けのインジケーター開発リポジトリです。

V1.0では、H4 200EMA方向、M15 EMA配列、M15 75EMAタッチを条件に、未確定足でアラート、確定足で矢印を表示するシンプルなインジケーターを作成します。

## Indicator

- Name: `M15_Alert_Indicator`
- File: `indicators/M15_Alert_Indicator.mq4`
- Platform: MetaTrader 4
- Main timeframe: M15
- Higher timeframe: H4

## V1.0 Scope

- H4 200EMA方向判定
- M15 EMA配列判定
- 75EMAタッチ判定
- 未確定足でアラート
- 確定足で矢印表示
- 同じ足への重複アラート・重複矢印を防止

V1.0では、SL/TPライン、ロット計算、自動売買、EA化、RSI、ATR、時間帯フィルター、ローソク足パターン、ブレイク条件は実装しません。

## Folder Structure

```text
EA_challenge/
├─ README.md
├─ CHANGELOG.md
├─ .gitignore
├─ docs/
├─ indicators/
│  └─ M15_Alert_Indicator.mq4
└─ releases/
   └─ V1.0/
```

## Signal Rules

BUY:

- H4の直近確定足終値がH4 200EMAより上
- M15で 20EMA > 75EMA > 200EMA
- M15のLow <= 75EMA
- M15のCloseまたは現在価格 >= 75EMA

SELL:

- H4の直近確定足終値がH4 200EMAより下
- M15で 20EMA < 75EMA < 200EMA
- M15のHigh >= 75EMA
- M15のCloseまたは現在価格 <= 75EMA

## Future Plan

V1.0で矢印とアラートを安定させたあと、EA化に向けてエントリー管理、SL/TP、ロット計算、検証用プリセットを追加していきます。
