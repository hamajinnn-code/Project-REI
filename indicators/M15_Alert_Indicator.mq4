#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| M15_Alert_Indicator                                               |
//|                                                                  |
//| V1.0: H4 200EMA trend + M15 EMA alignment + 75EMA touch alert     |
//| Platform: MetaTrader 4 / MQL4                                     |
//|                                                                  |
//| V1.0ではSL/TP、ロット計算、自動売買は実装しない。                 |
//| 後からEAへ移植しやすいように、判定ロジックは関数化している。       |
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
   datetime barTime = iTime(Symbol(), PERIOD_M15, shift);
   return(g_prefix + "_" + direction + "_ARROW_" + MakeTimeKey(barTime));
}

double GetM15EMA(int period, int shift)
{
   return(iMA(Symbol(), PERIOD_M15, period, 0, MODE_EMA, PRICE_CLOSE, shift));
}

bool HasEnoughBars(int shift)
{
   int m15Bars = iBars(Symbol(), PERIOD_M15);
   int h4Bars = iBars(Symbol(), PERIOD_H4);

   if(m15Bars <= shift + M15_Slow_EMA_Period + 5)
      return(false);

   if(h4Bars <= H4_EMA_Period + 5)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| H4 trend functions                                                 |
//+------------------------------------------------------------------+
bool IsH4TrendBuy()
{
   // H4の直近確定足だけを使い、未確定のH4足では判定しない。
   double h4Close = iClose(Symbol(), PERIOD_H4, 1);
   double h4EMA   = iMA(Symbol(), PERIOD_H4, H4_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);

   return(h4Close > h4EMA);
}

bool IsH4TrendSell()
{
   // H4の直近確定足だけを使い、未確定のH4足では判定しない。
   double h4Close = iClose(Symbol(), PERIOD_H4, 1);
   double h4EMA   = iMA(Symbol(), PERIOD_H4, H4_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);

   return(h4Close < h4EMA);
}

//+------------------------------------------------------------------+
//| M15 EMA alignment functions                                        |
//+------------------------------------------------------------------+
bool IsM15EMABuyAlignment(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   double fastEMA   = GetM15EMA(M15_Fast_EMA_Period, shift);
   double middleEMA = GetM15EMA(M15_Middle_EMA_Period, shift);
   double slowEMA   = GetM15EMA(M15_Slow_EMA_Period, shift);

   return(fastEMA > middleEMA && middleEMA > slowEMA);
}

bool IsM15EMASellAlignment(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   double fastEMA   = GetM15EMA(M15_Fast_EMA_Period, shift);
   double middleEMA = GetM15EMA(M15_Middle_EMA_Period, shift);
   double slowEMA   = GetM15EMA(M15_Slow_EMA_Period, shift);

   return(fastEMA < middleEMA && middleEMA < slowEMA);
}

//+------------------------------------------------------------------+
//| 75EMA touch functions                                              |
//+------------------------------------------------------------------+
bool IsBuyTouch75EMA(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   double ema75 = GetM15EMA(M15_Middle_EMA_Period, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M15, shift);
   double closePrice = iClose(Symbol(), PERIOD_M15, shift);

   // shift=0のアラート判定では、現在価格を終値相当として扱う。
   if(shift == 0)
      closePrice = Bid;

   return(lowPrice <= ema75 && closePrice >= ema75);
}

bool IsSellTouch75EMA(int shift)
{
   if(!HasEnoughBars(shift))
      return(false);

   double ema75 = GetM15EMA(M15_Middle_EMA_Period, shift);
   double highPrice = iHigh(Symbol(), PERIOD_M15, shift);
   double closePrice = iClose(Symbol(), PERIOD_M15, shift);

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
   return(IsH4TrendBuy()
          && IsM15EMABuyAlignment(shift)
          && IsBuyTouch75EMA(shift));
}

bool IsSellSignal(int shift)
{
   return(IsH4TrendSell()
          && IsM15EMASellAlignment(shift)
          && IsSellTouch75EMA(shift));
}

//+------------------------------------------------------------------+
//| Drawing functions                                                  |
//+------------------------------------------------------------------+
void DrawBuyArrow(int shift)
{
   // 矢印は確定足だけ。未確定足shift=0には絶対に出さない。
   if(!EnableArrow || shift <= 0)
      return;

   string name = ArrowObjectName("BUY", shift);

   if(ObjectFind(0, name) >= 0)
      return;

   datetime barTime = iTime(Symbol(), PERIOD_M15, shift);
   double arrowPrice = iLow(Symbol(), PERIOD_M15, shift) - ArrowOffsetPips * PipPoint();

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

   string name = ArrowObjectName("SELL", shift);

   if(ObjectFind(0, name) >= 0)
      return;

   datetime barTime = iTime(Symbol(), PERIOD_M15, shift);
   double arrowPrice = iHigh(Symbol(), PERIOD_M15, shift) + ArrowOffsetPips * PipPoint();

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

   datetime currentBarTime = iTime(Symbol(), PERIOD_M15, 0);

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
   datetime confirmedBarTime = iTime(Symbol(), PERIOD_M15, 1);

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
   int bars = iBars(Symbol(), PERIOD_M15);
   int lastShift = MathMin(HistoricalBars, bars - M15_Slow_EMA_Period - 5);

   if(lastShift < 1)
      return;

   // 過去足も確定足のみ。shift=0は対象外。
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
