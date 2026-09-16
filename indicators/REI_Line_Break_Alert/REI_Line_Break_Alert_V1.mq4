// Project REI Line Break Alert V1
// MT4 Indicator
// Version 1.0
// 開発開始日: 2026-09-08
// 既存M15_Alert_Indicatorとは独立したIndicatorです。

#property strict
#property indicator_chart_window
#property version "1.00"

// One scan per closed candle prevents duplicate alerts for every line.
// State belongs to this indicator instance; source lines are never modified.
datetime g_lastProcessedClosedBar = 0;

struct LineState
{
   string lineName;
   string buttonName;
   string stateKey;
   bool enabled;
   bool ownsButton;
};
LineState g_lines[];
string g_buttonPrefix;

// Terminal globals are limited to 63 ANSI characters. Short ASCII identities
// remain readable; long/Unicode identities use a SHA-256 digest (first 24 bytes).
// Length delimiters distinguish names containing separators. No timeframe:
// identical symbol + line name intentionally share state across charts.
string StateKey(const string lineName)
{
   string identity = IntegerToString(StringLen(Symbol())) + ":" + Symbol()
                     + ":" + lineName;
   string readable = "REI_LBA_S1_R_" + identity;
   bool ascii = true;
   for(int i = 0; i < StringLen(identity); i++)
      if(StringGetCharacter(identity, i) < 32 || StringGetCharacter(identity, i) > 126)
         ascii = false;
   if(ascii && StringLen(readable) <= 63) return(readable);

   uchar data[], key[], digest[];
   int count = StringToCharArray(identity, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(count <= 0) return("");
   ArrayResize(data, count - 1); // Do not hash the terminating zero.
   if(CryptEncode(CRYPT_HASH_SHA256, data, key, digest) != 32)
   {
      Print("REI LBA: cannot generate state key for ", lineName, " error=", GetLastError());
      return("");
   }
   string result = "REI_LBA_S1_H_";
   for(int i = 0; i < 24; i++) result += StringFormat("%02X", (uint)digest[i]);
   return(result);
}

bool SaveState(const int index)
{
   string key = g_lines[index].stateKey;
   if(key == "" || GlobalVariableSet(key, g_lines[index].enabled ? 1.0 : 0.0) == 0)
   {
      Print("REI LBA: state save failed for ", g_lines[index].lineName,
            " error=", GetLastError());
      return(false);
   }
   GlobalVariablesFlush(); // Persist clicks/automatic OFF immediately to disk.
   return(true);
}

void RestoreState(const int index)
{
   double value = 0;
   string key = g_lines[index].stateKey;
   if(key == "") { g_lines[index].enabled = false; return; }
   if(GlobalVariableGet(key, value))
      g_lines[index].enabled = (value == 1.0);
   else if(!GlobalVariableCheck(key))
   {
      g_lines[index].enabled = true; // Only genuinely new identities default ON.
      SaveState(index);
   }
   else
   {
      g_lines[index].enabled = false;
      Print("REI LBA: state read failed for ", g_lines[index].lineName);
   }
}

int FindLine(const string name)
{
   for(int i = 0; i < ArraySize(g_lines); i++)
      if(g_lines[i].lineName == name) return(i);
   return(-1);
}

bool IsPriceLine(const string name)
{
   return(ObjectFind(0, name) == 0 &&
          ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_HLINE);
}

// Hash keeps even a 63-character source name within MT4's name limit.
// Probe occupied names (including hash collisions) without changing them.
string NewButtonName(const string lineName)
{
   uint hash = 2166136261;
   for(int i = 0; i < StringLen(lineName); i++)
      hash = (hash ^ (uint)StringGetCharacter(lineName, i)) * 16777619;
   string base = g_buttonPrefix + IntegerToString((long)hash);
   string name = base;
   int suffix = 0;
   while(ObjectFind(0, name) >= 0)
      name = base + "_" + IntegerToString(++suffix);
   return(name);
}

void RemoveLine(const int index, const bool deleteState = false)
{
   // Detachment/reinitialization must retain saved state; actual deletion does not.
   if(deleteState && g_lines[index].stateKey != "")
   {
      if(GlobalVariableCheck(g_lines[index].stateKey) &&
         !GlobalVariableDel(g_lines[index].stateKey))
         Print("REI LBA: state delete failed for ", g_lines[index].lineName);
      GlobalVariablesFlush();
   }
   // Delete only the exact button created by this instance, never a prefix sweep.
   if(g_lines[index].ownsButton)
      ObjectDelete(0, g_lines[index].buttonName);
   int size = ArraySize(g_lines);
   for(int i = index; i < size - 1; i++) g_lines[i] = g_lines[i + 1];
   ArrayResize(g_lines, size - 1);
}

void UpdateButton(const int index)
{
   string name = g_lines[index].buttonName;
   if(!g_lines[index].ownsButton || ObjectFind(0, name) < 0)
   {
      g_lines[index].ownsButton = false;
      name = NewButtonName(g_lines[index].lineName);
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return;
      g_lines[index].buttonName = name;
      g_lines[index].ownsButton = true;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 42);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 18);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, g_lines[index].enabled ? "ON" : "OFF");
   ObjectSetString(0, name, OBJPROP_TOOLTIP, g_lines[index].lineName);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,
                    g_lines[index].enabled ? clrSeaGreen : clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR,
                    ObjectGetInteger(0, g_lines[index].lineName, OBJPROP_COLOR));
   ObjectSetInteger(0, name, OBJPROP_STATE, false);

   double price = 0;
   int x = 0, y = 0;
   int width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   bool visible = ObjectGetDouble(0, g_lines[index].lineName, OBJPROP_PRICE, 0, price)
                  && ChartTimePriceToXY(0, 0, iTime(NULL, 0, 0), price, x, y)
                  && y >= 0 && y < height && width >= 60;
   // Off-screen lines keep their state; hide their buttons until visible again.
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   if(!visible) return;
   x = width - 60;
   y = (int)MathMax(0, MathMin(height - 18, y - 9));
   // Keep nearby lines at their price height, staggering buttons to the left.
   for(int attempt = 0; attempt < index; attempt++)
   {
      bool overlap = false;
      for(int j = 0; j < index; j++)
      {
         string other = g_lines[j].buttonName;
         if(!g_lines[j].ownsButton || ObjectFind(0, other) < 0 ||
            ObjectGetInteger(0, other, OBJPROP_TIMEFRAMES) == OBJ_NO_PERIODS) continue;
         int ox = (int)ObjectGetInteger(0, other, OBJPROP_XDISTANCE);
         int oy = (int)ObjectGetInteger(0, other, OBJPROP_YDISTANCE);
         if(MathAbs(x - ox) < 46 && MathAbs(y - oy) < 20) { overlap = true; break; }
      }
      if(!overlap || x < 46) break;
      x -= 46;
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
}

