// Project REI Line Break Alert V1.6 - legacy controls cleanup and compact panel
// MT4 Indicator
// Version 1.6
// 開発開始日: 2026-09-08
// 既存M15_Alert_Indicatorとは独立したIndicatorです。

#property strict
#property indicator_chart_window
#property version "1.60"
#property indicator_buffers 5

// Display settings only; line monitoring and notifications do not use these inputs.
input bool ShowEMAs = true;     // Show all enabled EMAs
input bool ShowEMA20 = true;    // Show EMA20
input bool ShowEMA75 = true;    // Show EMA75
input bool ShowEMA200 = true;   // Show EMA200
input bool ShowEMA800 = true;   // Show EMA800 on M15 only
input bool ShowEMA3200 = true;  // Show EMA3200 on M15 only
// Panel UI only; Break/Touch alert semantics remain identical to V1.2.
input bool PanelStartsOpen = false;  // 管理パネルを開いた状態で起動
input int PanelRowsPerPage = 6;      // 1ページのライン数(3～10)
input int PanelRightMargin = 115;   // 右端からの余白(px)
input int PanelTopMargin = 76;      // 上端からの余白(px)
input bool RemoveLegacyButtons = true; // V1～V1.2の残存ボタンを除去

// Display-only buffers. Never read these in line monitoring or notifications.
double g_ema20[], g_ema75[], g_ema200[], g_ema800[], g_ema3200[];

bool SetupEMA(const int index, double &buffer[], const int period,
              const color lineColor, const int style, const bool visible)
{
   if(!SetIndexBuffer(index, buffer, INDICATOR_DATA)) return(false);
   ArraySetAsSeries(buffer, true);
   SetIndexStyle(index, visible ? DRAW_LINE : DRAW_NONE, style, 1, lineColor);
   SetIndexEmptyValue(index, EMPTY_VALUE);
   SetIndexDrawBegin(index, period - 1);
   SetIndexShift(index, 0);
   if(visible) SetIndexLabel(index, "EMA" + IntegerToString(period));
   else SetIndexLabel(index, NULL);
   return(true);
}

bool InitEMADisplay()
{
   bool m15 = (Period() == PERIOD_M15);
   IndicatorDigits(Digits);
   return(SetupEMA(0, g_ema20, 20, clrBlue, STYLE_SOLID, ShowEMAs && ShowEMA20) &&
          SetupEMA(1, g_ema75, 75, clrYellow, STYLE_SOLID, ShowEMAs && ShowEMA75) &&
          SetupEMA(2, g_ema200, 200, clrWhite, STYLE_SOLID, ShowEMAs && ShowEMA200) &&
          SetupEMA(3, g_ema800, 800, clrYellow, STYLE_DASH, ShowEMAs && ShowEMA800 && m15) &&
          SetupEMA(4, g_ema3200, 3200, clrRed, STYLE_DOT, ShowEMAs && ShowEMA3200 && m15));
}

void UpdateEMA(double &buffer[], const int period, const bool visible,
               const int rates_total, const int prev_calculated)
{
   bool full = (prev_calculated <= 0 || prev_calculated > rates_total);
   if(full) ArrayInitialize(buffer, EMPTY_VALUE);
   if(!visible) return;

   // For shift s, at least 'period' bars at s and OLDER must be available.
   // Leave the warm-up region empty, including after a chart history limit rolls.
   int oldestValid = rates_total - period;
   for(int s = (int)MathMax(0, oldestValid + 1); s < rates_total; s++)
      buffer[s] = EMPTY_VALUE;
   if(oldestValid < 0) return;

   // Recalculate the current bar and at least the last closed bar. A terminal
   // history reload resets prev_calculated and rebuilds the complete display.
   int start = full ? oldestValid : (int)MathMin(oldestValid,
                                               (int)MathMax(1, rates_total - prev_calculated));
   for(int s = start; s >= 0; s--)
   {
      ResetLastError();
      double value = iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, s);
      int error = GetLastError();
      buffer[s] = (error == 0 && MathIsValidNumber(value)) ? value : EMPTY_VALUE;
   }
}

