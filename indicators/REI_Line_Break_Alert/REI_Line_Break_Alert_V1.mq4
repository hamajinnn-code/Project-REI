// Project REI Line Break Alert V1
// MT4 Indicator
// Version 1.0
// 開発開始日: 2026-09-08
// 既存M15_Alert_Indicatorとは独立したIndicatorです。

#property strict
#property indicator_chart_window
#property version "1.00"

// One scan per closed candle prevents duplicate alerts for every line.
// State belongs to this indicator instance; no chart objects are modified.
datetime g_lastProcessedClosedBar = 0;

string TimeframeText()
{
   string text = EnumToString((ENUM_TIMEFRAMES)Period());
   if(StringFind(text, "PERIOD_") == 0)
      return(StringSubstr(text, 7));

   return(IntegerToString(Period()) + "min");
}

int OnInit()
{
   IndicatorShortName("Project REI Line Break Alert V1");
   g_lastProcessedClosedBar = 0;
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
   // Index 0 is forming; indices 1 and 2 must both be available.
   if(rates_total < 3)
      return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(close, true);
   datetime closedBarTime = time[1];
   if(closedBarTime <= 0)
      return(rates_total);

   // Start monitoring without replaying a signal on attachment/reinitialization.
   if(g_lastProcessedClosedBar == 0)
   {
      g_lastProcessedClosedBar = closedBarTime;
      return(rates_total);
   }

   // Do not rescan on ticks, line edits, or history recalculation of this bar.
   if(closedBarTime <= g_lastProcessedClosedBar)
      return(rates_total);

   g_lastProcessedClosedBar = closedBarTime;

   // Only price-chart horizontal lines: exclude oscillator subwindows.
   // All OBJ_HLINE objects qualify; there is no manual-creator flag filter.
   int lineCount = ObjectsTotal(0, 0, OBJ_HLINE);
   for(int index = 0; index < lineCount; index++)
   {
      string lineName = ObjectName(0, index, 0, OBJ_HLINE);
      if(lineName == "")
         continue;

      double linePrice = 0.0;
      if(!ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0, linePrice))
         continue;

      // Equality on the older close is allowed; the newer close must pass
      // strictly beyond the line. High/Low and the forming candle are unused.
      bool crossedUp = (close[2] <= linePrice && close[1] > linePrice);
      bool crossedDown = (close[2] >= linePrice && close[1] < linePrice);
      if(!crossedUp && !crossedDown)
         continue;

      string direction = crossedUp ? "上抜け" : "下抜け";
      Alert("Project REI Line Break Alert V1 | ", Symbol(),
            " | ", TimeframeText(), " | ", lineName, " | ", direction);
   }

   return(rates_total);
}
