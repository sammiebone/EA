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
input int      MaxOrders         = 2;        // Maximum number of open orders
input double   LotSize           = 0.01;     // Fixed Lot Size
input int      TakeProfitPips    = 50;       // Take Profit in Pips
input int      StopLossPips      = 25;       // Stop Loss in Pips
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

//--- Global Variables
datetime LastAnalysisTime = 0;
int      BuyVotes = 0;
int      SellVotes = 0;

// Indicator Handles (MQL4 style, direct usage)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    //---
    if (WaitPeriodMinutes < 1) {
        Print("WaitPeriodMinutes cannot be less than 1. Setting to 1.");
        WaitPeriodMinutes = 1;
    }
    LastAnalysisTime = TimeCurrent() - (WaitPeriodMinutes * 60); // Ensure first run
    Print("AdvancedEA Initialized. MaxOrders: ", MaxOrders, ", LotSize: ", LotSize, ", TP: ", TakeProfitPips, ", SL: ", StopLossPips, ", Wait: ", WaitPeriodMinutes);
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
    if (TimeCurrent() - LastAnalysisTime >= WaitPeriodMinutes * 60) {
        if(IsNewBar()){ // Optional: Only run on new bar within the minute interval
            Print("Analyzing market...");
            ResetVotes();
            AnalyzeStrategies();
            ProcessTradeDecisions();
            LastAnalysisTime = TimeCurrent();
        }
    }
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

    Print("Analysis Complete. Buy Votes: ", BuyVotes, ", Sell Votes: ", SellVotes);
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
        Print("SMA20: Buy Signal (Crossed Above)");
    } else if (closePrice1 < smaValue && closePrice2 >= smaValue) { // Price crossed below SMA
        SellVotes++;
        Print("SMA20: Sell Signal (Crossed Below)");
    } else if (closePrice1 > smaValue) {
        BuyVotes++; // Price is above SMA - bullish bias
        Print("SMA20: Buy Signal (Above SMA)");
    } else if (closePrice1 < smaValue) {
        SellVotes++; // Price is below SMA - bearish bias
        Print("SMA20: Sell Signal (Below SMA)");
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
    if (adxValue > 25) { // Trend is considered strong enough
        if (plusDI > minusDI && fastMA > slowMA) { // Uptrend
            // Optional: Check for pullback to fast MA or entry condition
            if (iClose(Symbol(), Period(), 1) > fastMA && iLow(Symbol(), Period(), 1) <= fastMA) { // Pullback to Fast MA in uptrend
                 BuyVotes++;
                 Print("TrendRiding: Buy Signal (Uptrend with pullback)");
            } else if (iClose(Symbol(), Period(), 1) > slowMA && iClose(Symbol(), Period(), 2) <= slowMA) { // Cross above slow MA
                 BuyVotes++;
                 Print("TrendRiding: Buy Signal (Uptrend, cross slow MA)");
            }
        } else if (minusDI > plusDI && fastMA < slowMA) { // Downtrend
            if (iClose(Symbol(), Period(), 1) < fastMA && iHigh(Symbol(), Period(), 1) >= fastMA) { // Pullback to Fast MA in downtrend
                 SellVotes++;
                 Print("TrendRiding: Sell Signal (Downtrend with pullback)");
            } else if (iClose(Symbol(), Period(), 1) < slowMA && iClose(Symbol(), Period(), 2) >= slowMA) { // Cross below slow MA
                 SellVotes++;
                 Print("TrendRiding: Sell Signal (Downtrend, cross slow MA)");
            }
        }
    } else {
        Print("TrendRiding: No strong trend (ADX < 25)");
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
        Print("ZigZag: Could not find recent ZigZag points.");
        return;
    }

    double currentHigh = iHigh(Symbol(), Period(), 0);
    double currentLow = iLow(Symbol(), Period(), 0);
    double prevClose = iClose(Symbol(), Period(), 1);

    // Breakout above last significant ZigZag high
    if (prevClose > lastHighZigZag && currentHigh > lastHighZigZag) { // Ensure current bar also supports breakout
        BuyVotes++;
        Print("ZigZag: Buy Signal (Breakout above ", DoubleToString(lastHighZigZag, Digits), ")");
    }
    // Breakout below last significant ZigZag low
    else if (prevClose < lastLowZigZag && currentLow < lastLowZigZag) { // Ensure current bar also supports breakout
        SellVotes++;
        Print("ZigZag: Sell Signal (Breakout below ", DoubleToString(lastLowZigZag, Digits), ")");
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
        Print("Volatility: Low volatility detected (BB Squeeze). Bandwidth: ", bandWidth, ", Avg Bandwidth: ", avgBandWidth);
        // Now look for breakout
        if (currentClose > iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 0) &&
            prevClose <= iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1) ) {
            BuyVotes++;
            Print("Volatility: Buy Signal (Breakout above Upper Band after squeeze)");
        } else if (currentClose < iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 0) &&
                   prevClose >= iBands(Symbol(), Period(), BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1) ) {
            SellVotes++;
            Print("Volatility: Sell Signal (Breakout below Lower Band after squeeze)");
        }
    } else {
         Print("Volatility: Normal or High volatility. Bandwidth: ", bandWidth, ", Avg Bandwidth: ", avgBandWidth);
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
    if (correlationSymbolChange > 0.001) { // Threshold for "significant" move (e.g. 0.1%)
        // If current symbol hasn't moved as much, or is lagging, it might follow
        if (currentSymbolChange < correlationSymbolChange * 0.5) { // Current symbol lagging
             BuyVotes++;
             Print("Correlation: Buy Signal (Positive correlation with ", CorrelationSymbol, " which is bullish)");
        }
    }
    // If CorrelationSymbol shows strong bearish movement, consider Sell for current.
    else if (correlationSymbolChange < -0.001) { // Threshold for "significant" move
        if (currentSymbolChange > correlationSymbolChange * 0.5) { // Current symbol lagging (more positive or less negative)
             SellVotes++;
             Print("Correlation: Sell Signal (Positive correlation with ", CorrelationSymbol, " which is bearish)");
        }
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
        Print("PricePattern: Buy Signal (Bullish Engulfing)");
    }

    // Bearish Engulfing
    // 1. Previous bar is bullish (close1 > open1)
    // 2. Current bar is bearish (close0 < open0)
    // 3. Current bar's open is above or equal to previous bar's close
    // 4. Current bar's close is below or equal to previous bar's open
    // (More strict: current body engulfs previous body: open0 > close1 && close0 < open1)
    else if (close1 > open1 && close0 < open0 && open0 >= close1 && close0 <= open1) {
        SellVotes++;
        Print("PricePattern: Sell Signal (Bearish Engulfing)");
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
                        Print("SMC: Buy Signal (Retest of Bullish Order Block after BoS)");
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
                        Print("SMC: Sell Signal (Retest of Bearish Order Block after BoS)");
                        return; // Found a signal
                    }
                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Process Trade Decisions and Place Orders                         |
//+------------------------------------------------------------------+
void ProcessTradeDecisions() {
    if (CountOpenTrades() >= MaxOrders) {
        Print("Max orders reached (", CountOpenTrades(), "). No new trade.");
        return;
    }

    double point = Point;
    if (Digits == 3 || Digits == 5) point *= 10; // For 3/5 digit brokers

    double tp = TakeProfitPips * point;
    double sl = StopLossPips * point;

    if (BuyVotes > SellVotes) {
        // Place Buy Order
        double price = Ask;
        double takeProfitLevel = price + tp;
        double stopLossLevel = price - sl;
        int ticket = OrderSend(Symbol(), OP_BUY, LotSize, price, 3, stopLossLevel, takeProfitLevel, "AdvancedEA_Buy", 0, 0, clrGreen);
        if (ticket > 0) {
            Print("BUY order placed successfully. Ticket: ", ticket, " Price: ", price, " TP: ", takeProfitLevel, " SL: ", stopLossLevel);
        } else {
            Print("Error placing BUY order: ", GetLastError());
        }
    } else if (SellVotes > BuyVotes) {
        // Place Sell Order
        double price = Bid;
        double takeProfitLevel = price - tp;
        double stopLossLevel = price + sl;
        int ticket = OrderSend(Symbol(), OP_SELL, LotSize, price, 3, stopLossLevel, takeProfitLevel, "AdvancedEA_Sell", 0, 0, clrRed);
        if (ticket > 0) {
            Print("SELL order placed successfully. Ticket: ", ticket, " Price: ", price, " TP: ", takeProfitLevel, " SL: ", stopLossLevel);
        } else {
            Print("Error placing SELL order: ", GetLastError());
        }
    } else {
        Print("No trade signal: BuyVotes (", BuyVotes, ") == SellVotes (", SellVotes, ")");
    }
}

//+------------------------------------------------------------------+
//| Count Open Trades for the current symbol and EA                  |
//+------------------------------------------------------------------+
int CountOpenTrades() {
    int count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() == Symbol() && (StringFind(OrderComment(), "AdvancedEA_Buy") != -1 || StringFind(OrderComment(), "AdvancedEA_Sell") != -1) ) { // Check magic number or comment
                count++;
            }
        }
    }
    return count;
}
//+------------------------------------------------------------------+

// --- End of File ---