void UpdateEMADisplay(const int rates_total, const int prev_calculated)
{
   if(rates_total <= 0) return;
   UpdateEMA(g_ema20, 20, ShowEMAs && ShowEMA20, rates_total, prev_calculated);
   UpdateEMA(g_ema75, 75, ShowEMAs && ShowEMA75, rates_total, prev_calculated);
   UpdateEMA(g_ema200, 200, ShowEMAs && ShowEMA200, rates_total, prev_calculated);
   // These are M15 long-period EMAs, not multi-timeframe H1/H4 iMA calls.
   bool m15 = (Period() == PERIOD_M15);
   UpdateEMA(g_ema800, 800, ShowEMAs && ShowEMA800 && m15, rates_total, prev_calculated);
   UpdateEMA(g_ema3200, 3200, ShowEMAs && ShowEMA3200 && m15, rates_total, prev_calculated);
}

// One scan per closed candle prevents duplicate alerts for every line.
// State belongs to this indicator instance; source lines are never modified.
datetime g_lastProcessedClosedBar = 0;

struct LineState
{
   string lineName;
   string stateKey;
   bool enabled;
   bool touchMode;
   bool hasTouchSample;
   double previousGap;
   string geometry;
};
LineState g_lines[];
string g_panelPrefix = "";
bool g_panelOpen = false;
int g_panelPage = 0;
int g_panelRows = 6;

// Terminal globals are limited to 63 ANSI characters. Short ASCII identities
// remain readable; long/Unicode identities use a SHA-256 digest (first 24 bytes).
// Length delimiters distinguish names containing separators. No timeframe:
// identical symbol + line name intentionally share state across charts.
string StateKey(const string lineName, const bool touchMode = false)
{
   string identity = IntegerToString(StringLen(Symbol())) + ":" + Symbol()
                     + ":" + lineName;
   string prefix = touchMode ? "REI_LBA_T1_" : "REI_LBA_S1_";
   string readable = prefix + "R_" + identity;
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
   string result = prefix + "H_";
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
      g_lines[index].enabled = !g_lines[index].touchMode; // New Touch is opt-in; Break retains V1.1 default.
      SaveState(index);
   }
   else
   {
      g_lines[index].enabled = false;
      Print("REI LBA: state read failed for ", g_lines[index].lineName);
   }
}

int FindLine(const string name, const bool touchMode = false)
{
   for(int i = 0; i < ArraySize(g_lines); i++)
      if(g_lines[i].lineName == name && g_lines[i].touchMode == touchMode) return(i);
   return(-1);
}

bool IsPriceLine(const string name)
{
   if(ObjectFind(0, name) != 0) return(false);
   long type = ObjectGetInteger(0, name, OBJPROP_TYPE);
   return(type == OBJ_HLINE || type == OBJ_TREND);
}

bool TrendBounds(const string name, datetime &left, datetime &right, bool &ray)
{
   long first = 0, second = 0, rayValue = 0;
   if(!ObjectGetInteger(0, name, OBJPROP_TIME, 0, first) ||
      !ObjectGetInteger(0, name, OBJPROP_TIME, 1, second) ||
      !ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT, 0, rayValue)) return(false);
   if(first <= 0 || second <= 0 || first == second) return(false);
   left = (datetime)(first < second ? first : second);
   right = (datetime)(first > second ? first : second);
   ray = (rayValue != 0);
   return(true);
}

bool TrendPriceAt(const string name, const datetime barTime, double &price)
{
   datetime left = 0, right = 0;
   bool ray = false;
   if(!TrendBounds(name, left, right, ray)) return(false);
   // Respect the drawn segment: no left extrapolation; right extension only
   // when Ray Right is enabled. Reject vertical/invalid anchor pairs above.
   if(barTime < left || (!ray && barTime > right)) return(false);
   ResetLastError();
   price = ObjectGetValueByTime(0, name, barTime, 0);
   return(GetLastError() == 0 && MathIsValidNumber(price));
}

// The panel uses its own unique object prefix. It never modifies or deletes
// source HLINE/TREND objects. Saved Break/Touch state keys remain unchanged.
string PanelName(const string suffix) { return(g_panelPrefix + suffix); }

// The original panel was too close to the right edge (16px).
// Keep all panel widgets in the same local coordinate system, shifting
// the entire group away from the price axis and Easyorder buttons.
int PanelLeft()
{
   int width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int rightMargin = (int)MathMax(8, PanelRightMargin);
   return((int)MathMax(0, width - rightMargin - 382));
}
int PanelTop()
{
   return((int)MathMax(17, PanelTopMargin));
}
int EffectivePanelRows()
{
   int height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int usable = (height - PanelTop() - 116) / 26;
   return((int)MathMax(1, MathMin(g_panelRows, usable)));
}

