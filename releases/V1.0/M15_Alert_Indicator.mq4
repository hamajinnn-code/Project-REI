#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| M15_Alert_Indicator                                               |
//|                                                                  |
//| V1.0: H4 200EMA trend + M15 EMA alignment + 75EMA touch alert     |
//| Platform: MetaTrader 4 / MQL4 build 1470                          |
//|                                                                  |
//| V1.0ではSL/TP、ロット計算、自動売買は実装しない。                  |
//| 後からEAへ移植しやすいように、判定ロジックは関数化している。        |
//+------------------------------------------------------------------+

input int    H4_EMA_Period         = 200;
input int    M15_Fast_EMA_Period   = 20;
input int    M15_Middle_EMA_Period = 75;
input int    M15_Slow_EMA_Period   = 200;
input int    HistoricalBars        = 500;
input bool   EnableAlert           = true;
input bool   EnablePopup           = true;
input bool   EnableArrow           = true;
input double ArrowOffsetPips       = 3.0;
input color  BuyArrowColor         = C'104,169,178';
input color  SellArrowColor        = C'205,139,157';

string   g_prefix;
datetime g_lastAlertBuyBarTime  = 0;
datetime g_lastAlertSellBarTime = 0;
datetime g_lastConfirmedBarTime = 0;

//+------------------------------------------------------------------+
//| Utility functions                                                  |
//+------------------------------------------------------------------+
double PipPoint()
{
   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
}

string BoolToText(bool value)
{
   if(value)
      return("true");

   return("false");
}

string TimeframeToString(int timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
   }

   return(IntegerToString(timeframe));
}

string MakeTimeKey(datetime barTime)
{
   string key = TimeToString(barTime, TIME_DATE | TIME_MINUTES);
   StringReplace(key, ".", "");
   StringReplace(key, ":", "");
   StringReplace(key, " ", "_");
   return(key);
}

string ArrowObjectName(string direction, int shift)
{
   datetime barTime = iTime(NULL, PERIOD_M15, shift);
   return(g_prefix + "_" + direction + "_ARROW_" + MakeTimeKey(barTime));
}

bool HasEnoughBars(int shift)
{
   int m15Bars = iBars(NULL, PERIOD_M15);
   int h4Bars = iBars(NULL, PERIOD_H4);

   // 今回のV1.0判定は固定でH4 200EMA、M15 20/75/200EMAを見る。
   if(m15Bars <= shift + 200 + 5)
      return(false);

   if(h4Bars <= 200 + 5)
      return(false);

   return(true);
}

void DeleteAllIndicatorArrows()
{
   // 条件修正前に作られた古い矢印が残ると誤認するため、起動時に自分の矢印だけ整理する。
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, g_prefix + "_") == 0 && StringFind(name, "_ARROW_") >= 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| H4 trend functions                                                 |
//+------------------------------------------------------------------+
bool IsH4TrendBuy()
{
   // H4は直近確定足だけを見る。未確定のH4足は使わない。
   double h4Close = iClose(NULL, PERIOD_H4, 1);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

   return(h4Close > h4Ema200);
}

bool IsH4TrendSell()
{
   // H4は直近確定足だけを見る。未確定のH4足は使わない。
   double h4Close = iClose(NULL, PERIOD_H4, 1);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

   return(h4Close < h4Ema200);
}

