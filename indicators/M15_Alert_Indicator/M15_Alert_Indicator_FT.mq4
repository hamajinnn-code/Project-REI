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
input int SlopeLookback = 5;

double Ema20Buffer[];
double Ema75Buffer[];
double Ema200Buffer[];
double BuyArrowBuffer[];
double SellArrowBuffer[];

int CachedH4Shift = -1;
bool CachedH4BuyTrend = false;
bool CachedH4SellTrend = false;

int OnInit()
{
   IndicatorShortName("M15_Alert_Indicator_FT_H4_M15_Check");

   SetIndexBuffer(0, Ema20Buffer);
   SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 1, DodgerBlue);
   SetIndexLabel(0, "EMA 20");

   SetIndexBuffer(1, Ema75Buffer);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 1, Orange);
   SetIndexLabel(1, "EMA 75");

   SetIndexBuffer(2, Ema200Buffer);
   SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 1, Silver);
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
   int limit = MathMin(rates_total - 1, HistoricalBars);
   bool buySignalAlreadyShown = false;
   bool sellSignalAlreadyShown = false;
   CachedH4Shift = -1;
   CachedH4BuyTrend = false;
   CachedH4SellTrend = false;

   for(int i = limit; i >= 1; i--)
   {
      double ema20 = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema75 = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema200 = iMA(NULL, 0, 200, 0, MODE_EMA, PRICE_CLOSE, i);

      Ema20Buffer[i] = ema20;
      Ema75Buffer[i] = ema75;
      Ema200Buffer[i] = ema200;

      BuyArrowBuffer[i] = EMPTY_VALUE;
      SellArrowBuffer[i] = EMPTY_VALUE;

      bool buyAlignment = (ema20 > ema75 && ema75 > ema200);
      bool sellAlignment = (ema20 < ema75 && ema75 < ema200);

      int lookback = SlopeLookback;
      if(lookback < 1)
         lookback = 1;

      bool hasSlopeData = (i + lookback < rates_total);
      double ema20Past = 0.0;
      double ema75Past = 0.0;
      bool buySlopeUp = false;
      bool sellSlopeDown = false;

      if(hasSlopeData)
      {
         ema20Past = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, i + lookback);
         ema75Past = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, i + lookback);
         buySlopeUp = (ema20 > ema20Past && ema75 > ema75Past);
         sellSlopeDown = (ema20 < ema20Past && ema75 < ema75Past);
      }

      bool buyPullbackReset = (Close[i] > ema20 && Low[i] > ema20);
      bool sellPullbackReset = (Close[i] < ema20 && High[i] < ema20);

      if(!buyAlignment || !buySlopeUp || buyPullbackReset)
         buySignalAlreadyShown = false;

      if(!sellAlignment || !sellSlopeDown || sellPullbackReset)
         sellSignalAlreadyShown = false;

      bool buyTouch = ((Low[i] <= ema20 && Close[i] >= ema20) ||
                       (Low[i] <= ema75 && Close[i] >= ema75));
      bool sellTouch = ((High[i] >= ema20 && Close[i] <= ema20) ||
                        (High[i] >= ema75 && Close[i] <= ema75));
      bool bullishCandle = (Close[i] > Open[i]);
      bool bearishCandle = (Close[i] < Open[i]);

      if(!buySignalAlreadyShown &&
         buyAlignment &&
         buySlopeUp &&
         buyTouch &&
         bullishCandle)
      {
         int buyH4Shift = GetConfirmedH4ShiftForM15Shift(i);
         if(GetCachedH4BuyTrend(buyH4Shift))
         {
            BuyArrowBuffer[i] = Low[i] - 10 * Point;
            buySignalAlreadyShown = true;
            continue;
         }
      }

      if(!sellSignalAlreadyShown &&
         sellAlignment &&
         sellSlopeDown &&
         sellTouch &&
         bearishCandle)
      {
         int sellH4Shift = GetConfirmedH4ShiftForM15Shift(i);
         if(GetCachedH4SellTrend(sellH4Shift))
         {
            SellArrowBuffer[i] = High[i] + 10 * Point;
            sellSignalAlreadyShown = true;
         }
      }
   }

   Ema20Buffer[0] = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   Ema75Buffer[0] = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, 0);
   Ema200Buffer[0] = iMA(NULL, 0, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   BuyArrowBuffer[0] = EMPTY_VALUE;
   SellArrowBuffer[0] = EMPTY_VALUE;

   return(rates_total);
}

int GetConfirmedH4ShiftForM15Shift(int m15Shift)
{
   datetime m15Time = iTime(NULL, 0, m15Shift);
   if(m15Time <= 0)
      return(-1);

   int h4Shift = iBarShift(NULL, PERIOD_H4, m15Time, false);
   if(h4Shift < 0)
      return(-1);

   return(h4Shift + 1);
}

void UpdateH4TrendCache(int h4Shift)
{
   if(h4Shift == CachedH4Shift)
      return;

   CachedH4Shift = h4Shift;
   CachedH4BuyTrend = false;
   CachedH4SellTrend = false;

   if(h4Shift < 0)
      return;
   if(iBars(NULL, PERIOD_H4) <= h4Shift + 200)
      return;

   double h4Close = iClose(NULL, PERIOD_H4, h4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, h4Shift);

   CachedH4BuyTrend = (h4Close > h4Ema200);
   CachedH4SellTrend = (h4Close < h4Ema200);
}

bool GetCachedH4BuyTrend(int h4Shift)
{
   UpdateH4TrendCache(h4Shift);
   return(CachedH4BuyTrend);
}

bool GetCachedH4SellTrend(int h4Shift)
{
   UpdateH4TrendCache(h4Shift);
   return(CachedH4SellTrend);
}
