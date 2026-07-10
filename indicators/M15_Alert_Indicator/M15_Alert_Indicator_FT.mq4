#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1 DodgerBlue
#property indicator_color2 Orange
#property indicator_color3 Silver
#property indicator_color4 Aqua
#property indicator_color5 Pink
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 1
#property indicator_width4 2
#property indicator_width5 2

input int HistoricalBars = 5000;
input int RecalculateBars = 300;
input int SlopeLookback = 5;
input bool ShowEMALines = false;

double Ema20Buffer[];
double Ema75Buffer[];
double Ema200Buffer[];
double BuyArrowBuffer[];
double SellArrowBuffer[];
int H4TrendCache[];

int CachedH4Shift = -1;
bool CachedH4BuyTrend = false;
bool CachedH4SellTrend = false;

int OnInit()
{
   IndicatorShortName("M15_Alert_Indicator_FT_H4_M15_Check");

   SetIndexBuffer(0, Ema20Buffer);
   if(ShowEMALines)
      SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 1, DodgerBlue);
   else
      SetIndexStyle(0, DRAW_NONE, STYLE_SOLID, 1, DodgerBlue);
   SetIndexLabel(0, "EMA 20");

   SetIndexBuffer(1, Ema75Buffer);
   if(ShowEMALines)
      SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 1, Orange);
   else
      SetIndexStyle(1, DRAW_NONE, STYLE_SOLID, 1, Orange);
   SetIndexLabel(1, "EMA 75");

   SetIndexBuffer(2, Ema200Buffer);
   if(ShowEMALines)
      SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 1, Silver);
   else
      SetIndexStyle(2, DRAW_NONE, STYLE_SOLID, 1, Silver);
   SetIndexLabel(2, "EMA 200");

   SetIndexBuffer(3, BuyArrowBuffer);
   SetIndexStyle(3, DRAW_ARROW, STYLE_SOLID, 2, Aqua);
   SetIndexArrow(3, 233);
   SetIndexEmptyValue(3, EMPTY_VALUE);
   SetIndexLabel(3, "BUY");

   SetIndexBuffer(4, SellArrowBuffer);
   SetIndexStyle(4, DRAW_ARROW, STYLE_SOLID, 2, Pink);
   SetIndexArrow(4, 234);
   SetIndexEmptyValue(4, EMPTY_VALUE);
   SetIndexLabel(4, "SELL");

   ArraySetAsSeries(Ema20Buffer, true);
   ArraySetAsSeries(Ema75Buffer, true);
   ArraySetAsSeries(Ema200Buffer, true);
   ArraySetAsSeries(BuyArrowBuffer, true);
   ArraySetAsSeries(SellArrowBuffer, true);

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
   int scanLimit;
   int lookback = MathMax(SlopeLookback, 1);
   int recalculateBars = MathMax(RecalculateBars, 1);
   if(prev_calculated == 0)
      scanLimit = MathMin(rates_total - 1, HistoricalBars);
   else
      scanLimit = MathMin(rates_total - 1, recalculateBars);

   int emaRecalcLimit = MathMin(rates_total - 1, scanLimit + lookback);
   int h4Bars = iBars(NULL, PERIOD_H4);
   bool buySignalAlreadyShown = false;
   bool sellSignalAlreadyShown = false;

   ArrayResize(H4TrendCache, rates_total);
   ArraySetAsSeries(H4TrendCache, true);

   CachedH4Shift = -1;
   CachedH4BuyTrend = false;
   CachedH4SellTrend = false;

   for(int e = emaRecalcLimit; e >= 0; e--)
   {
      Ema20Buffer[e] = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, e);
      Ema75Buffer[e] = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, e);
      Ema200Buffer[e] = iMA(NULL, 0, 200, 0, MODE_EMA, PRICE_CLOSE, e);
   }

   int sourceH4Shift = -1;
   datetime sourceH4OpenTime = 0;
   datetime nextH4OpenTime = 0;

   for(int h = scanLimit; h >= 1; h--)
   {
      datetime m15Time = iTime(NULL, 0, h);

      if(sourceH4Shift < 0 ||
         m15Time < sourceH4OpenTime ||
         (nextH4OpenTime > 0 && m15Time >= nextH4OpenTime))
      {
         sourceH4Shift = iBarShift(NULL, PERIOD_H4, m15Time, false);

         if(sourceH4Shift >= 0)
         {
            sourceH4OpenTime = iTime(NULL, PERIOD_H4, sourceH4Shift);
            if(sourceH4Shift > 0)
               nextH4OpenTime = iTime(NULL, PERIOD_H4, sourceH4Shift - 1);
            else
               nextH4OpenTime = 0;
         }
         else
         {
            sourceH4OpenTime = 0;
            nextH4OpenTime = 0;
         }
      }

      if(sourceH4Shift < 0)
         H4TrendCache[h] = 0;
      else
         H4TrendCache[h] = GetCachedH4Trend(sourceH4Shift + 1, h4Bars);
   }

   for(int i = scanLimit; i >= 1; i--)
   {
      double ema20 = Ema20Buffer[i];
      double ema75 = Ema75Buffer[i];
      double ema200 = Ema200Buffer[i];

      BuyArrowBuffer[i] = EMPTY_VALUE;
      SellArrowBuffer[i] = EMPTY_VALUE;

      bool h4Buy = (H4TrendCache[i] == 1);
      bool h4Sell = (H4TrendCache[i] == -1);
      bool buyAlignment = IsBuyAlignment(i);
      bool sellAlignment = IsSellAlignment(i);
      bool buySlopeUp = IsBuySlopeUp(i, rates_total);
      bool sellSlopeDown = IsSellSlopeDown(i, rates_total);
      bool buyTouch = IsBuyTouch20Or75EMA(i);
      bool sellTouch = IsSellTouch20Or75EMA(i);
      bool bullishCandle = IsBullishCandle(i);
      bool bearishCandle = IsBearishCandle(i);

      bool buyPullbackReset = (Close[i] > ema20 && Low[i] > ema20);
      bool sellPullbackReset = (Close[i] < ema20 && High[i] < ema20);

      if(!buyAlignment || !buySlopeUp || buyPullbackReset)
         buySignalAlreadyShown = false;

      if(!sellAlignment || !sellSlopeDown || sellPullbackReset)
         sellSignalAlreadyShown = false;

      if(!buySignalAlreadyShown &&
         h4Buy &&
         buyAlignment &&
         buySlopeUp &&
         buyTouch &&
         bullishCandle)
      {
         BuyArrowBuffer[i] = Low[i] - 10 * Point;
         buySignalAlreadyShown = true;
         continue;
      }

      if(!sellSignalAlreadyShown &&
         h4Sell &&
         sellAlignment &&
         sellSlopeDown &&
         sellTouch &&
         bearishCandle)
      {
         SellArrowBuffer[i] = High[i] + 10 * Point;
         sellSignalAlreadyShown = true;
      }
   }

   BuyArrowBuffer[0] = EMPTY_VALUE;
   SellArrowBuffer[0] = EMPTY_VALUE;

   return(rates_total);
}

