//+------------------------------------------------------------------+
//|                                                   AdvancedEA.mq4 |
//|                      Copyright 2023, OpenAI & Your Name/Company |
//|                                              http://www.openai.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, OpenAI & Your Name/Company"
#property link      "http://www.openai.com"
#property version   "1.00"
#property strict

//--- Input Parameters
input int      MaxOrders         = 50;       // Maximum number of trade SETS
input double   LotSize           = 3.0;     // Total Lot Size for a set of 3 orders
input int      TakeProfitPips1   = 50;       // Take Profit for 1st partial order
input int      TakeProfitPips2   = 100;      // Take Profit for 2nd partial order
input int      TakeProfitPips3   = 150;      // Take Profit for 3rd partial order
input int      InitialStopLossPips = 500;    // Initial Stop Loss for all partial orders
input int      BreakevenPlusPips = 10;        // Pips to add to SL when moving to Breakeven
input bool     TightenSL_On_Opposing_Signal = true; // Tighten SL if an opposing signal occurs
input int      WaitPeriodMinutes = 1;        // Wait period in minutes for re-analysis
input string   CorrelationSymbol = "EURUSD"; // Symbol for Correlation Strategy
input int      SMA_Period        = 20;       // SMA Period
input int      TrendMA_Fast_Period = 10;     // Trend Riding Fast MA Period
input int      TrendMA_Slow_Period = 50;     // Trend Riding Slow MA Period
input int      ZigZag_Depth      = 12;
input int      ZigZag_Deviation  = 5;
input int      ZigZag_Backstep   = 3;
input int      BB_Period         = 20;       // Bollinger Bands Period for Volatility
input double   BB_Deviation      = 2.0;      // Bollinger Bands Deviation
input double   VolatilityThresholdMultiplier = 0.5; // Multiplier for ATR/BB Width to define low volatility
input int      CorrelationPeriod = 14;       // Period for correlation calculation
input int      ADX_Period        = 14;       // ADX Period for Trend Riding
// RSI Inputs
input int      RSI_Period        = 14;       // RSI Period
input int      RSI_AppliedPrice  = PRICE_CLOSE; // RSI Applied Price
input int      RSI_Overbought_Level = 70;      // RSI Overbought Level
input int      RSI_Oversold_Level = 30;      // RSI Oversold Level
// Stochastic Inputs
input int      Stoch_K_Period    = 5;        // Stochastic K Period
input int      Stoch_D_Period    = 3;        // Stochastic D Period
input int      Stoch_Slowing     = 3;        // Stochastic Slowing
input int      Stoch_MA_Method   = MODE_SMA; // Stochastic MA Method
input int      Stoch_Overbought_Level = 80;    // Stochastic Overbought Level
input int      Stoch_Oversold_Level = 20;    // Stochastic Oversold Level
// MACD Inputs
input int      MACD_Fast_EMA_Period   = 12;     // MACD Fast EMA Period
input int      MACD_Slow_EMA_Period   = 26;     // MACD Slow EMA Period
input int      MACD_Signal_SMA_Period = 9;      // MACD Signal Line SMA Period
input int      MACD_AppliedPrice      = PRICE_CLOSE; // MACD Applied Price
// Candlestick Pattern Inputs
input double   PinBar_Wick_to_Body_Ratio = 2.0; // Min ratio of the main wick to the candle body for Pin Bar detection
// Trend Filter Inputs
input bool     Use_Trend_Filter        = true; // Enable/Disable the long-term trend filter
input int      Trend_Filter_EMA_Period = 200;  // EMA Period for the trend filter

//--- Global Variables
datetime LastAnalysisTime = 0;
int      g_EffectiveWaitPeriodMinutes; // Renamed for clarity and to avoid input modification issues
int      BuyVotes = 0;
int      SellVotes = 0;
int      g_setCounter = 0;      // Counter for trade sets to generate unique magic numbers

// Indicator Handles (MQL4 style, direct usage)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    //---
    if (WaitPeriodMinutes < 1) {
        Print("Input WaitPeriodMinutes '", WaitPeriodMinutes, "' is less than 1. Effective wait period set to 1 minute.");
        g_EffectiveWaitPeriodMinutes = 1;
    } else {
        g_EffectiveWaitPeriodMinutes = WaitPeriodMinutes;
    }
    LastAnalysisTime = TimeCurrent() - (g_EffectiveWaitPeriodMinutes * 60); // Ensure first run
    Print("AdvancedEA Initialized. MaxOrders (Sets): ", MaxOrders, ", Total LotSize: ", LotSize, ", InitialSL: ", InitialStopLossPips, ", EffectiveWait: ", g_EffectiveWaitPeriodMinutes);
    //---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //---
    Print("AdvancedEA Deinitialized. Reason: ", reason);
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

        if(IsNewBar()){ // Optional: Only run on new bar within the minute interval
            Print("New bar detected. Analyzing market...");
            ResetVotes();
            AnalyzeStrategies();
            ProcessTradeDecisions();
        }
    }
    // Call trade management on every tick
    ManageOpenTradesMQL4();
}

//+------------------------------------------------------------------+
//| Reset Buy/Sell Votes                                             |
//+------------------------------------------------------------------+
void ResetVotes(){
    BuyVotes = 0;
    SellVotes = 0;
}

//+------------------------------------------------------------------+
//| Check for a new bar                                              |
//+------------------------------------------------------------------+
bool IsNewBar() {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), Period(), 0);
    if (lastBarTime != currentBarTime) {
        lastBarTime = currentBarTime;
        return (true);
    }
    return (false);
}

