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

   for(int i = limit; i >= 1; i--)
   {
      Ema20Buffer[i] = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, i);
      Ema75Buffer[i] = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, i);
      Ema200Buffer[i] = iMA(NULL, 0, 200, 0, MODE_EMA, PRICE_CLOSE, i);

      BuyArrowBuffer[i] = EMPTY_VALUE;
      SellArrowBuffer[i] = EMPTY_VALUE;

      bool buyAlignment = IsBuyAlignment(i);
      bool sellAlignment = IsSellAlignment(i);
      bool buySlopeUp = IsBuySlopeUp(i, rates_total);
      bool sellSlopeDown = IsSellSlopeDown(i, rates_total);

      if(!buyAlignment || !buySlopeUp || IsBuyPullbackReset(i))
         buySignalAlreadyShown = false;

      if(!sellAlignment || !sellSlopeDown || IsSellPullbackReset(i))
         sellSignalAlreadyShown = false;

      if(!buySignalAlreadyShown && IsBuySignal(i, rates_total))
      {
         BuyArrowBuffer[i] = Low[i] - 10 * Point;
         buySignalAlreadyShown = true;
      }
      else if(!sellSignalAlreadyShown && IsSellSignal(i, rates_total))
      {
         SellArrowBuffer[i] = High[i] + 10 * Point;
         sellSignalAlreadyShown = true;
      }
   }

   Ema20Buffer[0] = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   Ema75Buffer[0] = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, 0);
   Ema200Buffer[0] = iMA(NULL, 0, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   BuyArrowBuffer[0] = EMPTY_VALUE;
   SellArrowBuffer[0] = EMPTY_VALUE;

   return(rates_total);
}

bool HasSlopeData(int shift, int rates_total)
{
   int lookback = SlopeLookback;
   if(lookback < 1)
      lookback = 1;

   return(shift + lookback < rates_total);
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
   int lookback = SlopeLookback;
   if(lookback < 1)
      lookback = 1;
   if(!HasSlopeData(shift, rates_total))
      return(false);

   double ema20Past = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, shift + lookback);
   double ema75Past = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, shift + lookback);

   return(Ema20Buffer[shift] > ema20Past &&
          Ema75Buffer[shift] > ema75Past);
}

bool IsSellSlopeDown(int shift, int rates_total)
{
   int lookback = SlopeLookback;
   if(lookback < 1)
      lookback = 1;
   if(!HasSlopeData(shift, rates_total))
      return(false);

   double ema20Past = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, shift + lookback);
   double ema75Past = iMA(NULL, 0, 75, 0, MODE_EMA, PRICE_CLOSE, shift + lookback);

   return(Ema20Buffer[shift] < ema20Past &&
          Ema75Buffer[shift] < ema75Past);
}

bool IsBuyTouch20Or75EMA(int shift)
{
   bool touch20 = (Low[shift] <= Ema20Buffer[shift] &&
                   Close[shift] >= Ema20Buffer[shift]);
   bool touch75 = (Low[shift] <= Ema75Buffer[shift] &&
                   Close[shift] >= Ema75Buffer[shift]);

   return(touch20 || touch75);
}

bool IsSellTouch20Or75EMA(int shift)
{
   bool touch20 = (High[shift] >= Ema20Buffer[shift] &&
                   Close[shift] <= Ema20Buffer[shift]);
   bool touch75 = (High[shift] >= Ema75Buffer[shift] &&
                   Close[shift] <= Ema75Buffer[shift]);

   return(touch20 || touch75);
}

bool IsBullishCandle(int shift)
{
   return(Close[shift] > Open[shift]);
}

bool IsBearishCandle(int shift)
{
   return(Close[shift] < Open[shift]);
}

bool IsBuyPullbackReset(int shift)
{
   return(Close[shift] > Ema20Buffer[shift] &&
          Low[shift] > Ema20Buffer[shift]);
}

bool IsSellPullbackReset(int shift)
{
   return(Close[shift] < Ema20Buffer[shift] &&
          High[shift] < Ema20Buffer[shift]);
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

bool IsH4BuyTrendForM15Shift(int m15Shift)
{
   int h4Shift = GetConfirmedH4ShiftForM15Shift(m15Shift);
   if(h4Shift < 0)
      return(false);
   if(iBars(NULL, PERIOD_H4) <= h4Shift + 200)
      return(false);

   double h4Close = iClose(NULL, PERIOD_H4, h4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, h4Shift);

   return(h4Close > h4Ema200);
}

bool IsH4SellTrendForM15Shift(int m15Shift)
{
   int h4Shift = GetConfirmedH4ShiftForM15Shift(m15Shift);
   if(h4Shift < 0)
      return(false);
   if(iBars(NULL, PERIOD_H4) <= h4Shift + 200)
      return(false);

   double h4Close = iClose(NULL, PERIOD_H4, h4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, h4Shift);

   return(h4Close < h4Ema200);
}

bool IsBuySignal(int shift, int rates_total)
{
   if(shift <= 0)
      return(false);
   if(!IsH4BuyTrendForM15Shift(shift))
      return(false);
   if(!IsBuyAlignment(shift))
      return(false);
   if(!IsBuySlopeUp(shift, rates_total))
      return(false);
   if(!IsBuyTouch20Or75EMA(shift))
      return(false);
   if(!IsBullishCandle(shift))
      return(false);

   return(true);
}

bool IsSellSignal(int shift, int rates_total)
{
   if(shift <= 0)
      return(false);
   if(!IsH4SellTrendForM15Shift(shift))
      return(false);
   if(!IsSellAlignment(shift))
      return(false);
   if(!IsSellSlopeDown(shift, rates_total))
      return(false);
   if(!IsSellTouch20Or75EMA(shift))
      return(false);
   if(!IsBearishCandle(shift))
      return(false);

   return(true);
}