//+------------------------------------------------------------------+
//| M15 EMA alignment functions                                        |
//+------------------------------------------------------------------+
bool IsM15EMABuyAlignment(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   // EMA配列の誤検知を防ぐため、V1.0では指定どおり固定の20/75/200EMAを直接取得する。
   double ema20  = iMA(NULL, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema75  = iMA(NULL, PERIOD_M15, 75, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema200 = iMA(NULL, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, shift);

   return(ema20 > ema75 && ema75 > ema200);
}

bool IsM15EMASellAlignment(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   // EMA配列の誤検知を防ぐため、V1.0では指定どおり固定の20/75/200EMAを直接取得する。
   double ema20  = iMA(NULL, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema75  = iMA(NULL, PERIOD_M15, 75, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema200 = iMA(NULL, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, shift);

   return(ema20 < ema75 && ema75 < ema200);
}

//+------------------------------------------------------------------+
//| 75EMA touch functions                                              |
//+------------------------------------------------------------------+
bool IsBuyTouch75EMA(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   double ema75 = iMA(NULL, PERIOD_M15, 75, 0, MODE_EMA, PRICE_CLOSE, shift);
   double lowPrice = iLow(NULL, PERIOD_M15, shift);
   double closePrice = iClose(NULL, PERIOD_M15, shift);

   // shift=0のアラート判定では、現在価格を終値相当として扱う。
   if(shift == 0)
      closePrice = Bid;

   return(lowPrice <= ema75 && closePrice >= ema75);
}

bool IsSellTouch75EMA(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   double ema75 = iMA(NULL, PERIOD_M15, 75, 0, MODE_EMA, PRICE_CLOSE, shift);
   double highPrice = iHigh(NULL, PERIOD_M15, shift);
   double closePrice = iClose(NULL, PERIOD_M15, shift);

   // shift=0のアラート判定では、現在価格を終値相当として扱う。
   if(shift == 0)
      closePrice = Bid;

   return(highPrice >= ema75 && closePrice <= ema75);
}

//+------------------------------------------------------------------+
//| Signal functions                                                   |
//+------------------------------------------------------------------+
bool IsBuySignal(int shift)
{
   // BUY矢印・BUYアラートは必ずこの関数の結果だけで判断する。
   return(IsH4TrendBuy()
          && IsM15EMABuyAlignment(shift)
          && IsBuyTouch75EMA(shift));
}

bool IsSellSignal(int shift)
{
   // SELL矢印・SELLアラートは必ずこの関数の結果だけで判断する。
   return(IsH4TrendSell()
          && IsM15EMASellAlignment(shift)
          && IsSellTouch75EMA(shift));
}

//+------------------------------------------------------------------+
//| Debug functions                                                    |
//+------------------------------------------------------------------+
void PrintBuyArrowDebug(int shift)
{
   double ema20  = iMA(NULL, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema75  = iMA(NULL, PERIOD_M15, 75, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema200 = iMA(NULL, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, shift);
   datetime barTime = iTime(NULL, PERIOD_M15, shift);

   Print("BUY arrow check",
         " shift=", shift,
         " Time[shift]=", TimeToString(barTime, TIME_DATE | TIME_MINUTES),
         " ema20=", DoubleToString(ema20, Digits),
         " ema75=", DoubleToString(ema75, Digits),
         " ema200=", DoubleToString(ema200, Digits),
         " ema20>ema75=", BoolToText(ema20 > ema75),
         " ema75>ema200=", BoolToText(ema75 > ema200),
         " IsM15EMABuyAlignment(shift)=", BoolToText(IsM15EMABuyAlignment(shift)),
         " IsBuySignal(shift)=", BoolToText(IsBuySignal(shift)));
}

void PrintSellArrowDebug(int shift)
{
   double ema20  = iMA(NULL, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema75  = iMA(NULL, PERIOD_M15, 75, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema200 = iMA(NULL, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, shift);
   datetime barTime = iTime(NULL, PERIOD_M15, shift);

   Print("SELL arrow check",
         " shift=", shift,
         " Time[shift]=", TimeToString(barTime, TIME_DATE | TIME_MINUTES),
         " ema20=", DoubleToString(ema20, Digits),
         " ema75=", DoubleToString(ema75, Digits),
         " ema200=", DoubleToString(ema200, Digits),
         " ema20<ema75=", BoolToText(ema20 < ema75),
         " ema75<ema200=", BoolToText(ema75 < ema200),
         " IsM15EMASellAlignment(shift)=", BoolToText(IsM15EMASellAlignment(shift)),
         " IsSellSignal(shift)=", BoolToText(IsSellSignal(shift)));
}

//+------------------------------------------------------------------+
//| Drawing functions                                                  |
//+------------------------------------------------------------------+
void DrawBuyArrow(int shift)
{
   // 矢印は確定足だけ。未確定足shift=0には絶対に出さない。
   if(!EnableArrow || shift <= 0)
      return;

   // 矢印直前の最終ガード。EMA配列がfalseならBUY矢印は絶対に出さない。
   if(!IsM15EMABuyAlignment(shift) || !IsBuySignal(shift))
   {
      PrintBuyArrowDebug(shift);
      return;
   }

   string name = ArrowObjectName("BUY", shift);

   if(ObjectFind(0, name) >= 0)
      return;

   PrintBuyArrowDebug(shift);

   datetime barTime = iTime(NULL, PERIOD_M15, shift);
   double arrowPrice = iLow(NULL, PERIOD_M15, shift) - ArrowOffsetPips * PipPoint();

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, arrowPrice);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233);
   ObjectSetInteger(0, name, OBJPROP_COLOR, BuyArrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "BUY " + Symbol() + " M15 75EMA touch");
}

void DrawSellArrow(int shift)
{
   // 矢印は確定足だけ。未確定足shift=0には絶対に出さない。
   if(!EnableArrow || shift <= 0)
      return;

   // 矢印直前の最終ガード。EMA配列がfalseならSELL矢印は絶対に出さない。
   if(!IsM15EMASellAlignment(shift) || !IsSellSignal(shift))
   {
      PrintSellArrowDebug(shift);
      return;
   }

   string name = ArrowObjectName("SELL", shift);

   if(ObjectFind(0, name) >= 0)
      return;

   PrintSellArrowDebug(shift);

   datetime barTime = iTime(NULL, PERIOD_M15, shift);
   double arrowPrice = iHigh(NULL, PERIOD_M15, shift) + ArrowOffsetPips * PipPoint();

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, arrowPrice);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, SellArrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "SELL " + Symbol() + " M15 75EMA touch");
}

//+------------------------------------------------------------------+
//| Alert functions                                                    |
//+------------------------------------------------------------------+
void SendSignalAlert(string direction)
{
   string message = Symbol() + " " + TimeframeToString(PERIOD_M15)
                    + " " + direction
                    + " price=" + DoubleToString(Bid, Digits);

   if(EnableAlert)
      Alert(message);

   if(EnablePopup)
      MessageBox(message, "M15 Alert Indicator", MB_OK | MB_ICONINFORMATION);
}

void CheckCurrentAlert()
{
   if(!EnableAlert && !EnablePopup)
      return;

   datetime currentBarTime = iTime(NULL, PERIOD_M15, 0);

   if(currentBarTime <= 0)
      return;

   bool buySignal = IsBuySignal(0);
   bool sellSignal = false;

   // 同じ足でBUY/SELLが同時に出ないよう、BUY成立時はSELLを判定しない。
   if(!buySignal)
      sellSignal = IsSellSignal(0);

   if(buySignal && g_lastAlertBuyBarTime != currentBarTime)
   {
      g_lastAlertBuyBarTime = currentBarTime;
      SendSignalAlert("BUY");
      return;
   }

   if(sellSignal && g_lastAlertSellBarTime != currentBarTime)
   {
      g_lastAlertSellBarTime = currentBarTime;
      SendSignalAlert("SELL");
   }
}

//+------------------------------------------------------------------+
//| Confirmed candle and historical scan                               |
//+------------------------------------------------------------------+
void CheckConfirmedSignal()
{
   datetime confirmedBarTime = iTime(NULL, PERIOD_M15, 1);

   if(confirmedBarTime <= 0 || confirmedBarTime == g_lastConfirmedBarTime)
      return;

   g_lastConfirmedBarTime = confirmedBarTime;

   // 確定足shift=1だけを新規シグナルとして確認する。
   if(IsBuySignal(1))
   {
      DrawBuyArrow(1);
      return;
   }

   if(IsSellSignal(1))
      DrawSellArrow(1);
}

void ScanHistoricalBars()
{
   int bars = iBars(NULL, PERIOD_M15);
   int lastShift = MathMin(HistoricalBars, bars - 200 - 5);

   if(lastShift < 1)
      return;

   // 過去足も確定足のみ。shift=0は対象外。矢印条件はIsBuySignal/IsSellSignalに統一する。
   for(int shift = lastShift; shift >= 1; shift--)
   {
      if(IsBuySignal(shift))
      {
         DrawBuyArrow(shift);
         continue;
      }

      if(IsSellSignal(shift))
         DrawSellArrow(shift);
   }
}

//+------------------------------------------------------------------+
//| MT4 event functions                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   g_prefix = "M15_ALERT_" + Symbol() + "_" + TimeframeToString(PERIOD_M15);

   IndicatorShortName("M15 Alert Indicator V1.0");

   DeleteAllIndicatorArrows();
   ScanHistoricalBars();

   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   CheckCurrentAlert();
   CheckConfirmedSignal();

   if(prev_calculated == 0)
      ScanHistoricalBars();

   return(rates_total);
}

void OnDeinit(const int reason)
{
   // V1.0では描画済み矢印を履歴確認用に残す。
}