//+------------------------------------------------------------------+
//| Analyze strategies and vote                                      |
//+------------------------------------------------------------------+
void AnalyzeStrategies() {
    // Strategy 1: SMA 20
    AnalyzeSMA20();

    // Strategy 2: Trend Riding (using ADX and MAs)
    AnalyzeTrendRiding();

    // Strategy 3: Breakout Trading using ZigZag Indicator
    AnalyzeZigZagBreakout();

    // Strategy 4: Decreased Volatility Breakout (using Bollinger Bands Width)
    AnalyzeDecreasedVolatilityBreakout();

    // Strategy 5: Correlation Trading
    AnalyzeCorrelation();

    // Strategy 6: Price Patterns (e.g., Engulfing)
    AnalyzePricePatterns();

    // Strategy 7: Smart Money Concepts (e.g., Basic Order Block)
    AnalyzeSmartMoneyConcepts();

    // Strategy 8: Head and Shoulders Pattern
    AnalyzeHeadAndShoulders();

    // Strategy 9: RSI Divergence
    AnalyzeRsiDivergence();

    // Strategy 10: RSI Crossover
    AnalyzeRsiCrossover();

    // Strategy 11: Stochastic Crossover
    AnalyzeStochasticCrossover();

    // Strategy 12: MACD Crossover
    AnalyzeMacdCrossover();

    // Strategy 14: Inside/Outside Bars
    AnalyzeInsideOutsideBars();

    // Strategy 15: Pin Bars
    AnalyzePinBars();

    // Strategy 17: Fair Value Gaps
    AnalyzeFairValueGaps();

    // --- Apply Long-Term Trend Filter ---
    if(Use_Trend_Filter) {
        double trend_ema_value = iMA(Symbol(), Period(), Trend_Filter_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
        double close_price = iClose(Symbol(), Period(), 1);

        if(close_price > trend_ema_value) { // Uptrend
            if(SellVotes > 0) {
                Print("Trend Filter: Ignoring ", SellVotes, " sell votes due to long-term uptrend.");
                SellVotes = 0;
            }
        } else if (close_price < trend_ema_value) { // Downtrend
            if(BuyVotes > 0) {
                Print("Trend Filter: Ignoring ", BuyVotes, " buy votes due to long-term downtrend.");
                BuyVotes = 0;
            }
        }
    }

    Print("Analysis Complete. Final Buy Votes: ", BuyVotes, ", Final Sell Votes: ", SellVotes);
}

//+------------------------------------------------------------------+
//| Strategy 1: SMA 20                                               |
//+------------------------------------------------------------------+
void AnalyzeSMA20() {
    double smaValue = iMA(Symbol(), Period(), SMA_Period, 0, MODE_SMA, PRICE_CLOSE, 0);
    double closePrice1 = iClose(Symbol(), Period(), 1); // Previous bar close
    double closePrice2 = iClose(Symbol(), Period(), 2); // Bar before previous

    if (closePrice1 > smaValue && closePrice2 <= smaValue) { // Price crossed above SMA
        BuyVotes++;
        Print("Strategy [SMA20]: Buy Signal (Price crossed above SMA).");
    } else if (closePrice1 < smaValue && closePrice2 >= smaValue) { // Price crossed below SMA
        SellVotes++;
        Print("Strategy [SMA20]: Sell Signal (Price crossed below SMA).");
    } else if (closePrice1 > smaValue) {
        BuyVotes++; // Price is above SMA - bullish bias
        Print("Strategy [SMA20]: Buy Signal (Price is above SMA).");
    } else if (closePrice1 < smaValue) {
        SellVotes++; // Price is below SMA - bearish bias
        Print("Strategy [SMA20]: Sell Signal (Price is below SMA).");
    } else {
        Print("Strategy [SMA20]: No signal.");
    }
}

//+------------------------------------------------------------------+
//| Strategy 2: Trend Riding (using ADX and MAs)                     |
//+------------------------------------------------------------------+
void AnalyzeTrendRiding() {
    double adxValue = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MAIN, 0);
    double plusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_PLUSDI, 0);
    double minusDI = iADX(Symbol(), Period(), ADX_Period, PRICE_CLOSE, MODE_MINUSDI, 0);

    double fastMA = iMA(Symbol(), Period(), TrendMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double slowMA = iMA(Symbol(), Period(), TrendMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 0);

    // Check for trend strength
    bool signalFound = false;
    if (adxValue > 25) { // Trend is considered strong enough
        if (plusDI > minusDI && fastMA > slowMA) { // Uptrend
            // Optional: Check for pullback to fast MA or entry condition
            if (iClose(Symbol(), Period(), 1) > fastMA && iLow(Symbol(), Period(), 1) <= fastMA) { // Pullback to Fast MA in uptrend
                 BuyVotes++;
                 Print("Strategy [TrendRiding]: Buy Signal (Strong uptrend with pullback to Fast MA).");
                 signalFound = true;
            } else if (iClose(Symbol(), Period(), 1) > slowMA && iClose(Symbol(), Period(), 2) <= slowMA) { // Cross above slow MA
                 BuyVotes++;
                 Print("Strategy [TrendRiding]: Buy Signal (Strong uptrend, price crossed Slow MA).");
                 signalFound = true;
            }
        } else if (minusDI > plusDI && fastMA < slowMA) { // Downtrend
            if (iClose(Symbol(), Period(), 1) < fastMA && iHigh(Symbol(), Period(), 1) >= fastMA) { // Pullback to Fast MA in downtrend
                 SellVotes++;
                 Print("Strategy [TrendRiding]: Sell Signal (Strong downtrend with pullback to Fast MA).");
                 signalFound = true;
            } else if (iClose(Symbol(), Period(), 1) < slowMA && iClose(Symbol(), Period(), 2) >= slowMA) { // Cross below slow MA
                 SellVotes++;
                 Print("Strategy [TrendRiding]: Sell Signal (Strong downtrend, price crossed Slow MA).");
                 signalFound = true;
            }
        }
    } else {
        Print("Strategy [TrendRiding]: No signal (ADX < 25 indicates weak trend).");
        signalFound = true;
    }

    if(!signalFound) {
        Print("Strategy [TrendRiding]: No signal (Trending conditions not met).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 3: Breakout Trading using ZigZag Indicator              |
//+------------------------------------------------------------------+
void AnalyzeZigZagBreakout() {
    // Find the last 2 ZigZag points.
    // ZigZag gives 3 buffers: 0 = main line (not useful for points), 1 = high points, 2 = low points
    double lastHighZigZag = 0;
    double lastLowZigZag = 0;
    int    shift = 1; // Start looking from the previous bar

    // Find last high point
    for (int i = 0; i < 200; i++) { // Look back up to 200 bars
        double val = iCustom(Symbol(), Period(), "ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep, 1, shift + i);
        if (val != 0 && val != EMPTY_VALUE) {
            lastHighZigZag = val;
            break;
        }
    }
    // Find last low point
    for (int i = 0; i < 200; i++) {
        double val = iCustom(Symbol(), Period(), "ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep, 2, shift + i);
        if (val != 0 && val != EMPTY_VALUE) {
            lastLowZigZag = val;
            break;
        }
    }

    if (lastHighZigZag == 0 || lastLowZigZag == 0) {
        Print("Strategy [ZigZag]: No signal (Could not find recent ZigZag points).");
        return;
    }

    double currentHigh = iHigh(Symbol(), Period(), 0);
    double currentLow = iLow(Symbol(), Period(), 0);
    double prevClose = iClose(Symbol(), Period(), 1);

    // Breakout above last significant ZigZag high
    if (prevClose > lastHighZigZag && currentHigh > lastHighZigZag) { // Ensure current bar also supports breakout
        BuyVotes++;
        Print("Strategy [ZigZag]: Buy Signal (Breakout above last high ", DoubleToString(lastHighZigZag, Digits), ").");
    }
    // Breakout below last significant ZigZag low
    else if (prevClose < lastLowZigZag && currentLow < lastLowZigZag) { // Ensure current bar also supports breakout
        SellVotes++;
        Print("Strategy [ZigZag]: Sell Signal (Breakout below last low ", DoubleToString(lastLowZigZag, Digits), ").");
    } else {
        Print("Strategy [ZigZag]: No signal (Price is within last ZigZag high/low).");
    }
}


//+------------------------------------------------------------------+
//| Strategy 4: Decreased Volatility Breakout (Bollinger Bands Width)|
//+------------------------------------------------------------------+
void AnalyzeDecreasedVolatilityBreakout() {
    double upperBand = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1);
    double lowerBand = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1);
    double middleBand = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1); // Or iMA

    if (upperBand == 0 || lowerBand == 0) return; // Indicator not ready

    double bandWidth = upperBand - lowerBand;

    // Calculate average bandwidth over last N periods to define "low"
    double avgBandWidth = 0;
    int count = 0;
    for(int i=1; i<=BB_Period; i++){
        double ub = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, i+1); // Shift back further
        double lb = iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, i+1);
        if(ub!=0 && lb!=0){
            avgBandWidth += (ub-lb);
            count++;
        }
    }
    if(count > 0) avgBandWidth /= count; else return;


    double currentClose = iClose(Symbol(), Period(), 0);
    double prevClose = iClose(Symbol(), Period(), 1); // Previous bar close

    // Check if current bandwidth is significantly lower than average (squeeze)
    if (bandWidth < avgBandWidth * VolatilityThresholdMultiplier) {
        // Now look for breakout
        if (currentClose > iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 0) &&
            prevClose <= iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1) ) {
            BuyVotes++;
            Print("Strategy [Volatility]: Buy Signal (Breakout above Upper Band after squeeze).");
        } else if (currentClose < iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 0) &&
                   prevClose >= iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1) ) {
            SellVotes++;
            Print("Strategy [Volatility]: Sell Signal (Breakout below Lower Band after squeeze).");
        } else {
            Print("Strategy [Volatility]: No signal (Low volatility squeeze detected, but no breakout yet).");
        }
    } else {
         Print("Strategy [Volatility]: No signal (Normal or High volatility, no squeeze).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 5: Correlation Trading                                  |
//+------------------------------------------------------------------+
void AnalyzeCorrelation() {
    if (CorrelationSymbol == "" || CorrelationSymbol == Symbol()) {
        Print("Correlation: Invalid or same CorrelationSymbol. Skipping.");
        return;
    }

    // Check if CorrelationSymbol exists and has enough data
    if(iBars(CorrelationSymbol, Period()) < CorrelationPeriod + 5){ // Need some buffer
        Print("Correlation: Not enough data for ", CorrelationSymbol, " on timeframe ", Period());
        return;
    }

    // Get price changes for current symbol
    double currentSymbolChange = (iClose(Symbol(), Period(), 0) - iClose(Symbol(), Period(), CorrelationPeriod)) / iClose(Symbol(), Period(), CorrelationPeriod);

    // Get price changes for correlation symbol
    // Ensure the correlated symbol's data is available
    double corrSymbolClose0 = iClose(CorrelationSymbol, Period(), 0);
    double corrSymbolCloseN = iClose(CorrelationSymbol, Period(), CorrelationPeriod);

    if(corrSymbolClose0 == 0 || corrSymbolCloseN == 0){
        Print("Correlation: Could not retrieve price data for ", CorrelationSymbol);
        return;
    }
    double correlationSymbolChange = (corrSymbolClose0 - corrSymbolCloseN) / corrSymbolCloseN;

    // This is a very simplified correlation logic.
    // Positive correlation: if CorrelationSymbol goes up, current symbol is expected to go up.
    // Negative correlation: if CorrelationSymbol goes up, current symbol is expected to go down.
    // For this example, let's assume positive correlation as a common scenario (e.g. AUDUSD and NZDUSD)
    // A more robust way would be to calculate Pearson correlation coefficient.

    // If CorrelationSymbol shows strong bullish movement, consider Buy for current.
    bool signalFound = false;
    if (correlationSymbolChange > 0.001) { // Threshold for "significant" move (e.g. 0.1%)
        // If current symbol hasn't moved as much, or is lagging, it might follow
        if (currentSymbolChange < correlationSymbolChange * 0.5) { // Current symbol lagging
             BuyVotes++;
             Print("Strategy [Correlation]: Buy Signal (Positive correlation with ", CorrelationSymbol, ", which is bullish).");
             signalFound = true;
        }
    }
    // If CorrelationSymbol shows strong bearish movement, consider Sell for current.
    else if (correlationSymbolChange < -0.001) { // Threshold for "significant" move
        if (currentSymbolChange > correlationSymbolChange * 0.5) { // Current symbol lagging (more positive or less negative)
             SellVotes++;
             Print("Strategy [Correlation]: Sell Signal (Positive correlation with ", CorrelationSymbol, ", which is bearish).");
             signalFound = true;
        }
    }

    if(!signalFound) {
        Print("Strategy [Correlation]: No signal (No significant divergence in correlation found).");
    }
}


//+------------------------------------------------------------------+
//| Strategy 6: Price Patterns (Engulfing)                           |
//+------------------------------------------------------------------+
void AnalyzePricePatterns() {
    // Bullish Engulfing: Previous bar is bearish, current bar is bullish and engulfs the previous bar's body
    double open1 = iOpen(Symbol(), Period(), 1);  // Previous bar open
    double close1 = iClose(Symbol(), Period(), 1); // Previous bar close
    double open0 = iOpen(Symbol(), Period(), 0);   // Current bar open
    double close0 = iClose(Symbol(), Period(), 0);  // Current bar close (at the moment of check)
    double high0 = iHigh(Symbol(), Period(), 0);
    double low0  = iLow(Symbol(), Period(), 0);
    double high1 = iHigh(Symbol(), Period(), 1);
    double low1  = iLow(Symbol(), Period(), 1);


    // Bullish Engulfing
    // 1. Previous bar is bearish (close1 < open1)
    // 2. Current bar is bullish (close0 > open0)
    // 3. Current bar's open is below or equal to previous bar's close
    // 4. Current bar's close is above or equal to previous bar's open
    // (More strict: current body engulfs previous body: open0 < close1 && close0 > open1)
    if (close1 < open1 && close0 > open0 && open0 <= close1 && close0 >= open1) {
        // Check if it's at a potential support (e.g. recent low or MA) for confirmation
        // For simplicity, we'll just use the pattern itself for now
        BuyVotes++;
        Print("Strategy [PricePattern]: Buy Signal (Bullish Engulfing).");
    }

    // Bearish Engulfing
    // 1. Previous bar is bullish (close1 > open1)
    // 2. Current bar is bearish (close0 < open0)
    // 3. Current bar's open is above or equal to previous bar's close
    // 4. Current bar's close is below or equal to previous bar's open
    // (More strict: current body engulfs previous body: open0 > close1 && close0 < open1)
    else if (close1 > open1 && close0 < open0 && open0 >= close1 && close0 <= open1) {
        SellVotes++;
        Print("Strategy [PricePattern]: Sell Signal (Bearish Engulfing).");
    } else {
        Print("Strategy [PricePattern]: No signal (No Engulfing pattern detected).");
    }
}

//+------------------------------------------------------------------+
//| Strategy 7: Smart Money Concepts (Basic Order Block)             |
//+------------------------------------------------------------------+
void AnalyzeSmartMoneyConcepts() {
    // Simplified Order Block:
    // Bullish OB: Last down candle before a strong up move that breaks structure (previous high).
    // Bearish OB: Last up candle before a strong down move that breaks structure (previous low).

    // Look back for a significant move (e.g., 3-5 bars)
    int lookback = 5;
    double highestHigh = 0;
    double lowestLow = 9999999;
    int breakHighBar = -1;
    int breakLowBar = -1;

    // Find recent highest high and lowest low (break of structure points)
    for (int i = 1; i <= lookback + 5; i++) { // Look a bit further for structure
        if (iHigh(Symbol(), Period(), i) > highestHigh) highestHigh = iHigh(Symbol(), Period(), i);
        if (iLow(Symbol(), Period(), i) < lowestLow) lowestLow = iLow(Symbol(), Period(), i);
    }

    // Bullish Scenario: Look for a break of a recent high
    // Then identify the down candle (order block) before that break.
    for (int i = 1; i <= lookback; i++) {
        // Check for a break of structure (BoS) - current/recent bar makes a new high
        if (iHigh(Symbol(), Period(), 0) > highestHigh && iHigh(Symbol(), Period(), 1) <= highestHigh) { // Current bar just broke
            // Now find the last down candle before this rally started (e.g., from i=1 up to i=lookback)
            for (int j = 1; j <= lookback; j++) {
                if (iClose(Symbol(), Period(), j+1) < iOpen(Symbol(), Period(), j+1)) { // Down candle at j+1
                    // Check if current price is retesting this OB's range
                    double obHigh = iHigh(Symbol(), Period(), j+1);
                    double obLow = iLow(Symbol(), Period(), j+1);
                    if (iClose(Symbol(), Period(), 0) >= obLow && iClose(Symbol(), Period(), 0) <= obHigh &&
                        iLow(Symbol(), Period(), 0) <= obHigh && iLow(Symbol(), Period(), 0) >= obLow * 0.98 ) { // Price entered OB zone
                        BuyVotes++;
                        Print("Strategy [SMC]: Buy Signal (Retest of Bullish Order Block after BoS).");
                        return; // Found a signal
                    }
                }
            }
        }
    }

    // Bearish Scenario: Look for a break of a recent low
    // Then identify the up candle (order block) before that break.
    for (int i = 1; i <= lookback; i++) {
        if (iLow(Symbol(), Period(), 0) < lowestLow && iLow(Symbol(), Period(), 1) >= lowestLow) { // Current bar just broke structure low
            for (int j = 1; j <= lookback; j++) {
                if (iClose(Symbol(), Period(), j+1) > iOpen(Symbol(), Period(), j+1)) { // Up candle at j+1
                    double obHigh = iHigh(Symbol(), Period(), j+1);
                    double obLow = iLow(Symbol(), Period(), j+1);
                    if (iClose(Symbol(), Period(), 0) <= obHigh && iClose(Symbol(), Period(), 0) >= obLow &&
                        iHigh(Symbol(), Period(), 0) >= obLow && iHigh(Symbol(), Period(), 0) <= obHigh * 1.02) { // Price entered OB zone
                        SellVotes++;
                        Print("Strategy [SMC]: Sell Signal (Retest of Bearish Order Block after BoS).");
                        return; // Found a signal
                    }
                }
            }
        }
    }
    Print("Strategy [SMC]: No signal (No BoS + Order Block retest found).");
}


//+------------------------------------------------------------------+
//| Helper Functions to Check for Open Trade Sets (MQL4)             |
//+------------------------------------------------------------------+
bool IsBuySetOpenMQL4() {
    long magic_base = 12345;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() == Symbol() &&
                OrderMagicNumber() == magic_base + 0 &&
                OrderType() == OP_BUY) {
                return true;
            }
        }
    }
    return false;
}