// V1/V1.1 used ON/OFF captions; V1.2 used B ON/B OFF/T ON/T OFF.
// Older instances create names like REI_LBA_<session>_<hash>; the V1.6
// panel uses REI_LBA_PNL_ and must NEVER be removed by this function.
// Only our legacy OBJ_BUTTON objects are deleted; no price lines, other
// indicators' controls, or persisted Break/Touch states are modified.
void CleanLegacyLbaButtons()
{
   if(!RemoveLegacyButtons) return;
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "REI_LBA_") != 0 ||
         StringFind(name, "REI_LBA_PNL_") == 0) continue;
      if(ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_BUTTON) continue;
      string label = ObjectGetString(0, name, OBJPROP_TEXT);
      bool v1Caption = (label == "ON" || label == "OFF");
      bool v12Caption = (label == "B ON" || label == "B OFF" ||
                         label == "T ON" || label == "T OFF");
      if(v1Caption || v12Caption)
      {
         if(!ObjectDelete(0, name))
            Print("REI LBA: legacy button deletion failed: ", name,
                  " err=", GetLastError());
      }
   }
}


void DeletePanelObject(const string suffix)
{
   string name = PanelName(suffix);
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
}

void DeleteAllPanelObjects()
{
   if(g_panelPrefix == "") return;
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, g_panelPrefix) == 0) ObjectDelete(0, name);
   }
}

void DeletePanelDetails()
{
   if(g_panelPrefix == "") return;
   string header = PanelName("HEADER");
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(name != header && StringFind(name, g_panelPrefix) == 0)
         ObjectDelete(0, name);
   }
}

void RemoveLine(const int index, const bool deleteState = false)
{
   if(deleteState && g_lines[index].stateKey != "")
   {
      if(GlobalVariableCheck(g_lines[index].stateKey) &&
         !GlobalVariableDel(g_lines[index].stateKey))
         Print("REI LBA: state delete failed for ", g_lines[index].lineName);
      GlobalVariablesFlush();
   }
   int count = ArraySize(g_lines);
   for(int i = index; i < count - 1; i++) g_lines[i] = g_lines[i + 1];
   ArrayResize(g_lines, count - 1);
}

bool CreatePanelObject(const string suffix, const ENUM_OBJECT type)
{
   string name = PanelName(suffix);
   if(ObjectFind(0, name) >= 0) return(true);
   if(!ObjectCreate(0, name, type, 0, 0, 0))
   {
      Print("REI LBA: panel create failed: ", name, " error=", GetLastError());
      return(false);
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 40);
   return(true);
}

void PanelButton(const string key, const string caption, const int right,
                 const int top, const int width, const color background,
                 const string tip)
{
   if(!CreatePanelObject(key, OBJ_BUTTON)) return;
   string name = PanelName(key);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelLeft() + 382 - right - width);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PanelTop() + top - 17);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrSlateGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

void PanelLabel(const string key, const string caption, const int right,
                const int top, const int fontSize, const string tip)
{
   if(!CreatePanelObject(key, OBJ_LABEL)) return;
   string name = PanelName(key);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelLeft() + 382 - right);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PanelTop() + top - 17);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
}

void PanelBackground(const int rows)
{
   if(!CreatePanelObject("BACKGROUND", OBJ_RECTANGLE_LABEL)) return;
   string name = PanelName("BACKGROUND");
   // OBJ_RECTANGLE_LABEL grows to the RIGHT from its X-distance, even when
   // the object corner is RIGHT_UPPER. Buttons instead extend to the LEFT
   // from the right edge. Use LEFT_UPPER for the frame and calculate its
   // left edge explicitly to make both use the exact same screen rectangle.
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelLeft());
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PanelTop() + 30);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 382);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 60 + 26 * rows);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

int CountPanelLines()
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_lines); i++)
      if(!g_lines[i].touchMode) count++;
   return(count);
}

string PanelLineAt(const int position)
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_lines); i++)
      if(!g_lines[i].touchMode)
      {
         if(count == position) return(g_lines[i].lineName);
         count++;
      }
   return("");
}

int CountEnabledModes()
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_lines); i++)
      if(g_lines[i].enabled) count++;
   return(count);
}

