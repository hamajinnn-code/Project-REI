#property strict
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1 clrAqua
#property indicator_color2 clrPink
#property indicator_color3 clrDodgerBlue
#property indicator_color4 clrGold
#property indicator_color5 clrSilver
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 1
#property indicator_width4 1
#property indicator_width5 1

//+------------------------------------------------------------------+
//| M15_Alert_Indicator                                               |
//| V1.0: H4 200EMA + M15 EMA alignment + 75EMA touch                 |
//| Drawing method: indicator buffers only                            |
//+------------------------------------------------------------------+

input int    HistoricalBars  = 5000;
input bool   EnableAlert     = true;
input bool   EnablePopup     = true;
input bool   EnableArrow     = true;
input bool   ShowDebugEMALines = true;
input double ArrowOffsetPips = 3.0;
input color  BuyArrowColor   = C'104,169,178';
input color  SellArrowColor  = C'205,139,157';

double BuyArrowBuffer[];
double SellArrowBuffer[];
double EMA20Buffer[];
double EMA75Buffer[];
double EMA200Buffer[];

datetime g_lastBuyAlertBarTime = 0;
datetime g_lastSellAlertBarTime = 0;
bool g_buySignalAlreadyShown = false;
bool g_sellSignalAlreadyShown = false;
int g_lastScannedBars = 0;
int g_lastBuyArrowCount = 0;
int g_lastSellArrowCount = 0;

int GetScanBars(int rates_total)
{
   int availableBars = MathMin(Bars, iBars(NULL, PERIOD_M15));
   int safeBars = availableBars - 300;

   if(safeBars < 1)
      return(0);

   int scanBars = MathMin(HistoricalBars, safeBars);
   scanBars = MathMin(scanBars, rates_total - 1);
   scanBars = MathMin(scanBars, 20000);

   if(scanBars < 1)
      return(0);

   return(scanBars);
}

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

   datetime m15Time = iTime(NULL, PERIOD_M15, shift);
   int h4Shift = iBarShift(NULL, PERIOD_H4, m15Time, false);
   int confirmedH4Shift = h4Shift + 1;

   if(m15Time <= 0 || h4Shift < 0)
      return(false);

   if(iBars(NULL, PERIOD_H4) <= confirmedH4Shift + 205)
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

int GetH4ShiftForM15Shift(int m15Shift)
{
   datetime m15Time = iTime(NULL, PERIOD_M15, m15Shift);

   if(m15Time <= 0)
      return(-1);

   return(iBarShift(NULL, PERIOD_H4, m15Time, false));
}

int GetConfirmedH4ShiftForM15Shift(int m15Shift)
{
   int h4Shift = GetH4ShiftForM15Shift(m15Shift);

   if(h4Shift < 0)
      return(-1);

   return(h4Shift + 1);
}

bool IsH4BuyTrendForM15Shift(int m15Shift)
{
   int confirmedH4Shift = GetConfirmedH4ShiftForM15Shift(m15Shift);

   if(confirmedH4Shift < 1)
      return(false);

   double h4Close = iClose(NULL, PERIOD_H4, confirmedH4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, confirmedH4Shift);

   return(h4Close > h4Ema200);
}

bool IsH4SellTrendForM15Shift(int m15Shift)
{
   int confirmedH4Shift = GetConfirmedH4ShiftForM15Shift(m15Shift);

   if(confirmedH4Shift < 1)
      return(false);

   double h4Close = iClose(NULL, PERIOD_H4, confirmedH4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, confirmedH4Shift);

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
   if(!IsH4BuyTrendForM15Shift(shift)) return(false);
   if(!IsM15BuyAlignment(shift)) return(false);
   if(!IsBuyTouch75EMA(shift)) return(false);
   return(true);
}

bool IsSellSignal(int shift)
{
   if(shift <= 0) return(false);
   if(!HasEnoughBars(shift)) return(false);
   if(!IsH4SellTrendForM15Shift(shift)) return(false);
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
   datetime m15Time = iTime(NULL, PERIOD_M15, shift);
   int h4Shift = GetH4ShiftForM15Shift(shift);
   int confirmedH4Shift = GetConfirmedH4ShiftForM15Shift(shift);
   double h4Close = iClose(NULL, PERIOD_H4, confirmedH4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, confirmedH4Shift);

   Print("BUY buffer arrow",
         " M15 shift=", shift,
         " M15 time=", TimeToString(m15Time, TIME_DATE | TIME_MINUTES),
         " M15 ema20=", DoubleToString(ema20, Digits),
         " M15 ema75=", DoubleToString(ema75, Digits),
         " M15 ema200=", DoubleToString(ema200, Digits),
         " ema20>ema75=", BoolText(ema20 > ema75),
         " ema75>ema200=", BoolText(ema75 > ema200),
         " IsM15BuyAlignment(shift)=", BoolText(IsM15BuyAlignment(shift)),
         " H4 shift=", h4Shift,
         " confirmedH4Shift=", confirmedH4Shift,
         " H4 close=", DoubleToString(h4Close, Digits),
         " H4 ema200=", DoubleToString(h4Ema200, Digits),
         " IsH4BuyTrendForM15Shift(shift)=", BoolText(IsH4BuyTrendForM15Shift(shift)),
         " IsBuyTouch75EMA(shift)=", BoolText(IsBuyTouch75EMA(shift)),
         " IsBuySignal(shift)=", BoolText(IsBuySignal(shift)),
         " BuyArrowBuffer[shift]=", DoubleToString(BuyArrowBuffer[shift], Digits));
}

