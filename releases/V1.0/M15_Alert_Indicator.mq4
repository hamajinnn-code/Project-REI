#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| M15_Alert_Indicator                                               |
//| V1.0: H4 200EMA + M15 EMA alignment + 75EMA touch                 |
//| Platform: MetaTrader 4 / MQL4 build 1470                          |
//+------------------------------------------------------------------+

input int    HistoricalBars  = 500;
input bool   EnableAlert     = true;
input bool   EnablePopup     = true;
input bool   EnableArrow     = true;
input double ArrowOffsetPips = 3.0;
input color  BuyArrowColor   = C'104,169,178';
input color  SellArrowColor  = C'205,139,157';

string   g_objectPrefix = "";
datetime g_lastBuyAlertBarTime = 0;
datetime g_lastSellAlertBarTime = 0;
datetime g_lastCheckedClosedBarTime = 0;

//+------------------------------------------------------------------+
//| Utility                                                           |
//+------------------------------------------------------------------+
double PipPoint()
{
   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
}

string BoolText(bool value)
{
   if(value)
      return("true");

   return("false");
}

string TimeKey(datetime barTime)
{
   string key = TimeToString(barTime, TIME_DATE | TIME_MINUTES);
   StringReplace(key, ".", "");
   StringReplace(key, ":", "");
   StringReplace(key, " ", "_");
   return(key);
}

string ArrowName(string side, int shift)
{
   datetime barTime = iTime(NULL, PERIOD_M15, shift);
   return(g_objectPrefix + "_" + side + "_" + TimeKey(barTime));
}

bool HasEnoughBars(int shift)
{
   if(iBars(NULL, PERIOD_M15) <= shift + 205)
      return(false);

   if(iBars(NULL, PERIOD_H4) <= 205)
      return(false);

   return(true);
}