void UpdatePanel()
{
   if(g_panelPrefix == "") return;
   int total = CountPanelLines();
   int active = CountEnabledModes();
   PanelButton("HEADER",
               "REI Alerts " + IntegerToString(active) + "/" +
               IntegerToString(total * 2) + (g_panelOpen ? " [-]" : " [+]"),
               16, 17, 170, clrDarkSlateGray, "Open/close Break and Touch panel");
   if(!g_panelOpen)
   {
      DeletePanelDetails();
      return;
   }
   int pageSize = EffectivePanelRows();
   int pages = (int)MathMax(1, (total + pageSize - 1) / pageSize);
   if(g_panelPage >= pages) g_panelPage = pages - 1;
   if(g_panelPage < 0) g_panelPage = 0;
   int start = g_panelPage * pageSize;
   int shown = (int)MathMin(pageSize, total - start);
   PanelBackground(shown);
   PanelLabel("TITLE", "Line / Break / Touch", 154, 56, 9,
              "B: close break, T: price touch");
   if(total == 0)
      PanelLabel("EMPTY", "No horizontal/trend lines", 154, 87, 9,
                 "Draw HLINE or TREND on chart");
   else
      DeletePanelObject("EMPTY");

   for(int row = 0; row < g_panelRows; row++)
   {
      string key = IntegerToString(row);
      if(row >= shown)
      {
         DeletePanelObject("NAME_" + key);
         DeletePanelObject("BREAK_" + key);
         DeletePanelObject("TOUCH_" + key);
         continue;
      }
      string name = PanelLineAt(start + row);
      int b = FindLine(name, false), t = FindLine(name, true);
      bool bOn = (b >= 0 && g_lines[b].enabled);
      bool tOn = (t >= 0 && g_lines[t].enabled);
      string shortName = name;
      if(StringLen(shortName) > 23)
         shortName = StringSubstr(shortName, 0, 20) + "...";
      int y = 82 + row * 26;
      PanelLabel("NAME_" + key, shortName, 154, y + 3, 9, name);
      PanelButton("BREAK_" + key, bOn ? "B ON" : "B OFF",
                  88, y, 59, bOn ? clrSeaGreen : clrDimGray,
                  name + " | Break");
      PanelButton("TOUCH_" + key, tOn ? "T ON" : "T OFF",
                  22, y, 59, tOn ? clrSeaGreen : clrDimGray,
                  name + " | Touch");
   }
   int foot = 83 + shown * 26;
   PanelLabel("PAGE", "Page " + IntegerToString(g_panelPage + 1) + "/" +
              IntegerToString(pages) + " (" + IntegerToString(total) +
              " lines)", 154, foot + 4, 9, "");
   if(pages > 1)
   {
      PanelButton("PREV", "<", 88, foot, 28, clrDarkSlateGray, "Previous page");
      PanelButton("NEXT", ">", 22, foot, 28, clrDarkSlateGray, "Next page");
   }
   else
   {
      DeletePanelObject("PREV");
      DeletePanelObject("NEXT");
   }
}

void TogglePanelMode(const int row, const bool touchMode)
{
   string lineName = PanelLineAt(g_panelPage * EffectivePanelRows() + row);
   if(lineName == "" || !IsPriceLine(lineName)) return;
   int i = FindLine(lineName, touchMode);
   if(i < 0) return;
   g_lines[i].enabled = !g_lines[i].enabled;
   PrimeTouchSample(i);
   SaveState(i);
   UpdatePanel();
   ChartRedraw(0);
}

void SyncLines()
{
   for(int i = ArraySize(g_lines) - 1; i >= 0; i--)
      if(!IsPriceLine(g_lines[i].lineName)) RemoveLine(i, true);

   int count = ObjectsTotal(0, 0, -1);
   for(int i = 0; i < count; i++)
   {
      string name = ObjectName(0, i, 0, -1);
      if(name == "" || !IsPriceLine(name)) continue;
      for(int mode = 0; mode < 2; mode++)
      {
         bool touchMode = (mode == 1);
         if(FindLine(name, touchMode) >= 0) continue;
         int index = ArraySize(g_lines);
         if(ArrayResize(g_lines, index + 1) != index + 1) continue;
         g_lines[index].lineName = name;
         g_lines[index].touchMode = touchMode;
         g_lines[index].stateKey = StateKey(name, touchMode);
         g_lines[index].hasTouchSample = false;
         g_lines[index].previousGap = 0;
         g_lines[index].geometry = "";
         RestoreState(index);
         PrimeTouchSample(index);
      }
   }
   for(int i = 0; i < ArraySize(g_lines); i++)
   {
      // Read also refreshes the terminal's four-week expiry and synchronizes
      // instances monitoring the same symbol/name. Do not write on every tick.
      double saved = 0;
      if(g_lines[i].stateKey != "" && GlobalVariableGet(g_lines[i].stateKey, saved))
      {
         if(g_lines[i].enabled != (saved == 1.0))
            g_lines[i].hasTouchSample = false;
         g_lines[i].enabled = (saved == 1.0);
      }

   }
}