bool IsSellSetOpenMQL4() {
    long magic_base = 12345;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() == Symbol() &&
                OrderMagicNumber() == magic_base + 0 &&
                OrderType() == OP_SELL) {
                return true;
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
        if (IsBuySetOpenMQL4() && SellVotes > BuyVotes) {
            Print("Opposing SELL signal detected while BUY set is open. Tightening SL.");
            double new_sl = iLow(Symbol(), Period(), 1);
            long instance_magic_base = 10000;
            for (int i = OrdersTotal() - 1; i >= 0; i--) {
                if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                    if (OrderSymbol() == Symbol() && OrderType() == OP_BUY && OrderMagicNumber() >= instance_magic_base) {
                        if (new_sl > OrderStopLoss()) {
                            if(!OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0)) {
                                Print("Error tightening SL for BUY Ticket ", OrderTicket(), ": ", GetLastError());
                            } else {
                                Print("Tightened SL for BUY Ticket ", OrderTicket(), " to ", new_sl);
                            }
                        }
                    }
                }
            }
            return; // Stop further processing
        }
        if (IsSellSetOpenMQL4() && BuyVotes > SellVotes) {
            Print("Opposing BUY signal detected while SELL set is open. Tightening SL.");
            double new_sl = iHigh(Symbol(), Period(), 1);
            long instance_magic_base = 10000;
            for (int i = OrdersTotal() - 1; i >= 0; i--) {
                if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                    if (OrderSymbol() == Symbol() && OrderType() == OP_SELL && OrderMagicNumber() >= instance_magic_base) {
                        if (new_sl < OrderStopLoss() || OrderStopLoss() == 0) {
                             if(!OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0)) {
                                Print("Error tightening SL for SELL Ticket ", OrderTicket(), ": ", GetLastError());
                            } else {
                                Print("Tightened SL for SELL Ticket ", OrderTicket(), " to ", new_sl);
                            }
                        }
                    }
                }
            }
            return; // Stop further processing
        }
    }

    // --- Standard Trade Opening Logic ---
    if (CountOpenTrades() >= MaxOrders) {
        Print("Max orders reached (", CountOpenTrades(), " sets). No new trade.");
        return;
    }

    // Lot Size Calculation
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    double partialLotSize = LotSize / 3.0;
    // Normalize lot size
    partialLotSize = MathRound(partialLotSize / lotStep) * lotStep;
    if (partialLotSize < minLot) partialLotSize = minLot;
    if (partialLotSize * 3.0 > LotSize + lotStep) {
        Print("Total LotSize ", LotSize, " is too small to be split into 3 valid partial orders (min partial: ", minLot, "). Aborting.");
        return;
    }

    double point = Point;
    if (_Digits == 3 || _Digits == 5) point *= 10;

    int tp_pips[] = {TakeProfitPips1, TakeProfitPips2, TakeProfitPips3};
    int sl_pips = InitialStopLossPips;
    long instance_magic_base = 10000; // A base to distinguish this EA from others

    if (BuyVotes > SellVotes) {
        long setBaseMagic = instance_magic_base + (g_setCounter * 10);
        g_setCounter++;

        Print("Attempting to place BUY orders (Set Magic Base: ", setBaseMagic, ")... PartialLot: ", DoubleToString(partialLotSize,2));
        for (int i = 0; i < 3; i++) {
            double price = Ask;
            double takeProfitLevel = price + tp_pips[i] * point;
            double stopLossLevel = price - sl_pips * point;
            string comment = "AdvEA_Buy_P" + (string)(i+1);
            int magicNumber = setBaseMagic + i;

            int ticket = OrderSend(Symbol(), OP_BUY, partialLotSize, price, 3, stopLossLevel, takeProfitLevel, comment, magicNumber, 0, clrGreen);
            if (ticket > 0) {
                Print("BUY order #", i+1, " (Magic: ", magicNumber, ") placed successfully. Ticket: ", ticket, " Lot: ", partialLotSize, " TP: ", takeProfitLevel, " SL: ", stopLossLevel);
            } else {
                Print("Error placing BUY order #", i+1, " (Magic: ", magicNumber, "): ", GetLastError());
            }
            Sleep(100); // Small pause between orders
        }
    } else if (SellVotes > BuyVotes) {
        long setBaseMagic = instance_magic_base + (g_setCounter * 10);
        g_setCounter++;

        Print("Attempting to place SELL orders (Set Magic Base: ", setBaseMagic, ")... PartialLot: ", DoubleToString(partialLotSize,2));
        for (int i = 0; i < 3; i++) {
            double price = Bid;
            double takeProfitLevel = price - tp_pips[i] * point;
            double stopLossLevel = price + sl_pips * point;
            string comment = "AdvEA_Sell_P" + (string)(i+1);
            int magicNumber = setBaseMagic + i;

            int ticket = OrderSend(Symbol(), OP_SELL, partialLotSize, price, 3, stopLossLevel, takeProfitLevel, comment, magicNumber, 0, clrRed);
            if (ticket > 0) {
                Print("SELL order #", i+1, " (Magic: ", magicNumber, ") placed successfully. Ticket: ", ticket, " Lot: ", partialLotSize, " TP: ", takeProfitLevel, " SL: ", stopLossLevel);
            } else {
                Print("Error placing SELL order #", i+1, " (Magic: ", magicNumber, "): ", GetLastError());
            }
            Sleep(100); // Small pause between orders
        }
    } else {
        Print("No trade signal: BuyVotes (", BuyVotes, ") == SellVotes (", SellVotes, ")");
    }
}

