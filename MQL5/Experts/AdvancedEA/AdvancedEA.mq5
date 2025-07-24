//+------------------------------------------------------------------+
//|                                                   AdvancedEA.mq5 |
//|                      Copyright 2023, OpenAI & Your Name/Company |
//|                                  https://www.mql5.com/en/users/ai |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, OpenAI & Your Name/Company"
#property link      "https://www.mql5.com/en/users/ai"
#property version   "1.00"
#property description "Advanced Expert Advisor with multiple strategies for MT5"

//--- Include CTrade for simplified trading
#include <Trade\Trade.mqh>
//--- Include Controls for GUI
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

// Enum for strategy indices
enum ENUM_STRATEGIES {
    STRAT_SMA20,
    STRAT_TREND_RIDING,
    STRAT_ZIGZAG,
    STRAT_VOLATILITY,
    STRAT_CORRELATION,
    STRAT_PRICE_PATTERNS,
    STRAT_SMC,
    STRAT_HNS,
    STRAT_RSI_DIV,
    STRAT_RSI_CROSS,
    STRAT_STOCH_CROSS,
    STRAT_MACD_CROSS,
    STRAT_IO_BARS,
    STRAT_PIN_BARS,
    STRAT_3BAR_REVERSAL,
    STRAT_FVG,
    TOTAL_STRATEGIES // Keep this last to represent the total count
};

//+------------------------------------------------------------------+
//| Class for the Information and Control Panel                      |
//+------------------------------------------------------------------+
class CInfoPanel : public CAppDialog
  {
private:
   // Panel objects
   CLabel      m_buy_votes_label;
   CLabel      m_sell_votes_label;
   // Dynamic controls
   CButton    *m_strategy_buttons[TOTAL_STRATEGIES];
   string      m_strategy_names[TOTAL_STRATEGIES];


public:
                     CInfoPanel(void);
                    ~CInfoPanel(void);
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   // Method to update vote counts
   void              UpdateVoteCounts(int buyVotes, int sellVotes);

protected:
   // Event handler for chart events
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
  };
//+------------------------------------------------------------------+
//| CInfoPanel constructor                                           |
//+------------------------------------------------------------------+
CInfoPanel::CInfoPanel(void)
  {
   m_strategy_names[STRAT_SMA20] = "SMA 20 Crossover";
   m_strategy_names[STRAT_TREND_RIDING] = "Trend Riding";
   m_strategy_names[STRAT_ZIGZAG] = "ZigZag Breakout";
   m_strategy_names[STRAT_VOLATILITY] = "Volatility Breakout";
   m_strategy_names[STRAT_CORRELATION] = "Correlation";
   m_strategy_names[STRAT_PRICE_PATTERNS] = "Engulfing Pattern";
   m_strategy_names[STRAT_SMC] = "Smart Money Concepts";
   m_strategy_names[STRAT_HNS] = "Head & Shoulders";
   m_strategy_names[STRAT_RSI_DIV] = "RSI Divergence";
   m_strategy_names[STRAT_RSI_CROSS] = "RSI OB/OS Crossover";
   m_strategy_names[STRAT_STOCH_CROSS] = "Stochastic Crossover";
   m_strategy_names[STRAT_MACD_CROSS] = "MACD Crossover";
   m_strategy_names[STRAT_IO_BARS] = "Inside/Outside Bars";
   m_strategy_names[STRAT_PIN_BARS] = "Pin Bars";
   m_strategy_names[STRAT_3BAR_REVERSAL] = "Three-Bar Reversal";
   m_strategy_names[STRAT_FVG] = "Fair Value Gaps";
  }
//+------------------------------------------------------------------+
//| CInfoPanel destructor                                            |
//+------------------------------------------------------------------+
CInfoPanel::~CInfoPanel(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the panel                                                 |
//+------------------------------------------------------------------+
bool CInfoPanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
//--- create the base dialog
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
//--- create controls
   int y_pos = 10;
   int x_pos = 10;
   int label_width = 200;
   int button_width = 60;

   // Title Label
   CLabel* title_label = new CLabel();
   Add(title_label);
   title_label.Create(m_chart.ChartId(),m_name+"_Title",m_subwin,x_pos,y_pos,x_pos+label_width,y_pos+20);
   title_label.Text("Strategy Status & Votes");
   y_pos += 25;

   // Vote Count Labels
   Add(m_buy_votes_label);
   m_buy_votes_label.Create(m_chart.ChartId(),m_name+"_BuyVotes",m_subwin,x_pos,y_pos,x_pos+label_width,y_pos+20);
   m_buy_votes_label.Text("Buy Votes: 0");
   m_buy_votes_label.Color(clrGreen);
   y_pos += 20;

   Add(m_sell_votes_label);
   m_sell_votes_label.Create(m_chart.ChartId(),m_name+"_SellVotes",m_subwin,x_pos,y_pos,x_pos+label_width,y_pos+20);
   m_sell_votes_label.Text("Sell Votes: 0");
   m_sell_votes_label.Color(clrRed);
   y_pos += 25;

   // --- Create a Label and Button for each Strategy ---
   for(int i=0; i<TOTAL_STRATEGIES; i++) {
      CLabel* strat_label = new CLabel();
      Add(strat_label);
      strat_label.Create(m_chart.ChartId(),m_name+"_label_"+(string)i,m_subwin,x_pos,y_pos,x_pos+label_width,y_pos+20);
      strat_label.Text(m_strategy_names[i]);

      m_strategy_buttons[i] = new CButton();
      Add(m_strategy_buttons[i]);
      string button_name = "Btn_Strat_"+(string)i;
      m_strategy_buttons[i].Create(m_chart.ChartId(),button_name,m_subwin,x_pos+label_width+5,y_pos,x_pos+label_width+5+button_width,y_pos+20);

      if(g_strategyEnabled[i]) {
         m_strategy_buttons[i].Text("ON");
         m_strategy_buttons[i].ColorBackground(clrGreen);
      } else {
         m_strategy_buttons[i].Text("OFF");
         m_strategy_buttons[i].ColorBackground(clrRed);
      }
      // The object's name IS its identifier. No need for the .Name() property.

      y_pos += 22; // Move down for the next row
   }

//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Update vote counts on the panel                                  |
//+------------------------------------------------------------------+
void CInfoPanel::UpdateVoteCounts(int buyVotes, int sellVotes)
  {
   m_buy_votes_label.Text("Buy Votes: " + (string)buyVotes);
   m_sell_votes_label.Text("Sell Votes: " + (string)sellVotes);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Event handler                                                    |
//+------------------------------------------------------------------+
bool CInfoPanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   //--- handle chart events
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      // sparam is the name of the clicked object
      // Our button names are "Btn_Strat_0", "Btn_Strat_1", etc.
      if(StringFind(sparam, "Btn_Strat_") == 0) {
         string strat_id_str = StringSubstr(sparam, 10); // Get the number part
         int strat_id = (int)StringToInteger(strat_id_str);

         if(strat_id >= 0 && strat_id < TOTAL_STRATEGIES) {
            // Toggle the strategy state
            g_strategyEnabled[strat_id] = !g_strategyEnabled[strat_id];

            // Update button appearance
            if(g_strategyEnabled[strat_id]) {
               m_strategy_buttons[strat_id].Text("ON");
               m_strategy_buttons[strat_id].ColorBackground(clrGreen);
            } else {
               m_strategy_buttons[strat_id].Text("OFF");
               m_strategy_buttons[strat_id].ColorBackground(clrRed);
            }
            ChartRedraw();
            return(true); // Event processed
         }
      }
     }
//---
   return(false);
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   g_info_panel.ChartEvent(id,lparam,dparam,sparam);
  }

//--- Input Parameters
input group "General Settings"
input int      MaxOrders         = 50;       // Maximum number of trade SETS
input double   LotSize           = 3.0;     // Total Lot Size for a set of 3 orders
input int      TakeProfitPips1   = 50;       // Take Profit for 1st partial order
input int      TakeProfitPips2   = 100;      // Take Profit for 2nd partial order
input int      TakeProfitPips3   = 150;      // Take Profit for 3rd partial order
input int      InitialStopLossPips = 500;    // Initial Stop Loss for all partial orders
input int      BreakevenPlusPips = 10;        // Pips to add to SL when moving to Breakeven
input bool     TightenSL_On_Opposing_Signal = true; // Tighten SL if an opposing signal occurs
input int      WaitPeriodMinutes = 1;        // Wait period in minutes for re-analysis
input string   MagicNumberSuffix = "AdvEA";  // Suffix for Magic Number

input group "Correlation Strategy"
input string   CorrelationSymbol = "EURUSD"; // Symbol for Correlation Strategy
input int      CorrelationPeriod = 14;       // Period for correlation calculation

input group "SMA Strategy"
input int      SMA_Period        = 20;       // SMA Period

input group "Trend Riding Strategy"
input int      TrendMA_Fast_Period = 10;     // Trend Riding Fast MA Period
input int      TrendMA_Slow_Period = 50;     // Trend Riding Slow MA Period
input int      ADX_Period        = 14;       // ADX Period for Trend Riding

input group "ZigZag Strategy"
input int      ZigZag_Depth      = 12;
input int      ZigZag_Deviation  = 5;
input int      ZigZag_Backstep   = 3;

input group "Volatility Strategy"
input int      BB_Period         = 20;       // Bollinger Bands Period for Volatility
input double   BB_Deviation      = 2.0;      // Bollinger Bands Deviation
input double   VolatilityThresholdMultiplier = 0.5; // Multiplier for ATR/BB Width to define low volatility

input group "RSI Divergence Strategy"
input int      RSI_Period        = 14;       // RSI Period
input ENUM_APPLIED_PRICE RSI_AppliedPrice = PRICE_CLOSE; // RSI Applied Price
input int      RSI_Overbought_Level = 70;      // RSI Overbought Level
input int      RSI_Oversold_Level = 30;      // RSI Oversold Level

input group "Stochastic Crossover Strategy"
input int      Stoch_K_Period    = 5;        // Stochastic K Period
input int      Stoch_D_Period    = 3;        // Stochastic D Period
input int      Stoch_Slowing     = 3;        // Stochastic Slowing
input ENUM_MA_METHOD Stoch_MA_Method = MODE_SMA; // Stochastic MA Method
input int      Stoch_Overbought_Level = 80;    // Stochastic Overbought Level
input int      Stoch_Oversold_Level = 20;    // Stochastic Oversold Level

input group "MACD Crossover Strategy"
input int      MACD_Fast_EMA_Period   = 12;     // MACD Fast EMA Period
input int      MACD_Slow_EMA_Period   = 26;     // MACD Slow EMA Period
input int      MACD_Signal_SMA_Period = 9;      // MACD Signal Line SMA Period
input ENUM_APPLIED_PRICE MACD_AppliedPrice = PRICE_CLOSE; // MACD Applied Price

input group "ATR Trailing Stop"
input bool     Use_ATR_TrailingStop = true;    // Enable/Disable ATR Trailing Stop
input int      ATR_Period           = 14;     // ATR Period for Trailing Stop & Keltner Channels
input double   ATR_Multiplier       = 2.0;    // ATR Multiplier for Trailing Stop

input group "Keltner Channel Strategy"
input int      KC_EMA_Period        = 20;     // EMA Period for Keltner Channel Middle Line
input double   KC_ATR_Multiplier    = 2.0;    // ATR Multiplier for Keltner Channel Bands