void OnTimer()
{
   // An old indicator/template can recreate legacy buttons after initial
   // cleanup. Sweep exact REI_LBA_ legacy buttons on the 1-second timer.
   // If older indicators are still installed, remove those instances too
   // to prevent duplicate Break/Touch notifications.
   CleanLegacyLbaButtons();
   SyncLines();
   UpdatePanel();
   ChartRedraw();
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, g_panelPrefix) == 0)
   {
      if(sparam == PanelName("HEADER")) g_panelOpen = !g_panelOpen;
      else if(sparam == PanelName("PREV"))
         g_panelPage = (int)MathMax(0, g_panelPage - 1);
      else if(sparam == PanelName("NEXT")) g_panelPage++;
      else if(g_panelOpen)
      {
         for(int row = 0; row < g_panelRows; row++)
         {
            string key = IntegerToString(row);
            if(sparam == PanelName("BREAK_" + key))
            {
               TogglePanelMode(row, false);
               return;
            }
            if(sparam == PanelName("TOUCH_" + key))
            {
               TogglePanelMode(row, true);
               return;
            }
         }
      }
      UpdatePanel();
      ChartRedraw(0);
      return;
   }
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE ||
      id == CHARTEVENT_CHART_CHANGE)
   {
      if(id != CHARTEVENT_CHART_CHANGE)
         for(int i = 0; i < ArraySize(g_lines); i++)
            if(g_lines[i].lineName == sparam) PrimeTouchSample(i);
      SyncLines();
      UpdatePanel();
      ChartRedraw(0);
   }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteAllPanelObjects();
   for(int i = ArraySize(g_lines) - 1; i >= 0; i--) RemoveLine(i);
   ChartRedraw(0);
}

string TimeframeText()
{
   string text = EnumToString((ENUM_TIMEFRAMES)Period());
   if(StringFind(text, "PERIOD_") == 0)
      return(StringSubstr(text, 7));

   return(IntegerToString(Period()) + "min");
}


// A line edit resets sampling even if no chart event was delivered.
string TouchGeometry(const string name)
{
   return(IntegerToString(ObjectGetInteger(0, name, OBJPROP_TYPE)) + "|" +
          DoubleToString(ObjectGetDouble(0, name, OBJPROP_PRICE, 0), 16) + "|" +
          DoubleToString(ObjectGetDouble(0, name, OBJPROP_PRICE, 1), 16) + "|" +
          IntegerToString(ObjectGetInteger(0, name, OBJPROP_TIME, 0)) + "|" +
          IntegerToString(ObjectGetInteger(0, name, OBJPROP_TIME, 1)) + "|" +
          IntegerToString(ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT)));
}

// Pure tick-to-line predicate: crossing gaps count as reaching the line.
int TouchDirection(const double previousGap, const double gap)
{
   if(previousGap < 0 && gap >= 0) return(1);
   if(previousGap > 0 && gap <= 0) return(-1);
   return(0);
}


void PrimeTouchSample(const int index)
{
   g_lines[index].hasTouchSample = false;
   if(!g_lines[index].touchMode || !g_lines[index].enabled) return;
   MqlTick tick;
   if(!SymbolInfoTick(Symbol(), tick) || tick.bid <= 0 || tick.time <= 0) return;
   string name = g_lines[index].lineName;
   double price = 0;
   bool valid = false;
   if(ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_HLINE)
      valid = ObjectGetDouble(0, name, OBJPROP_PRICE, 0, price);
   else
      valid = TrendPriceAt(name, tick.time, price);
   if(!valid || !MathIsValidNumber(price)) return;
   g_lines[index].geometry = TouchGeometry(name);
   g_lines[index].previousGap = tick.bid - price;
   g_lines[index].hasTouchSample = true;
}

