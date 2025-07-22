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

//--- Input Parameters
input group "General Settings"
input int      MaxOrders         = 50;       // Maximum number of trade SETS
input double   LotSize           = 0.03;     // Total Lot Size for a set of 3 orders
input int      TakeProfitPips1   = 50;       // Take Profit for 1st partial order
input int      TakeProfitPips2   = 100;      // Take Profit for 2nd partial order
input int      TakeProfitPips3   = 150;      // Take Profit for 3rd partial order
input int      InitialStopLossPips = 500;    // Initial Stop Loss for all partial orders
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


//--- Global Variables
datetime LastAnalysisTime = 0;
int      g_EffectiveWaitPeriodMinutes; // To avoid input modification issues
int      BuyVotes = 0;
int      SellVotes = 0;
ulong    MagicNumberBase; // Will be constructed in OnInit

//--- Indicator Handles
int      hSMA;
int      hADX;
int      hTrendMAFast;
int      hTrendMASlow;
int      hZigZag;
int      hBands;
// For correlation symbol data
int      hCorrSymbolSMA; // Example if needed, direct price usually better

//--- CTrade instance
CTrade   trade;

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

    trade.SetExpertMagicNumber(MagicNumberBase);
    trade.SetDeviationInPoints(3); // Slippage
    //---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //--- Release indicator handles
    IndicatorRelease(hSMA);
    IndicatorRelease(hADX);
    IndicatorRelease(hTrendMAFast);
    IndicatorRelease(hTrendMASlow);
    IndicatorRelease(hZigZag);
    IndicatorRelease(hBands);
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

    printf("Analysis Complete. Buy Votes: %d, Sell Votes: %d", BuyVotes, SellVotes);
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
        BuyVotes++;
        printf("SMA20: Buy Signal (Crossed Above)");
    } else if (closePrice1 < smaValue && closePrice2 >= smaValue) {
        SellVotes++;
        printf("SMA20: Sell Signal (Crossed Below)");
    } else if (closePrice1 > smaValue) {
        BuyVotes++;
        printf("SMA20: Buy Signal (Above SMA)");
    } else if (closePrice1 < smaValue) {
        SellVotes++;
        printf("SMA20: Sell Signal (Below SMA)");
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


    if (adxValue > 25) {
        if (plusDI > minusDI && fastMA > slowMA) { // Uptrend
            if (close1 > fastMA && low1 <= fastMA) {
                 BuyVotes++;
                 printf("TrendRiding: Buy Signal (Uptrend with pullback)");
            } else if (close1 > slowMA && close2 <= slowMA) {
                 BuyVotes++;
                 printf("TrendRiding: Buy Signal (Uptrend, cross slow MA)");
            }
        } else if (minusDI > plusDI && fastMA < slowMA) { // Downtrend
            if (close1 < fastMA && high1 >= fastMA) {
                 SellVotes++;
                 printf("TrendRiding: Sell Signal (Downtrend with pullback)");
            } else if (close1 < slowMA && close2 >= slowMA) {
                 SellVotes++;
                 printf("TrendRiding: Sell Signal (Downtrend, cross slow MA)");
            }
        }
    } else {
        printf("TrendRiding: No strong trend (ADX < 25)");
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
        printf("ZigZag: Could not find recent ZigZag points.");
        return;
    }

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return; // rates[0]=current (incomplete), rates[1]=previous closed
    double currentHigh = rates[0].high; // Current bar's high so far
    double currentLow = rates[0].low;   // Current bar's low so far
    double prevClose = rates[1].close;  // Previous bar's close

    if (prevClose > lastHighZigZag && currentHigh > lastHighZigZag) {
        BuyVotes++;
        printf("ZigZag: Buy Signal (Breakout above %s)", DoubleToString(lastHighZigZag, _Digits));
    } else if (prevClose < lastLowZigZag && currentLow < lastLowZigZag) {
        SellVotes++;
        printf("ZigZag: Sell Signal (Breakout below %s)", DoubleToString(lastLowZigZag, _Digits));
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
        printf("Volatility: Low volatility detected (BB Squeeze). Bandwidth: %s, Avg Bandwidth: %s", DoubleToString(bandWidth1,_Digits), DoubleToString(avgBandWidth,_Digits));
        if (currentClose > upperBand0 && prevClose <= upperBand1 ) {
            BuyVotes++;
            printf("Volatility: Buy Signal (Breakout above Upper Band after squeeze)");
        } else if (currentClose < lowerBand0 && prevClose >= lowerBand1 ) {
            SellVotes++;
            printf("Volatility: Sell Signal (Breakout below Lower Band after squeeze)");
        }
    } else {
         printf("Volatility: Normal or High volatility. Bandwidth: %s, Avg Bandwidth: %s", DoubleToString(bandWidth1,_Digits), DoubleToString(avgBandWidth,_Digits));
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

    if (correlationSymbolChange > 0.001) {
        if (currentSymbolChange < correlationSymbolChange * 0.5) {
             BuyVotes++;
             printf("Correlation: Buy Signal (Positive correlation with %s which is bullish)", CorrelationSymbol);
        }
    } else if (correlationSymbolChange < -0.001) {
        if (currentSymbolChange > correlationSymbolChange * 0.5) {
             SellVotes++;
             printf("Correlation: Sell Signal (Positive correlation with %s which is bearish)", CorrelationSymbol);
        }
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
        BuyVotes++;
        printf("PricePattern: Buy Signal (Bullish Engulfing of bar at shift 1 over shift 2)");
    }
    // Bearish Engulfing: Bar at shift 1 engulfs bar at shift 2
    // 1. Bar at shift 2 is bullish (close2 > open2)
    // 2. Bar at shift 1 is bearish (close1 < open1)
    // 3. Bar 1's body engulfs Bar 2's body (open1 > close2 && close1 < open2)
    else if (close2 > open2 && close1 < open1 && open1 >= close2 && close1 <= open2) {
        SellVotes++;
        printf("PricePattern: Sell Signal (Bearish Engulfing of bar at shift 1 over shift 2)");
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
                    BuyVotes++;
                    printf("SMC: Buy Signal (Retest of Bullish Order Block at %s after BoS)", TimeToString(rates[j].time));
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
                    SellVotes++;
                    printf("SMC: Sell Signal (Retest of Bearish Order Block at %s after BoS)", TimeToString(rates[j].time));
                    return;
                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Process Trade Decisions and Place Orders                         |
//+------------------------------------------------------------------+
void ProcessTradeDecisions() {
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
        double ask_price;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask_price)) {
            printf("Error getting SYMBOL_ASK for Buy: %d. Aborting trade.", GetLastError());
            return;
        }
        printf("Attempting to place BUY orders (3 partials)... Ask: %.5f, PartialLot: %.2f", ask_price, partialLotSize);

        for (int i = 0; i < 3; i++) {
            trade.SetExpertMagicNumber(MagicNumberBase + (ulong)i); // Set unique magic for each partial

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
                       i+1, MagicNumberBase + (ulong)i, ask_price, partialLotSize, takeProfitLevel, tp_pips[i], stopLossLevel, InitialStopLossPips, trade.ResultComment());
            } else {
                printf("Error placing BUY order #%d (Magic: %llu): %s (Code: %d)", i+1, MagicNumberBase + (ulong)i, trade.ResultComment(), trade.ResultRetcode());
            }
        }
    } else if (SellVotes > BuyVotes) {
        double bid_price;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid_price)) {
            printf("Error getting SYMBOL_BID for Sell: %d. Aborting trade.", GetLastError());
            return;
        }
        printf("Attempting to place SELL orders (3 partials)... Bid: %.5f, PartialLot: %.2f", bid_price, partialLotSize);

        for (int i = 0; i < 3; i++) {
            trade.SetExpertMagicNumber(MagicNumberBase + (ulong)i); // Set unique magic for each partial

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
                PositionGetInteger(POSITION_MAGIC) == (MagicNumberBase + 0) ) { // Check for the first partial of a set
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

        bool isTP1 = false;
        ulong currentSetBaseMagicForDeal = 0;

        // Check if this deal's magic is a "base + 0" for a set from THIS EA instance
        // This logic assumes MagicNumberBase from OnInit is the absolute start,
        // and set identifiers are effectively (MagicNumberBase + some_offset_multiple_of_10)
        // The actual magic for TP1 is `set_actual_base_magic + 0`
        // Let's assume the magic numbers set during trade placement are:
        // TP1: unique_set_base_magic + 0
        // TP2: unique_set_base_magic + 1
        // TP3: unique_set_base_magic + 2
        // The `trade.SetExpertMagicNumber(MagicNumberBase + (ulong)i)` in ProcessTradeDecisions
        // means for a single EA instance, the sets are NOT distinguished by unique base magics yet.
        // The current magic scheme is: EA_Instance_MagicBase+0, EA_Instance_MagicBase+1, EA_Instance_MagicBase+2.
        // This means if MaxOrders > 1, this BE logic will apply to ALL TP2/TP3s of this EA instance if ANY TP1 hits.
        // This is a simplification for now as per the current magic number strategy in ProcessTradeDecisions.

        if (deal_symbol == _Symbol &&
            deal_magic == (MagicNumberBase + 0) && // This is the TP1 for THIS EA instance's general set structure
            deal_entry_type == DEAL_ENTRY_OUT &&
            deal_reason == DEAL_REASON_TP) {

            isTP1 = true;
            currentSetBaseMagicForDeal = MagicNumberBase; // The "set" is identified by the EA's instance MagicNumberBase

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
                        if(pos_type == POSITION_TYPE_BUY && current_sl >= open_price) already_at_be = true;
                        if(pos_type == POSITION_TYPE_SELL && current_sl <= open_price) already_at_be = true;
                        if(current_sl == 0 && open_price ==0) already_at_be = false; // SL not set case

                        if (MathAbs(current_sl - open_price) > _Point * 0.1 && !already_at_be ) { // Check if SL is not already BE (with small tolerance)
                            printf("ManageOpenTrades: Moving SL to BE for Ticket: %llu (Magic: %llu), Open: %.5f", pos_ticket, pos_magic, open_price);

                            // Set SL to open_price. TP remains the same.
                            // CTrade::PositionModify expects SL and TP levels, not pips.
                            if (trade.PositionModify(pos_ticket, open_price, current_tp)) {
                                printf("ManageOpenTrades: Successfully moved SL to BE for Ticket %llu. New SL: %.5f", pos_ticket, open_price);
                            } else {
                                printf("ManageOpenTrades: Failed to move SL to BE for Ticket %llu. Error: %s (Code: %d)",
                                       pos_ticket, trade.ResultComment(), trade.ResultRetcode());
                            }
                        } else {
                             printf("ManageOpenTrades: SL for Ticket %llu (Magic: %llu) is already at/past breakeven or not set. Current SL: %.5f, Open: %.5f", pos_ticket, pos_magic, current_sl, open_price);
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
}

//+------------------------------------------------------------------+
// --- End of File ---
