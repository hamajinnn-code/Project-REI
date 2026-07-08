#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 C'104,169,178'
#property indicator_color2 C'205,139,157'
#property indicator_width1 2
#property indicator_width2 2

//+------------------------------------------------------------------+
//| M15_Alert_Indicator                                               |
//| V1.0: H4 200EMA + M15 EMA alignment + 75EMA touch                 |
//| Drawing method: indicator buffers only                            |
//+------------------------------------------------------------------+

input int    HistoricalBars  = 500;
input bool   EnableAlert     = true;
input bool   EnablePopup     = true;
input bool   EnableArrow     = true;
input double ArrowOffsetPips = 3.0;
input color  BuyArrowColor   = C'104,169,178';
input color  SellArrowColor  = C'205,139,157';

double BuyArrowBuffer[];
double SellArrowBuffer[];

datetime g_lastBuyAlertBarTime = 0;
datetime g_lastSellAlertBarTime = 0;

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

bool HasEnoughBars(int shift)
{
   if(iBars(NULL, PERIOD_M15) <= shift + 205)
      return(false);

   if(iBars(NULL, PERIOD_H4) <= 205)
      return(false);

   return(true);
}

void DeleteLegacyArrowObjects()
{
   // V1.0 is buffer-only. Old object arrows can make it look like logic has not changed.
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, "M15_Alert_Indicator") >= 0 ||
         StringFind(name, "M15_ALERT_") >= 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Signal functions                                                   |
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
   if(!HasEnoughBars(shift)) return(false);
   if(!IsH4BuyTrend()) return(false);
   if(!IsM15BuyAlignment(shift)) return(false);
   if(!IsBuyTouch75EMA(shift)) return(false);
   return(true);
}

bool IsSellSignal(int shift)
{
   if(shift <= 0) return(false);
   if(!HasEnoughBars(shift)) return(false);
   if(!IsH4SellTrend()) return(false);
   if(!IsM15SellAlignment(shift)) return(false);
   if(!IsSellTouch75EMA(shift)) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Debug                                                             |
//+------------------------------------------------------------------+
void PrintBuyBufferDebug(int shift)
{
   double ema20  = GetM15EMA(20, shift);
   double ema75  = GetM15EMA(75, shift);
   double ema200 = GetM15EMA(200, shift);
   datetime barTime = iTime(NULL, PERIOD_M15, shift);

   Print("BUY buffer arrow",
         " shift=", shift,
         " Time[shift]=", TimeToString(barTime, TIME_DATE | TIME_MINUTES),
         " ema20=", DoubleToString(ema20, Digits),
         " ema75=", DoubleToString(ema75, Digits),
         " ema200=", DoubleToString(ema200, Digits),
         " IsH4BuyTrend()=", BoolText(IsH4BuyTrend()),
         " IsM15BuyAlignment(shift)=", BoolText(IsM15BuyAlignment(shift)),
         " IsBuyTouch75EMA(shift)=", BoolText(IsBuyTouch75EMA(shift)),
         " IsBuySignal(shift)=", BoolText(IsBuySignal(shift)),
         " BuyArrowBuffer[shift]=", DoubleToString(BuyArrowBuffer[shift], Digits));
}

void PrintSellBufferDebug(int shift)
{
   double ema20  = GetM15EMA(20, shift);
   double ema75  = GetM15EMA(75, shift);
   double ema200 = GetM15EMA(200, shift);
   datetime barTime = iTime(NULL, PERIOD_M15, shift);

   Print("SELL buffer arrow",
         " shift=", shift,
         " Time[shift]=", TimeToString(barTime, TIME_DATE | TIME_MINUTES),
         " ema20=", DoubleToString(ema20, Digits),
         " ema75=", DoubleToString(ema75, Digits),
         " ema200=", DoubleToString(ema200, Digits),
         " IsH4SellTrend()=", BoolText(IsH4SellTrend()),
         " IsM15SellAlignment(shift)=", BoolText(IsM15SellAlignment(shift)),
         " IsSellTouch75EMA(shift)=", BoolText(IsSellTouch75EMA(shift)),
         " IsSellSignal(shift)=", BoolText(IsSellSignal(shift)),
         " SellArrowBuffer[shift]=", DoubleToString(SellArrowBuffer[shift], Digits));
}

//+------------------------------------------------------------------+
//| Buffer drawing                                                     |
//+------------------------------------------------------------------+
void UpdateArrowBuffers(int rates_total)
{
   int maxShift = MathMin(HistoricalBars, rates_total - 1);
   maxShift = MathMin(maxShift, iBars(NULL, PERIOD_M15) - 205);

   if(maxShift < 1)
      return;

   double arrowOffset = ArrowOffsetPips * PipPoint();
   int start = maxShift;

   for(int i = start; i >= 1; i--)
   {
      BuyArrowBuffer[i] = EMPTY_VALUE;
      SellArrowBuffer[i] = EMPTY_VALUE;

      if(EnableArrow && IsBuySignal(i))
      {
         BuyArrowBuffer[i] = Low[i] - arrowOffset;
         PrintBuyBufferDebug(i);
      }
      else if(EnableArrow && IsSellSignal(i))
      {
         SellArrowBuffer[i] = High[i] + arrowOffset;
         PrintSellBufferDebug(i);
      }
   }

   // The current candle must never show an arrow in V1.0.
   BuyArrowBuffer[0] = EMPTY_VALUE;
   SellArrowBuffer[0] = EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Alert                                                             |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| MT4 events                                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorShortName("M15 Alert Indicator V1.0 buffer");

   SetIndexBuffer(0, BuyArrowBuffer);
   SetIndexBuffer(1, SellArrowBuffer);

   ArraySetAsSeries(BuyArrowBuffer, true);
   ArraySetAsSeries(SellArrowBuffer, true);

   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 2, BuyArrowColor);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 2, SellArrowColor);
   SetIndexArrow(0, 233);
   SetIndexArrow(1, 234);
   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexLabel(0, "BUY signal");
   SetIndexLabel(1, "SELL signal");

   Print("M15_Alert_Indicator V1.0 rebuild loaded");
   Comment("M15_Alert_Indicator V1.0 rebuild active");

   DeleteLegacyArrowObjects();

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
   Comment("M15_Alert_Indicator V1.0 rebuild active");

   UpdateArrowBuffers(rates_total);
   CheckCurrentAlert();

   return(rates_total);
}

void OnDeinit(const int reason)
{
   Comment("");
}