//+------------------------------------------------------------------+
//| Breakeven Logic for MQL4                                         |
//+------------------------------------------------------------------+
int BreakevenTriggeredForTP1Tickets[]; // Stores tickets of TP1s that triggered BE

bool IsTicketInArrayMQL4(int ticket, int &tickets_array[]) {
    for (int i = 0; i < ArraySize(tickets_array); i++) {
        if (tickets_array[i] == ticket) return true;
    }
    return false;
}

void ManageOpenTradesMQL4() {
    long instance_magic_base = 10000;

    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            int deal_magic = OrderMagicNumber();
            bool isTP1 = (deal_magic >= instance_magic_base) && (deal_magic % 10 == 0);

            if (isTP1 && OrderSymbol() == Symbol()) {
                if (IsTicketInArrayMQL4(OrderTicket(), BreakevenTriggeredForTP1Tickets)) continue;

                if (OrderClosePrice() == OrderTakeProfit() && OrderTakeProfit() != 0) {
                    long setBaseMagic = deal_magic; // For TP1, its magic is the set's base magic

                    Print("ManageTrades: TP1 (Ticket: ", OrderTicket(), ") hit TP. Processing BE for siblings of set ", setBaseMagic);

                    int arr_size = ArraySize(BreakevenTriggeredForTP1Tickets);
                    ArrayResize(BreakevenTriggeredForTP1Tickets, arr_size + 1);
                    BreakevenTriggeredForTP1Tickets[arr_size] = OrderTicket();

                    for (int j = OrdersTotal() - 1; j >= 0; j--) {
                        if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) {
                            int current_magic = OrderMagicNumber();
                            if (OrderSymbol() == Symbol() && (current_magic == setBaseMagic + 1 || current_magic == setBaseMagic + 2)) {
                                double open_price = OrderOpenPrice();
                                double current_sl = OrderStopLoss();
                                double point = Point;
                                if (_Digits == 3 || _Digits == 5) point *= 10;
                                double profit_buffer = BreakevenPlusPips * point;
                                double new_sl;

                                if (OrderType() == OP_BUY) {
                                    new_sl = open_price + profit_buffer;
                                    if (current_sl < new_sl) {
                                        // Before modifying, refresh rates and check if SL is too close
                                        RefreshRates();
                                        if(new_sl <= Bid) {
                                            if(!OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrNONE)) {
                                                Print("Error modifying BUY order ", OrderTicket(), " to BE+: ", GetLastError());
                                            } else {
                                                Print("Successfully moved SL to BE+ for BUY order ", OrderTicket());
                                            }
                                        }
                                    }
                                } else { // OP_SELL
                                    new_sl = open_price - profit_buffer;
                                    if (current_sl > new_sl || current_sl == 0) {
                                        RefreshRates();
                                        if(new_sl >= Ask) {
                                            if(!OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrNONE)) {
                                                Print("Error modifying SELL order ", OrderTicket(), " to BE+: ", GetLastError());
                                            } else {
                                                Print("Successfully moved SL to BE+ for SELL order ", OrderTicket());
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Break after finding and processing one TP1 hit to avoid multiple BE triggers in one tick
                    break;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Count Open Trades for the current symbol and EA                  |
//+------------------------------------------------------------------+
int CountOpenTrades() { // This now counts sets
    int setCount = 0;
    long instance_magic_base = 10000;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            // A set is identified by its first partial order, which has a magic number ending in 0
            if (OrderSymbol() == Symbol() && OrderMagicNumber() >= instance_magic_base && OrderMagicNumber() % 10 == 0) {
                setCount++;
            }
        }
    }
    return setCount;
}
//+------------------------------------------------------------------+
//| Strategy 8: Head and Shoulders Pattern (MQL4)                    |
//+------------------------------------------------------------------+
// MQL4 does not have structs in the same way as MQL5 for this purpose easily,
// so we will use parallel arrays to store ZigZag point data.
void AnalyzeHeadAndShoulders() {
    // 1. Get ZigZag points
    int pointsToScan = 30;
    double zz_prices[];
    int zz_indices[];
    bool zz_isHigh[];
    int zz_count = 0;

    for (int i = 0; i < pointsToScan; i++) {
        double high_val = iCustom(Symbol(), Period(), "ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep, 1, i);
        if (high_val != 0) {
            ArrayResize(zz_prices, zz_count + 1);
            ArrayResize(zz_indices, zz_count + 1);
            ArrayResize(zz_isHigh, zz_count + 1);
            zz_prices[zz_count] = high_val;
            zz_indices[zz_count] = i;
            zz_isHigh[zz_count] = true;
            zz_count++;
        }
        double low_val = iCustom(Symbol(), Period(), "ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep, 2, i);
        if (low_val != 0) {
            ArrayResize(zz_prices, zz_count + 1);
            ArrayResize(zz_indices, zz_count + 1);
            ArrayResize(zz_isHigh, zz_count + 1);
            zz_prices[zz_count] = low_val;
            zz_indices[zz_count] = i;
            zz_isHigh[zz_count] = false;
            zz_count++;
        }
    }

    if (zz_count < 5) {
        Print("Strategy [H&S]: Not enough ZigZag points found (", zz_count, ").");
        return;
    }

    // Sort the points by index because iCustom doesn't guarantee order
    for (int i = 0; i < zz_count - 1; i++) {
        for (int j = i + 1; j < zz_count; j++) {
            if (zz_indices[i] > zz_indices[j]) {
                // Swap all parallel array elements
                double temp_price = zz_prices[i]; zz_prices[i] = zz_prices[j]; zz_prices[j] = temp_price;
                int temp_index = zz_indices[i]; zz_indices[i] = zz_indices[j]; zz_indices[j] = temp_index;
                bool temp_isHigh = zz_isHigh[i]; zz_isHigh[i] = zz_isHigh[j]; zz_isHigh[j] = temp_isHigh;
            }
        }
    }

    // 2. Loop through points to find patterns
    for (int i = 0; i <= zz_count - 5; i++) {
        bool p1_isHigh = zz_isHigh[i]; double p1_price = zz_prices[i]; int p1_index = zz_indices[i];
        bool p2_isHigh = zz_isHigh[i+1]; double p2_price = zz_prices[i+1]; int p2_index = zz_indices[i+1];
        bool p3_isHigh = zz_isHigh[i+2]; double p3_price = zz_prices[i+2]; int p3_index = zz_indices[i+2];
        bool p4_isHigh = zz_isHigh[i+3]; double p4_price = zz_prices[i+3]; int p4_index = zz_indices[i+3];
        bool p5_isHigh = zz_isHigh[i+4]; double p5_price = zz_prices[i+4]; int p5_index = zz_indices[i+4];

        // --- Head and Shoulders (Bearish) ---
        if(p1_isHigh && !p2_isHigh && p3_isHigh && !p4_isHigh && p5_isHigh) {
            if (p3_price > p1_price && p3_price > p5_price) {
                double patternHeight = p3_price - MathMin(p2_price, p4_price);
                if (MathAbs(p1_price - p5_price) < (patternHeight * 0.15)) {
                    double slope = (p4_price - p2_price) / (p4_index - p2_index);
                    double neckline_val = p4_price + slope * (0 - p4_index);
                    if (iClose(Symbol(), Period(), 0) < neckline_val) {
                        SellVotes++;
                        Print("Strategy [H&S]: Sell Signal (Head and Shoulders pattern confirmed by neckline break).");
                        return;
                    }
                }
            }
        }

        // --- Inverse Head and Shoulders (Bullish) ---
        if(!p1_isHigh && p2_isHigh && !p3_isHigh && p4_isHigh && !p5_isHigh) {
            if (p3_price < p1_price && p3_price < p5_price) {
                double patternHeight = MathMax(p2_price, p4_price) - p3_price;
                if (MathAbs(p1_price - p5_price) < (patternHeight * 0.15)) {
                    double slope = (p4_price - p2_price) / (p4_index - p2_index);
                    double neckline_val = p4_price + slope * (0 - p4_index);
                    if (iClose(Symbol(), Period(), 0) > neckline_val) {
                        BuyVotes++;
                        Print("Strategy [H&S]: Buy Signal (Inverse Head and Shoulders pattern confirmed by neckline break).");
                        return;
                    }
                }
            }
        }
    }

    Print("Strategy [H&S]: No signal (No H&S pattern detected).");
}

//+------------------------------------------------------------------+
//| Strategy 9: RSI Divergence (MQL4)                                |
//+------------------------------------------------------------------+
void AnalyzeRsiDivergence() {
    // 1. Get ZigZag points (reusing H&S logic structure)
    int pointsToScan = 20;
    double zz_prices[];
    int zz_indices[];
    bool zz_isHigh[];
    int zz_count = 0;

    for (int i = 0; i < pointsToScan; i++) {
        double high_val = iCustom(Symbol(), Period(), "ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep, 1, i);
        if (high_val != 0) {
            ArrayResize(zz_prices, zz_count + 1); ArrayResize(zz_indices, zz_count + 1); ArrayResize(zz_isHigh, zz_count + 1);
            zz_prices[zz_count] = high_val; zz_indices[zz_count] = i; zz_isHigh[zz_count] = true; zz_count++;
        }
        double low_val = iCustom(Symbol(), Period(), "ZigZag", ZigZag_Depth, ZigZag_Deviation, ZigZag_Backstep, 2, i);
        if (low_val != 0) {
            ArrayResize(zz_prices, zz_count + 1); ArrayResize(zz_indices, zz_count + 1); ArrayResize(zz_isHigh, zz_count + 1);
            zz_prices[zz_count] = low_val; zz_indices[zz_count] = i; zz_isHigh[zz_count] = false; zz_count++;
        }
    }
    if (zz_count < 4) { Print("Strategy [RSI Divergence]: Not enough ZigZag points."); return; }
    // Sort points
    for (int i = 0; i < zz_count - 1; i++) for (int j = i + 1; j < zz_count; j++) if (zz_indices[i] > zz_indices[j]) {
        double temp_price = zz_prices[i]; zz_prices[i] = zz_prices[j]; zz_prices[j] = temp_price;
        int temp_index = zz_indices[i]; zz_indices[i] = zz_indices[j]; zz_indices[j] = temp_index;
        bool temp_isHigh = zz_isHigh[i]; zz_isHigh[i] = zz_isHigh[j]; zz_isHigh[j] = temp_isHigh;
    }

    // Find last two highs and last two lows
    double H1_price=0, H2_price=0, L1_price=0, L2_price=0;
    int H1_index=0, H2_index=0, L1_index=0, L2_index=0;
    int highsFound = 0, lowsFound = 0;
    for(int i = zz_count - 1; i >= 0; i--) {
        if(zz_isHigh[i]) {
            if(highsFound == 0) { H2_price = zz_prices[i]; H2_index = zz_indices[i]; }
            if(highsFound == 1) { H1_price = zz_prices[i]; H1_index = zz_indices[i]; }
            highsFound++;
        } else {
            if(lowsFound == 0) { L2_price = zz_prices[i]; L2_index = zz_indices[i]; }
            if(lowsFound == 1) { L1_price = zz_prices[i]; L1_index = zz_indices[i]; }
            lowsFound++;
        }
        if(highsFound >= 2 && lowsFound >= 2) break;
    }

    // Check for Bearish Divergence
    if(highsFound >= 2) {
        if(H2_price > H1_price) {
            double rsi_h1 = iRSI(Symbol(), Period(), RSI_Period, RSI_AppliedPrice, H1_index);
            double rsi_h2 = iRSI(Symbol(), Period(), RSI_Period, RSI_AppliedPrice, H2_index);
            if(rsi_h2 < rsi_h1 && rsi_h1 > 50 && rsi_h2 > 50) {
                SellVotes++;
                Print("Strategy [RSI Divergence]: Sell Signal (Bearish divergence confirmed).");
                return;
            }
        }
    }

    // Check for Bullish Divergence
    if(lowsFound >= 2) {
        if(L2_price < L1_price) {
            double rsi_l1 = iRSI(Symbol(), Period(), RSI_Period, RSI_AppliedPrice, L1_index);
            double rsi_l2 = iRSI(Symbol(), Period(), RSI_Period, RSI_AppliedPrice, L2_index);
            if(rsi_l2 > rsi_l1 && rsi_l1 < 50 && rsi_l2 < 50) {
                BuyVotes++;
                Print("Strategy [RSI Divergence]: Buy Signal (Bullish divergence confirmed).");
                return;
            }
        }
    }

    Print("Strategy [RSI Divergence]: No signal (No divergence detected).");
}

//+------------------------------------------------------------------+
//| Strategy 10: RSI Overbought/Oversold Crossover (MQL4)            |
//+------------------------------------------------------------------+
void AnalyzeRsiCrossover() {
    double rsi_shift1 = iRSI(Symbol(), Period(), RSI_Period, RSI_AppliedPrice, 1);
    double rsi_shift2 = iRSI(Symbol(), Period(), RSI_Period, RSI_AppliedPrice, 2);

    // Check for Bearish Crossover
    if (rsi_shift2 >= RSI_Overbought_Level && rsi_shift1 < RSI_Overbought_Level) {
        SellVotes++;
        Print("Strategy [RSI Crossover]: Sell Signal (RSI crossed down from Overbought zone).");
        return;
    }

    // Check for Bullish Crossover
    if (rsi_shift2 <= RSI_Oversold_Level && rsi_shift1 > RSI_Oversold_Level) {
        BuyVotes++;
        Print("Strategy [RSI Crossover]: Buy Signal (RSI crossed up from Oversold zone).");
        return;
    }

    Print("Strategy [RSI Crossover]: No signal (No OB/OS crossover detected).");
}

//+------------------------------------------------------------------+
//| Strategy 11: Stochastic Oscillator Crossover (MQL4)              |
//+------------------------------------------------------------------+
void AnalyzeStochasticCrossover() {
    double k_shift1 = iStochastic(Symbol(), Period(), Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, Stoch_MA_Method, 0, MODE_MAIN, 1);
    double d_shift1 = iStochastic(Symbol(), Period(), Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, Stoch_MA_Method, 0, MODE_SIGNAL, 1);
    double k_shift2 = iStochastic(Symbol(), Period(), Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, Stoch_MA_Method, 0, MODE_MAIN, 2);
    double d_shift2 = iStochastic(Symbol(), Period(), Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, Stoch_MA_Method, 0, MODE_SIGNAL, 2);

    // Check for Bearish Crossover
    if (k_shift1 > Stoch_Overbought_Level && d_shift1 > Stoch_Overbought_Level) {
        if (k_shift2 > d_shift2 && k_shift1 < d_shift1) {
            SellVotes++;
            Print("Strategy [Stochastic]: Sell Signal (K crossed below D in Overbought zone).");
            return;
        }
    }

    // Check for Bullish Crossover
    if (k_shift1 < Stoch_Oversold_Level && d_shift1 < Stoch_Oversold_Level) {
        if (k_shift2 < d_shift2 && k_shift1 > d_shift1) {
            BuyVotes++;
            Print("Strategy [Stochastic]: Buy Signal (K crossed above D in Oversold zone).");
            return;
        }
    }

    Print("Strategy [Stochastic Crossover]: No signal (No OB/OS crossover detected).");
}

//+------------------------------------------------------------------+
//| Strategy 12: MACD Crossover (MQL4)                               |
//+------------------------------------------------------------------+
void AnalyzeMacdCrossover() {
    double main_shift1 = iMACD(Symbol(), Period(), MACD_Fast_EMA_Period, MACD_Slow_EMA_Period, MACD_Signal_SMA_Period, MACD_AppliedPrice, MODE_MAIN, 1);
    double signal_shift1 = iMACD(Symbol(), Period(), MACD_Fast_EMA_Period, MACD_Slow_EMA_Period, MACD_Signal_SMA_Period, MACD_AppliedPrice, MODE_SIGNAL, 1);
    double main_shift2 = iMACD(Symbol(), Period(), MACD_Fast_EMA_Period, MACD_Slow_EMA_Period, MACD_Signal_SMA_Period, MACD_AppliedPrice, MODE_MAIN, 2);
    double signal_shift2 = iMACD(Symbol(), Period(), MACD_Fast_EMA_Period, MACD_Slow_EMA_Period, MACD_Signal_SMA_Period, MACD_AppliedPrice, MODE_SIGNAL, 2);

    // Check for Bullish Crossover
    if (main_shift2 <= signal_shift2 && main_shift1 > signal_shift1) {
        BuyVotes++;
        Print("Strategy [MACD Crossover]: Buy Signal (Main line crossed above Signal line).");
        return;
    }

    // Check for Bearish Crossover
    if (main_shift2 >= signal_shift2 && main_shift1 < signal_shift1) {
        SellVotes++;
        Print("Strategy [MACD Crossover]: Sell Signal (Main line crossed below Signal line).");
        return;
    }

    Print("Strategy [MACD Crossover]: No signal (No crossover detected).");
}

//+------------------------------------------------------------------+
//| Strategy 14: Inside/Outside Bars (MQL4)                          |
//+------------------------------------------------------------------+
void AnalyzeInsideOutsideBars() {
    // Check for Inside Bar Breakout
    bool isInsideBar = iHigh(Symbol(), Period(), 1) < iHigh(Symbol(), Period(), 2) && iLow(Symbol(), Period(), 1) > iLow(Symbol(), Period(), 2);
    if (isInsideBar) {
        if (iClose(Symbol(), Period(), 0) > iHigh(Symbol(), Period(), 1)) {
            BuyVotes++;
            Print("Strategy [I/O Bars]: Buy Signal (Breakout of Inside Bar high).");
            return;
        }
        if (iClose(Symbol(), Period(), 0) < iLow(Symbol(), Period(), 1)) {
            SellVotes++;
            Print("Strategy [I/O Bars]: Sell Signal (Breakout of Inside Bar low).");
            return;
        }
    }

    // Check for Outside Bar
    bool isOutsideBar = iHigh(Symbol(), Period(), 1) > iHigh(Symbol(), Period(), 2) && iLow(Symbol(), Period(), 1) < iLow(Symbol(), Period(), 2);
    if(isOutsideBar) {
        if(iClose(Symbol(), Period(), 1) > iOpen(Symbol(), Period(), 1)) {
            BuyVotes++;
            Print("Strategy [I/O Bars]: Buy Signal (Bullish Outside Bar detected).");
            return;
        }
        if(iClose(Symbol(), Period(), 1) < iOpen(Symbol(), Period(), 1)) {
            SellVotes++;
            Print("Strategy [I/O Bars]: Sell Signal (Bearish Outside Bar detected).");
            return;
        }
    }

    Print("Strategy [I/O Bars]: No signal (No Inside Bar breakout or Outside Bar detected).");
}

//+------------------------------------------------------------------+
//| Strategy 15: Pin Bars (Hammer / Shooting Star) (MQL4)            |
//+------------------------------------------------------------------+
void AnalyzePinBars() {
    double open = iOpen(Symbol(), Period(), 1);
    double high = iHigh(Symbol(), Period(), 1);
    double low = iLow(Symbol(), Period(), 1);
    double close = iClose(Symbol(), Period(), 1);

    double bodySize = MathAbs(open - close);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;

    if (bodySize < Point) bodySize = Point;

    // Bullish Pin Bar (Hammer)
    if (lowerWick > (bodySize * PinBar_Wick_to_Body_Ratio) && upperWick < bodySize) {
        BuyVotes++;
        Print("Strategy [Pin Bars]: Buy Signal (Bullish Pin Bar / Hammer detected).");
        return;
    }

    // Bearish Pin Bar (Shooting Star)
    if (upperWick > (bodySize * PinBar_Wick_to_Body_Ratio) && lowerWick < bodySize) {
        SellVotes++;
        Print("Strategy [Pin Bars]: Sell Signal (Bearish Pin Bar / Shooting Star detected).");
        return;
    }

    Print("Strategy [Pin Bars]: No signal (No valid Pin Bar detected).");
}

//+------------------------------------------------------------------+
//| Strategy 17: Fair Value Gaps (Imbalances) (MQL4)                 |
//+------------------------------------------------------------------+
void AnalyzeFairValueGaps() {
    int lookback = 50;

    // Find the most recent FVG that has not been filled
    for (int i = 1; i < lookback - 2; i++) {
        // Bullish FVG (gap between low of i and high of i+2) -> Potential Sell Signal
        double bullish_fvg_top = iHigh(Symbol(), Period(), i+2);
        double bullish_fvg_bottom = iLow(Symbol(), Period(), i);
        if (bullish_fvg_top > bullish_fvg_bottom) {
            bool filled = false;
            for(int j = i-1; j >= 0; j--) {
                if(iLow(Symbol(), Period(), j) < bullish_fvg_top) {
                    filled = true;
                    break;
                }
            }
            if(!filled) {
                if(iClose(Symbol(), Period(), 0) <= bullish_fvg_top && iClose(Symbol(), Period(), 0) >= bullish_fvg_bottom) {
                    SellVotes++;
                    Print("Strategy [FVG]: Sell Signal (Price entered a Bullish FVG zone).");
                    return;
                }
            }
        }

        // Bearish FVG (gap between high of i and low of i+2) -> Potential Buy Signal
        double bearish_fvg_top = iHigh(Symbol(), Period(), i);
        double bearish_fvg_bottom = iLow(Symbol(), Period(), i+2);
        if (bearish_fvg_top > bearish_fvg_bottom) {
            bool filled = false;
            for(int j = i-1; j >= 0; j--) {
                if(iHigh(Symbol(), Period(), j) > bearish_fvg_bottom) {
                    filled = true;
                    break;
                }
            }
            if(!filled) {
                if(iClose(Symbol(), Period(), 0) >= bearish_fvg_bottom && iClose(Symbol(), Period(), 0) <= bearish_fvg_top) {
                    BuyVotes++;
                    Print("Strategy [FVG]: Buy Signal (Price entered a Bearish FVG zone).");
                    return;
                }
            }
        }
    }

    Print("Strategy [FVG]: No signal (No recent, unfilled FVG is being tested).");
}

//+------------------------------------------------------------------+

// --- End of File ---