bool IsBuyAlignment(int shift)
{
   return(Ema20Buffer[shift] > Ema75Buffer[shift] &&
          Ema75Buffer[shift] > Ema200Buffer[shift]);
}

bool IsSellAlignment(int shift)
{
   return(Ema20Buffer[shift] < Ema75Buffer[shift] &&
          Ema75Buffer[shift] < Ema200Buffer[shift]);
}

bool IsBuySlopeUp(int shift, int rates_total)
{
   int lookback = MathMax(SlopeLookback, 1);
   if(shift + lookback >= rates_total)
      return(false);

   return(Ema20Buffer[shift] > Ema20Buffer[shift + lookback] &&
          Ema75Buffer[shift] > Ema75Buffer[shift + lookback]);
}

bool IsSellSlopeDown(int shift, int rates_total)
{
   int lookback = MathMax(SlopeLookback, 1);
   if(shift + lookback >= rates_total)
      return(false);

   return(Ema20Buffer[shift] < Ema20Buffer[shift + lookback] &&
          Ema75Buffer[shift] < Ema75Buffer[shift + lookback]);
}

bool IsBuyTouch20Or75EMA(int shift)
{
   return((Low[shift] <= Ema20Buffer[shift] && Close[shift] >= Ema20Buffer[shift]) ||
          (Low[shift] <= Ema75Buffer[shift] && Close[shift] >= Ema75Buffer[shift]));
}

bool IsSellTouch20Or75EMA(int shift)
{
   return((High[shift] >= Ema20Buffer[shift] && Close[shift] <= Ema20Buffer[shift]) ||
          (High[shift] >= Ema75Buffer[shift] && Close[shift] <= Ema75Buffer[shift]));
}

bool IsBullishCandle(int shift)
{
   return(Close[shift] > Open[shift]);
}

bool IsBearishCandle(int shift)
{
   return(Close[shift] < Open[shift]);
}

int GetCachedH4Trend(int h4Shift, int h4Bars)
{
   if(h4Shift == CachedH4Shift)
   {
      if(CachedH4BuyTrend)
         return(1);
      if(CachedH4SellTrend)
         return(-1);
      return(0);
   }

   CachedH4Shift = h4Shift;
   CachedH4BuyTrend = false;
   CachedH4SellTrend = false;

   if(h4Shift < 0)
      return(0);
   if(h4Bars <= h4Shift + 200)
      return(0);

   double h4Close = iClose(NULL, PERIOD_H4, h4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, h4Shift);

   CachedH4BuyTrend = (h4Close > h4Ema200);
   CachedH4SellTrend = (h4Close < h4Ema200);

   if(CachedH4BuyTrend)
      return(1);
   if(CachedH4SellTrend)
      return(-1);
   return(0);
}