input group "Candlestick Patterns"
input double   PinBar_Wick_to_Body_Ratio = 2.0; // Min ratio of the main wick to the candle body for Pin Bar detection


input group "Trend Filter"
input bool     Use_Trend_Filter        = true; // Enable/Disable the long-term trend filter
input int      Trend_Filter_EMA_Period = 200;  // EMA Period for the trend filter

input group "Trade Management"
input bool     Use_Time_Based_Exit = true;     // Enable/Disable closing trades after N bars
input int      Max_Bars_Open       = 100;    // Max number of bars a trade can stay open

input group "Market Regime Filter"
input bool     Use_Market_Regime_Filter = true;  // Enable/Disable ADX Market Regime Filter
input int      Regime_ADX_Period        = 14;   // ADX Period for Regime Filter
input double   Regime_ADX_Trending_Threshold = 25.0; // ADX value above which market is considered trending

input group "--- Strategies (Initial State) ---"
input bool Inp_Enable_SMA20         = true;
input bool Inp_Enable_TrendRiding   = true;
input bool Inp_Enable_ZigZag        = true;
input bool Inp_Enable_Volatility    = true;
input bool Inp_Enable_Correlation   = true;
input bool Inp_Enable_PricePatterns = true;
input bool Inp_Enable_SMC           = true;
input bool Inp_Enable_HnS           = true;
input bool Inp_Enable_RsiDiv        = true;
input bool Inp_Enable_RsiCross      = true;
input bool Inp_Enable_StochCross    = true;
input bool Inp_Enable_MacdCross     = true;
input bool Inp_Enable_IOBars        = true;
input bool Inp_Enable_PinBars       = true;
input bool Inp_Enable_3BarReversal  = true;
input bool Inp_Enable_FVG           = true;

input group "--- Strategy Weights ---"
input int Weight_SMA20         = 1;
input int Weight_TrendRiding   = 1;
input int Weight_ZigZag        = 2;
input int Weight_Volatility    = 1;
input int Weight_Correlation   = 1;
input int Weight_PricePatterns = 2;
input int Weight_SMC           = 3;
input int Weight_HnS           = 3;
input int Weight_RsiDiv        = 3;
input int Weight_RsiCross      = 1;
input int Weight_StochCross    = 1;
input int Weight_MacdCross     = 1;
input int Weight_IOBars        = 2;
input int Weight_PinBars       = 2;
input int Weight_3BarReversal  = 2;
input int Weight_FVG           = 3;


//--- Global Variables
bool     g_strategyEnabled[TOTAL_STRATEGIES]; // Runtime state of each strategy
datetime LastAnalysisTime = 0;
int      g_EffectiveWaitPeriodMinutes; // To avoid input modification issues
int      BuyVotes = 0;
int      SellVotes = 0;
ulong    MagicNumberBase; // Will be constructed in OnInit
int      g_setCounter = 0;      // Counter for trade sets to generate unique magic numbers

//--- Indicator Handles
int      hSMA;
int      hADX;
int      hTrendMAFast;
int      hTrendMASlow;
int      hZigZag;
int      hBands;
int      hRSI;
int      hStoch;
int      hMACD;
int      hATR;
int      hKC_EMA;
int      hTrendFilterEMA;
int      hRegimeADX;
// For correlation symbol data
int      hCorrSymbolSMA; // Example if needed, direct price usually better

//--- CTrade instance
CTrade   trade;
//--- GUI Panel instance
CInfoPanel   g_info_panel;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    //---
    if (WaitPeriodMinutes < 1) {
        printf("Input WaitPeriodMinutes '%d' is less than 1. Effective wait period set to 1 minute.", WaitPeriodMinutes);
        g_EffectiveWaitPeriodMinutes = 1;
    } else {
        g_EffectiveWaitPeriodMinutes = WaitPeriodMinutes;
    }
    // Generate a unique magic number for this chart instance
    MagicNumberBase = StringToInteger(Symbol()) + Period() + StringToInteger(MagicNumberSuffix);

    // Initialize strategy states from inputs
    g_strategyEnabled[STRAT_SMA20] = Inp_Enable_SMA20;
    g_strategyEnabled[STRAT_TREND_RIDING] = Inp_Enable_TrendRiding;
    g_strategyEnabled[STRAT_ZIGZAG] = Inp_Enable_ZigZag;
    g_strategyEnabled[STRAT_VOLATILITY] = Inp_Enable_Volatility;
    g_strategyEnabled[STRAT_CORRELATION] = Inp_Enable_Correlation;
    g_strategyEnabled[STRAT_PRICE_PATTERNS] = Inp_Enable_PricePatterns;
    g_strategyEnabled[STRAT_SMC] = Inp_Enable_SMC;
    g_strategyEnabled[STRAT_HNS] = Inp_Enable_HnS;
    g_strategyEnabled[STRAT_RSI_DIV] = Inp_Enable_RsiDiv;
    g_strategyEnabled[STRAT_RSI_CROSS] = Inp_Enable_RsiCross;
    g_strategyEnabled[STRAT_STOCH_CROSS] = Inp_Enable_StochCross;
    g_strategyEnabled[STRAT_MACD_CROSS] = Inp_Enable_MacdCross;
    g_strategyEnabled[STRAT_IO_BARS] = Inp_Enable_IOBars;
    g_strategyEnabled[STRAT_PIN_BARS] = Inp_Enable_PinBars;
    g_strategyEnabled[STRAT_3BAR_REVERSAL] = Inp_Enable_3BarReversal;
    g_strategyEnabled[STRAT_FVG] = Inp_Enable_FVG;

    LastAnalysisTime = TimeCurrent() - (g_EffectiveWaitPeriodMinutes * 60); // Ensure first run
    printf("AdvancedEA Initialized. MaxOrders (Sets): %d, Total LotSize: %.2f, TP1: %d, TP2: %d, TP3: %d, InitialSL: %d, EffectiveWait: %d, MagicSuffix: %s",
           MaxOrders, LotSize, TakeProfitPips1, TakeProfitPips2, TakeProfitPips3, InitialStopLossPips, g_EffectiveWaitPeriodMinutes, MagicNumberSuffix); // MagicNumberBase is ulong

    //--- Initialize indicators
    hSMA = iMA(_Symbol, _Period, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);
    if(hSMA == INVALID_HANDLE) { printf("Error creating SMA indicator"); return(INIT_FAILED); }

    hADX = iADX(_Symbol, _Period, ADX_Period);
    if(hADX == INVALID_HANDLE) { printf("Error creating ADX indicator"); return(INIT_FAILED); }

    hTrendMAFast = iMA(_Symbol, _Period, TrendMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    if(hTrendMAFast == INVALID_HANDLE) { printf("Error creating Trend Fast MA indicator"); return(INIT_FAILED); }

    hTrendMASlow = iMA(_Symbol, _Period, TrendMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    if(hTrendMASlow == INVALID_HANDLE) { printf("Error creating Trend Slow MA indicator"); return(INIT_FAILED); }

    hZigZag = iCustom(_Symbol, _Period, "Examples\\ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep);
    if(hZigZag == INVALID_HANDLE) { printf("Error creating ZigZag indicator (check path 'Examples\\\\ZigZag')"); return(INIT_FAILED); }
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits); // For ZigZag display if needed

    hBands = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    if(hBands == INVALID_HANDLE) { printf("Error creating Bollinger Bands indicator"); return(INIT_FAILED); }

    hRSI = iRSI(_Symbol, _Period, RSI_Period, RSI_AppliedPrice);
    if(hRSI == INVALID_HANDLE) { printf("Error creating RSI indicator"); return(INIT_FAILED); }

    hStoch = iStochastic(_Symbol, _Period, Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, Stoch_MA_Method, STO_LOWHIGH);
    if(hStoch == INVALID_HANDLE) { printf("Error creating Stochastic indicator"); return(INIT_FAILED); }

    hMACD = iMACD(_Symbol, _Period, MACD_Fast_EMA_Period, MACD_Slow_EMA_Period, MACD_Signal_SMA_Period, MACD_AppliedPrice);
    if(hMACD == INVALID_HANDLE) { printf("Error creating MACD indicator"); return(INIT_FAILED); }

    hATR = iATR(_Symbol, _Period, ATR_Period);
    if(hATR == INVALID_HANDLE) { printf("Error creating ATR indicator"); return(INIT_FAILED); }

    hKC_EMA = iMA(_Symbol, _Period, KC_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    if(hKC_EMA == INVALID_HANDLE) { printf("Error creating Keltner Channel EMA indicator"); return(INIT_FAILED); }

    hTrendFilterEMA = iMA(_Symbol, _Period, Trend_Filter_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    if(hTrendFilterEMA == INVALID_HANDLE) { printf("Error creating Trend Filter EMA indicator"); return(INIT_FAILED); }

    hRegimeADX = iADX(_Symbol, _Period, Regime_ADX_Period);
    if(hRegimeADX == INVALID_HANDLE) { printf("Error creating Regime Filter ADX indicator"); return(INIT_FAILED); }

    trade.SetExpertMagicNumber(MagicNumberBase);
    trade.SetDeviationInPoints(3); // Slippage

    //--- Create GUI Panel ---
    if(!g_info_panel.Create(0,"AdvancedEA_Panel",0,20,50,300,400)) {
        printf("Error creating GUI panel");
        return(INIT_FAILED);
    }
    if(!g_info_panel.Run()) {
        printf("Error running GUI panel");
        return(INIT_FAILED);
    }

    //---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //--- Destroy panel
    g_info_panel.Destroy(reason);
    //--- Release indicator handles
    IndicatorRelease(hSMA);
    IndicatorRelease(hADX);
    IndicatorRelease(hTrendMAFast);
    IndicatorRelease(hTrendMASlow);
    IndicatorRelease(hZigZag);
    IndicatorRelease(hBands);
    IndicatorRelease(hRSI);
    IndicatorRelease(hStoch);
    IndicatorRelease(hMACD);
    IndicatorRelease(hATR);
    IndicatorRelease(hKC_EMA);
    IndicatorRelease(hTrendFilterEMA);
    IndicatorRelease(hRegimeADX);
    printf("AdvancedEA Deinitialized. Reason: %d", reason);
    //---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //--- Check if it's time to analyze
    if (TimeCurrent() - LastAnalysisTime >= g_EffectiveWaitPeriodMinutes * 60) {
         // It's time to check. Reset the timer for the next interval.
         LastAnalysisTime = TimeCurrent();

         MqlRates rates[];
         if(CopyRates(_Symbol, _Period, 0, 1, rates) > 0) { // Check if new bar started for the current timeframe
            static datetime lastBarTime = 0;
            if (rates[0].time != lastBarTime) {
                lastBarTime = rates[0].time;
                printf("New bar detected. Analyzing market...");
                ResetVotes();
                AnalyzeStrategies();
                ProcessTradeDecisions();
            }
         }
    }
    // Call trade management on every tick
    ManageOpenTrades();
}

//+------------------------------------------------------------------+
//| Reset Buy/Sell Votes                                             |
//+------------------------------------------------------------------+
void ResetVotes(){
    BuyVotes = 0;
    SellVotes = 0;
}

//+------------------------------------------------------------------+
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift) {
    double val[];
    if (CopyBuffer(handle, buffer, shift, 1, val) > 0) {
        return val[0];
    }
    // Return an unlikely value or handle error appropriately
    printf("Error copying buffer for handle %d, buffer %d, shift %d. Error: %d", handle, buffer, shift, GetLastError());
    return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Analyze strategies and vote                                      |
//+------------------------------------------------------------------+
void AnalyzeStrategies() {
    bool analysis_enabled[TOTAL_STRATEGIES];
    ArrayCopy(analysis_enabled, g_strategyEnabled, 0, 0, WHOLE_ARRAY);

    // --- Apply Market Regime Filter ---
    if(Use_Market_Regime_Filter) {
        double adx_value = GetIndicatorValue(hRegimeADX, MAIN_LINE, 1);
        if(adx_value != EMPTY_VALUE) {
            if(adx_value > Regime_ADX_Trending_Threshold) { // --- TRENDING MARKET ---
                printf("Market Regime: TRENDING (ADX=%.2f). Disabling range/reversal strategies.", adx_value);
                analysis_enabled[STRAT_RSI_DIV] = false;
                analysis_enabled[STRAT_RSI_CROSS] = false;
                analysis_enabled[STRAT_STOCH_CROSS] = false;
                analysis_enabled[STRAT_PIN_BARS] = false;
                analysis_enabled[STRAT_3BAR_REVERSAL] = false;
                analysis_enabled[STRAT_FVG] = false;
            } else { // --- RANGING MARKET ---
                printf("Market Regime: RANGING (ADX=%.2f). Disabling trend-following strategies.", adx_value);
                analysis_enabled[STRAT_TREND_RIDING] = false;
                analysis_enabled[STRAT_MACD_CROSS] = false;
                // We keep SMA20 as it can give signals in both
            }
        }
    }

    // --- Execute Enabled Strategies ---
    if(analysis_enabled[STRAT_SMA20]) AnalyzeSMA20();
    if(analysis_enabled[STRAT_TREND_RIDING]) AnalyzeTrendRiding();
    if(analysis_enabled[STRAT_ZIGZAG]) AnalyzeZigZagBreakout();
    if(analysis_enabled[STRAT_VOLATILITY]) AnalyzeDecreasedVolatilityBreakout();
    if(analysis_enabled[STRAT_CORRELATION]) AnalyzeCorrelation();
    if(analysis_enabled[STRAT_PRICE_PATTERNS]) AnalyzePricePatterns();
    if(analysis_enabled[STRAT_SMC]) AnalyzeSmartMoneyConcepts();
    if(analysis_enabled[STRAT_HNS]) AnalyzeHeadAndShoulders();
    if(analysis_enabled[STRAT_RSI_DIV]) AnalyzeRsiDivergence();
    if(analysis_enabled[STRAT_RSI_CROSS]) AnalyzeRsiCrossover();
    if(analysis_enabled[STRAT_STOCH_CROSS]) AnalyzeStochasticCrossover();
    if(analysis_enabled[STRAT_MACD_CROSS]) AnalyzeMacdCrossover();
    if(analysis_enabled[STRAT_IO_BARS]) AnalyzeInsideOutsideBars();
    if(analysis_enabled[STRAT_PIN_BARS]) AnalyzePinBars();
    if(analysis_enabled[STRAT_3BAR_REVERSAL]) AnalyzeThreeBarReversal();
    if(analysis_enabled[STRAT_FVG]) AnalyzeFairValueGaps();

    // --- Apply Long-Term Trend Filter ---
    if(Use_Trend_Filter) {
        double trend_ema_value = GetIndicatorValue(hTrendFilterEMA, 0, 1);
        MqlRates rates[];
        if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0) {
            double close_price = rates[0].close;
            if(close_price > trend_ema_value) { // Uptrend
                if(SellVotes > 0) {
                    printf("Trend Filter: Ignoring %d sell votes due to long-term uptrend.", SellVotes);
                    SellVotes = 0;
                }
            } else if (close_price < trend_ema_value) { // Downtrend
                if(BuyVotes > 0) {
                    printf("Trend Filter: Ignoring %d buy votes due to long-term downtrend.", BuyVotes);
                    BuyVotes = 0;
                }
            }
        }
    }

    printf("Analysis Complete. Final Buy Votes: %d, Final Sell Votes: %d", BuyVotes, SellVotes);
    g_info_panel.UpdateVoteCounts(BuyVotes, SellVotes);
}

//+------------------------------------------------------------------+
//| Strategy 1: SMA 20                                               |
//+------------------------------------------------------------------+
void AnalyzeSMA20() {
    double smaValue = GetIndicatorValue(hSMA, 0, 0);
    if(smaValue == EMPTY_VALUE) return;

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, 2, rates) < 2) return; // Need 2 previous bars
    double closePrice1 = rates[1].close; // Previous bar close (rates[0] is current, rates[1] is previous)
    double closePrice2 = rates[0].close; // Bar before previous (rates[0] is oldest here, rates[1] is newest if CopyRates from past)
                                        // Let's re-copy for clarity
    if(CopyRates(_Symbol, _Period, 1, 2, rates) <2) return; // rates[0] is shift 2, rates[1] is shift 1
    closePrice1 = rates[1].close; // previous bar
    closePrice2 = rates[0].close; // bar before previous


    if(CopyRates(_Symbol, _Period, 0, 3, rates) <3) return; // rates[0] = current (incomplete), rates[1]=prev, rates[2]=prev-1
    // For calculations based on closed bars:
    smaValue = GetIndicatorValue(hSMA, 0, 1); // SMA of the previous bar
    if(smaValue == EMPTY_VALUE) return;
    closePrice1 = rates[1].close; // Previous bar close
    closePrice2 = rates[2].close; // Bar before previous


    if (closePrice1 > smaValue && closePrice2 <= smaValue) {
        BuyVotes += Weight_SMA20;
        printf("Strategy [SMA20]: Buy Signal (Price crossed above SMA). Adding %d votes.", Weight_SMA20);
    } else if (closePrice1 < smaValue && closePrice2 >= smaValue) {
        SellVotes += Weight_SMA20;
        printf("Strategy [SMA20]: Sell Signal (Price crossed below SMA). Adding %d votes.", Weight_SMA20);
    } else if (closePrice1 > smaValue) {
        BuyVotes += Weight_SMA20;
        printf("Strategy [SMA20]: Buy Signal (Price is above SMA). Adding %d votes.", Weight_SMA20);
    } else if (closePrice1 < smaValue) {
        SellVotes += Weight_SMA20;
        printf("Strategy [SMA20]: Sell Signal (Price is below SMA). Adding %d votes.", Weight_SMA20);
    } else {
        printf("Strategy [SMA20]: No signal.");
    }
}

