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
input bool EnableEngulfingFilter = true;
input double EngulfingBodyRatio = 1.0;
input bool EnableReferenceSLTP = true;
input int ZigZagDepth = 12;
input int ZigZagDeviation = 5;
input int ZigZagBackstep = 3;
input int ZigZagSearchBars = 500;
input int ZigZagConfirmBars = 3;
input double RiskRewardRatio = 2.0;
input int ReferenceLineLengthBars = 40;
input color ReferenceSLColor = LightCoral;
input color ReferenceTPColor = LightBlue;
input int ReferenceLineWidth = 1;
input int ReferenceLineStyle = STYLE_DASH;
input bool ShowReferenceEntryLine = false;
input bool EnableSLTPDebugLog = false;

double Ema20Buffer[];
double Ema75Buffer[];
double Ema200Buffer[];
double BuyArrowBuffer[];
double SellArrowBuffer[];
int H4TrendCache[];
double H4SignalEma200Cache[];

int CachedH4Shift = -1;
bool CachedH4BuyTrend = false;
bool CachedH4SellTrend = false;
int CachedSignalH4Shift = -1;
double CachedSignalH4Ema200 = 0.0;

int OnInit()
{
   IndicatorShortName("M15_Alert_Indicator_FT_V1.3");

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

   DeleteReferenceLines();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteReferenceLines();
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
   ArrayResize(H4SignalEma200Cache, rates_total);
   ArraySetAsSeries(H4TrendCache, true);
   ArraySetAsSeries(H4SignalEma200Cache, true);

   CachedH4Shift = -1;
   CachedH4BuyTrend = false;
   CachedH4SellTrend = false;
   CachedSignalH4Shift = -1;
   CachedSignalH4Ema200 = 0.0;

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
      {
         H4TrendCache[h] = 0;
         H4SignalEma200Cache[h] = 0.0;
      }
      else
      {
         H4TrendCache[h] = GetCachedH4Trend(sourceH4Shift + 1, h4Bars);
         H4SignalEma200Cache[h] = GetCachedSignalH4Ema200(sourceH4Shift, h4Bars);
      }
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
      double signalH4Ema200 = H4SignalEma200Cache[i];
      bool h4PriceBuy = (signalH4Ema200 > 0.0 && Close[i] > signalH4Ema200);
      bool h4PriceSell = (signalH4Ema200 > 0.0 && Close[i] < signalH4Ema200);
      bool buyAlignment = IsBuyAlignment(i);
      bool sellAlignment = IsSellAlignment(i);
      bool buySlopeUp = IsBuySlopeUp(i, rates_total);
      bool sellSlopeDown = IsSellSlopeDown(i, rates_total);
      bool buyTouch = IsBuyTouch20Or75EMA(i);
      bool sellTouch = IsSellTouch20Or75EMA(i);
      bool bullishCandle = IsBullishCandle(i);
      bool bearishCandle = IsBearishCandle(i);
      bool bullishEngulfing = (!EnableEngulfingFilter || IsBullishEngulfing(i));
      bool bearishEngulfing = (!EnableEngulfingFilter || IsBearishEngulfing(i));

      bool buyPullbackReset = (Close[i] > ema20 && Low[i] > ema20);
      bool sellPullbackReset = (Close[i] < ema20 && High[i] < ema20);

      if(!buyAlignment || !buySlopeUp || buyPullbackReset)
         buySignalAlreadyShown = false;

      if(!sellAlignment || !sellSlopeDown || sellPullbackReset)
         sellSignalAlreadyShown = false;

      if(!buySignalAlreadyShown &&
         h4Buy &&
         h4PriceBuy &&
         buyAlignment &&
         buySlopeUp &&
         buyTouch &&
         bullishCandle &&
         bullishEngulfing)
      {
         BuyArrowBuffer[i] = Low[i] - 10 * Point;
         UpdateReferenceSLTPLines(i, true);
         buySignalAlreadyShown = true;
         continue;
      }

      if(!sellSignalAlreadyShown &&
         h4Sell &&
         h4PriceSell &&
         sellAlignment &&
         sellSlopeDown &&
         sellTouch &&
         bearishCandle &&
         bearishEngulfing)
      {
         SellArrowBuffer[i] = High[i] + 10 * Point;
         UpdateReferenceSLTPLines(i, false);
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

bool IsBullishEngulfing(int shift)
{
   if(shift <= 0)
      return(false);
   if(shift + 1 >= Bars)
      return(false);
   if(Close[shift + 1] >= Open[shift + 1])
      return(false);
   if(Close[shift] <= Open[shift])
      return(false);
   if(Open[shift] > Close[shift + 1])
      return(false);
   if(Close[shift] < Open[shift + 1])
      return(false);

   double currentBody = MathAbs(Close[shift] - Open[shift]);
   double previousBody = MathAbs(Close[shift + 1] - Open[shift + 1]);

   return(currentBody >= previousBody * EngulfingBodyRatio);
}

bool IsBearishEngulfing(int shift)
{
   if(shift <= 0)
      return(false);
   if(shift + 1 >= Bars)
      return(false);
   if(Close[shift + 1] <= Open[shift + 1])
      return(false);
   if(Close[shift] >= Open[shift])
      return(false);
   if(Open[shift] < Close[shift + 1])
      return(false);
   if(Close[shift] > Open[shift + 1])
      return(false);

   double currentBody = MathAbs(Close[shift] - Open[shift]);
   double previousBody = MathAbs(Close[shift + 1] - Open[shift + 1]);

   return(currentBody >= previousBody * EngulfingBodyRatio);
}

double ZigZagTolerance()
{
   if(Digits == 3 || Digits == 5)
      return(Point);
   return(Point * 3.0);
}

double GetZigZagValue(int shift)
{
   return(iCustom(NULL,
                  PERIOD_M15,
                  "ZigZag",
                  ZigZagDepth,
                  ZigZagDeviation,
                  ZigZagBackstep,
                  0,
                  shift));
}

bool IsValidZigZagValue(double value)
{
   if(value == 0.0)
      return(false);
   if(value == EMPTY_VALUE)
      return(false);
   return(true);
}

bool FindPreviousConfirmedZigZagLow(int signalShift, int &pivotShift, double &pivotPrice)
{
   pivotShift = -1;
   pivotPrice = 0.0;

   int startShift = signalShift + MathMax(ZigZagConfirmBars, 1);
   int endShift = signalShift + MathMax(ZigZagSearchBars, startShift - signalShift);
   int maxBars = Bars - 1;
   endShift = MathMin(endShift, maxBars);

   for(int shift = startShift; shift <= endShift; shift++)
   {
      double zz = GetZigZagValue(shift);
      if(!IsValidZigZagValue(zz))
         continue;
      if(MathAbs(zz - Low[shift]) > ZigZagTolerance())
         continue;
      if(zz >= Close[signalShift])
         continue;

      pivotShift = shift;
      pivotPrice = zz;
      return(true);
   }

   return(false);
}

bool FindPreviousConfirmedZigZagHigh(int signalShift, int &pivotShift, double &pivotPrice)
{
   pivotShift = -1;
   pivotPrice = 0.0;

   int startShift = signalShift + MathMax(ZigZagConfirmBars, 1);
   int endShift = signalShift + MathMax(ZigZagSearchBars, startShift - signalShift);
   int maxBars = Bars - 1;
   endShift = MathMin(endShift, maxBars);

   for(int shift = startShift; shift <= endShift; shift++)
   {
      double zz = GetZigZagValue(shift);
      if(!IsValidZigZagValue(zz))
         continue;
      if(MathAbs(zz - High[shift]) > ZigZagTolerance())
         continue;
      if(zz <= Close[signalShift])
         continue;

      pivotShift = shift;
      pivotPrice = zz;
      return(true);
   }

   return(false);
}

bool CalculateBuyReferenceSLTP(int signalShift,
                               double &entryPrice,
                               double &stopLoss,
                               double &takeProfit)
{
   int pivotShift = -1;
   double pivotPrice = 0.0;

   entryPrice = Close[signalShift];
   if(!FindPreviousConfirmedZigZagLow(signalShift, pivotShift, pivotPrice))
      return(false);

   stopLoss = pivotPrice;
   double risk = entryPrice - stopLoss;
   if(stopLoss >= entryPrice || risk <= 0.0)
      return(false);

   takeProfit = entryPrice + risk * RiskRewardRatio;
   if(takeProfit <= entryPrice)
      return(false);

   if(EnableSLTPDebugLog)
      PrintReferenceSLTPDebug("BUY", signalShift, pivotShift, entryPrice, stopLoss, risk, takeProfit);

   return(true);
}

bool CalculateSellReferenceSLTP(int signalShift,
                                double &entryPrice,
                                double &stopLoss,
                                double &takeProfit)
{
   int pivotShift = -1;
   double pivotPrice = 0.0;

   entryPrice = Close[signalShift];
   if(!FindPreviousConfirmedZigZagHigh(signalShift, pivotShift, pivotPrice))
      return(false);

   stopLoss = pivotPrice;
   double risk = stopLoss - entryPrice;
   if(stopLoss <= entryPrice || risk <= 0.0)
      return(false);

   takeProfit = entryPrice - risk * RiskRewardRatio;
   if(takeProfit >= entryPrice)
      return(false);

   if(EnableSLTPDebugLog)
      PrintReferenceSLTPDebug("SELL", signalShift, pivotShift, entryPrice, stopLoss, risk, takeProfit);

   return(true);
}

string ReferenceObjectPrefix()
{
   return("M15_Alert_Indicator_FT_Reference_" + Symbol() + "_" + IntegerToString(Period()) + "_");
}

void DeleteReferenceLines()
{
   string prefix = ReferenceObjectPrefix();

   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(name);
   }
}

datetime ReferenceLineEndTime(int signalShift)
{
   int seconds = Period() * 60;
   if(seconds <= 0)
      seconds = 15 * 60;

   return(Time[signalShift] + seconds * MathMax(ReferenceLineLengthBars, 1));
}

void DrawReferenceLine(string suffix,
                       int signalShift,
                       double price,
                       color lineColor,
                       string labelText)
{
   string name = ReferenceObjectPrefix() + suffix;
   datetime startTime = Time[signalShift];
   datetime endTime = ReferenceLineEndTime(signalShift);

   ObjectDelete(name);
   if(!ObjectCreate(name, OBJ_TREND, 0, startTime, price, endTime, price))
      return;

   ObjectSet(name, OBJPROP_COLOR, lineColor);
   ObjectSet(name, OBJPROP_WIDTH, ReferenceLineWidth);
   ObjectSet(name, OBJPROP_STYLE, ReferenceLineStyle);
   ObjectSet(name, OBJPROP_RAY, false);
   ObjectSetText(name, labelText, 8, "Arial", lineColor);
}

void UpdateReferenceSLTPLines(int signalShift, bool isBuy)
{
   if(!EnableReferenceSLTP)
   {
      DeleteReferenceLines();
      return;
   }

   double entryPrice = 0.0;
   double stopLoss = 0.0;
   double takeProfit = 0.0;
   bool ok = false;

   if(isBuy)
      ok = CalculateBuyReferenceSLTP(signalShift, entryPrice, stopLoss, takeProfit);
   else
      ok = CalculateSellReferenceSLTP(signalShift, entryPrice, stopLoss, takeProfit);

   DeleteReferenceLines();
   if(!ok)
      return;

   DrawReferenceLine("SL", signalShift, stopLoss, ReferenceSLColor, "Reference SL");
   DrawReferenceLine("TP", signalShift, takeProfit, ReferenceTPColor, "Reference TP RR 1:" + DoubleToString(RiskRewardRatio, 1));

   if(ShowReferenceEntryLine)
      DrawReferenceLine("ENTRY", signalShift, entryPrice, Silver, "Reference Entry");
}

void PrintReferenceSLTPDebug(string direction,
                             int signalShift,
                             int pivotShift,
                             double entryPrice,
                             double stopLoss,
                             double risk,
                             double takeProfit)
{
   Print("Reference SLTP",
         " direction=", direction,
         " signalTime=", TimeToString(Time[signalShift], TIME_DATE | TIME_MINUTES),
         " signalShift=", signalShift,
         " entry=", DoubleToString(entryPrice, Digits),
         " pivotShift=", pivotShift,
         " pivotTime=", TimeToString(Time[pivotShift], TIME_DATE | TIME_MINUTES),
         " pivotPrice=", DoubleToString(stopLoss, Digits),
         " SL=", DoubleToString(stopLoss, Digits),
         " risk=", DoubleToString(risk, Digits),
         " TP=", DoubleToString(takeProfit, Digits),
         " RR=", DoubleToString(RiskRewardRatio, 2));
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

double GetCachedSignalH4Ema200(int h4Shift, int h4Bars)
{
   if(h4Shift == CachedSignalH4Shift)
      return(CachedSignalH4Ema200);

   CachedSignalH4Shift = h4Shift;
   CachedSignalH4Ema200 = 0.0;

   if(h4Shift < 0)
      return(0.0);
   if(h4Bars <= h4Shift + 200)
      return(0.0);

   CachedSignalH4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, h4Shift);
   return(CachedSignalH4Ema200);
}