void DeleteIndicatorArrows()
{
   // 古い判定で出た矢印が残ると確認を誤るため、このインジケーターの矢印だけ削除して再描画する。
   string legacyPrefix = "M15_ALERT_" + Symbol() + "_M15";

   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, g_objectPrefix + "_BUY_") == 0 ||
         StringFind(name, g_objectPrefix + "_SELL_") == 0 ||
         StringFind(name, legacyPrefix + "_BUY_") == 0 ||
         StringFind(name, legacyPrefix + "_SELL_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Required signal functions                                         |
//+------------------------------------------------------------------+
double GetM15EMA(int period, int shift)
{
   return iMA(NULL, PERIOD_M15, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

bool IsH4BuyTrend()
{
   double h4Close = iClose(NULL, PERIOD_H4, 1);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

   return(h4Close > h4Ema200);
}

bool IsH4SellTrend()
{
   double h4Close = iClose(NULL, PERIOD_H4, 1);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

   return(h4Close < h4Ema200);
}

bool IsM15BuyAlignment(int shift)
{
   double ema20  = GetM15EMA(20, shift);
   double ema75  = GetM15EMA(75, shift);
   double ema200 = GetM15EMA(200, shift);

   return(ema20 > ema75 && ema75 > ema200);
}

bool IsM15SellAlignment(int shift)
{
   double ema20  = GetM15EMA(20, shift);
   double ema75  = GetM15EMA(75, shift);
   double ema200 = GetM15EMA(200, shift);

   return(ema20 < ema75 && ema75 < ema200);
}

bool IsBuyTouch75EMA(int shift)
{
   double ema75 = GetM15EMA(75, shift);
   double lowPrice = iLow(NULL, PERIOD_M15, shift);
   double closePrice = iClose(NULL, PERIOD_M15, shift);

   return(lowPrice <= ema75 && closePrice >= ema75);
}

bool IsSellTouch75EMA(int shift)
{
   double ema75 = GetM15EMA(75, shift);
   double highPrice = iHigh(NULL, PERIOD_M15, shift);
   double closePrice = iClose(NULL, PERIOD_M15, shift);

   return(highPrice >= ema75 && closePrice <= ema75);
}

bool IsBuySignal(int shift)
{
   if(shift <= 0) return(false);
   if(!IsH4BuyTrend()) return(false);
   if(!IsM15BuyAlignment(shift)) return(false);
   if(!IsBuyTouch75EMA(shift)) return(false);
   return(true);
}

bool IsSellSignal(int shift)
{
   if(shift <= 0) return(false);
   if(!IsH4SellTrend()) return(false);
   if(!IsM15SellAlignment(shift)) return(false);
   if(!IsSellTouch75EMA(shift)) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Debug                                                            |
//+------------------------------------------------------------------+
void PrintSignalDebug(string side, int shift)
{
   double ema20  = GetM15EMA(20, shift);
   double ema75  = GetM15EMA(75, shift);
   double ema200 = GetM15EMA(200, shift);
   datetime barTime = iTime(NULL, PERIOD_M15, shift);

   bool h4Trend = false;
   bool alignment = false;
   bool touch = false;
   bool signal = false;

   if(side == "BUY")
   {
      h4Trend = IsH4BuyTrend();
      alignment = IsM15BuyAlignment(shift);
      touch = IsBuyTouch75EMA(shift);
      signal = IsBuySignal(shift);
   }
   else
   {
      h4Trend = IsH4SellTrend();
      alignment = IsM15SellAlignment(shift);
      touch = IsSellTouch75EMA(shift);
      signal = IsSellSignal(shift);
   }

   Print(side,
         " shift=", shift,
         " Time[shift]=", TimeToString(barTime, TIME_DATE | TIME_MINUTES),
         " ema20=", DoubleToString(ema20, Digits),
         " ema75=", DoubleToString(ema75, Digits),
         " ema200=", DoubleToString(ema200, Digits),
         " H4 trend=", BoolText(h4Trend),
         " M15 alignment=", BoolText(alignment),
         " 75EMA touch=", BoolText(touch),
         " signal=", BoolText(signal));
}

//+------------------------------------------------------------------+
//| Drawing                                                           |
//+------------------------------------------------------------------+
void DrawBuyArrow(int shift)
{
   // 矢印表示はIsBuySignalの結果だけで行う。75EMAタッチ単体では絶対に描画しない。
   if(!EnableArrow)
      return;

   if(!IsBuySignal(shift))
      return;

   string name = ArrowName("BUY", shift);

   if(ObjectFind(0, name) >= 0)
      return;

   PrintSignalDebug("BUY", shift);

   datetime barTime = iTime(NULL, PERIOD_M15, shift);
   double price = iLow(NULL, PERIOD_M15, shift) - ArrowOffsetPips * PipPoint();

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233);
   ObjectSetInteger(0, name, OBJPROP_COLOR, BuyArrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "BUY M15 EMA alignment + 75EMA touch");
}

void DrawSellArrow(int shift)
{
   // 矢印表示はIsSellSignalの結果だけで行う。75EMAタッチ単体では絶対に描画しない。
   if(!EnableArrow)
      return;

   if(!IsSellSignal(shift))
      return;

   string name = ArrowName("SELL", shift);

   if(ObjectFind(0, name) >= 0)
      return;

   PrintSignalDebug("SELL", shift);

   datetime barTime = iTime(NULL, PERIOD_M15, shift);
   double price = iHigh(NULL, PERIOD_M15, shift) + ArrowOffsetPips * PipPoint();

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, SellArrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "SELL M15 EMA alignment + 75EMA touch");
}

//+------------------------------------------------------------------+
//| Scan and alert                                                     |
//+------------------------------------------------------------------+
void ScanHistoricalBars()
{
   int bars = iBars(NULL, PERIOD_M15);
   int lastShift = MathMin(HistoricalBars, bars - 205);

   if(lastShift < 1)
      return;

   for(int shift = lastShift; shift >= 1; shift--)
   {
      // 過去スキャンもリアルタイム確定足も同じIsBuySignal/IsSellSignalだけを使う。
      if(IsBuySignal(shift))
      {
         DrawBuyArrow(shift);
         continue;
      }

      if(IsSellSignal(shift))
         DrawSellArrow(shift);
   }
}

void CheckCurrentAlert()
{
   if(!EnableAlert && !EnablePopup)
      return;

   datetime currentBarTime = iTime(NULL, PERIOD_M15, 0);

   if(currentBarTime <= 0)
      return;

   double ema75 = GetM15EMA(75, 0);
   double lowPrice = iLow(NULL, PERIOD_M15, 0);
   double highPrice = iHigh(NULL, PERIOD_M15, 0);
   double currentPrice = Bid;

   // アラートだけは未確定足を監視する。矢印はIsBuySignal/IsSellSignalによりshift=0では出ない。
   bool buyAlert = IsH4BuyTrend()
                   && IsM15BuyAlignment(0)
                   && lowPrice <= ema75
                   && currentPrice >= ema75;

   bool sellAlert = IsH4SellTrend()
                    && IsM15SellAlignment(0)
                    && highPrice >= ema75
                    && currentPrice <= ema75;

   if(buyAlert && g_lastBuyAlertBarTime != currentBarTime)
   {
      g_lastBuyAlertBarTime = currentBarTime;
      string buyMessage = Symbol() + " M15 BUY 75EMA touch price=" + DoubleToString(currentPrice, Digits);

      if(EnableAlert)
         Alert(buyMessage);

      if(EnablePopup)
         MessageBox(buyMessage, "M15 Alert Indicator", MB_OK | MB_ICONINFORMATION);

      return;
   }

   if(sellAlert && g_lastSellAlertBarTime != currentBarTime)
   {
      g_lastSellAlertBarTime = currentBarTime;
      string sellMessage = Symbol() + " M15 SELL 75EMA touch price=" + DoubleToString(currentPrice, Digits);

      if(EnableAlert)
         Alert(sellMessage);

      if(EnablePopup)
         MessageBox(sellMessage, "M15 Alert Indicator", MB_OK | MB_ICONINFORMATION);
   }
}

void CheckClosedBar()
{
   datetime closedBarTime = iTime(NULL, PERIOD_M15, 1);

   if(closedBarTime <= 0 || closedBarTime == g_lastCheckedClosedBarTime)
      return;

   g_lastCheckedClosedBarTime = closedBarTime;

   if(IsBuySignal(1))
   {
      DrawBuyArrow(1);
      return;
   }

   if(IsSellSignal(1))
      DrawSellArrow(1);
}

//+------------------------------------------------------------------+
//| MT4 events                                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   g_objectPrefix = "M15_ALERT_V10_" + Symbol();

   IndicatorShortName("M15 Alert Indicator V1.0");

   DeleteIndicatorArrows();
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
   CheckClosedBar();

   return(rates_total);
}

void OnDeinit(const int reason)
{
}