//+------------------------------------------------------------------+
//| Strategy 2: Trend Riding (using ADX and MAs)                     |
//+------------------------------------------------------------------+
void AnalyzeTrendRiding() {
    double adxValue = GetIndicatorValue(hADX, MAIN_LINE, 1); // ADX on previous bar
    double plusDI   = GetIndicatorValue(hADX, PLUSDI_LINE, 1);
    double minusDI  = GetIndicatorValue(hADX, MINUSDI_LINE, 1);

    double fastMA   = GetIndicatorValue(hTrendMAFast, 0, 1);
    double slowMA   = GetIndicatorValue(hTrendMASlow, 0, 1);

    if(adxValue == EMPTY_VALUE || plusDI == EMPTY_VALUE || minusDI == EMPTY_VALUE || fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE) return;

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, 3, rates) < 3) return; // rates[0]=shift 3, rates[1]=shift 2, rates[2]=shift 1

    double close1 = rates[2].close; // Previous bar
    double low1 = rates[2].low;
    double high1 = rates[2].high;
    double close2 = rates[1].close; // Bar before previous


    bool signalFound = false;
    if (adxValue > 25) {
        if (plusDI > minusDI && fastMA > slowMA) { // Uptrend
            if (close1 > fastMA && low1 <= fastMA) {
                 BuyVotes += Weight_TrendRiding;
                 printf("Strategy [TrendRiding]: Buy Signal (Strong uptrend with pullback to Fast MA). Adding %d votes.", Weight_TrendRiding);
                 signalFound = true;
            } else if (close1 > slowMA && close2 <= slowMA) {
                 BuyVotes += Weight_TrendRiding;
                 printf("Strategy [TrendRiding]: Buy Signal (Strong uptrend, price crossed Slow MA). Adding %d votes.", Weight_TrendRiding);
                 signalFound = true;
            }
        } else if (minusDI > plusDI && fastMA < slowMA) { // Downtrend
            if (close1 < fastMA && high1 >= fastMA) {
                 SellVotes += Weight_TrendRiding;
                 printf("Strategy [TrendRiding]: Sell Signal (Strong downtrend with pullback to Fast MA). Adding %d votes.", Weight_TrendRiding);
                 signalFound = true;
            } else if (close1 < slowMA && close2 >= slowMA) {
                 SellVotes += Weight_TrendRiding;
                 printf("Strategy [TrendRiding]: Sell Signal (Strong downtrend, price crossed Slow MA). Adding %d votes.", Weight_TrendRiding);
                 signalFound = true;
            }
        }
    } else {
        printf("Strategy [TrendRiding]: No signal (ADX < 25 indicates weak trend).");
        signalFound = true; // Mark as "processed" to avoid the final "no signal" message
    }

    if(!signalFound) {
        printf("Strategy [TrendRiding]: No signal (Trending conditions not met).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 3: Breakout Trading using ZigZag Indicator              |
//+------------------------------------------------------------------+
void AnalyzeZigZagBreakout() {
    double highZigZagBuffer[], lowZigZagBuffer[];
    int lookbackZigZag = 200; // How many bars to look back for ZigZag points

    if (CopyBuffer(hZigZag, 1, 1, lookbackZigZag, highZigZagBuffer) <= 0 ||
        CopyBuffer(hZigZag, 2, 1, lookbackZigZag, lowZigZagBuffer) <= 0) {
        printf("ZigZag: Error copying ZigZag buffers.");
        return;
    }

    double lastHighZigZag = 0;
    double lastLowZigZag = 0;

    for (int i = 0; i < lookbackZigZag; i++) { // Zigzag buffers are filled backwards from current (idx 0 = shift 1)
        if (highZigZagBuffer[i] != 0 && highZigZagBuffer[i] != EMPTY_VALUE) {
            lastHighZigZag = highZigZagBuffer[i];
            break;
        }
    }
    for (int i = 0; i < lookbackZigZag; i++) {
        if (lowZigZagBuffer[i] != 0 && lowZigZagBuffer[i] != EMPTY_VALUE) {
            lastLowZigZag = lowZigZagBuffer[i];
            break;
        }
    }

    if (lastHighZigZag == 0 || lastLowZigZag == 0) {
        printf("Strategy [ZigZag]: No signal (Could not find recent ZigZag points).");
        return;
    }

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return; // rates[0]=current (incomplete), rates[1]=previous closed
    double currentHigh = rates[0].high; // Current bar's high so far
    double currentLow = rates[0].low;   // Current bar's low so far
    double prevClose = rates[1].close;  // Previous bar's close

    if (prevClose > lastHighZigZag && currentHigh > lastHighZigZag) {
        BuyVotes += Weight_ZigZag;
        printf("Strategy [ZigZag]: Buy Signal (Breakout above last high %s). Adding %d votes.", DoubleToString(lastHighZigZag, _Digits), Weight_ZigZag);
    } else if (prevClose < lastLowZigZag && currentLow < lastLowZigZag) {
        SellVotes += Weight_ZigZag;
        printf("Strategy [ZigZag]: Sell Signal (Breakout below last low %s). Adding %d votes.", DoubleToString(lastLowZigZag, _Digits), Weight_ZigZag);
    } else {
        printf("Strategy [ZigZag]: No signal (Price is within last ZigZag high/low).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 4: Decreased Volatility Breakout (Bollinger Bands Width)|
//+------------------------------------------------------------------+
void AnalyzeDecreasedVolatilityBreakout() {
    double upperBand1 = GetIndicatorValue(hBands, 1, 1); // Upper band, previous bar
    double lowerBand1 = GetIndicatorValue(hBands, 2, 1); // Lower band, previous bar
    if(upperBand1 == EMPTY_VALUE || lowerBand1 == EMPTY_VALUE) return;
    double bandWidth1 = upperBand1 - lowerBand1;

    double avgBandWidth = 0;
    int count = 0;
    for(int i = 2; i <= BB_Period + 1; i++){ // Shift back further, from 2 to BB_Period+1
        double ub = GetIndicatorValue(hBands, 1, i);
        double lb = GetIndicatorValue(hBands, 2, i);
        if(ub != EMPTY_VALUE && lb != EMPTY_VALUE && ub !=0 && lb !=0){
            avgBandWidth += (ub-lb);
            count++;
        }
    }
    if(count > 0) avgBandWidth /= count; else return;

    MqlRates rates[]; // rates[0]=current(incomplete), rates[1]=prev closed
    if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return;
    double currentClose = rates[0].close;
    double prevClose    = rates[1].close;

    double upperBand0 = GetIndicatorValue(hBands, 1, 0); // Upper band, current bar
    double lowerBand0 = GetIndicatorValue(hBands, 2, 0); // Lower band, current bar
    if(upperBand0 == EMPTY_VALUE || lowerBand0 == EMPTY_VALUE) return;


    if (bandWidth1 < avgBandWidth * VolatilityThresholdMultiplier) {
        // printf("Volatility: Low volatility detected (BB Squeeze). Bandwidth: %s, Avg Bandwidth: %s", DoubleToString(bandWidth1,_Digits), DoubleToString(avgBandWidth,_Digits));
        if (currentClose > upperBand0 && prevClose <= upperBand1 ) {
            BuyVotes += Weight_Volatility;
            printf("Strategy [Volatility]: Buy Signal (Breakout above Upper Band after squeeze). Adding %d votes.", Weight_Volatility);
        } else if (currentClose < lowerBand0 && prevClose >= lowerBand1 ) {
            SellVotes += Weight_Volatility;
            printf("Strategy [Volatility]: Sell Signal (Breakout below Lower Band after squeeze). Adding %d votes.", Weight_Volatility);
        } else {
            printf("Strategy [Volatility]: No signal (Low volatility squeeze detected, but no breakout yet).");
        }
    } else {
         printf("Strategy [Volatility]: No signal (Normal or High volatility, no squeeze).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 5: Correlation Trading                                  |
//+------------------------------------------------------------------+
void AnalyzeCorrelation() {
    if (CorrelationSymbol == "" || CorrelationSymbol == _Symbol) {
        printf("Correlation: Invalid or same CorrelationSymbol. Skipping.");
        return;
    }

    long barsCorr = SeriesInfoInteger(CorrelationSymbol, _Period, SERIES_BARS_COUNT);
    if(barsCorr < CorrelationPeriod + 5){
        printf("Correlation: Not enough data for %s on timeframe %s", CorrelationSymbol, EnumToString(_Period));
        return;
    }

    MqlRates ratesCurrentSymbol[], ratesCorrSymbol[];
    if(CopyRates(_Symbol, _Period, 0, CorrelationPeriod + 1, ratesCurrentSymbol) < CorrelationPeriod +1) return;
    if(CopyRates(CorrelationSymbol, _Period, 0, CorrelationPeriod + 1, ratesCorrSymbol) < CorrelationPeriod +1) return;

    // ratesCurrentSymbol[0] is current incomplete bar, ratesCurrentSymbol[CorrelationPeriod] is (CorrelationPeriod) bars ago
    double currentSymbolClose0 = ratesCurrentSymbol[0].close;
    double currentSymbolCloseN = ratesCurrentSymbol[CorrelationPeriod].close;
    if(currentSymbolCloseN == 0) return; // Avoid division by zero
    double currentSymbolChange = (currentSymbolClose0 - currentSymbolCloseN) / currentSymbolCloseN;

    double corrSymbolClose0 = ratesCorrSymbol[0].close;
    double corrSymbolCloseN = ratesCorrSymbol[CorrelationPeriod].close;
    if(corrSymbolCloseN == 0) return; // Avoid division by zero
    double correlationSymbolChange = (corrSymbolClose0 - corrSymbolCloseN) / corrSymbolCloseN;

    bool signalFound = false;
    if (correlationSymbolChange > 0.001) { // Threshold for "significant" move
        if (currentSymbolChange < correlationSymbolChange * 0.5) { // Current symbol lagging
             BuyVotes += Weight_Correlation;
             printf("Strategy [Correlation]: Buy Signal (Positive correlation with %s, which is bullish). Adding %d votes.", CorrelationSymbol, Weight_Correlation);
             signalFound = true;
        }
    } else if (correlationSymbolChange < -0.001) { // Threshold for "significant" move
        if (currentSymbolChange > correlationSymbolChange * 0.5) { // Current symbol lagging
             SellVotes += Weight_Correlation;
             printf("Strategy [Correlation]: Sell Signal (Positive correlation with %s, which is bearish). Adding %d votes.", CorrelationSymbol, Weight_Correlation);
             signalFound = true;
        }
    }

    if(!signalFound) {
        printf("Strategy [Correlation]: No signal (No significant divergence in correlation found).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 6: Price Patterns (Engulfing)                           |
//+------------------------------------------------------------------+
void AnalyzePricePatterns() {
    MqlRates rates[]; // rates[0]=current(incomplete), rates[1]=prev, rates[2]=prev-1
    if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return; // Need current and previous bar data

    double open1  = rates[1].open;  // Previous bar open
    double close1 = rates[1].close; // Previous bar close
    double open0  = rates[0].open;   // Current bar open (at the moment of tick)
    double close0 = rates[0].close;  // Current bar close (at the moment of tick)

    // Bullish Engulfing on the PREVIOUS completed bar relative to the one before it
    // We need data for bar at shift 1 and shift 2
    if(CopyRates(_Symbol, _Period, 1, 2, rates) < 2) return; // rates[0] = shift 2, rates[1] = shift 1
    open1  = rates[1].open;  // Bar at shift 1 (previous bar)
    close1 = rates[1].close; // Bar at shift 1
    double open2  = rates[0].open;   // Bar at shift 2 (bar before previous)
    double close2 = rates[0].close;  // Bar at shift 2

    // Bullish Engulfing: Bar at shift 1 engulfs bar at shift 2
    // 1. Bar at shift 2 is bearish (close2 < open2)
    // 2. Bar at shift 1 is bullish (close1 > open1)
    // 3. Bar 1's body engulfs Bar 2's body (open1 < close2 && close1 > open2)
    if (close2 < open2 && close1 > open1 && open1 <= close2 && close1 >= open2) {
        BuyVotes += Weight_PricePatterns;
        printf("Strategy [PricePattern]: Buy Signal (Bullish Engulfing). Adding %d votes.", Weight_PricePatterns);
    }
    // Bearish Engulfing: Bar at shift 1 engulfs bar at shift 2
    // 1. Bar at shift 2 is bullish (close2 > open2)
    // 2. Bar at shift 1 is bearish (close1 < open1)
    // 3. Bar 1's body engulfs Bar 2's body (open1 > close2 && close1 < open2)
    else if (close2 > open2 && close1 < open1 && open1 >= close2 && close1 <= open2) {
        SellVotes += Weight_PricePatterns;
        printf("Strategy [PricePattern]: Sell Signal (Bearish Engulfing). Adding %d votes.", Weight_PricePatterns);
    } else {
        printf("Strategy [PricePattern]: No signal (No Engulfing pattern detected).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 7: Smart Money Concepts (Basic Order Block)             |
//+------------------------------------------------------------------+
void AnalyzeSmartMoneyConcepts() {
    int lookback = 5;
    int structureLookback = lookback + 10; // Look further for structure points
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, structureLookback + 2, rates) < structureLookback + 2) return;
    // rates[0] is current, rates[1] is shift 1, etc.

    double highestHigh = 0;
    double lowestLow = DBL_MAX;
    int    bosHighBarIndex = -1; // Index in 'rates' array
    int    bosLowBarIndex = -1;  // Index in 'rates' array

    // Find recent highest high and lowest low (structure points) from SHIFT 2 to structureLookback+1
    // (Excluding current bar rates[0] and previous bar rates[1] for structure definition)
    for (int i = 2; i <= structureLookback + 1; i++) {
        if (rates[i].high > highestHigh) highestHigh = rates[i].high;
        if (rates[i].low < lowestLow) lowestLow = rates[i].low;
    }

    // Bullish Scenario: Break of recent high (highestHigh) by rates[1] or rates[0]
    // And identify the down candle (order block) before that break.
    // Check if rates[1] (previous closed bar) broke structure
    if (rates[1].high > highestHigh) {
        bosHighBarIndex = 1;
    }
    // Or if rates[0] (current bar) broke structure (more aggressive)
    else if (rates[0].high > highestHigh && rates[1].high <= highestHigh) {
         bosHighBarIndex = 0;
    }

    if (bosHighBarIndex != -1) { // Break of Structure High identified
        // Find the last down candle (from bosHighBarIndex + 1 up to lookback bars prior)
        for (int j = bosHighBarIndex + 1; j <= bosHighBarIndex + lookback + 1 && j < ArraySize(rates) ; j++) {
            if (rates[j].close < rates[j].open) { // Down candle at index j
                double obHigh = rates[j].high;
                double obLow = rates[j].low;
                // Check if current price (rates[0].close) is retesting this OB's range
                if (rates[0].close >= obLow && rates[0].close <= obHigh &&
                    rates[0].low <= obHigh && rates[0].low >= obLow * 0.995 ) { // Price entered OB zone (allow slight penetration for low)
                    BuyVotes += Weight_SMC;
                    printf("Strategy [SMC]: Buy Signal (Retest of Bullish Order Block at %s after BoS). Adding %d votes.", TimeToString(rates[j].time), Weight_SMC);
                    return;
                }
            }
        }
    }

    // Bearish Scenario: Break of recent low (lowestLow) by rates[1] or rates[0]
    // Check if rates[1] (previous closed bar) broke structure
    if (rates[1].low < lowestLow) {
        bosLowBarIndex = 1;
    }
    // Or if rates[0] (current bar) broke structure
    else if (rates[0].low < lowestLow && rates[1].low >= lowestLow) {
        bosLowBarIndex = 0;
    }

    if (bosLowBarIndex != -1) { // Break of Structure Low identified
        // Find the last up candle (from bosLowBarIndex + 1 up to lookback bars prior)
        for (int j = bosLowBarIndex + 1; j <= bosLowBarIndex + lookback + 1 && j < ArraySize(rates); j++) {
            if (rates[j].close > rates[j].open) { // Up candle at index j
                double obHigh = rates[j].high;
                double obLow = rates[j].low;
                if (rates[0].close <= obHigh && rates[0].close >= obLow &&
                    rates[0].high >= obLow && rates[0].high <= obHigh * 1.005) { // Price entered OB zone (allow slight penetration for high)
                    SellVotes += Weight_SMC;
                    printf("Strategy [SMC]: Sell Signal (Retest of Bearish Order Block at %s after BoS). Adding %d votes.", TimeToString(rates[j].time), Weight_SMC);
                    return;
                }
            }
        }
    }

    printf("Strategy [SMC]: No signal (No BoS + Order Block retest found).");
}


//+------------------------------------------------------------------+
//| Helper Functions to Check for Open Trade Sets                    |
//+------------------------------------------------------------------+
bool IsBuySetOpen() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionSelectByTicket(PositionGetTicket(i))) {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_MAGIC) == (MagicNumberBase + 0) &&
                PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                return true; // Found the first partial of a buy set
            }
        }
    }
    return false;
}

bool IsSellSetOpen() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionSelectByTicket(PositionGetTicket(i))) {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_MAGIC) == (MagicNumberBase + 0) &&
                PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                return true; // Found the first partial of a sell set
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Process Trade Decisions and Place Orders                         |
//+------------------------------------------------------------------+
void ProcessTradeDecisions() {
    // --- Tighten SL on Opposing Signal Logic ---
    if (TightenSL_On_Opposing_Signal) {
        MqlRates rates[];
        if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0) { // Get previous bar data
            if (IsBuySetOpen() && SellVotes > BuyVotes) {
                printf("Opposing SELL signal detected while BUY set is open. Tightening SL.");
                double new_sl = rates[0].low; // Low of the previous candle
                // This logic needs to find ALL partials of the set.
                // We only know one set is open because IsBuySetOpen is true.
                for (int i = PositionsTotal() - 1; i >= 0; i--) {
                    if (PositionSelectByTicket(PositionGetTicket(i))) {
                        if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                             long pos_magic = PositionGetInteger(POSITION_MAGIC);
                             if((ulong)pos_magic >= MagicNumberBase && (pos_magic % 10) < 3) { // Check if it's one of our partials
                                if (new_sl > PositionGetDouble(POSITION_SL)) {
                                    trade.PositionModify(PositionGetTicket(i), new_sl, PositionGetDouble(POSITION_TP));
                                    printf("Tightened SL for BUY Ticket %llu to %.5f", PositionGetTicket(i), new_sl);
                                }
                             }
                        }
                    }
                }
                return; // Stop further processing to avoid opening a new trade
            }
            if (IsSellSetOpen() && BuyVotes > SellVotes) {
                printf("Opposing BUY signal detected while SELL set is open. Tightening SL.");
                double new_sl = rates[0].high; // High of the previous candle
                for (int i = PositionsTotal() - 1; i >= 0; i--) {
                    if (PositionSelectByTicket(PositionGetTicket(i))) {
                        if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                            long pos_magic = PositionGetInteger(POSITION_MAGIC);
                            if((ulong)pos_magic >= MagicNumberBase && (pos_magic % 10) < 3) { // Check if it's one of our partials
                                if (new_sl < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0) {
                                     trade.PositionModify(PositionGetTicket(i), new_sl, PositionGetDouble(POSITION_TP));
                                     printf("Tightened SL for SELL Ticket %llu to %.5f", PositionGetTicket(i), new_sl);
                                }
                            }
                        }
                    }
                }
                return; // Stop further processing
            }
        }
    }

    // --- Standard Trade Opening Logic ---
    if (CountOpenPositions() >= MaxOrders) {
        printf("Max positions reached (%d sets). No new trade.", CountOpenPositions());
        return;
    }

    // Lot Size Calculation for 3 partial orders
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    double partialLotSize = LotSize / 3.0;

    // Normalize to lot step
    partialLotSize = MathRound(partialLotSize / lotStep) * lotStep;

    // Enforce minimum lot size
    if (partialLotSize < minLot) {
        partialLotSize = minLot;
    }

    // Enforce maximum lot size (per partial order, though total LotSize should also be checked ideally)
    if (partialLotSize > maxLot) {
        partialLotSize = maxLot; // This case is less likely if total LotSize is reasonable
    }

    // Final check if total requested lot is too small to be split even into minLot partials
    if (partialLotSize * 3.0 > LotSize + lotStep) { // Adding lotStep for a small tolerance
         printf("Total LotSize %.2f is too small to be split into 3 valid partial orders for symbol %s (min partial: %.2f). Min total needed: %.2f. Aborting.",
               LotSize, _Symbol, minLot, minLot * 3.0);
        return;
    }
    if (partialLotSize == 0) { // Should be caught by minLot, but as a safeguard
        printf("Calculated partial lot size is zero. Aborting trade. Check LotSize input and symbol volume limits.");
        return;
    }


    double currentPoint = _Point; // Point size
    // TP and SL pips will be used per order
    long initial_sl_points_val = InitialStopLossPips; // Use the input directly for SL pips
    int tp_pips[] = {TakeProfitPips1, TakeProfitPips2, TakeProfitPips3};

    // Min distance for SL/TP from current price
    long stops_level_raw_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    // printf("Debug: stops_level_raw_points for SYMBOL_TRADE_STOPS_LEVEL: %ld", stops_level_raw_points);

    if (BuyVotes > SellVotes) {
        ulong setBaseMagic = MagicNumberBase + (g_setCounter * 10);
        g_setCounter++; // Increment for the next set

        double ask_price;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask_price)) {
            printf("Error getting SYMBOL_ASK for Buy: %d. Aborting trade.", GetLastError());
            return;
        }
        printf("Attempting to place BUY orders (Set Magic Base: %llu)... Ask: %.5f, PartialLot: %.2f", setBaseMagic, ask_price, partialLotSize);

        for (int i = 0; i < 3; i++) {
            trade.SetExpertMagicNumber(setBaseMagic + (ulong)i); // Set unique magic for each partial

            double tp_distance_pips = tp_pips[i] * currentPoint;
            double sl_distance_pips = initial_sl_points_val * currentPoint;

            // Ensure TP/SL distances respect minimum stop level distance
            if (tp_distance_pips < stops_level_raw_points * currentPoint) tp_distance_pips = stops_level_raw_points * currentPoint;
            if (sl_distance_pips < stops_level_raw_points * currentPoint) sl_distance_pips = stops_level_raw_points * currentPoint;

            double takeProfitLevel = ask_price + tp_distance_pips;
            double stopLossLevel = ask_price - sl_distance_pips;

            takeProfitLevel = NormalizeDouble(takeProfitLevel, _Digits);
            stopLossLevel = NormalizeDouble(stopLossLevel, _Digits);

            string comment = StringFormat("AdvEA_Buy_P%d_SL%d_TP%d", i + 1, InitialStopLossPips, tp_pips[i]);

            if(trade.Buy(partialLotSize, _Symbol, ask_price, stopLossLevel, takeProfitLevel, comment)) {
                printf("BUY order #%d (Magic: %llu) placed successfully. Price: %.5f, Lot: %.2f, TP: %.5f (Pips: %d), SL: %.5f (Pips: %d), Result: %s",
                       i+1, setBaseMagic + (ulong)i, ask_price, partialLotSize, takeProfitLevel, tp_pips[i], stopLossLevel, InitialStopLossPips, trade.ResultComment());
            } else {
                printf("Error placing BUY order #%d (Magic: %llu): %s (Code: %d)", i+1, setBaseMagic + (ulong)i, trade.ResultComment(), trade.ResultRetcode());
            }
        }
    } else if (SellVotes > BuyVotes) {
        ulong setBaseMagic = MagicNumberBase + (g_setCounter * 10);
        g_setCounter++; // Increment for the next set

        double bid_price;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid_price)) {
            printf("Error getting SYMBOL_BID for Sell: %d. Aborting trade.", GetLastError());
            return;
        }
        printf("Attempting to place SELL orders (Set Magic Base: %llu)... Bid: %.5f, PartialLot: %.2f", setBaseMagic, bid_price, partialLotSize);

        for (int i = 0; i < 3; i++) {
            trade.SetExpertMagicNumber(setBaseMagic + (ulong)i); // Set unique magic for each partial

            double tp_distance_pips = tp_pips[i] * currentPoint;
            double sl_distance_pips = initial_sl_points_val * currentPoint;

            // Ensure TP/SL distances respect minimum stop level distance
            if (tp_distance_pips < stops_level_raw_points * currentPoint) tp_distance_pips = stops_level_raw_points * currentPoint;
            if (sl_distance_pips < stops_level_raw_points * currentPoint) sl_distance_pips = stops_level_raw_points * currentPoint;

            double takeProfitLevel = bid_price - tp_distance_pips;
            double stopLossLevel = bid_price + sl_distance_pips;

            takeProfitLevel = NormalizeDouble(takeProfitLevel, _Digits);
            stopLossLevel = NormalizeDouble(stopLossLevel, _Digits);

            string comment = StringFormat("AdvEA_Sell_P%d_SL%d_TP%d", i + 1, InitialStopLossPips, tp_pips[i]);

            if(trade.Sell(partialLotSize, _Symbol, bid_price, stopLossLevel, takeProfitLevel, comment)) {
                printf("SELL order #%d (Magic: %llu) placed successfully. Price: %.5f, Lot: %.2f, TP: %.5f (Pips: %d), SL: %.5f (Pips: %d), Result: %s",
                       i+1, MagicNumberBase + (ulong)i, bid_price, partialLotSize, takeProfitLevel, tp_pips[i], stopLossLevel, InitialStopLossPips, trade.ResultComment());
            } else {
                printf("Error placing SELL order #%d (Magic: %llu): %s (Code: %d)", i+1, MagicNumberBase + (ulong)i, trade.ResultComment(), trade.ResultRetcode());
            }
        }
    } else {
        printf("No trade signal: BuyVotes (%d) == SellVotes (%d)", BuyVotes, SellVotes);
    }
}