void SyncLines()
{
   for(int i = ArraySize(g_lines) - 1; i >= 0; i--)
      if(!IsPriceLine(g_lines[i].lineName)) RemoveLine(i, true);

   int count = ObjectsTotal(0, 0, OBJ_HLINE);
   for(int i = 0; i < count; i++)
   {
      string name = ObjectName(0, i, 0, OBJ_HLINE);
      if(name == "" || FindLine(name) >= 0) continue;
      int index = ArraySize(g_lines);
      if(ArrayResize(g_lines, index + 1) != index + 1) continue;
      g_lines[index].lineName = name;
      g_lines[index].buttonName = "";
      g_lines[index].stateKey = StateKey(name);
      RestoreState(index);
      g_lines[index].ownsButton = false;
   }
   for(int i = 0; i < ArraySize(g_lines); i++)
   {
      // Read also refreshes the terminal's four-week expiry and synchronizes
      // instances monitoring the same symbol/name. Do not write on every tick.
      double saved = 0;
      if(g_lines[i].stateKey != "" && GlobalVariableGet(g_lines[i].stateKey, saved))
         g_lines[i].enabled = (saved == 1.0);
      UpdateButton(i);
   }
}

void OnTimer()
{
   // Detect new/deleted lines even without market ticks. No shared chart flags.
   SyncLines();
   ChartRedraw();
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      for(int i = 0; i < ArraySize(g_lines); i++)
      {
         if(g_lines[i].ownsButton && g_lines[i].buttonName == sparam &&
            IsPriceLine(g_lines[i].lineName))
         {
            g_lines[i].enabled = !g_lines[i].enabled;
            SaveState(i);
            UpdateButton(i);
            ChartRedraw();
            return;
         }
      }
   }
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE ||
      id == CHARTEVENT_CHART_CHANGE)
   {
      SyncLines();
      ChartRedraw();
   }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i = ArraySize(g_lines) - 1; i >= 0; i--) RemoveLine(i);
   ChartRedraw();
}

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
   // SyncLines restores persisted state before creating buttons or scanning prices.
   ArrayResize(g_lines, 0);
   g_buttonPrefix = "REI_LBA_" + IntegerToString((long)GetTickCount()) + "_";
   if(!EventSetTimer(1)) return(INIT_FAILED);
   SyncLines();
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
   SyncLines();
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

      int stateIndex = FindLine(lineName);
      if(stateIndex < 0 || !g_lines[stateIndex].enabled)
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

      string direction = crossedUp ? "UP_BREAK" : "DOWN_BREAK";
      // Disarm before notifying; a manual ON click is needed for another alert.
      g_lines[stateIndex].enabled = false;
      SaveState(stateIndex);
      UpdateButton(stateIndex);
      // Use exactly the same message for the local alert and mobile push.
      string message = Symbol() + " | " + TimeframeText() + " | " + lineName
                       + " | " + direction;
      Alert(message);
      // One attempt per break, with no retries. Failure must not re-arm the line
      // or interrupt monitoring. MT4 notification settings/rate limits apply.
      ResetLastError();
      if(!SendNotification(message))
      {
         int pushError = GetLastError();
         Print("REI LBA: SendNotification failed | error=", pushError,
               " | ", message);
      }
      ChartRedraw();
   }

   return(rates_total);
}