void PrintSellBufferDebug(int shift)
{
   double ema20  = GetM15EMA(20, shift);
   double ema75  = GetM15EMA(75, shift);
   double ema200 = GetM15EMA(200, shift);
   datetime m15Time = iTime(NULL, PERIOD_M15, shift);
   int h4Shift = GetH4ShiftForM15Shift(shift);
   int confirmedH4Shift = GetConfirmedH4ShiftForM15Shift(shift);
   double h4Close = iClose(NULL, PERIOD_H4, confirmedH4Shift);
   double h4Ema200 = iMA(NULL, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, confirmedH4Shift);

   Print("SELL buffer arrow",
         " M15 shift=", shift,
         " M15 time=", TimeToString(m15Time, TIME_DATE | TIME_MINUTES),
         " M15 ema20=", DoubleToString(ema20, Digits),
         " M15 ema75=", DoubleToString(ema75, Digits),
         " M15 ema200=", DoubleToString(ema200, Digits),
         " ema20<ema75=", BoolText(ema20 < ema75),
         " ema75<ema200=", BoolText(ema75 < ema200),
         " IsM15SellAlignment(shift)=", BoolText(IsM15SellAlignment(shift)),
         " H4 shift=", h4Shift,
         " confirmedH4Shift=", confirmedH4Shift,
         " H4 close=", DoubleToString(h4Close, Digits),
         " H4 ema200=", DoubleToString(h4Ema200, Digits),
         " IsH4SellTrendForM15Shift(shift)=", BoolText(IsH4SellTrendForM15Shift(shift)),
         " IsSellTouch75EMA(shift)=", BoolText(IsSellTouch75EMA(shift)),
         " IsSellSignal(shift)=", BoolText(IsSellSignal(shift)),
         " SellArrowBuffer[shift]=", DoubleToString(SellArrowBuffer[shift], Digits));
}

//+------------------------------------------------------------------+
//| Buffer drawing                                                     |
//+------------------------------------------------------------------+
void UpdateArrowBuffers(int rates_total)
{
   int availableM15Bars = iBars(NULL, PERIOD_M15);
   int clearLimit = MathMin(rates_total - 1, availableM15Bars - 1);
   clearLimit = MathMin(clearLimit, 20000);
   int scanBars = GetScanBars(rates_total);

   if(clearLimit >= 0)
   {
      for(int clearShift = clearLimit; clearShift >= 0; clearShift--)
      {
         BuyArrowBuffer[clearShift] = EMPTY_VALUE;
         SellArrowBuffer[clearShift] = EMPTY_VALUE;
      }
   }

   g_lastScannedBars = 0;
   g_lastBuyArrowCount = 0;
   g_lastSellArrowCount = 0;

   if(scanBars < 1)
   {
      g_buySignalAlreadyShown = false;
      g_sellSignalAlreadyShown = false;
      return;
   }

   double arrowOffset = ArrowOffsetPips * PipPoint();
   int start = scanBars;
   bool buySignalAlreadyShown = false;
   bool sellSignalAlreadyShown = false;

   // Scan old candles to new candles so the first touch after alignment is detected correctly.
   for(int i = start; i >= 1; i--)
   {
      g_lastScannedBars++;

      bool buyAlignment = IsM15BuyAlignment(i);
      bool sellAlignment = IsM15SellAlignment(i);

      // Reset the shown flag when the matching EMA alignment breaks.
      if(!buyAlignment)
         buySignalAlreadyShown = false;

      if(!sellAlignment)
         sellSignalAlreadyShown = false;

      // Show only the first BUY touch after a fresh bullish alignment.
      if(buyAlignment && !buySignalAlreadyShown && IsBuySignal(i))
      {
         if(EnableArrow)
         {
            BuyArrowBuffer[i] = Low[i] - arrowOffset;
            g_lastBuyArrowCount++;
            PrintBuyBufferDebug(i);
         }

         buySignalAlreadyShown = true;
         continue;
      }

      // Show only the first SELL touch after a fresh bearish alignment.
      if(sellAlignment && !sellSignalAlreadyShown && IsSellSignal(i))
      {
         if(EnableArrow)
         {
            SellArrowBuffer[i] = High[i] + arrowOffset;
            g_lastSellArrowCount++;
            PrintSellBufferDebug(i);
         }

         sellSignalAlreadyShown = true;
      }
   }

   // Use the same suppression state for confirmed arrows and current-bar alerts.
   g_buySignalAlreadyShown = buySignalAlreadyShown;
   g_sellSignalAlreadyShown = sellSignalAlreadyShown;

   // The current candle must never show an arrow in V1.0.
   BuyArrowBuffer[0] = EMPTY_VALUE;
   SellArrowBuffer[0] = EMPTY_VALUE;
}