//+------------------------------------------------------------------+
//| Count Open Positions for the current symbol and EA               |
//+------------------------------------------------------------------+
int CountOpenPositions() { // Counts the number of "sets" of trades
    int setCount = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong position_ticket = PositionGetTicket(i);
        if (position_ticket > 0) {
            // A "set" is identified by its first partial order's magic number.
            // The first partial order of a set opened by this EA instance has magic number MagicNumberBase + 0.
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                (ulong)PositionGetInteger(POSITION_MAGIC) == (MagicNumberBase + 0) ) { // Check for the first partial of a set
                setCount++;
            }
        }
    }
    return setCount;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage Open Trades (e.g., for Breakeven)                         |
//+------------------------------------------------------------------+
// Helper function to check if a ticket exists in our tracking array
bool IsTicketInArray(ulong ticket, const ulong &tickets_array[]) {
    for (int i = 0; i < ArraySize(tickets_array); i++) {
        if (tickets_array[i] == ticket) {
            return true;
        }
    }
    return false;
}

static ulong BreakevenTriggeredForTP1DealTickets[]; // Stores deal tickets of TP1s that triggered BE

void ManageOpenTrades() {
    // --- Breakeven Logic ---
    // If TP1 of a set is hit, move SL of TP2 and TP3 to Breakeven for that set.

    if (!HistorySelect(0, TimeCurrent())) {
        printf("ManageOpenTrades: Error selecting history! Code: %d", GetLastError());
        return;
    }

    int deals = HistoryDealsTotal();
    for (int i = deals - 1; i >= 0; i--) { // Iterate backwards for potentially better performance on recent deals
        ulong deal_ticket = HistoryDealGetTicket(i);
        if (deal_ticket == 0) continue;

        // Check if this deal_ticket has already triggered a breakeven action
        if (IsTicketInArray(deal_ticket, BreakevenTriggeredForTP1DealTickets)) {
            continue;
        }

        long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
        string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
        long deal_entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY); // DEAL_ENTRY_OUT means it's a closing deal
        long deal_reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);   // DEAL_REASON_TP means closed by TakeProfit

        // Identify the base magic for the set this deal belongs to.
        // Our set magics are: set_base, set_base+1, set_base+2
        // The deal_magic for TP1 is 'set_base + 0'.
        // So, if (deal_magic - MagicNumberBase) % 10 == 0, it's a TP1. (This assumes MagicNumberBase itself is a multiple of 10 or 0)
        // And the set_base for this deal would be deal_magic itself if it's a TP1.

        ulong currentSetBaseMagicForDeal = 0;

        // Check if this deal's magic is a "base + 0" for a set from THIS EA instance
        // This logic assumes MagicNumberBase from OnInit is the absolute start,
        // and set identifiers are effectively (MagicNumberBase + some_offset_multiple_of_10)
        // The actual magic for TP1 is `set_actual_base_magic + 0`
        // Let's assume the magic numbers set during trade placement are:
        // TP1: unique_set_base_magic + 0
        // TP2: unique_set_base_magic + 1
        // TP3: unique_set_base_magic + 2
        // The magic for a TP1 order will be `...0`. We can identify it by checking `deal_magic % 10 == 0`.
        // The base magic for its specific set can then be derived from the deal's magic number.
        bool isTP1 = ((ulong)deal_magic >= MagicNumberBase) && (deal_magic % 10 == 0);

        if (isTP1 && deal_symbol == _Symbol && deal_entry_type == DEAL_ENTRY_OUT && deal_reason == DEAL_REASON_TP) {

            ulong currentSetBaseMagicForDeal = deal_magic; // Since TP1 magic is set_base + 0

            // Mark this TP1 deal as processed for BE to avoid redundant actions
            int currentSize = ArraySize(BreakevenTriggeredForTP1DealTickets);
            ArrayResize(BreakevenTriggeredForTP1DealTickets, currentSize + 1);
            BreakevenTriggeredForTP1DealTickets[currentSize] = deal_ticket;

            printf("ManageOpenTrades: TP1 (Deal Ticket: %llu, Magic: %llu) hit TP. Processing BE for siblings.", deal_ticket, deal_magic);

            // Now find open sibling positions (TP2 and TP3) for this EA's set structure
            for (int j = PositionsTotal() - 1; j >= 0; j--) {
                ulong pos_ticket = PositionGetTicket(j);
                if (pos_ticket == 0) continue;

                // Select position to work with its properties
                if(PositionSelectByTicket(pos_ticket)) {
                    long pos_magic = PositionGetInteger(POSITION_MAGIC);
                    string pos_symbol = PositionGetString(POSITION_SYMBOL);

                    if (pos_symbol == _Symbol &&
                       (pos_magic == (currentSetBaseMagicForDeal + 1) || pos_magic == (currentSetBaseMagicForDeal + 2))) {

                        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                        double current_sl = PositionGetDouble(POSITION_SL);
                        double current_tp = PositionGetDouble(POSITION_TP); // Keep original TP

                        // Check if SL is already at breakeven (or better for buys, worse for sells - meaning already past BE)
                        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                        bool already_at_be = false;
                        double profit_buffer_price = BreakevenPlusPips * _Point;

                        if(pos_type == POSITION_TYPE_BUY && current_sl >= (open_price + profit_buffer_price)) already_at_be = true;
                        if(pos_type == POSITION_TYPE_SELL && current_sl <= (open_price - profit_buffer_price) && current_sl != 0) already_at_be = true;

                        if (!already_at_be) {
                            double new_stop_loss;

                            if(pos_type == POSITION_TYPE_BUY) {
                                new_stop_loss = open_price + profit_buffer_price;
                            } else { // It's a SELL
                                new_stop_loss = open_price - profit_buffer_price;
                            }

                            new_stop_loss = NormalizeDouble(new_stop_loss, _Digits);

                            // Check if the new SL is valid (not too close to current price)
                            if ((pos_type == POSITION_TYPE_BUY && new_stop_loss <= SymbolInfoDouble(_Symbol, SYMBOL_BID)) ||
                                (pos_type == POSITION_TYPE_SELL && new_stop_loss >= SymbolInfoDouble(_Symbol, SYMBOL_ASK))) {

                                printf("ManageOpenTrades: Moving SL to BE+%d for Ticket: %llu (Magic: %llu), Open: %.5f", BreakevenPlusPips, pos_ticket, pos_magic, open_price);

                                if (trade.PositionModify(pos_ticket, new_stop_loss, current_tp)) {
                                    printf("ManageOpenTrades: Successfully moved SL to BE+%d for Ticket %llu. New SL: %.5f", BreakevenPlusPips, pos_ticket, new_stop_loss);
                                } else {
                                    printf("ManageOpenTrades: Failed to move SL to BE+%d for Ticket %llu. Error: %s (Code: %d)",
                                           BreakevenPlusPips, pos_ticket, trade.ResultComment(), trade.ResultRetcode());
                                }
                            } else {
                                 printf("ManageOpenTrades: Cannot move SL to BE+%d for Ticket %llu, new SL %.5f is too close to current price.", BreakevenPlusPips, pos_ticket, new_stop_loss);
                            }
                        } else {
                             printf("ManageOpenTrades: SL for Ticket %llu (Magic: %llu) is already at/past BE+%d. Current SL: %.5f, Open: %.5f", pos_ticket, pos_magic, BreakevenPlusPips, current_sl, open_price);
                        }
                    }
                }
            }
            // Since we found and processed the relevant TP1 deal for this EA's set structure,
            // and assuming only one "active" set structure at a time for this BE logic, we can break.
            // If multiple sets could have their TP1 hit simultaneously, this break might be premature.
            // However, BreakevenTriggeredForTP1DealTickets should prevent re-processing the same TP1 deal.
            // For now, let's assume one TP1 hit event is processed per ManageOpenTrades call for this EA's general set.
            break;
        }
    }

    // --- ATR Trailing Stop Logic ---
    if (Use_ATR_TrailingStop) {
        double atr_value = GetIndicatorValue(hATR, 0, 1); // Get ATR of the last completed bar
        if (atr_value == EMPTY_VALUE) {
            printf("ManageOpenTrades: Could not get ATR value for trailing stop.");
            return;
        }

        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            if (PositionSelectByTicket(PositionGetTicket(i))) {
                // Check if the position belongs to this EA instance by checking its magic number range
                long pos_magic = PositionGetInteger(POSITION_MAGIC);
                if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                    (ulong)pos_magic >= MagicNumberBase && (pos_magic % 10 < 3)) // Belongs to one of our sets
                {
                    double current_sl = PositionGetDouble(POSITION_SL);
                    double current_tp = PositionGetDouble(POSITION_TP);
                    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                    double trailing_stop_level = 0;
                    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

                    if (pos_type == POSITION_TYPE_BUY) {
                        trailing_stop_level = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (atr_value * ATR_Multiplier);
                        // SL only moves up
                        if (trailing_stop_level > current_sl || current_sl == 0) {
                            // Ensure new SL is not above open price if it hasn't been moved to BE yet
                            if (current_sl < open_price && trailing_stop_level >= open_price) {
                                // This could be a BE move, let's respect that logic or just trail
                            }
                            if (trade.PositionModify(PositionGetTicket(i), trailing_stop_level, current_tp)) {
                                printf("ManageOpenTrades: Trailed SL for BUY Ticket %llu to %.5f", PositionGetTicket(i), trailing_stop_level);
                            }
                        }
                    } else if (pos_type == POSITION_TYPE_SELL) {
                        trailing_stop_level = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (atr_value * ATR_Multiplier);
                        // SL only moves down
                        if (trailing_stop_level < current_sl || current_sl == 0) {
                            if (trade.PositionModify(PositionGetTicket(i), trailing_stop_level, current_tp)) {
                                printf("ManageOpenTrades: Trailed SL for SELL Ticket %llu to %.5f", PositionGetTicket(i), trailing_stop_level);
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Time-Based Exit Logic ---
    if (Use_Time_Based_Exit) {
        // Use a list to store tickets of sets to be closed to avoid issues while iterating
        ulong tickets_to_close[];
        int to_close_count = 0;

        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            if (PositionSelectByTicket(PositionGetTicket(i))) {
                // Check if it's a master position of a set managed by this EA
                long pos_magic = PositionGetInteger(POSITION_MAGIC);
                if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                    pos_magic >= MagicNumberBase && (pos_magic % 10 == 0))
                {
                    datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
                    int bars_open = iBarShift(_Symbol, _Period, open_time, false);

                    if (bars_open > Max_Bars_Open) {
                        printf("ManageOpenTrades: Set with base magic %llu has been open for %d bars (Max: %d). Closing set.", pos_magic, bars_open, Max_Bars_Open);
                        // This master ticket needs its set closed.
                        // Instead of closing here, we find all tickets of the set and add to a list to close after the loop.
                        ulong setBaseMagic = pos_magic;
                        for(int j = PositionsTotal() - 1; j >= 0; j--) {
                            if(PositionSelectByTicket(PositionGetTicket(j))) {
                                long sibling_magic = PositionGetInteger(POSITION_MAGIC);
                                if(PositionGetString(POSITION_SYMBOL) == _Symbol && (sibling_magic - (sibling_magic % 10)) == setBaseMagic) {
                                     ArrayResize(tickets_to_close, to_close_count + 1);
                                     tickets_to_close[to_close_count] = PositionGetTicket(j);
                                     to_close_count++;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Now close the collected tickets
        for(int i=0; i < to_close_count; i++) {
            trade.PositionClose(tickets_to_close[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Strategy 8: Head and Shoulders Pattern                           |
//+------------------------------------------------------------------+
// Structure to hold ZigZag point data
struct ZigZagPoint {
    double price;
    datetime time;
    int index; // Bar index
    bool isHigh; // true for high, false for low
};

void AnalyzeHeadAndShoulders() {
    // 1. Get ZigZag points
    int pointsToScan = 30; // Scan last 30 ZigZag points
    ZigZagPoint zz_points[];
    int zz_count = 0;

    double high_buffer[], low_buffer[];
    if(CopyBuffer(hZigZag, 1, 0, pointsToScan, high_buffer) <= 0 || CopyBuffer(hZigZag, 2, 0, pointsToScan, low_buffer) <= 0) {
        printf("Strategy [H&S]: Error copying ZigZag buffers.");
        return;
    }

    // MqlRates for getting time
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, pointsToScan, rates) <= 0) return;

    // Populate our ZigZagPoint array
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(rates, true);

    for (int i = 0; i < pointsToScan; i++) {
        if (high_buffer[i] != 0) {
            ArrayResize(zz_points, zz_count + 1);
            zz_points[zz_count].price = high_buffer[i];
            zz_points[zz_count].time = rates[i].time;
            zz_points[zz_count].index = i;
            zz_points[zz_count].isHigh = true;
            zz_count++;
        }
        if (low_buffer[i] != 0) {
            ArrayResize(zz_points, zz_count + 1);
            zz_points[zz_count].price = low_buffer[i];
            zz_points[zz_count].time = rates[i].time;
            zz_points[zz_count].index = i;
            zz_points[zz_count].isHigh = false;
            zz_count++;
        }
    }
    if(zz_count < 6) { // Need at least 6 points for a full H&S with breakout check
        printf("Strategy [H&S]: Not enough ZigZag points found (%d).", zz_count);
        return;
    }

    // 2. Loop through points to find patterns
    // We are looking for a sequence of 5 points for the core pattern
    for (int i = zz_count - 5; i >= 0; i--) {
        ZigZagPoint p1 = zz_points[i];
        ZigZagPoint p2 = zz_points[i+1];
        ZigZagPoint p3 = zz_points[i+2];
        ZigZagPoint p4 = zz_points[i+3];
        ZigZagPoint p5 = zz_points[i+4];

        // --- Head and Shoulders (Bearish) ---
        // p1=High, p2=Low, p3=High (Head), p4=Low, p5=High
        if(p1.isHigh && !p2.isHigh && p3.isHigh && !p4.isHigh && p5.isHigh) {
            // Validate geometry
            if (p3.price > p1.price && p3.price > p5.price) { // Head is highest
                // Validate symmetry (e.g., shoulders are within 1.5% of pattern height)
                double patternHeight = p3.price - MathMin(p2.price, p4.price);
                if (MathAbs(p1.price - p5.price) < (patternHeight * 0.15)) {
                    // Calculate neckline
                    // Neckline is a line between p2 and p4
                    double slope = (p4.price - p2.price) / (p4.index - p2.index);
                    // Extrapolate neckline to current bar (index 0)
                    double neckline_val_at_current_bar = p4.price + slope * (0 - p4.index);

                    // Check for breakout
                    if (rates[0].close < neckline_val_at_current_bar) {
                        SellVotes += Weight_HnS;
                        printf("Strategy [H&S]: Sell Signal (Head and Shoulders pattern confirmed by neckline break). Adding %d votes.", Weight_HnS);
                        return; // Exit after finding first valid pattern
                    }
                }
            }
        }

        // --- Inverse Head and Shoulders (Bullish) ---
        // p1=Low, p2=High, p3=Low (Head), p4=High, p5=Low
        if(!p1.isHigh && p2.isHigh && !p3.isHigh && p4.isHigh && !p5.isHigh) {
            // Validate geometry
            if (p3.price < p1.price && p3.price < p5.price) { // Head is lowest
                // Validate symmetry
                double patternHeight = MathMax(p2.price, p4.price) - p3.price;
                if (MathAbs(p1.price - p5.price) < (patternHeight * 0.15)) {
                    // Calculate neckline
                    double slope = (p4.price - p2.price) / (p4.index - p2.index);
                    double neckline_val_at_current_bar = p4.price + slope * (0 - p4.index);

                    // Check for breakout
                    if (rates[0].close > neckline_val_at_current_bar) {
                        BuyVotes += Weight_HnS;
                        printf("Strategy [H&S]: Buy Signal (Inverse Head and Shoulders pattern confirmed by neckline break). Adding %d votes.", Weight_HnS);
                        return; // Exit
                    }
                }
            }
        }
    }

    printf("Strategy [H&S]: No signal (No H&S pattern detected).");
}


//+------------------------------------------------------------------+
//| Strategy 9: RSI Divergence                                       |
//+------------------------------------------------------------------+
void AnalyzeRsiDivergence() {
    // We reuse the ZigZagPoint struct defined in the H&S section
    int pointsToScan = 20; // Scan last 20 ZigZag points
    ZigZagPoint zz_points[];
    int zz_count = 0;

    double high_buffer[], low_buffer[];
    if(CopyBuffer(hZigZag, 1, 0, pointsToScan, high_buffer) <= 0 || CopyBuffer(hZigZag, 2, 0, pointsToScan, low_buffer) <= 0) {
        printf("Strategy [RSI Divergence]: Error copying ZigZag buffers.");
        return;
    }

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, pointsToScan, rates) <= 0) return;

    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(rates, true);

    for (int i = 0; i < pointsToScan; i++) {
        if (high_buffer[i] != 0) {
            ArrayResize(zz_points, zz_count + 1);
            zz_points[zz_count].price = high_buffer[i];
            zz_points[zz_count].index = i;
            zz_points[zz_count].isHigh = true;
            zz_count++;
        }
        if (low_buffer[i] != 0) {
            ArrayResize(zz_points, zz_count + 1);
            zz_points[zz_count].price = low_buffer[i];
            zz_points[zz_count].index = i;
            zz_points[zz_count].isHigh = false;
            zz_count++;
        }
    }

    if(zz_count < 4) {
        printf("Strategy [RSI Divergence]: Not enough ZigZag points found (%d).", zz_count);
        return;
    }

    // Find last two highs and last two lows
    ZigZagPoint H1, H2, L1, L2;
    int highsFound = 0;
    int lowsFound = 0;
    for(int i = zz_count - 1; i >= 0; i--) {
        if(zz_points[i].isHigh) {
            if(highsFound == 0) H2 = zz_points[i];
            if(highsFound == 1) H1 = zz_points[i];
            highsFound++;
        } else {
            if(lowsFound == 0) L2 = zz_points[i];
            if(lowsFound == 1) L1 = zz_points[i];
            lowsFound++;
        }
        if(highsFound >= 2 && lowsFound >= 2) break;
    }

    // --- Check for Bearish Divergence ---
    if(highsFound >= 2) {
        if(H2.price > H1.price) { // Price made a higher high
            double rsi_h1 = GetIndicatorValue(hRSI, 0, H1.index);
            double rsi_h2 = GetIndicatorValue(hRSI, 0, H2.index);
            if(rsi_h1 != EMPTY_VALUE && rsi_h2 != EMPTY_VALUE && rsi_h2 < rsi_h1) {
                // Optional: Check if RSI is in overbought territory
                if(rsi_h1 > 50 && rsi_h2 > 50) {
                    SellVotes += Weight_RsiDiv;
                    printf("Strategy [RSI Divergence]: Sell Signal (Bearish divergence confirmed). Adding %d votes.", Weight_RsiDiv);
                    return; // Exit after finding a signal
                }
            }
        }
    }

    // --- Check for Bullish Divergence ---
    if(lowsFound >= 2) {
        if(L2.price < L1.price) { // Price made a lower low
            double rsi_l1 = GetIndicatorValue(hRSI, 0, L1.index);
            double rsi_l2 = GetIndicatorValue(hRSI, 0, L2.index);
            if(rsi_l1 != EMPTY_VALUE && rsi_l2 != EMPTY_VALUE && rsi_l2 > rsi_l1) {
                // Optional: Check if RSI is in oversold territory
                if(rsi_l1 < 50 && rsi_l2 < 50) {
                    BuyVotes += Weight_RsiDiv;
                    printf("Strategy [RSI Divergence]: Buy Signal (Bullish divergence confirmed). Adding %d votes.", Weight_RsiDiv);
                    return; // Exit
                }
            }
        }
    }

    printf("Strategy [RSI Divergence]: No signal (No divergence detected).");
}


//+------------------------------------------------------------------+
//| Strategy 10: RSI Overbought/Oversold Crossover                   |
//+------------------------------------------------------------------+
void AnalyzeRsiCrossover() {
    double rsi_values[];
    if(CopyBuffer(hRSI, 0, 1, 2, rsi_values) < 2) { // Get RSI for shift 1 and 2
        printf("Strategy [RSI Crossover]: Error copying RSI buffer.");
        return;
    }
    // rsi_values[0] is for shift 2, rsi_values[1] is for shift 1
    double rsi_shift2 = rsi_values[0];
    double rsi_shift1 = rsi_values[1];

    // Check for Bearish Crossover (exiting Overbought)
    if (rsi_shift2 >= RSI_Overbought_Level && rsi_shift1 < RSI_Overbought_Level) {
        SellVotes += Weight_RsiCross;
        printf("Strategy [RSI Crossover]: Sell Signal (RSI crossed down from Overbought zone). Adding %d votes.", Weight_RsiCross);
        return;
    }

    // Check for Bullish Crossover (exiting Oversold)
    if (rsi_shift2 <= RSI_Oversold_Level && rsi_shift1 > RSI_Oversold_Level) {
        BuyVotes += Weight_RsiCross;
        printf("Strategy [RSI Crossover]: Buy Signal (RSI crossed up from Oversold zone). Adding %d votes.", Weight_RsiCross);
        return;
    }

    printf("Strategy [RSI Crossover]: No signal (No OB/OS crossover detected).");
}


//+------------------------------------------------------------------+
//| Strategy 11: Stochastic Oscillator Crossover                     |
//+------------------------------------------------------------------+
void AnalyzeStochasticCrossover() {
    double k_values[], d_values[];
    // Get Main line (%K) for shift 1 and 2
    if(CopyBuffer(hStoch, MAIN_LINE, 1, 2, k_values) < 2) {
        printf("Strategy [Stochastic]: Error copying K-line buffer.");
        return;
    }
    // Get Signal line (%D) for shift 1 and 2
    if(CopyBuffer(hStoch, SIGNAL_LINE, 1, 2, d_values) < 2) {
        printf("Strategy [Stochastic]: Error copying D-line buffer.");
        return;
    }

    // k_values[0] is shift 2, k_values[1] is shift 1
    double k_shift2 = k_values[0];
    double k_shift1 = k_values[1];
    double d_shift2 = d_values[0];
    double d_shift1 = d_values[1];

    // Check for Bearish Crossover in Overbought zone
    if (k_shift1 > Stoch_Overbought_Level && d_shift1 > Stoch_Overbought_Level) { // Both lines in OB zone
        if (k_shift2 > d_shift2 && k_shift1 < d_shift1) { // K crossed below D
            SellVotes += Weight_StochCross;
            printf("Strategy [Stochastic]: Sell Signal (K crossed below D in Overbought zone). Adding %d votes.", Weight_StochCross);
            return;
        }
    }

    // Check for Bullish Crossover in Oversold zone
    if (k_shift1 < Stoch_Oversold_Level && d_shift1 < Stoch_Oversold_Level) { // Both lines in OS zone
        if (k_shift2 < d_shift2 && k_shift1 > d_shift1) { // K crossed above D
            BuyVotes += Weight_StochCross;
            printf("Strategy [Stochastic]: Buy Signal (K crossed above D in Oversold zone). Adding %d votes.", Weight_StochCross);
            return;
        }
    }

    printf("Strategy [Stochastic Crossover]: No signal (No OB/OS crossover detected).");
}


//+------------------------------------------------------------------+
//| Strategy 12: MACD Crossover                                      |
//+------------------------------------------------------------------+
void AnalyzeMacdCrossover() {
    double macd_main_values[], macd_signal_values[];
    // Get Main line for shift 1 and 2
    if(CopyBuffer(hMACD, MAIN_LINE, 1, 2, macd_main_values) < 2) {
        printf("Strategy [MACD]: Error copying Main line buffer.");
        return;
    }
    // Get Signal line for shift 1 and 2
    if(CopyBuffer(hMACD, SIGNAL_LINE, 1, 2, macd_signal_values) < 2) {
        printf("Strategy [MACD]: Error copying Signal line buffer.");
        return;
    }

    // macd_values[0] is shift 2, macd_values[1] is shift 1
    double main_shift2 = macd_main_values[0];
    double main_shift1 = macd_main_values[1];
    double signal_shift2 = macd_signal_values[0];
    double signal_shift1 = macd_signal_values[1];

    // Check for Bullish Crossover
    if (main_shift2 <= signal_shift2 && main_shift1 > signal_shift1) {
        BuyVotes += Weight_MacdCross;
        printf("Strategy [MACD Crossover]: Buy Signal (Main line crossed above Signal line). Adding %d votes.", Weight_MacdCross);
        return;
    }

    // Check for Bearish Crossover
    if (main_shift2 >= signal_shift2 && main_shift1 < signal_shift1) {
        SellVotes += Weight_MacdCross;
        printf("Strategy [MACD Crossover]: Sell Signal (Main line crossed below Signal line). Adding %d votes.", Weight_MacdCross);
        return;
    }

    printf("Strategy [MACD Crossover]: No signal (No crossover detected).");
}


//+------------------------------------------------------------------+
//| Strategy 13: Keltner Channel Breakout                            |
//+------------------------------------------------------------------+
void AnalyzeKeltnerChannels() {
    // Get EMA values
    double ema_values[];
    if(CopyBuffer(hKC_EMA, 0, 1, 2, ema_values) < 2) {
        printf("Strategy [KC]: Error copying EMA buffer.");
        return;
    }
    double ema_shift2 = ema_values[0];
    double ema_shift1 = ema_values[1];

    // Get ATR values
    double atr_values[];
    if(CopyBuffer(hATR, 0, 1, 2, atr_values) < 2) {
        printf("Strategy [KC]: Error copying ATR buffer.");
        return;
    }
    double atr_shift2 = atr_values[0];
    double atr_shift1 = atr_values[1];

    // Calculate Keltner Channel values for last two bars
    double upper_band_shift1 = ema_shift1 + (atr_shift1 * KC_ATR_Multiplier);
    double lower_band_shift1 = ema_shift1 - (atr_shift1 * KC_ATR_Multiplier);
    double upper_band_shift2 = ema_shift2 + (atr_shift2 * KC_ATR_Multiplier);
    double lower_band_shift2 = ema_shift2 - (atr_shift2 * KC_ATR_Multiplier);

    // Get close prices for last two bars
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, 2, rates) < 2) return;
    double close_shift2 = rates[0].close;
    double close_shift1 = rates[1].close;

    // Check for Buy Signal (breakout of upper channel)
    if (close_shift1 > upper_band_shift1 && close_shift2 <= upper_band_shift2) {
        BuyVotes += Weight_Volatility; // Keltner is a volatility strategy
        printf("Strategy [Keltner Channel]: Buy Signal (Price closed above Upper Band). Adding %d votes.", Weight_Volatility);
        return;
    }

    // Check for Sell Signal (breakout of lower channel)
    if (close_shift1 < lower_band_shift1 && close_shift2 >= lower_band_shift2) {
        SellVotes += Weight_Volatility; // Keltner is a volatility strategy
        printf("Strategy [Keltner Channel]: Sell Signal (Price closed below Lower Band). Adding %d votes.", Weight_Volatility);
        return;
    }

    printf("Strategy [Keltner Channel]: No signal (No breakout detected).");
}


//+------------------------------------------------------------------+
//| Strategy 14: Inside/Outside Bars                                 |
//+------------------------------------------------------------------+
void AnalyzeInsideOutsideBars() {
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3) { // Need current, prev, and bar before prev
        printf("Strategy [I/O Bars]: Error copying rates.");
        return;
    }
    // rates[0] = current bar (shift 0)
    // rates[1] = previous bar (shift 1)
    // rates[2] = bar before previous (shift 2)

    // --- Check for Inside Bar Breakout ---
    bool isInsideBar = rates[1].high < rates[2].high && rates[1].low > rates[2].low;
    if (isInsideBar) {
        // Bullish breakout of Inside Bar's high
        if (rates[0].close > rates[1].high) {
            BuyVotes += Weight_IOBars;
            printf("Strategy [I/O Bars]: Buy Signal (Breakout of Inside Bar high). Adding %d votes.", Weight_IOBars);
            return;
        }
        // Bearish breakout of Inside Bar's low
        if (rates[0].close < rates[1].low) {
            SellVotes += Weight_IOBars;
            printf("Strategy [I/O Bars]: Sell Signal (Breakout of Inside Bar low). Adding %d votes.", Weight_IOBars);
            return;
        }
    }

    // --- If no Inside Bar breakout, check for Outside Bar ---
    bool isOutsideBar = rates[1].high > rates[2].high && rates[1].low < rates[2].low;
    if(isOutsideBar) {
        // Bullish Outside Bar
        if(rates[1].close > rates[1].open) {
            BuyVotes += Weight_IOBars;
            printf("Strategy [I/O Bars]: Buy Signal (Bullish Outside Bar detected). Adding %d votes.", Weight_IOBars);
            return;
        }
        // Bearish Outside Bar
        if(rates[1].close < rates[1].open) {
            SellVotes += Weight_IOBars;
            printf("Strategy [I/O Bars]: Sell Signal (Bearish Outside Bar detected). Adding %d votes.", Weight_IOBars);
            return;
        }
    }

    printf("Strategy [I/O Bars]: No signal (No Inside Bar breakout or Outside Bar detected).");
}


//+------------------------------------------------------------------+
//| Strategy 15: Pin Bars (Hammer / Shooting Star)                   |
//+------------------------------------------------------------------+
void AnalyzePinBars() {
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, 1, rates) < 1) { // Get previous completed bar
        printf("Strategy [Pin Bars]: Error copying rates.");
        return;
    }

    double open = rates[0].open;
    double high = rates[0].high;
    double low = rates[0].low;
    double close = rates[0].close;

    double bodySize = MathAbs(open - close);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;

    // Avoid division by zero for doji-like candles
    if (bodySize < _Point) {
        bodySize = _Point;
    }

    // Check for Bullish Pin Bar (Hammer)
    if (lowerWick > (bodySize * PinBar_Wick_to_Body_Ratio) && upperWick < bodySize) {
        BuyVotes += Weight_PinBars;
        printf("Strategy [Pin Bars]: Buy Signal (Bullish Pin Bar / Hammer detected). Adding %d votes.", Weight_PinBars);
        return;
    }

    // Check for Bearish Pin Bar (Shooting Star)
    if (upperWick > (bodySize * PinBar_Wick_to_Body_Ratio) && lowerWick < bodySize) {
        SellVotes += Weight_PinBars;
        printf("Strategy [Pin Bars]: Sell Signal (Bearish Pin Bar / Shooting Star detected). Adding %d votes.", Weight_PinBars);
        return;
    }

    printf("Strategy [Pin Bars]: No signal (No valid Pin Bar detected).");
}


//+------------------------------------------------------------------+
//| Strategy 16: Three-Bar Reversal                                  |
//+------------------------------------------------------------------+
void AnalyzeThreeBarReversal() {
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 1, 4, rates) < 4) { // Get last 4 completed bars
        printf("Strategy [3-Bar Reversal]: Error copying rates.");
        return;
    }
    // rates[0] = shift 4 (oldest)
    // rates[1] = shift 3
    // rates[2] = shift 2
    // rates[3] = shift 1 (most recent completed)

    // Bullish Three-Bar Reversal
    // Bar 2 is the lowest point
    bool isLowerLow = rates[2].low < rates[1].low;
    bool isLowerHigh = rates[2].high < rates[1].high;
    // Bar 1 makes a higher low and closes above Bar 2's high
    bool isHigherLow_reversal = rates[3].low > rates[2].low;
    bool isBreakoutClose = rates[3].close > rates[2].high;

    if (isLowerLow && isLowerHigh && isHigherLow_reversal && isBreakoutClose) {
        BuyVotes += Weight_3BarReversal;
        printf("Strategy [3-Bar Reversal]: Buy Signal (Bullish reversal pattern detected). Adding %d votes.", Weight_3BarReversal);
        return;
    }

    // Bearish Three-Bar Reversal
    // Bar 2 is the highest point
    bool isHigherHigh = rates[2].high > rates[1].high;
    bool isHigherLow_trend = rates[2].low > rates[1].low;
    // Bar 1 makes a lower high and closes below Bar 2's low
    bool isLowerHigh_reversal = rates[3].high < rates[2].high;
    bool isBreakdownClose = rates[3].close < rates[2].low;

    if (isHigherHigh && isHigherLow_trend && isLowerHigh_reversal && isBreakdownClose) {
        SellVotes += Weight_3BarReversal;
        printf("Strategy [3-Bar Reversal]: Sell Signal (Bearish reversal pattern detected). Adding %d votes.", Weight_3BarReversal);
        return;
    }

    printf("Strategy [3-Bar Reversal]: No signal (No reversal pattern detected).");
}


//+------------------------------------------------------------------+
//| Strategy 17: Fair Value Gaps (Imbalances)                        |
//+------------------------------------------------------------------+
void AnalyzeFairValueGaps() {
    int lookback = 50;
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, lookback, rates) < lookback) {
        printf("Strategy [FVG]: Error copying rates.");
        return;
    }
    ArraySetAsSeries(rates, true); // rates[0] is current bar

    // Find the most recent FVG that has not been filled
    for (int i = 1; i < lookback - 2; i++) { // Start from shift 1, need 3 bars (i, i+1, i+2)
        // Bullish FVG (gap between low of i and high of i+2) -> Potential Sell Signal
        double bullish_fvg_top = rates[i+2].high;
        double bullish_fvg_bottom = rates[i].low;
        if (bullish_fvg_top > bullish_fvg_bottom) {
            // Check if this FVG was already filled by subsequent candles before the current one
            bool filled = false;
            for(int j = i-1; j >= 0; j--) {
                if(rates[j].low < bullish_fvg_top) {
                    filled = true;
                    break;
                }
            }
            if(!filled) {
                // FVG is valid and unfilled. Check if current price is mitigating it.
                if(rates[0].close <= bullish_fvg_top && rates[0].close >= bullish_fvg_bottom) {
                    SellVotes += Weight_FVG;
                    printf("Strategy [FVG]: Sell Signal (Price entered a Bullish FVG zone). Adding %d votes.", Weight_FVG);
                    return;
                }
            }
        }

        // Bearish FVG (gap between high of i and low of i+2) -> Potential Buy Signal
        double bearish_fvg_top = rates[i].high;
        double bearish_fvg_bottom = rates[i+2].low;
        if (bearish_fvg_top > bearish_fvg_bottom) {
            // Check if this FVG was already filled
            bool filled = false;
            for(int j = i-1; j >= 0; j--) {
                if(rates[j].high > bearish_fvg_bottom) {
                    filled = true;
                    break;
                }
            }
            if(!filled) {
                // FVG is valid and unfilled. Check if current price is mitigating it.
                if(rates[0].close >= bearish_fvg_bottom && rates[0].close <= bearish_fvg_top) {
                    BuyVotes += Weight_FVG;
                    printf("Strategy [FVG]: Buy Signal (Price entered a Bearish FVG zone). Adding %d votes.", Weight_FVG);
                    return;
                }
            }
        }
    }

    printf("Strategy [FVG]: No signal (No recent, unfilled FVG is being tested).");
}


//+------------------------------------------------------------------+
// --- End of file ---