void CheckTouchAlerts()
{
   MqlTick tick;
   if(!SymbolInfoTick(Symbol(), tick) || tick.bid <= 0 || tick.time <= 0) return;
   for(int i = 0; i < ArraySize(g_lines); i++)
   {
      if(!g_lines[i].touchMode || !g_lines[i].enabled) continue;
      string name = g_lines[i].lineName;
      if(!IsPriceLine(name)) continue;
      string geometry = TouchGeometry(name);
      if(geometry != g_lines[i].geometry)
      {
         g_lines[i].geometry = geometry;
         g_lines[i].hasTouchSample = false;
      }
      double linePrice = 0;
      bool valid = false;
      if(ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_HLINE)
         valid = ObjectGetDouble(0, name, OBJPROP_PRICE, 0, linePrice);
      else
         valid = TrendPriceAt(name, tick.time, linePrice);
      if(!valid || !MathIsValidNumber(linePrice))
      {
         g_lines[i].hasTouchSample = false;
         continue;
      }
      double gap = tick.bid - linePrice;
      // First sample only establishes a baseline; no historical replay on ON.
      int direction = g_lines[i].hasTouchSample ?
                      TouchDirection(g_lines[i].previousGap, gap) : 0;
      g_lines[i].previousGap = gap;
      g_lines[i].hasTouchSample = true;
      if(direction == 0) continue;

      // Only Touch state is disarmed. Break's state/key are never written here.
      g_lines[i].enabled = false;
      SaveState(i);

      string message = Symbol() + " | " + TimeframeText() + " | " + name +
                       " | Touch | " + (direction > 0 ? "UP_TOUCH" : "DOWN_TOUCH");
      Alert(message);
      ResetLastError();
      if(!SendNotification(message))
         Print("REI LBA: SendNotification failed | error=", GetLastError(), " | ", message);
      ChartRedraw();
   }
}

int OnInit()
{
   IndicatorShortName("Line Break Alert_V1.6");
   if(!InitEMADisplay()) return(INIT_FAILED);
   g_lastProcessedClosedBar = 0;
   // SyncLines restores persisted state before creating buttons or scanning prices.
   ArrayResize(g_lines, 0);
   g_panelPrefix = "REI_LBA_PNL_" + IntegerToString((long)ChartID()) + "_" +
                   IntegerToString((long)GetTickCount()) + "_";
   g_panelOpen = PanelStartsOpen;
   g_panelPage = 0;
   g_panelRows = (int)MathMax(3, MathMin(10, PanelRowsPerPage));
   CleanLegacyLbaButtons();
   if(!EventSetTimer(1)) return(INIT_FAILED);
   SyncLines();
   UpdatePanel();
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
   UpdateEMADisplay(rates_total, prev_calculated);
   SyncLines();
   CheckTouchAlerts();
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

   // Only price-chart HLINE/TREND objects; source objects are read-only.
   // All objects of these types qualify (there is no manual-creator filter).
   int lineCount = ArraySize(g_lines);
   for(int index = 0; index < lineCount; index++)
   {
      if(g_lines[index].touchMode) continue;
      string lineName = g_lines[index].lineName;
      if(!IsPriceLine(lineName))
         continue;

      int stateIndex = FindLine(lineName);
      if(stateIndex < 0 || !g_lines[stateIndex].enabled)
         continue;

      bool crossedUp = false, crossedDown = false;
      if(ObjectGetInteger(0, lineName, OBJPROP_TYPE) == OBJ_HLINE)
      {
         // Preserve the original horizontal-line close-break conditions.
         double linePrice = 0.0;
         if(!ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0, linePrice)) continue;
         crossedUp = (close[2] <= linePrice && close[1] > linePrice);
         crossedDown = (close[2] >= linePrice && close[1] < linePrice);
      }
      else
      {
         // MT4 plots each candle at its opening timestamp. Compare each CLOSED
         // candle's close against the trend at that candle's own chart timestamp.
         // Never substitute TimeCurrent(), time[0], or a single price for both.
         double previousLinePrice = 0.0, latestLinePrice = 0.0;
         if(!TrendPriceAt(lineName, time[2], previousLinePrice) ||
            !TrendPriceAt(lineName, time[1], latestLinePrice)) continue;
         crossedUp = (close[2] <= previousLinePrice && close[1] > latestLinePrice);
         crossedDown = (close[2] >= previousLinePrice && close[1] < latestLinePrice);
      }
      if(!crossedUp && !crossedDown)
         continue;

      string direction = crossedUp ? "UP_BREAK" : "DOWN_BREAK";
      // Disarm before notifying; a manual ON click is needed for another alert.
      g_lines[stateIndex].enabled = false;
      SaveState(stateIndex);
      UpdatePanel();
      // Use exactly the same message for the local alert and mobile push.
      string message = Symbol() + " | " + TimeframeText() + " | " + lineName
                       + " | Break | " + direction;
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