void UpdateDebugEMALines(int rates_total)
{
   int maxShift = GetScanBars(rates_total);

   if(maxShift < 0)
      return;

   for(int i = maxShift; i >= 0; i--)
   {
      if(ShowDebugEMALines)
      {
         EMA20Buffer[i] = GetM15EMA(20, i);
         EMA75Buffer[i] = GetM15EMA(75, i);
         EMA200Buffer[i] = GetM15EMA(200, i);
      }
      else
      {
         EMA20Buffer[i] = EMPTY_VALUE;
         EMA75Buffer[i] = EMPTY_VALUE;
         EMA200Buffer[i] = EMPTY_VALUE;
      }
   }
}

void UpdateStatusComment()
{
   Comment("M15_Alert_Indicator V1.0 backtest scan active",
           "\nHistoricalBars: ", HistoricalBars,
           "\nScanned bars: ", g_lastScannedBars,
           "\nBUY arrows: ", g_lastBuyArrowCount,
           "\nSELL arrows: ", g_lastSellArrowCount);
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

   bool buyAlignment = IsM15BuyAlignment(0);
   bool sellAlignment = IsM15SellAlignment(0);

   // Reset alert suppression when the current EMA alignment breaks.
   if(!buyAlignment)
      g_buySignalAlreadyShown = false;

   if(!sellAlignment)
      g_sellSignalAlreadyShown = false;

   bool buyAlert = !g_buySignalAlreadyShown
                   && IsH4BuyTrendForM15Shift(0)
                   && buyAlignment
                   && lowPrice <= ema75
                   && currentPrice >= ema75;

   bool sellAlert = !g_sellSignalAlreadyShown
                    && IsH4SellTrendForM15Shift(0)
                    && sellAlignment
                    && highPrice >= ema75
                    && currentPrice <= ema75;

   if(buyAlert && g_lastBuyAlertBarTime != currentBarTime)
   {
      g_lastBuyAlertBarTime = currentBarTime;
      g_buySignalAlreadyShown = true;
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
      g_sellSignalAlreadyShown = true;
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
   SetIndexBuffer(2, EMA20Buffer);
   SetIndexBuffer(3, EMA75Buffer);
   SetIndexBuffer(4, EMA200Buffer);

   ArraySetAsSeries(BuyArrowBuffer, true);
   ArraySetAsSeries(SellArrowBuffer, true);
   ArraySetAsSeries(EMA20Buffer, true);
   ArraySetAsSeries(EMA75Buffer, true);
   ArraySetAsSeries(EMA200Buffer, true);

   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 2, BuyArrowColor);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 2, SellArrowColor);
   SetIndexStyle(2, ShowDebugEMALines ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 1, clrDodgerBlue);
   SetIndexStyle(3, ShowDebugEMALines ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 1, clrGold);
   SetIndexStyle(4, ShowDebugEMALines ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 1, clrSilver);
   SetIndexArrow(0, 233);
   SetIndexArrow(1, 234);
   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexEmptyValue(2, EMPTY_VALUE);
   SetIndexEmptyValue(3, EMPTY_VALUE);
   SetIndexEmptyValue(4, EMPTY_VALUE);
   SetIndexLabel(0, "BUY signal");
   SetIndexLabel(1, "SELL signal");
   SetIndexLabel(2, "Debug 20EMA");
   SetIndexLabel(3, "Debug 75EMA");
   SetIndexLabel(4, "Debug 200EMA");

   Print("M15_Alert_Indicator V1.0 rebuild loaded");
   UpdateStatusComment();

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
   if(Period() != PERIOD_M15)
   {
      Comment("M15_Alert_Indicator V1.0 backtest scan active",
              "\nPlease attach this indicator to an M15 chart.");
      return(rates_total);
   }

   UpdateDebugEMALines(rates_total);
   UpdateArrowBuffers(rates_total);
   UpdateStatusComment();
   CheckCurrentAlert();

   return(rates_total);
}

void OnDeinit(const int reason)
{
   Comment("");
}
