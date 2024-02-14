//+------------------------------------------------------------------+
//|                                               multisymbol_a1.mq5 |
//|                                                          AC_2024 |
//|                                Based on Dillon Grech / Darwinex  |
//+------------------------------------------------------------------+

//+--------------------------------------------------------------------------------+
//| DISCLAIMER AND TERMS OF USE OF THIS EXPERT ADVISOR                             |
//| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"    |
//| AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE      |
//| IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE |
//| DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE   |
//| FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL     |
//| DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR     |
//| SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER     |
//| CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,  |
//| OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  |
//| OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.           |
//+--------------------------------------------------------------------------------+

#property link          "https://github.com/agustinc10"
#property description   "multisymbol_a1"
#property version       "1.00"

// Expert Setup

//Libraries and Setup
#include  <Trade/Trade.mqh>             // Include MQL trade object functions
CTrade    Trade;                        // Declare Trade as pointer to CTrade class      

input group "==== General Inputs ===="
input int     MagicNumber   = 2000001;  // Unique identifier for this expert advisor for EA not get confused between each other
input string  TradeComment  = __FILE__; // Optional comment for trades
input bool CommentsOnScreen = false;    // Print comments on screen

//Multi-Symbol EA Variables
enum   MULTISYMBOL {Current, All_but_NZD, Selected_Symbols}; 
input  MULTISYMBOL InputMultiSymbol   = Current;
input string       TradeSymbols       = "AUDUSD|EURUSD|GBPUSD|USDCAD|USDCHF|USDJPY";   // Selected Symbols 
string             AllTradableSymbols = "AUDUSD|EURUSD|GBPUSD|USDCAD|USDCHF|USDJPY|AUDCAD|AUDCHF|AUDJPY|CADCHF|CADJPY|CHFJPY|EURAUD|EURCAD|EURCHF|EURGBP|EURJPY|GBPAUD|GBPCAD|GBPCHF|GBPJPY";//|NZDUSD|AUDNZD||EURNZD|GBPNZD|NZDCAD|NZDCHF|NZDJPY";
int                NumberOfTradeableSymbols;
string             SymbolArray[];

input group "==== Range Inputs ===="
input int InpRangeStart     = 120;     // range start time in minutes (after midnight). (ex: 600min is 10am)
input int InpRangeDuration  = 1260;    // range duration in minutes (ex: 120min = 2hs)
input int InpRangeClose     = 1410;    // range close time in minutes (ex: 1200min = 20hs) (-1 = off)

// Candle Processing
input group "==== Candle Processing ===="
enum ENUM_BAR_PROCESSING_METHOD {
   PROCESS_ALL_DELIVERED_TICKS,               //Process All Delivered Ticks
   ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR,        //Process Ticks From New M1 Bar
   ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR   //Process Ticks From New TF Bar
};
input ENUM_TIMEFRAMES            TradeTimeframe      = PERIOD_H1;                                 //Trading Timeframe
input ENUM_BAR_PROCESSING_METHOD BarProcessingMethod = ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR;  //EA Bar Processing Method

int      TicksReceived  =  0;            //Number of ticks received by the EA
int      TicksProcessed[];               //Number of ticks processed by the EA (will depend on the BarProcessingMethod being used)
datetime TimeLastTickProcessed[];        //Used to control the processing of trades so that processing only happens at the desired intervals (to allow like-for-like back testing between the Strategy Tester and Live Trading)

int      iBarForProcessing;              //This will either be bar 0 or bar 1, and depends on the BarProcessingMethod - Set in OnInit()

// WARNING: TAKE INTO ACCOUNT
// The following issues do not apply in Live Trading since you are always receiving every Tick
// If I choose Processing Method = All Ticks, in the Backtester I have to select Modelling with Ticks
// If I choose Processing Method = New_M1_BAr, in the Backtester I have to select Modelling with Ticks or M1 OHLC (because I need to receive at least 1 tick every minute)
// If I choose Processing Method = New_Trade_TF_Bar in the Backtester I have to select a TF lower than that.     If Modelling TF is equal to "Trading Timeframe", errors occur and you miss trades.
//    Since I loop when a tick from the CURRENT Symbol arrives (ex. EURUSD), it may happen that the tick for the change of candle (ex. 10am) of another symbol (Ex. GBPUSD) hasn't arrived yet.
//    In that case I will only receive the tick of 10am of GBPUSD when the 11am tick of EURUSD arrives.
//    So if I use a lower timeframe in the tester, I get time for all symbols to "catch up"   

// Include common functions
#include <_Agustin/ACFunctions.mqh>
input double AtrLossMulti      = 1.0;   // ATR Loss Multiple
input double AtrProfitMulti    = 1.0;   // ATR Profit Multiple

input int InpPosTimer          = 600;   // Minutes for Position close (-1 = off) 
input int InpOrderTimer        = 65 ;   // Minutes for Order delete (-1 = off) 
input bool CloseFlag = true; // Use close condition

// INCLUDES

// WARNING: Timeframe hardcoded to 1h in mqh file to be able to backtest with open bars of 1h
/*#include <_Darwinex/DWEX_Portfolio_Risk_Man_Multi_Position.mqh>

input group "==== Value at Risk ===="
input ENUM_TIMEFRAMES InpVaRTimeframe    = PERIOD_D1;    //Value at Risk Timeframe
input int             InpStdDevPeriods   = 21;           //Std Deviation Periods
input int             InpCorrelPeriods   = 42;           //Pearson Correlation Coeff Periods
input double          InpVaRPercent      = 5;            //Max VaR to open a new position

// Instantiate CPortfolioRiskMan object
CPortfolioRiskMan PortfolioRisk(InpVaRTimeframe, InpStdDevPeriods, InpCorrelPeriods);
*/

// STOCHASTIC Variables
input group "==== Stochastic Inputs ===="
int       StochHandle[];
enum   STOCHASTICENTRY {LONG_when_IN_OB, LONG_when_OUT_OS, LONG_when_CROSS_50, LOCAL_PEAK, ALL_ENTRIES}; 
input  STOCHASTICENTRY Stoch_Entry   = LONG_when_IN_OB;  // Entry when entering or exiting OB/OS
input int InpKPeriod = 14;           // %K for the Stochastic
input int InpDPeriod = 3;            // %D for the Stochastic
input int InpSlowing = 1;            // Slowing for the Stochastic
input int InpStochOS = 20;           // OB/OS margin for Stochastic
int InpStochOB = 100 - InpStochOS;
int InpMAStoch = 16;           // Period for Stoch MA (<50)
input int InpCandlesEntry = 1;       // Velas OS para entrar Long
input int InpCandlesOpposite = 1;    // Velas OB para evitar entrar Long


// MEAN AVERAGE Variables
input group "==== MA Inputs ===="
int fast_MA_Handle[];
int slow_MA_Handle[];
int uslow_MA_Handle[];
int kama_Handle[];
int ama_Handle[];
enum   MATREND {Aligned, Reversed, No_Trend, All_minus_Aligned, All_Trades}; 
input  MATREND MA_Trend_Filter   = Aligned;  // Long when Long, Short, or when No Trend
input ENUM_MA_METHOD InpMethodFastMA = MODE_SMA;
input int InpFastMA  = 10;    // fast period
ENUM_MA_METHOD InpMethodSlowMA = InpMethodFastMA;
input int InpSlowMA  = 20;    // slow period
ENUM_MA_METHOD InpMethodUSlowMA = InpMethodFastMA;
input int InpUSlowMA = 50;    // ultra slow period

const string KAMAName = "Agustin\\Darwinex\\Darwinex_KAMA"; // Credit to Darwinex / TradeLikeAMachine
input int InpKAMA    = 10;    // KAMA period
input double InpAtrMaMultiplier = 1;  // ATR Multiplier 

// ATR Variables
input group "==== ATR Inputs ===="
int       AtrHandle[];
input int InpAtrPeriod = 14;     // ATR Period
input double InpAtrEnvelopeIN = 2.0;   // ATR distance to MA - IN
double InpAtrEnvelopeOUT = InpAtrEnvelopeIN;   // ATR distance to MA - OUT

// RSI Variables
input group "==== RSI Inputs ===="
int       RSIHandle[];
input int InpRSIPeriod = 14;     // RSI Period
input int InpRSIOS = 30;         // RSI OverSold Level
int InpRSIOB = 100 - InpRSIOS;   // RSI OverBought Level

// Slow STOCHASTIC Variables
input group "==== Slow Stochastic Inputs ===="
int       StochHandle2[];
input int InpKPeriod2 = 50;           // %K for the SLOW Stochastic
input int InpDPeriod2 = 5;            // %D for the SLOW Stochastic
input int InpSlowing2 = 1;            // Slowing for the SLOW Stochastic
input int InpStochOS2 = 20;           // OB/OS margin for SLOW Stochastic
int InpStochOB2 = 100 - InpStochOS2;
input int InpStochTrendUP = 60;         // Limit to determine Trend UP
int InpStochTrendDOWN = 100 - InpStochTrendUP;

/*// RSI STOCHASTIC Variables
input group "==== RSI Stoch Inputs ===="
const string RSIStochasticName = "Agustin\\Downloads\\stochastic_rsi"; // Credit to Darwinex / TradeLikeAMachine
int       RSIStochHandle[];
input int InpRSIPeriod = 14;           // %K for the Stochastic
input int InpStoRSIPeriod = 10;            // %D for the Stochastic
input int InpRSIStochSmoothing = 5;            // Slowing for the Stochastic
input int InpRSIStochOB = 80;
input int InpRSIStochOS = 20;
*/
// AROON Variables
input group "==== Aroon Inputs ===="
const string AroonName = "Agustin\\AC_Aroon"; // Credit to Darwinex / TradeLikeAMachine
input int InpAroonPeriod = 100;                          // period of the Aroon Indicator
int InpAroonShift  = 0;                            // horizontal shift of the indicator in bars
input double AroonMin= 70;       // Valor de Aroon para indicar tendencia.
input double AroonMax= 100;       // Valor max de Aroon para habilitar entrada.
int AroonHandle[];

// NOISE Variables
input group "==== Noise Filter Inputs ===="
const string ERName = "Agustin\\Darwinex\\Darwinex_EffRatio"; // Credit to Darwinex / TradeLikeAMachine
int ERHandle[];
input int InpERPeriod        = 10;     // Efficiency Ratio Period
input double InpERlimit      = 0.3;    // ER limit value

// PIVOT Variables
input group "==== Pivot Inputs ===="
input int InpHHLLperiod     = 10;      // Candles to consider Pivot Point in 4x Timeframe
//input int InpDistanceToPeak = 5;     // Candles to last peak from current candle
input bool InpDraw          = false;   // Allow HHLL object drawing           

// OPEN TRADE ARRAYS
ulong    OpenTradeOrderTicket[];    //To store 'order' ticket for trades (1 cell per symbol. They are 0 unless there is an open Trade)
////////Place additional trade arrays here as required to assist with open trade management
ulong    OpenTradePositionTicket[];    //To store 'position' ticket for trades (1 cell per symbol. They are 0 unless there is an open Trade)
long     OpenTradePositionID[];
int      FlagStochastic[];          //To store if trend is up or down.
//int      FlagAroon[]; 

// Indicators' condition arrays 
double   StochasticCurrentK[];
double   StochasticCurrentD[];
double   StochasticPrevK[];
double   StochasticPrevD[];
string   StochasticK_Dir[];
string   StochasticD_Dir[];
int      ConsecutiveOB[];
int      ConsecutiveOS[];

string   FastMA_Dir[];
string   TripleMA[];
double   RSIvalue[];
double   EfficiencyRatio[];
string   HHLLsequence[];
string   Candlesequence[];
string   CandlesequencePrev[];
string   AtrDirection[];
string   AtrvsMA[];

//Expert Core Arrays
string SymbolMetrics[];

//Expert Variables
string     ExpertComments = "";
string     IndicatorSignal1;
string     IndicatorSignal2;
string     IndicatorSignal3;
string     Trend;

// Custom Metrics or LogFile (include one or the other)
// If using Custom Metrics, uncomment init and ontick functions
//#include <_Agustin/CustomMetrics.mqh>
//#include <_Agustin/LogFile.mqh>

enum ENUM_DIAGNOSTIC_LOGGING_LEVEL
{
   DIAG_LOGGING_NONE,                           // NONE
   DIAG_LOGGING_LOW,                            // LOW - Major Diagnostics Only
   DIAG_LOGGING_MEDIUM,                         // MEDIUM - Medium level logging
   DIAG_LOGGING_HIGH                            // HIGH - All Diagnostics (Warning - Use with caution)
};

input group "==== Log Mode ===="
input ENUM_DIAGNOSTIC_LOGGING_LEVEL       DiagnosticLoggingLevel = DIAG_LOGGING_NONE;         //Diagnostic Logging Level
int outputFileHandleInline = INVALID_HANDLE;

int OnInit(){
   if (!CheckInputs()) return INIT_PARAMETERS_INCORRECT; // check correct input from user
   //Declare magic number for all trades
   Trade.SetExpertMagicNumber(MagicNumber);

   /* if using a pointer CTrade *Trade
   Trade = new CTrade();
   if(!Trade)                                             // Same as doing if(CheckPointer(Trade)==POINTER_INVALID)
      Print("Pointer to CTrade is ", EnumToString(CheckPointer(Trade)));
   else
      Trade.SetExpertMagicNumber(MagicNumber);
   */

   //Set up multi-symbol EA Tradable Symbols
   if(InputMultiSymbol == Current) {
      NumberOfTradeableSymbols = 1;
      ArrayResize(SymbolArray, NumberOfTradeableSymbols);
      SymbolArray[0] = Symbol();
      Print("EA will process ", SymbolArray[0], " only");
   } 
   else {  
      string TradeSymbolsToUse = "";
      if(InputMultiSymbol == All_but_NZD) 
         TradeSymbolsToUse = AllTradableSymbols;
      else 
         TradeSymbolsToUse = TradeSymbols;
      
      //Convert TradeSymbolsToUse to the String array SymbolArray
      NumberOfTradeableSymbols = StringSplit(TradeSymbolsToUse, '|', SymbolArray);
      Print("EA will process ", NumberOfTradeableSymbols, " Symbols: ", TradeSymbolsToUse);
   }
      
   //Determine which bar we will used (0 or 1) to perform processing of data
   iBarForProcessing = setProcessingBar(BarProcessingMethod, iBarForProcessing);

   // Add Symbols to Marketwatch
   AddToMarketWatch();
   //Resize core arrays for Multi-Symbol EA
   ResizeCoreArrays();
   //Resize indicator arrays for Multi-Symbol EA
   ResizeIndicatorArrays();
   
   Print("All arrays sized to accomodate ", NumberOfTradeableSymbols, " symbols");

   //Initialize Arrays
   ArrayInitialize(TimeLastTickProcessed, D'1971.01.01 00:00');
   ArrayInitialize(OpenTradeOrderTicket, 0);
   ArrayInitialize(OpenTradePositionTicket, 0);
   ArrayInitialize(OpenTradePositionID, 0);
   ArrayInitialize(FlagStochastic, 0);
   //ArrayInitialize(FlagAroon, 0);
   ArrayInitialize(StochasticCurrentK, 0);
   ArrayInitialize(StochasticCurrentD, 0);
   ArrayInitialize(StochasticPrevK, 0);
   ArrayInitialize(StochasticPrevD, 0);
   ArrayInitialize(ConsecutiveOB, 0);
   ArrayInitialize(ConsecutiveOS, 0);

   ArrayInitialize(RSIvalue, 0);
   ArrayInitialize(EfficiencyRatio, 0);


   //Set Up Multi-Symbol Handles for Indicators
   if (!SetUpIndicatorHandles()) return(INIT_FAILED);

   //if (OnInitCustomMetrics() != 0) return INIT_PARAMETERS_INCORRECT;

   //OpenEquityFile(DiagnosticLoggingLevel, equityFileHandle);
   DiagnosticFileInline(DiagnosticLoggingLevel, outputFileHandleInline, TradeComment);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   //Release Indicator Arrays
   ReleaseIndicatorHandles();
   Comment("");
   //CloseEquityFile(DiagnosticLoggingLevel, equityFileHandle);
   CloseDiagnosticFileInline(DiagnosticLoggingLevel, outputFileHandleInline);

   ObjectsDeleteAll(0);    // We can delete defining a prefix of the name of the objects   
}

void OnTick(){ 
   // Quick check if trading is possible
   if (!IsTradeAllowed()) return;      

   //EquityMainData(DiagnosticLoggingLevel, equityFileHandle);
   
   //Declare comment variables
   ExpertComments="";
   TicksReceived++;
   
   //Run multi-symbol loop   
   for(int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {      
      //Store Current Symbol
      string CurrentSymbol = SymbolArray[SymbolLoop];
      // Exit if the market may be closed // https://youtu.be/GejPtodJow
      if( !IsMarketOpen(CurrentSymbol, TimeCurrent())){
         Print ("Market Closed");   
         return;
      }
       
      //Control EA so that we only process trades at required intervals (Either 'Every Tick', 'TF Open Prices' or 'M1 Open Prices')
      bool ProcessThisIteration = false;     //Set to false by default and then set to true below if required
      ProcessThisIteration = TickProcessingMultiSymbol(ProcessThisIteration, SymbolLoop, CurrentSymbol);

      // Process Trades if appropriate
      if(ProcessThisIteration == true){
         TicksProcessed[SymbolLoop]++; 

         // Get tickets positions
         GetOpenPositionTickets();

         // Close Trades by timer
         /* if (OpenTradeOrderTicket[SymbolLoop] != 0)
            ClosePositionByTimer(SymbolLoop, InpPosTimer);
         */
         if (OpenTradePositionTicket[SymbolLoop] != 0 && Time_Filter_Signals() == "Close by Time"){
            ProcessTradeCloseTimeRange(SymbolLoop);
            Print ("Close because out of range");
         }      
         
         // Close Signals
         string CloseSignalStatus = "";
         if(CloseFlag == true)
            if (OpenTradePositionTicket[SymbolLoop] != 0){   
               ProcessTradeClose(SymbolLoop);
         }

         // Modify positions
         /*if (OpenTradeOrderTicket[SymbolLoop] != 0)   
            ProcessTradeModify(SymbolLoop);
         */

         //Print(iSpread(CurrentSymbol,TradeTimeframe,0)," / ", iSpread(CurrentSymbol, PERIOD_M1,0)," / ", iSpread(CurrentSymbol, PERIOD_D1,0));

         IndicatorSignal1  = Stochastic_SignalOpen(SymbolLoop); //HHLL_SignalOpen(SymbolLoop); //Stochastic_SignalOpen(SymbolLoop); //      
         IndicatorSignal2  = MA_SignalOpen(SymbolLoop, IndicatorSignal1); //MA_SignalOpen(SymbolLoop);//MA_SignalOpen(SymbolLoop);////Stochastic_SignalOpen(SymbolLoop);//Stochastic_SignalOpen(SymbolLoop); // MA_SignalOpen(SymbolLoop);  
         
         // Reset OpenTradeOrderTicket values to account old Orders and for SL and TP executions
         ResetOpenOrders(SymbolLoop, InpOrderTimer);
         ResetOpenTrades(SymbolLoop);
        
         //Enter Trades
         if (Time_Filter_Signals() == "Time ok"){ // && GetERValue(SymbolLoop, iBarForProcessing) >= InpERlimit){
            if (OpenTradeOrderTicket[SymbolLoop] == 0 && OpenTradePositionTicket[SymbolLoop] == 0){
               if(
                  //SyR_SignalOpen(SymbolLoop) == "Long"
                  //Hour_SignalOpen(SymbolLoop) == "Long" 
                  //&& RSI_SignalOpen(SymbolLoop) != "No Long"
                  MA_SignalOpen(SymbolLoop, IndicatorSignal1) == "Long"
                  && Stochastic_SignalOpen(SymbolLoop) == "Long"
                  //Candle_SignalOpen(SymbolLoop, iBarForProcessing) == "Long"
                  //&& WideRangeBar_Filter(SymbolLoop) != "No Long"
                  //&& AMA_SignalOpen(SymbolLoop) == "Long"
                  && ATR_SignalOpen(SymbolLoop) == "UP"
                  
                  )
                  ProcessTradeOpen(CurrentSymbol, SymbolLoop, ORDER_TYPE_BUY);

               else if(
                  //SyR_SignalOpen(SymbolLoop) == "Short"
                  //Hour_SignalOpen(SymbolLoop) == "Short"                  
                  //&& RSI_SignalOpen(SymbolLoop) != "No Short"
                  MA_SignalOpen(SymbolLoop, IndicatorSignal1) == "Short"
                  && Stochastic_SignalOpen(SymbolLoop) == "Short" 
                  //Candle_SignalOpen(SymbolLoop, iBarForProcessing) == "Short"
                  //&& WideRangeBar_Filter(SymbolLoop) != "No Short"
                  ///&& AMA_SignalOpen(SymbolLoop) == "Short"
                  && ATR_SignalOpen(SymbolLoop) == "UP"
                  )
                  ProcessTradeOpen(CurrentSymbol, SymbolLoop, ORDER_TYPE_SELL);
            }
         }

         //Update Symbol Metrics
         SymbolMetrics[SymbolLoop] = CurrentSymbol + 
                                    " ON " + EnumToString(TradeTimeframe) + " CHART" +
                                    " | Ticks Processed: " + IntegerToString(TicksProcessed[SymbolLoop])+
                                    " | Last Candle: " + TimeToString(TimeLastTickProcessed[SymbolLoop])+
                                    " | Indicator 1: " + IndicatorSignal1+
                                    " | Indicator 2: " + IndicatorSignal2+
                                    " | CloseSignal: " + CloseSignalStatus;
      }      
      //Update expert comments for each symbol
      ExpertComments = ExpertComments + SymbolMetrics[SymbolLoop] + "\n\r";
   }  
   //Comment expert behaviour
   if(CommentsOnScreen == true){
   Comment("\n\rExpert: ", MagicNumber, "\n\r",
            "MT5 Server Time: ", TimeCurrent(), "\n\r",
            "Ticks Received: ", TicksReceived,"\n\r\n\r",  
            "Symbols Traded:\n\r", 
            ExpertComments
            );
   }

   //OnTickCustomMetrics();         
}

// EXPERT CUSTOM FUNCTIONS //

// Get Stochastic K Value and D Values
double Stochastic_K(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = candle + 1; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    IndexK          = 0; // %K Line
   double Buffer[];         

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      Fill = tlamCopyBuffer(StochHandle[SymbolLoop],IndexK, StartCandle, RequiredCandles, Buffer, CurrentSymbol, "%K");
   
   if(Fill==false) return 0; //If buffers are not completely filled, return to end onTick
   
   double Kvalue = NormalizeDouble(Buffer[candle], 2);
   return Kvalue;      
}
double Stochastic_D(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = candle + 1; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    IndexD          = 1; // %D Line
   double Buffer[];          

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      Fill = tlamCopyBuffer(StochHandle[SymbolLoop],IndexD, StartCandle, RequiredCandles, Buffer, CurrentSymbol, "%D");
   
   if(Fill==false) return 0; //If buffers are not completely filled, return to end onTick
   
   double Dvalue = NormalizeDouble(Buffer[candle], 2);
   return Dvalue;      
}

// Get MA Values
double GetFastMAValue(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = candle + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferFastMA[];  

   //Populate buffers for fast MA lines
   bool FillFastMA   = tlamCopyBuffer(fast_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferFastMA, CurrentSymbol, "Fast MA");
   if(FillFastMA == false) return 0;
   //Find required MA signal lines
   double FastMAValue  = NormalizeDouble(BufferFastMA[candle], SymbolDigits);

   return(FastMAValue);
}
double GetSlowMAValue(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = candle + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferSlowMA[];  

   //Populate buffers for Slow MA lines
   bool FillSlowMA   = tlamCopyBuffer(slow_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferSlowMA, CurrentSymbol, "Slow MA");
   if(FillSlowMA == false) return 0;
   //Find required MA signal lines
   double SlowMAValue  = NormalizeDouble(BufferSlowMA[candle], SymbolDigits);

   return(SlowMAValue);
}
double GetUSlowMAValue(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = candle + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferUSlowMA[];  

   //Populate buffers for USlow MA lines
   bool FillUSlowMA   = tlamCopyBuffer(uslow_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferUSlowMA, CurrentSymbol, "USlow MA");
   if(FillUSlowMA == false) return 0;
   //Find required MA signal lines
   double USlowMAValue  = NormalizeDouble(BufferUSlowMA[candle], SymbolDigits);

   return(USlowMAValue);
}

// Get Indicator Values
double RSI_Value(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = candle + 1; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    Index           = 0; 
   double Buffer[];         

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      Fill = tlamCopyBuffer(RSIHandle[SymbolLoop],Index, StartCandle, RequiredCandles, Buffer, CurrentSymbol, "RSI");

   if(Fill==false) return 0; //If buffers are not completely filled, return to end onTick
   
   //Find required Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    CurrRSI   = NormalizeDouble(Buffer[candle], 2);
   
   return CurrRSI;
}
double GetERValue(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = candle + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0;          //ATR Line
   double    BufferER[];                   //Capture 2 candles for ATR [0,1]

   //Populate buffers for ATR
   bool FillER   = tlamCopyBuffer(ERHandle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferER, CurrentSymbol, "ER");
   if(FillER == false) return false;

   //Find required ATR value
   double EffRatio = NormalizeDouble(BufferER[candle], SymbolDigits);

   return EffRatio;
}
double GetAtrValue(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = candle + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; //ATR Line
   double    BufferAtr[];         //Capture 2 candles for ATR [0,1]

   //Populate buffers for ATR
   bool FillAtr   = tlamCopyBuffer(AtrHandle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferAtr, CurrentSymbol, "ATR");
   if(FillAtr == false) return false;

   //Find required ATR value
   double Atr = NormalizeDouble(BufferAtr[candle], SymbolDigits);

   return Atr;
}

// Get HHLL Sequence
string HHLL_Sequence(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error      

   int High1 = FindPeak(CurrentSymbol, MODE_HIGH, InpHHLLperiod, 1, TradeTimeframe);
   int High2 = FindPeak(CurrentSymbol, MODE_HIGH, InpHHLLperiod, High1 + 1, TradeTimeframe);
   int High3 = FindPeak(CurrentSymbol, MODE_HIGH, InpHHLLperiod, High2 + 1, TradeTimeframe);
   int Low1 = FindPeak(CurrentSymbol, MODE_LOW, InpHHLLperiod, 1, TradeTimeframe);
   int Low2 = FindPeak(CurrentSymbol, MODE_LOW, InpHHLLperiod, Low1 + 1, TradeTimeframe);
   int Low3 = FindPeak(CurrentSymbol, MODE_LOW, InpHHLLperiod, Low2 + 1, TradeTimeframe);

   double High1value = iHigh(CurrentSymbol, TradeTimeframe, High1);
   double High2value = iHigh(CurrentSymbol, TradeTimeframe, High2);
   double High3value = iHigh(CurrentSymbol, TradeTimeframe, High3);
   double Low1value = iLow(CurrentSymbol, TradeTimeframe, Low1);
   double Low2value = iLow(CurrentSymbol, TradeTimeframe, Low2);
   double Low3value = iLow(CurrentSymbol, TradeTimeframe, Low3);
   
   string currH = (High1value >= High2value) ? "HH" : "LH";
   string prevH = (High2value >= High3value) ? "HH" : "LH";
   string currL = (Low1value < Low2value) ? "LL" : "HL";
   string prevL = (Low2value < Low3value) ? "LL" : "HL"; 

   string seq1 = "";
   string seq2 = "";
 
   // Bubble Sort algorithm to sort the values in ascending order
   double series[] = {High1, High2, Low1, Low2}; 
   int n = ArraySize(series);
   for (int i = 0; i < n - 1; i++) {
      for (int j = 0; j < n - i - 1; j++) {
         if (series[j] > series[j + 1]) {
               // Swap values
               double temp = series[j];
               series[j] = series[j + 1];
               series[j + 1] = temp;
         }
      }
   }

   seq1 = (series[0] == High1) ? currH : currL;   
   if       (series[1] == High1) seq2 = currH;
   else if  (series[1] == Low1)  seq2 = currL;
   else if  (series[1] == High2) seq2 = prevH;
   else if  (series[1] == Low2)  seq2 = prevL;

   string sequence = seq2 + seq1;
   return sequence;
}

// Get Stochastic Open Signals
string Stochastic_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 30; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    IndexK          = 0; // %K Line
   int    IndexD          = 1; // %D Line
   double BufferK[];         
   double BufferD[];          

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      FillK = tlamCopyBuffer(StochHandle[SymbolLoop],IndexK, StartCandle, RequiredCandles, BufferK, CurrentSymbol, "%K");
   bool      FillD = tlamCopyBuffer(StochHandle[SymbolLoop],IndexD, StartCandle, RequiredCandles, BufferD, CurrentSymbol, "%D");

   if(FillK==false || FillD==false) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    CurrK   = NormalizeDouble(BufferK[iBarForProcessing], 2);
   double    CurrD   = NormalizeDouble(BufferD[iBarForProcessing], 2);
   double    PrevK   = NormalizeDouble(BufferK[iBarForProcessing + 1], 2);
   double    PrevD   = NormalizeDouble(BufferD[iBarForProcessing + 1], 2);
   double    PrevK3   = NormalizeDouble(BufferK[iBarForProcessing + 2], 2);
   double    PrevD3   = NormalizeDouble(BufferD[iBarForProcessing + 2], 2);
   
   double Open[]; 
   double High[];
   double Low[];
   double Close[];

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Close);
   if (values!= RequiredCandles){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}   

   int countOB = 0;
   int countOS = 0;
   int countOBConsec = 0;
   int countOSConsec = 0;

   for (int i = iBarForProcessing + 1; i < 12; i++){
      if(BufferK[i] > InpStochOB) countOB++;
   }
   for (int i = iBarForProcessing + 1; i < 12; i++){
      if(BufferK[i] < InpStochOS) countOS++;
   }

   for (int i = iBarForProcessing + 1; i < 12; i++){
      if(BufferK[i] > InpStochOB) countOBConsec++;
      else break;
   }
   for (int i = iBarForProcessing + 1; i < 12; i++){
      if(BufferK[i] < InpStochOS) countOSConsec++;
      else break;
   }

   if(Stoch_Entry == LONG_when_IN_OB){
      if(PrevK < InpStochOB && CurrK > InpStochOB 
         ) 
         return "Long";
      else if (PrevK > InpStochOS && CurrK < InpStochOS
         ) 
         return "Short";
   }

   else if(Stoch_Entry == LONG_when_OUT_OS){
      if(PrevK < InpStochOS && CurrK > InpStochOS
         ) 
         return "Long";
      else if (PrevK > InpStochOB && CurrK < InpStochOB
         ) 
         return "Short";
   }
   
   else if(Stoch_Entry == LONG_when_CROSS_50){
      if(PrevK < 50 && CurrK > 50
         ) 
         return "Long";
      else if (PrevK > 50 && CurrK < 50
         ) 
         return "Short";
   }
   else if(Stoch_Entry == LOCAL_PEAK){
      if(PrevK3 > PrevK && PrevK < CurrK && CurrK > InpStochOS && Close[iBarForProcessing] > High[iBarForProcessing + 1] && PrevK < InpStochOB
         ) 
         return "Long";
      else if (PrevK3 < PrevK && PrevK > CurrK && CurrK < InpStochOB && Close[iBarForProcessing] < Low[iBarForProcessing + 1] && PrevK > InpStochOS
         ) 
         return "Short";
   }
   else if(Stoch_Entry == ALL_ENTRIES){
      if((PrevK < InpStochOB && CurrK > InpStochOB) 
         || (PrevK < InpStochOS && CurrK > InpStochOS)
         || (PrevK < 50 && CurrK > 50)
         || (PrevK3 > PrevK && PrevK < CurrK && CurrK > InpStochOS && Close[iBarForProcessing] > High[iBarForProcessing + 1] && PrevK < InpStochOB)
         ) 
         return "Long";
      else if ((PrevK > InpStochOS && CurrK < InpStochOS)
         || (PrevK > InpStochOB && CurrK < InpStochOB)
         || (PrevK > 50 && CurrK < 50)
         || (PrevK3 < PrevK && PrevK > CurrK && CurrK < InpStochOB && Close[iBarForProcessing] < Low[iBarForProcessing + 1] && PrevK > InpStochOS)
         ) 
         return "Short";
   }

   return   "No Trade";    
}

// Get Stochastic Close Signals
string Stochastic_SignalClose(int SymbolLoop, ENUM_POSITION_TYPE positiontype){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 6;      // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    IndexK          = 0;      // %K Line
   int    IndexD          = 1;      // %D Line
   double BufferK[];         
   double BufferD[];       

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      FillK = tlamCopyBuffer(StochHandle[SymbolLoop],IndexK, StartCandle, RequiredCandles, BufferK, CurrentSymbol, "%K");
   bool      FillD = tlamCopyBuffer(StochHandle[SymbolLoop],IndexD, StartCandle, RequiredCandles, BufferD, CurrentSymbol, "%D");

   if(FillK==false || FillD==false) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    CurrK = NormalizeDouble(BufferK[iBarForProcessing], 2);
   double    CurrD = NormalizeDouble(BufferD[iBarForProcessing], 2);
   double    PrevK   = NormalizeDouble(BufferK[iBarForProcessing + 1], 2);
   double    PrevD   = NormalizeDouble(BufferD[iBarForProcessing + 1], 2);
   double    K3   = NormalizeDouble(BufferK[iBarForProcessing + 2], 2);
   double    D3   = NormalizeDouble(BufferD[iBarForProcessing + 2], 2);

   int countK_OS = 0;   // Count how many candles %K is OverSold
   int countK_OB = 0;
   int limit_count = 2; // Allowed times for %K to be OB or OS
   for(int i = iBarForProcessing; i < 4; i++){
      if (BufferK[i] < InpStochOS) countK_OS++;
      if (BufferK[i] > InpStochOB) countK_OB++;
   }

   double Open[]; 
   double High[];
   double Low[];
   double Close[];

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Close);
   if (values!= RequiredCandles){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}   

   //Print("countK_OS: ", countK_OS, ". countK_OB: ", countK_OB, " - ", EnumToString(positiontype));

   //Return Stochastic Long and Short Signal

   if(Stoch_Entry == LONG_when_IN_OB){
      if (positiontype == POSITION_TYPE_BUY){ 
         if(CurrK < InpStochOB) 
            return "Close_Long";
      }
      else if(positiontype == POSITION_TYPE_SELL){
         if(CurrK > InpStochOS) 
            return "Close_Short";
      }
   }
   
   else{
      if (positiontype == POSITION_TYPE_BUY){ 
         if(//(PrevK > InpStochOS && CurrK < InpStochOS)
            (PrevK > InpStochOB
            && (Low[iBarForProcessing] < Low[iBarForProcessing + 1]                                                                                      // Min menor que min anterior                                                                                 
            || Close[iBarForProcessing] 
            < MathMin(Close[iBarForProcessing + 1], Open[iBarForProcessing + 1]) + (MathAbs(Close[iBarForProcessing + 1] - Open[iBarForProcessing + 1]) /2)))   // Cierre menor que mitad de cuerpo de vela anterior
            || (PrevK > InpStochOB && CurrK < InpStochOB)                                                                                                // Salida de OB
            ) 
            return "Close_Long";
      }
      if (positiontype == POSITION_TYPE_SELL){ 
         if(//(PrevK < InpStochOB && CurrK > InpStochOB)
            (PrevK < InpStochOS
            && (High[iBarForProcessing] > High[iBarForProcessing + 1]
            || Close[iBarForProcessing] 
            > MathMin(Close[iBarForProcessing + 1], Open[iBarForProcessing + 1]) + (MathAbs(Close[iBarForProcessing + 1] - Open[iBarForProcessing + 1]) /2)))
            || (PrevK < InpStochOS && CurrK > InpStochOS)         
            ) 
            return "Close_Short";
      }
   }
   return "No_Close_Signal";
}

// Get RSI Open Signals
string RSI_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 50; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    Index          = 0; 
   double Buffer[];         

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      Fill = tlamCopyBuffer(RSIHandle[SymbolLoop],Index, StartCandle, RequiredCandles, Buffer, CurrentSymbol, "RSI");

   if(Fill==false) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    CurrRSI   = NormalizeDouble(Buffer[iBarForProcessing], 2);
   double    PrevRSI   = NormalizeDouble(Buffer[iBarForProcessing + 1], 2);
   
   if (PrevRSI < InpRSIOS)                          return "No Long";
   else if (PrevRSI > InpRSIOB)                     return "No Short";   
   else                                             return "No Trade";   
}

// Get MA Open Signals
string MA_SignalOpen(int SymbolLoop, string other_indicator){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = InpSlowMA + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferFastMA[];  
   double    BufferSlowMA[];  
   double    BufferUSlowMA[];

   //Populate buffers for fast MA lines
   bool FillFastMA   = tlamCopyBuffer(fast_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferFastMA, CurrentSymbol, "Fast MA");
   if(FillFastMA == false) return "FILL_ERROR";
   bool FillSlowMA   = tlamCopyBuffer(slow_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferSlowMA, CurrentSymbol, "Slow MA");
   if(FillSlowMA == false) return "FILL_ERROR";
   bool FillUSlowMA   = tlamCopyBuffer(uslow_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferUSlowMA, CurrentSymbol, "Ultra Slow MA");
   if(FillUSlowMA == false) return "FILL_ERROR";
   /*
   double sumdif = 0;
   for (int i = iBarForProcessing; i <= 5; i++){
      sumdif += NormalizeDouble(iClose(CurrentSymbol, TradeTimeframe,i) - BufferFastMA[i], SymbolDigits);
   }
   */
   //Find required MA signal lines
   double CurrentFastMA  = NormalizeDouble(BufferFastMA[iBarForProcessing], SymbolDigits);
   double CurrentSlowMA  = NormalizeDouble(BufferSlowMA[iBarForProcessing], SymbolDigits);
   double CurrentUSlowMA = NormalizeDouble(BufferUSlowMA[iBarForProcessing], SymbolDigits);

   double PrevFastMA  = NormalizeDouble(BufferFastMA[iBarForProcessing + 1], SymbolDigits);
   double PrevSlowMA  = NormalizeDouble(BufferSlowMA[iBarForProcessing + 1], SymbolDigits);
   double PrevUSlowMA = NormalizeDouble(BufferUSlowMA[iBarForProcessing + 1], SymbolDigits);

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);
   double PrevAtr = GetAtrValue(SymbolLoop, iBarForProcessing + 1);

   int crossup = 0;
   int crossdown = 0;
   for (int i = iBarForProcessing; i < iBarForProcessing + InpAtrMaMultiplier; i ++){
      if (BufferFastMA[i + 1] < BufferSlowMA[i + 1] && BufferFastMA[i] > BufferSlowMA[i]){
         crossup = 1;
         break;
      }
   }
   for (int i = iBarForProcessing; i < iBarForProcessing + InpAtrMaMultiplier; i ++){
      if (BufferFastMA[i + 1] > BufferSlowMA[i + 1] && BufferFastMA[i] < BufferSlowMA[i]){
         crossdown = 1;
         break;
      }
   }

   double Open[]; 
   double High[];
   double Low[];
   double Close[];

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Close);
   if (values!= RequiredCandles){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}   

   /*//Submit MA Long and Short Trades
   if(MA_Trend_Filter == Aligned){
      if(CurrentSlowMA - BufferSlowMA[10] > CurrentAtr * InpAtrMaMultiplier) return "Long";
      else if (BufferSlowMA[10] - CurrentSlowMA > CurrentAtr * InpAtrMaMultiplier) return "Short";
      else return "No Trade";
   }
   else if(MA_Trend_Filter == Reversed){
      if(CurrentSlowMA - BufferSlowMA[10] > CurrentAtr * InpAtrMaMultiplier) return "Short";
      else if (BufferSlowMA[10] - CurrentSlowMA > CurrentAtr * InpAtrMaMultiplier) return "Long";
      else return "No Trade";
   }
   else if(MA_Trend_Filter == No_Trend){
      if(CurrentSlowMA - BufferSlowMA[10] < CurrentAtr * InpAtrMaMultiplier) return "No Trend";
      else if (BufferSlowMA[10] - CurrentSlowMA < CurrentAtr * InpAtrMaMultiplier) return "No Trend";
      else return other_indicator;
   }   
   else if(MA_Trend_Filter == All_minus_Aligned){
      if(CurrentSlowMA - BufferSlowMA[10] > CurrentAtr * InpAtrMaMultiplier) return "Short";
      else if (BufferSlowMA[10] - CurrentSlowMA > CurrentAtr * InpAtrMaMultiplier) return "Long";
      else return other_indicator;
   }
   return other_indicator;
   */
      
   if ((CurrentFastMA > CurrentSlowMA && crossup == 0)
      //|| (CurrentFastMA < CurrentSlowMA && (crossup == 1)) //|| crossdown == 1))
      //(Close[iBarForProcessing] > CurrentFastMA && Close[iBarForProcessing] > CurrentSlowMA &&  (crossup == 1 || crossdown == 1))

      )
         return "Long";
   else if ((CurrentFastMA < CurrentSlowMA && crossdown == 0)
     // || (CurrentFastMA > CurrentSlowMA && (crossdown == 1)) //|| crossup == 1 ))
      //(Close[iBarForProcessing] > CurrentFastMA && Close[iBarForProcessing] > CurrentSlowMA &&  (crossup == 1 || crossdown == 1))

      )
         return "Short";
   /*         
   if (//(CurrentFastMA > CurrentSlowMA && crossup == 0 && Close[iBarForProcessing] > CurrentSlowMA)
      //|| 
      (Close[iBarForProcessing] < CurrentFastMA && Close[iBarForProcessing] < CurrentSlowMA &&  (crossup == 1 || crossdown == 1))
      )
         return "Long";
   else if (//(CurrentFastMA < CurrentSlowMA && crossdown == 0 && Close[iBarForProcessing] < CurrentSlowMA)
      //|| 
      (Close[iBarForProcessing] > CurrentFastMA && Close[iBarForProcessing] > CurrentSlowMA &&  (crossup == 1 || crossdown == 1))
      )
         return "Short";
         */
   else return "No Trade";

}

// Get MA Close Signals
string MA_SignalClose(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = 5; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferFastMA[];  
   double    BufferSlowMA[];  
   double    BufferUSlowMA[];

   //Populate buffers for fast MA lines
   bool FillFastMA   = tlamCopyBuffer(fast_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferFastMA, CurrentSymbol, "Fast MA");
   if(FillFastMA == false) return "FILL_ERROR";
   bool FillSlowMA   = tlamCopyBuffer(slow_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferSlowMA, CurrentSymbol, "Slow MA");
   if(FillSlowMA == false) return "FILL_ERROR";
   bool FillUSlowMA   = tlamCopyBuffer(uslow_MA_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferUSlowMA, CurrentSymbol, "Ultra Slow MA");
   if(FillUSlowMA == false) return "FILL_ERROR";

   //Find required MA signal lines
   double CurrentFastMA  = NormalizeDouble(BufferFastMA[iBarForProcessing], SymbolDigits);
   double CurrentSlowMA  = NormalizeDouble(BufferSlowMA[iBarForProcessing], SymbolDigits);
   double CurrentUSlowMA = NormalizeDouble(BufferUSlowMA[iBarForProcessing], SymbolDigits);

   double PrevFastMA  = NormalizeDouble(BufferFastMA[iBarForProcessing + 1], SymbolDigits);
   double PrevSlowMA  = NormalizeDouble(BufferSlowMA[iBarForProcessing + 1], SymbolDigits);
   double PrevUSlowMA = NormalizeDouble(BufferUSlowMA[iBarForProcessing + 1], SymbolDigits);

   double CurrentClose = NormalizeDouble(iClose(CurrentSymbol, TradeTimeframe,iBarForProcessing), SymbolDigits);
   double PrevClose    = NormalizeDouble(iClose(CurrentSymbol, TradeTimeframe,iBarForProcessing + 1), SymbolDigits);
   double CurrentOpen = NormalizeDouble(iOpen(CurrentSymbol, TradeTimeframe,iBarForProcessing), SymbolDigits);
   double PrevOpen    = NormalizeDouble(iOpen(CurrentSymbol, TradeTimeframe,iBarForProcessing + 1), SymbolDigits);

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);

   //Close MA Long and Short Trades
   if(//PrevClose < PrevSlowMA && CurrentClose < CurrentSlowMA
      (CurrentFastMA < CurrentSlowMA) 
      )
      return("Close_Long");
   else if (//PrevClose > PrevSlowMA && CurrentClose > CurrentSlowMA
      (CurrentFastMA > CurrentSlowMA )
      )
      return("Close_Short");
   else
      return("No_Close_Signal");
}

// Get ATR Open Signals
string ATR_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);
   double PrevAtr = GetAtrValue(SymbolLoop, iBarForProcessing + 1);

   if (CurrentAtr >= PrevAtr) return "UP";
   else return "DOWN";
}

// Get HOUR Open Signals
string Hour_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   double Close9 = iClose(CurrentSymbol,TradeTimeframe,iBarForProcessing);
   double Close8 = iClose(CurrentSymbol,TradeTimeframe,iBarForProcessing + 1);
   double Open9 = iOpen(CurrentSymbol,TradeTimeframe,iBarForProcessing);
   double Open8 = iOpen(CurrentSymbol,TradeTimeframe,iBarForProcessing + 1);

   if (Close9 - Open8 >= 0) return "Long";
   else if (Close9 - Open8 < 0) return "Short";
   else return "No Trade";
}

// Get Wide Range Bar Filters
string WideRangeBar_Filter(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   double Open[];
   double High[];
   double Low[];
   double Close[];

   const int StartCandle   = 0;
   int RequiredOHLC        = 5;

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Close);
   if (values!= RequiredOHLC){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}  

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);
   double PrevAtr    = GetAtrValue(SymbolLoop, iBarForProcessing + 1);
   double Atr2       = GetAtrValue(SymbolLoop, iBarForProcessing + 2);
   double Atr3       = GetAtrValue(SymbolLoop, iBarForProcessing + 3);
   double MAvalue    = GetFastMAValue(SymbolLoop, iBarForProcessing);
   
   bool WRBup    = false;
   bool WRBdown  = false;
   int  WRBmulti = 3;

   for (int i = 0; i < RequiredOHLC - 1; i++){
      if(High[iBarForProcessing + i] - Low[iBarForProcessing + i] > WRBmulti * GetAtrValue(SymbolLoop, iBarForProcessing + i + 1)
         && Close[iBarForProcessing + i] > Open[iBarForProcessing + i]
         ){
            WRBup = true;
            break;
         }
   }
   for (int i = 0; i < RequiredOHLC - 1; i++){
      if(High[iBarForProcessing + i] - Low[iBarForProcessing + i] > WRBmulti * GetAtrValue(SymbolLoop, iBarForProcessing + i + 1)
         && Close[iBarForProcessing + i] < Open[iBarForProcessing + i]
         ){
            WRBdown = true;
            break;
         }
   } 

   if (WRBup == true) return "No Short";
   else if (WRBdown == true) return "No Long";
   else return "ok";
     
}

//Get Candle Sequence
string Candle_Sequence(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   double Open[];
   double High[];
   double Low[];
   double Close[];
   double body[];
   double shadowup[];
   double shadowdown[];
   string pattern = "No_pattern";
   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);

   const int StartCandle   = 0;
   int RequiredOHLC        = candle + 6;

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);

   ArrayResize(body, RequiredOHLC);
   ArrayResize(shadowup, RequiredOHLC);
   ArrayResize(shadowdown, RequiredOHLC);

   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Close);
   if (values!= RequiredOHLC){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}  

   for(int i = 0; i < RequiredOHLC; i++){
      body[i] = NormalizeDouble(Close[i] - Open[i], SymbolDigits);
      shadowup[i] = NormalizeDouble(High[i] - MathMax(Close[i], Open[i]), SymbolDigits);
      shadowdown[i] = NormalizeDouble(MathMin(Close[i], Open[i]) - Low[i], SymbolDigits);
   } 
   
   if (body[candle + 2] < 0 && body[candle + 1] > 0 && body[candle] > 0 
      && Close[candle + 1] > (Close[candle + 2] + MathAbs(body[candle + 2]/2))
      && Close[candle] > High[candle + 2] && Close[candle] > High[candle + 1]
      ) pattern = "BULLISH_3-Inside-Up";

   else if (body[candle + 2] > 0 && body[candle + 1] < 0 && body[candle] < 0 
      && Close[candle + 1] < (Close[candle + 2] - MathAbs(body[candle + 2]/2))
      && Close[candle] < Low[candle + 2] && Close[candle] > Low[candle + 1]
      ) pattern = "BEARISH_3-Inside-Down";
   
   else if (shadowup[candle] > 2 * MathAbs(body[candle]) && shadowdown[candle] < 0.5 * MathAbs(body[candle])
      && body[candle] > 0
      && Low[candle] < MathMin(Low[candle + 1], MathMin(Low[candle + 2], MathMin(Low[candle + 3], MathMin(Low[candle + 4], Low[candle + 5])))) + 0.2 * GetAtrValue(SymbolLoop, candle)
      ) pattern = "BULLISH_Inverted-Hammer";
   else if (shadowup[candle] > 2 * MathAbs(body[candle]) && shadowdown[candle] < 0.5 * MathAbs(body[candle])
      && High[candle] > MathMax(High[candle + 1], MathMax(High[candle + 2], MathMax(High[candle + 3], MathMax(High[candle + 4], High[candle + 5]))))
      ) pattern = "BEARISH_Shooting-Star";

   else if (body[candle] > 0 && body[candle + 1] < 0 && Close[candle] > High[candle + 1]) pattern = "BULLISH_Engulfing";
   else if (body[candle] < 0 && body[candle + 1] > 0 && Close[candle] < Low[candle + 1]) pattern  = "BEARISH_Engulfing";
   
   else if (shadowdown[candle] > 2 * MathAbs(body[candle]) && shadowup[candle] < 0.5 * MathAbs(body[candle]) 
      && Low[candle] < MathMin(Low[candle + 1], MathMin(Low[candle + 2], MathMin(Low[candle + 3], MathMin(Low[candle + 4], Low[candle + 5]))))
      ) pattern = "BULLISH_Hammer";
   else if (shadowdown[candle] > 2 * MathAbs(body[candle]) && shadowup[candle] < 0.5 * MathAbs(body[candle])
      && body[candle] < 0
      && High[candle] > MathMax(High[candle + 1], MathMax(High[candle + 2], MathMax(High[candle + 3], MathMax(High[candle + 4], High[candle + 5])))) - 0.2 * GetAtrValue(SymbolLoop, candle)
      ) pattern = "BEARISH_Hanging-Man";
   
   return pattern;
}

//Get Candle Sequence Open Signal
string Candle_SignalOpen(int SymbolLoop, int candle){
   if(StringFind(Candle_Sequence(SymbolLoop, candle), "BULLISH") != -1) return "Long";
   else if(StringFind(Candle_Sequence(SymbolLoop, candle), "BEARISH") != -1) return "Short";
   else return "No Trade";
}

/*// Get Adaptive MA Open Signals
string AMA_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = InpKAMA + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferAMA[];  

   //Populate buffers for fast MA lines
   bool FillAMA   = tlamCopyBuffer(ama_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferAMA, CurrentSymbol, "Adaptive MA");
   if(FillAMA == false) return "FILL_ERROR";

   //Find required MA signal lines
   double CurrentAMA  = NormalizeDouble(BufferAMA[iBarForProcessing], SymbolDigits);

   double PrevAMA  = NormalizeDouble(BufferAMA[iBarForProcessing + 1], SymbolDigits);

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);
   double PrevAtr = GetAtrValue(SymbolLoop, iBarForProcessing + 1);

   double Open[]; 
   double High[];
   double Low[];
   double Close[];

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Close);
   if (values!= RequiredCandles){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}   

   double FastMA = GetFastMAValue(SymbolLoop, iBarForProcessing);

   if (PrevAMA - CurrentAMA < 0.5 * CurrentAtr
      && (MathMax(High[iBarForProcessing], Low[iBarForProcessing]) < CurrentAMA - 2 * CurrentAtr
      || MathMax(High[iBarForProcessing], Low[iBarForProcessing]) > CurrentAMA)
      ) return "Long";
   else if (CurrentAMA - PrevAMA < 0.5 * CurrentAtr
      && (MathMin(High[iBarForProcessing], Low[iBarForProcessing]) > CurrentAMA + 2 * CurrentAtr
      || MathMin(High[iBarForProcessing], Low[iBarForProcessing]) < CurrentAMA)
   ) return "Short";
   else return "No Trade"; 
//   return "No Trade";
}

// Get Adaptive MA Close Signals
string AMA_SignalClose(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = InpKAMA + 1; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; 
   double    BufferAMA[];  

   //Populate buffers for fast MA lines
   bool FillAMA   = tlamCopyBuffer(ama_Handle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferAMA, CurrentSymbol, "Adaptive MA");
   if(FillAMA == false) return "FILL_ERROR";

   //Find required MA signal lines
   double CurrentAMA  = NormalizeDouble(BufferAMA[iBarForProcessing], SymbolDigits);

   double PrevAMA  = NormalizeDouble(BufferAMA[iBarForProcessing + 1], SymbolDigits);

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);
   double PrevAtr = GetAtrValue(SymbolLoop, iBarForProcessing + 1);

   double Open[]; 
   double High[];
   double Low[];
   double Close[];

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Close);
   if (values!= RequiredCandles){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredCandles, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}   

   double FastMA = GetFastMAValue(SymbolLoop, iBarForProcessing);

   if (FastMA < CurrentAMA) return "Close_Long";
   else if (FastMA > CurrentAMA) return "Close_Short";
   else return "No_Close_Signal"; 
//   return "No Trade";
}

// Get HHLL Open Signals
string HHLL_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   string currH = "";
   string prevH = "";
   string currL = "";
   string prevL = "";       

   int HighCandle1 = LastHighCandle(CurrentSymbol, TradeTimeframe, InpHHLLperiod*4, 1, currH, prevH, InpDraw);
   int LowCandle1  = LastLowCandle(CurrentSymbol, TradeTimeframe, InpHHLLperiod*4, 1, currL, prevL, InpDraw);
   
   if (currHigh == "HH" && LowCandle1 == 1)  
      return "Long";
   else if (currLow == "LL" && HighCandle1 == 1) 
      return "Short"; 
   else 
      return "No Trade";   
}

// Get Support and Resistances based on HH and LL
string SyR_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   string currH = "";
   string prevH = "";
   string currL = "";
   string prevL = "";       

   int HighCandle1 = LastHighCandle(CurrentSymbol, TradeTimeframe, InpHHLLperiod*4, 1, currH, prevH, InpDraw);
   int LowCandle1  = LastLowCandle(CurrentSymbol, TradeTimeframe, InpHHLLperiod*4, 1, currL, prevL, InpDraw);

   double Open[];
   double High[];
   double Low[];
   double Close[];

   const int StartCandle   = 0;
   int RequiredOHLC        = 5;

   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);
   int values = CopyClose(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Close);
   if (values!= RequiredOHLC){ Print("Not enough data for Close"); return "ERROR: Not enough data for Close";}
   values = CopyOpen(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Open);
   // if (values!= RequiredOHLC){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, High);
   // if (values!= RequiredOHLC){ Print("Not enough data for High"); return;}
   values = CopyLow(CurrentSymbol, TradeTimeframe, StartCandle, RequiredOHLC, Low);
   // if (values!= RequiredOHLC){ Print("Not enough data for Low"); return;}  

   double CurrentAtr = GetAtrValue(SymbolLoop, iBarForProcessing);
   double PrevAtr    = GetAtrValue(SymbolLoop, iBarForProcessing + 1);
   double Atr2       = GetAtrValue(SymbolLoop, iBarForProcessing + 2);
   double Atr3       = GetAtrValue(SymbolLoop, iBarForProcessing + 3);
   double MAvalue    = GetFastMAValue(SymbolLoop, iBarForProcessing);
   
   bool WRBup = false;
   bool WRBdown = false;
   int WRBmulti = 3;

   for (int i = 0; i < RequiredOHLC - 1; i++){
      if(High[iBarForProcessing + i] - Low[iBarForProcessing + i] > WRBmulti * GetAtrValue(SymbolLoop, iBarForProcessing + i + 1)
         && Close[iBarForProcessing + i] > Open[iBarForProcessing + i]
         ){
            WRBup = true;
            break;
         }
   }
   for (int i = 0; i < RequiredOHLC - 1; i++){
      if(High[iBarForProcessing + i] - Low[iBarForProcessing + i] > WRBmulti * GetAtrValue(SymbolLoop, iBarForProcessing + i + 1)
         && Close[iBarForProcessing + i] < Open[iBarForProcessing + i]
         ){
            WRBdown = true;
            break;
         }
   }

   int syrnumber = 4;      // 4 picos, incluyendo el último no confirmado [0]
   double HighValues[];
   ArrayResize(HighValues, InpHHLLperiod);
   LastPeakValue(CurrentSymbol, TradeTimeframe, MODE_HIGH,InpHHLLperiod*4, syrnumber, HighValues, InpDraw);  

   double LowValues[];
   ArrayResize(LowValues, InpHHLLperiod);
   LastPeakValue(CurrentSymbol, TradeTimeframe, MODE_LOW,InpHHLLperiod*4, syrnumber, LowValues, InpDraw);

   double syr[];
   int syrsize = ArrayResize(syr,ArraySize(HighValues)-1 + ArraySize(LowValues)-1);

   ArrayCopy(syr, HighValues, 0, 1);                            // I don't want the last peak, so I start in 1 and copy size-1
   ArrayCopy(syr, LowValues, ArraySize(HighValues)-1, 1);

   if (InpDraw == true){
      ObjectsDeleteAll(0, "SyR");        
      for (int i = 0; i < syrsize; i++){                          
         HLineCreate(0,"SyR"+IntegerToString(i),0,syr[i], clrGreen);
      }
   }

   bool longcondition = false;
   bool shortcondition = false;

   for(int i = 0; i < syrsize; i++){
      if(//MathMin(Open[iBarForProcessing + 1], Close[iBarForProcessing + 1]) > syr[i] 
          Low[iBarForProcessing] < (syr[i] + 0.0 * CurrentAtr) //&& Close[iBarForProcessing] > syr[i]
         && Close[iBarForProcessing] > Open[iBarForProcessing] //&& Open[iBarForProcessing] > syr[i]
         && ((Close[iBarForProcessing + 1] < Open[iBarForProcessing + 1] && Close[iBarForProcessing + 1] > syr[i] ) 
         || (Close[iBarForProcessing + 2] < Open[iBarForProcessing + 2] && Close[iBarForProcessing + 2] > syr[i]))
         )
         longcondition = true;
   }
   for(int i = 0; i < syrsize; i++){
      if(//MathMax(Open[iBarForProcessing + 1], Close[iBarForProcessing + 1]) < syr[i]
          High[iBarForProcessing] > (syr[i] - 0.0 * CurrentAtr) //&& Close[iBarForProcessing] < syr[i]
         && Close[iBarForProcessing] < Open[iBarForProcessing] //&& Open[iBarForProcessing] < syr[i]
         && ((Close[iBarForProcessing + 1] > Open[iBarForProcessing + 1] && Close[iBarForProcessing + 1] < syr[i])  
         || (Close[iBarForProcessing + 2] > Open[iBarForProcessing + 2] && Close[iBarForProcessing + 2] < syr[i]))
         )
         shortcondition = true;
   }

   if (longcondition == true
      && WRBdown == false
      //&& MathMin(Close[iBarForProcessing],Open[iBarForProcessing])- Low[iBarForProcessing] > 2*(MathAbs(Open[iBarForProcessing]-Close[iBarForProcessing]))
      )
      return "Long";
   else if (shortcondition == true
            && WRBup == false
            //&& High[iBarForProcessing] - MathMax(Close[iBarForProcessing],Open[iBarForProcessing]) > 2*(MathAbs(Open[iBarForProcessing]-Close[iBarForProcessing]))
            )
            return "Short";
   else 
      return "No Trade";   
}

// Get HHLL Close Signals
string HHLL_SignalClose(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   string currHigh = "";
   string prevHigh = "";
   string currLow = "";
   string prevLow = "";       

   int lastHighCandle = LastHighCandle(CurrentSymbol, TradeTimeframe, InpHHLLperiod, 1, currHigh, prevHigh, InpDraw);
   int lastLowCandle  = LastLowCandle(CurrentSymbol, TradeTimeframe, InpHHLLperiod, 1, currLow, prevLow, InpDraw);

   if (lastHighCandle == 1)  
      return "Close_Long";
   else if (lastLowCandle == 1) 
      return "Close_Short";
   else 
      return "No_Close_Signal";   
 
}


// Get SlowStochastic Open Signals
string SlowStochastic_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 6; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    IndexK          = 0; // %K Line
   int    IndexD          = 1; // %D Line
   double BufferK[];         
   double BufferD[];          

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      FillK = tlamCopyBuffer(StochHandle2[SymbolLoop],IndexK, StartCandle, RequiredCandles, BufferK, CurrentSymbol, "%K");
   bool      FillD = tlamCopyBuffer(StochHandle2[SymbolLoop],IndexD, StartCandle, RequiredCandles, BufferD, CurrentSymbol, "%D");

   if(FillK==false || FillD==false ) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    CurrK   = NormalizeDouble(BufferK[iBarForProcessing], 2);
   double    CurrD   = NormalizeDouble(BufferD[iBarForProcessing], 2);
   double    PrevK   = NormalizeDouble(BufferK[iBarForProcessing + 1], 2);
   double    PrevD   = NormalizeDouble(BufferD[iBarForProcessing + 1], 2);

   //Return Stochastic Long and Short Signal
   if(CurrK > InpStochTrendUP
      )
      return   "Long";
   else if (CurrK < InpStochTrendDOWN
      )
      return   "Short";
   else
      return   "No Trade";   
}
*/
// Get SlowStochastic Close Signals
string SlowStochastic_SignalClose(int SymbolLoop, ENUM_POSITION_TYPE positiontype){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 6;      // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    IndexK          = 0;      // %K Line
   int    IndexD          = 1;      // %D Line
   double BufferK[];         
   double BufferD[];       

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      FillK = tlamCopyBuffer(StochHandle2[SymbolLoop],IndexK, StartCandle, RequiredCandles, BufferK, CurrentSymbol, "%K");
   bool      FillD = tlamCopyBuffer(StochHandle2[SymbolLoop],IndexD, StartCandle, RequiredCandles, BufferD, CurrentSymbol, "%D");

   if(FillK==false || FillD==false) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    CurrK = NormalizeDouble(BufferK[iBarForProcessing], 2);
   double    CurrD = NormalizeDouble(BufferD[iBarForProcessing], 2);
   double    PrevK   = NormalizeDouble(BufferK[iBarForProcessing + 1], 2);
   double    PrevD   = NormalizeDouble(BufferD[iBarForProcessing + 1], 2);

   //Return Stochastic Long and Short Signal
   if (positiontype == POSITION_TYPE_BUY){ 
      if ((PrevK > InpStochOB2 && CurrK < InpStochOB2)
      )
      return   "Close_Long";
   }

   else if(positiontype == POSITION_TYPE_SELL)
      if((PrevK < InpStochOS2 && CurrK > InpStochOS2)
      )
      return   "Close_Short";
   
   return   "No_Close_Signal";   
}
/*
// Get Stochastic RSI Open Signals
string StochRSI_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 3; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    Index           = 0; // %K Line
   double Buffer[];         

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      Fill = tlamCopyBuffer(RSIStochHandle[SymbolLoop],Index, StartCandle, RequiredCandles, Buffer, CurrentSymbol, "Stochastic RSI");

   if(Fill==false) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required RSI Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    Current = NormalizeDouble(Buffer[iBarForProcessing], SymbolDigits);
   double    Prev   = NormalizeDouble(Buffer[iBarForProcessing + 1], SymbolDigits);

   //Return RSI Stochastic Long and Short Signal
   if(Prev > InpRSIStochOS && Current < InpRSIStochOS)
      return   "Long";
   else if (Prev < InpRSIStochOB && Current > InpRSIStochOB)
      return   "Short";
   else
      return   "No Trade";   
}

// Get Stochastic RSI Close Signals
string StochRSI_SignalClose(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 3; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   int    Index           = 0; // %K Line
   double Buffer[];         

   // ArraySetAsSeries done inside tlamCopyBuffer
   // Define %K and %Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      Fill = tlamCopyBuffer(RSIStochHandle[SymbolLoop],Index, StartCandle, RequiredCandles, Buffer, CurrentSymbol, "Stochastic RSI");

   if(Fill==false) return "Fill Error"; //If buffers are not completely filled, return to end onTick
   
   //Find required RSI Stochastic signal lines and normalize to prevent rounding errors in crossovers
   double    Current = NormalizeDouble(Buffer[iBarForProcessing], SymbolDigits);
   double    Prev   = NormalizeDouble(Buffer[iBarForProcessing + 1], SymbolDigits);

   //Return RSI Stochastic Long and Short Signal
   if(Current > InpRSIStochOB)
      return   "Close_Long";
   else if (Current < InpRSIStochOS)
      return   "Close_Short";
   else
      return   "No_Close_Signal";   
}
*/


///////////////////////////////////////////////////////////

// Reset values OpenTradeOrderTicket array to account for SL and TP executions
void ResetOpenTrades(int SymbolLoop) {
   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  position_ticket  = OpenTradePositionTicket[SymbolLoop];
   if (OpenTradePositionTicket[SymbolLoop] != 0 && !PositionSelectByTicket(position_ticket)) { 
      Print (CurrentSymbol, " - ",  position_ticket, " Ticket not found. SL or TP executed. Reset OpenTrade Array");
      OpenTradePositionTicket[SymbolLoop] = 0; 

      if(!HistorySelectByPosition(OpenTradePositionID[SymbolLoop]))
         Print("Failed to HistorySelectByPosition ", OpenTradePositionID[SymbolLoop], " for symbol ", CurrentSymbol); 
      else{
         ulong dealTicket = 0;
         for (int i = 0; i < HistoryDealsTotal(); i++){
            if(HistoryDealGetInteger(HistoryDealGetTicket(i), DEAL_ENTRY) == DEAL_ENTRY_OUT){
               dealTicket = HistoryDealGetTicket(i);
            }
         }
         OutputMainDataInline(DiagnosticLoggingLevel, outputFileHandleInline, dealTicket, SymbolLoop);
      }      
      OpenTradePositionID[SymbolLoop] = 0;
   }      
}

//Process trades to enter buy or sell
bool ProcessTradeOpen(string CurrentSymbol, int SymbolLoop, ENUM_ORDER_TYPE OrderType)
{
   ResetLastError();
   // Check general conditions
   if (IsNewOrderAllowed()){ // && CountOpenPosition(MagicNumber) == 0 && trange.f_entry == true  // && CountOpenOrders(InpMagicNumber) == 0) { // && ER_Buffer[1] >= InpERlimit     

      //INSERT YOUR PRE-CHECKS HERE

      //Set symbol string and variables 
      int    SymbolDigits   = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error
     
      //double CurrentFastMA  = GetFastMAValue(SymbolLoop, iBarForProcessing);
      double CurrentAtr     = GetAtrValue(SymbolLoop, iBarForProcessing);
      double StopLossSize   = NormalizeDouble(MathMin(CurrentAtr * AtrLossMulti, SymbolInfoDouble(CurrentSymbol, SYMBOL_BID)/2), SymbolDigits); //AtrLossMulti * SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT);//NormalizeDouble(CurrentAtr * InpAtrEnvelopeIN, SymbolDigits);//  250 * SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT);// 
      double TakeProfitSize = NormalizeDouble(MathMin(CurrentAtr * AtrProfitMulti, SymbolInfoDouble(CurrentSymbol, SYMBOL_BID)/2), SymbolDigits); //AtrProfitMulti * SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT);//NormalizeDouble(CurrentAtr * InpAtrEnvelopeOUT, SymbolDigits);//

      double Price           = 0;
      double StopLossPrice   = 0;
      double TakeProfitPrice = 0;

      double LotSize = CalculateLots(CurrentSymbol, StopLossSize); //0.1;//       
      //double StopLossSize   = RiskSLSize( CurrentSymbol, 140, LotSize );

      if (!Checkstoplevels(CurrentSymbol, StopLossSize, TakeProfitSize)) return false;                                                   
      if (!CheckMoneyForTrade(CurrentSymbol, LotSize, OrderType)) return false;         
      //if (SymbolInfoInteger(CurrentSymbol, SYMBOL_SPREAD) > 10) return false;
      if (LotSize == 0) return false;

      double CurrentHigh     = NormalizeDouble(iHigh(CurrentSymbol, TradeTimeframe, iBarForProcessing), SymbolDigits);
      double CurrentLow      = NormalizeDouble(iLow(CurrentSymbol, TradeTimeframe, iBarForProcessing), SymbolDigits);
      double ask             = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), SymbolDigits);
      double bid             = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), SymbolDigits);

      bool success = false;
      //Open buy or sell orders
      if (OrderType == ORDER_TYPE_BUY) {
      //   if(!VaRCalc(CurrentSymbol, LotSize)) return false;
         Price           = ask;
         StopLossPrice   = NormalizeDouble(Price - StopLossSize, SymbolDigits);
         TakeProfitPrice = NormalizeDouble(Price + TakeProfitSize, SymbolDigits);
         success = Trade.PositionOpen(CurrentSymbol, OrderType, LotSize, Price, StopLossPrice, TakeProfitPrice, "BUY - " + __FILE__);
      } 
      else if (OrderType == ORDER_TYPE_SELL) {
      //   if(!VaRCalc(CurrentSymbol, -LotSize)) return false;
         Price           = bid;
         StopLossPrice   = NormalizeDouble(Price + StopLossSize, SymbolDigits);
         TakeProfitPrice = NormalizeDouble(Price - TakeProfitSize, SymbolDigits);
         success = Trade.PositionOpen(CurrentSymbol, OrderType, LotSize, Price, StopLossPrice, TakeProfitPrice, "SELL - " + __FILE__);
      }
      else if (OrderType == ORDER_TYPE_BUY_STOP) {
      //   if(!VaRCalc(CurrentSymbol, LotSize)) return false;
         Price           = CurrentHigh + 20 * SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT);
         StopLossPrice   = NormalizeDouble(CurrentLow - StopLossSize, SymbolDigits);
         TakeProfitPrice = NormalizeDouble(Price + TakeProfitSize, SymbolDigits);
         if (ask < Price)
            success = Trade.BuyStop(LotSize, Price, CurrentSymbol, StopLossPrice, TakeProfitPrice, ORDER_TIME_GTC, 0, "BUY STOP - " + __FILE__);
      } 
      else if (OrderType == ORDER_TYPE_SELL_STOP) {
      //   if(!VaRCalc(CurrentSymbol, -LotSize)) return false;
         Price           = CurrentLow - 20 * SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT); 
         StopLossPrice   = NormalizeDouble(CurrentHigh + StopLossSize, SymbolDigits);
         TakeProfitPrice = NormalizeDouble(Price - TakeProfitSize, SymbolDigits);
         if (bid > Price)
            success = Trade.SellStop(LotSize, Price, CurrentSymbol, StopLossPrice, TakeProfitPrice, ORDER_TIME_GTC, 0, "SELL STOP - "+ __FILE__);
      }
      
      //--- if the result fails - try to find out why 
      if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we opened the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to open position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
      }
      // Set OpenTradeOrderTicket to prevent future trades being opened until this is closed
      OpenTradeOrderTicket[SymbolLoop] = Trade.ResultOrder(); 
      // Print successful
      Print("Trade Processed For ", CurrentSymbol," OrderType ", OrderType, " Lot Size ", LotSize);

      
      // Set Indicators' Conditions at open 
      SetStochasticArrays(SymbolLoop, iBarForProcessing);
      SetMAArrays(SymbolLoop, iBarForProcessing);
      SetERArray(SymbolLoop, iBarForProcessing);
      SetRSIArray(SymbolLoop, iBarForProcessing);
      SetHHLLArray(SymbolLoop, iBarForProcessing);
      SetCandleSequenceArray(SymbolLoop, iBarForProcessing);
      SetAtrArrays(SymbolLoop, iBarForProcessing);
      
      ulong dealTicket = Trade.ResultDeal();
      HistoryDealSelect(dealTicket);
      OpenTradePositionID[SymbolLoop] =  HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID); 
      OutputMainDataInline(DiagnosticLoggingLevel, outputFileHandleInline, dealTicket, SymbolLoop);

   }  
   return(true);
}

//Process trades to close
bool ProcessTradeCloseTimeRange(int SymbolLoop) {
   ResetLastError();

   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  order_ticket     = OpenTradeOrderTicket[SymbolLoop];
   ulong  position_ticket  = OpenTradePositionTicket[SymbolLoop];

   // INCLUDE PRE-CLOSURE CHECKS HERE
   Print ("TIMECLOSE Position ticket to close: ", position_ticket, " - ", CurrentSymbol);
   if (!PositionSelectByTicket(position_ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to select position by ticket for ticket ", position_ticket, " - ", CurrentSymbol); return false; } 
   long magicnumber = 0;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber != MagicNumber) return false;

   //SETUP CTrade tradeObject HERE
  
   Trade.PositionClose(position_ticket);

   //CHECK FOR ERRORS AND HANDLE EXCEPTIONS HERE
   if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we closed the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to close position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
   }

   // Set OpenTradeOrderTicket to 0 to allow future tradesto be opened
   OpenTradeOrderTicket[SymbolLoop] = 0;
   OpenTradePositionTicket[SymbolLoop] = 0;
   //Print (CloseSignalStatus, " successful");

   ulong dealTicket = Trade.ResultDeal();
   OutputMainDataInline(DiagnosticLoggingLevel, outputFileHandleInline, dealTicket, SymbolLoop);
   OpenTradePositionID[SymbolLoop] = 0;
   /*// Print Array status
   string Output = "";
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
      Output += SymbolArray[SymbolLoop] + " - T: " + (string) OpenTradeOrderTicket[SymbolLoop] + " / ";
   }      
   Print(Output);
   */
   return true;
}

//Process trades to close buy or sell
bool ProcessTradeClose(int SymbolLoop) {
   ResetLastError();

   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  order_ticket     = OpenTradeOrderTicket[SymbolLoop];
   ulong  position_ticket  = OpenTradePositionTicket[SymbolLoop];
   string CloseSignalStatusLONG = "";
   string CloseSignalStatusSHORT = "";

   // INCLUDE PRE-CLOSURE CHECKS HERE
   // Print ("Position ticket to close: ", position_ticket, " - ", CurrentSymbol);
   if (!PositionSelectByTicket(position_ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to select position by ticket for ticket ", position_ticket, " - ", CurrentSymbol); return false; } 
   long magicnumber = 0;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber != MagicNumber) return false;

   //SETUP CTrade tradeObject HERE

   ENUM_POSITION_TYPE positiontype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   string CloseSignalStatus1 = SlowStochastic_SignalClose(SymbolLoop, positiontype); // Stochastic_SignalClose(SymbolLoop, positiontype);//HHLL_SignalClose(SymbolLoop); //Stochastic_SignalClose(SymbolLoop, positiontype); 
   string CloseSignalStatus2 = CloseSignalStatus1; //MA_SignalClose(SymbolLoop);

   if ((CloseSignalStatus1 == "Close_Long" || CloseSignalStatus2 == "Close_Long")){
      CloseSignalStatusLONG = "Close_Long";
   }
   if ((CloseSignalStatus1 == "Close_Short" || CloseSignalStatus2 == "Close_Short")){
      CloseSignalStatusSHORT = "Close_Short";
   }

   if (positiontype == POSITION_TYPE_BUY && CloseSignalStatusLONG == "Close_Long"){
      Trade.PositionClose(position_ticket);
   }
   else if (positiontype == POSITION_TYPE_SELL && CloseSignalStatusSHORT == "Close_Short"){
      Trade.PositionClose(position_ticket);
   }
   else return false;

   //CHECK FOR ERRORS AND HANDLE EXCEPTIONS HERE
   if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we closed the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to close position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
   }

   // Set OpenTradeOrderTicket to 0 to allow future trades to be opened
   OpenTradeOrderTicket[SymbolLoop] = 0;
   OpenTradePositionTicket[SymbolLoop] = 0;
   //Print (CloseSignalStatus, " successful");

   ulong dealTicket = Trade.ResultDeal();
   OutputMainDataInline(DiagnosticLoggingLevel, outputFileHandleInline, dealTicket, SymbolLoop);
   OpenTradePositionID[SymbolLoop] = 0;

   return true;
}

//Process trades to modify SL or TP
bool ProcessTradeModify(int SymbolLoop) {
   ResetLastError();

   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  position_ticket  = OpenTradePositionTicket[SymbolLoop];
   int    SymbolDigits   = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error
   
   double Atr     = GetAtrValue(SymbolLoop, iBarForProcessing);
   double CurrentFastMA  = GetFastMAValue(SymbolLoop, iBarForProcessing);
   double TakeProfitSize = NormalizeDouble(Atr * InpAtrEnvelopeOUT, SymbolDigits);//NormalizeDouble(MathMin(CurrentAtr * AtrProfitMulti, SymbolInfoDouble(CurrentSymbol, SYMBOL_BID)/2), SymbolDigits);
   
   // INCLUDE PRE-CLOSURE CHECKS HERE
   // Print ("Position ticket to close: ", position_ticket, " - ", CurrentSymbol);
   if (!PositionSelectByTicket(position_ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to select position by ticket for ticket ", position_ticket, " - ", CurrentSymbol); return false; } 
   long magicnumber = 0;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber != MagicNumber) return false;

   double StopLossPrice   = PositionGetDouble(POSITION_SL);
   double TakeProfitPrice = 0;
   if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
      TakeProfitPrice = NormalizeDouble(CurrentFastMA + TakeProfitSize, SymbolDigits);
      Trade.PositionModify(position_ticket, StopLossPrice, TakeProfitPrice);
   }
   else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
      TakeProfitPrice = NormalizeDouble(CurrentFastMA - TakeProfitSize, SymbolDigits);
      Trade.PositionModify(position_ticket, StopLossPrice, TakeProfitPrice);
   }
   else return false;

   //CHECK FOR ERRORS AND HANDLE EXCEPTIONS HERE
   if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we closed the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to MODIFY position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
   }

   // Print ("Modified ticket; ", position_ticket, " successful");
   return true;
}

// Position TIMER (Hay que pulir el cálculo de días para cuando agarra un fin de semana)
bool ClosePositionByTimer(int SymbolLoop, int PosTimer){
   ResetLastError();
   if (PosTimer < 0) return false;

   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  position_ticket  = OpenTradePositionTicket[SymbolLoop];

   // INCLUDE PRE-CLOSURE CHECKS HERE
   // Print ("Position ticket to close: ", position_ticket, " - ", CurrentSymbol);
   if (!PositionSelectByTicket(position_ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to select position by ticket for ticket ", position_ticket, " - ", CurrentSymbol); return false; } 
   long magicnumber = 0;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber != MagicNumber) return false;

   //SETUP CTrade tradeObject HERE
   //pido la fecha y hora de apertura
   datetime PositionOpenTime = (datetime) PositionGetInteger(POSITION_TIME);
   //creo estructura
   MqlDateTime MyOpenTime;   
   //Convierto la hora de apertura a esta esctructura
   TimeToStruct(PositionOpenTime, MyOpenTime);
   int OpenMinutes = MyOpenTime.day * 24 * 60 + MyOpenTime.hour * 60 + MyOpenTime.min;
   //pido la hora local
   datetime CurrentTime = TimeCurrent();
   //Creo estructura
   MqlDateTime MyCurrentTime;
   //Convierto la hora local a esta esctructura
   TimeToStruct(CurrentTime, MyCurrentTime);
   //pido la hora y minutos local 
   int CurrentMinutes = MyCurrentTime.day *24 * 60+ MyCurrentTime.hour * 60 + MyCurrentTime.min;
   
   //Ahora puedo calcular la diferencia de enteros.
   int Difference = CurrentMinutes - OpenMinutes;

   //Print ("### OrderTicket: ", ticket);
   //Print ("### OrderOpenTime: ",OrderOpenTime);
   //Print ("### LocalTime: ",LocalTime);
   //Print ("### Difference: ",Difference);
   
   if (MathAbs(Difference) <= PosTimer)
      return false;

   Trade.PositionClose(position_ticket);
   //CHECK FOR ERRORS AND HANDLE EXCEPTIONS HERE
   if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we closed the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to close position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
   }

   // Set OpenTradeOrderTicket to 0 to allow future tradesto be opened
   OpenTradeOrderTicket[SymbolLoop] = 0;
   OpenTradePositionTicket[SymbolLoop] = 0;

   Print ("### Close position due to timer expiration. Ticket: ", position_ticket);
   
   ulong dealTicket = Trade.ResultDeal();
   OutputMainDataInline(DiagnosticLoggingLevel, outputFileHandleInline, dealTicket, SymbolLoop);
   OpenTradePositionID[SymbolLoop] = 0;

   return true;      
}     

///////////////////////////////////////////////////////////

// Add Symbols to MarketWatch
void AddToMarketWatch()
{
   bool addSuccess;
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      addSuccess = SymbolSelect(SymbolArray[SymbolLoop], true);
      if(addSuccess)
         Print("Successfully added ", SymbolArray[SymbolLoop], " to Marketwatch (or already there)");
      else 
         Print("Error adding symbol ", SymbolArray[SymbolLoop], " to Marketwatch");
   }
}

//tlamCopyBuffer is the standard MQL5 copybuffer plus error checking.
bool tlamCopyBuffer(int ind_handle,            // handle of the indicator 
                    int buffer_num,            // for indicators with multiple buffers
                    int firstCandle,           // first required candle
                    int numBarsRequired,       // number of values to copy 
                    double &localArray[],      // local array 
                    string symbolDescription,  
                    string indDesc)
{
   int availableBars;
   bool success = false;
   int failureCount = 0;

   //Sometimes a delay in prices coming through can cause failure, so allow 3 attempts
   while(!success){
      availableBars = BarsCalculated(ind_handle);
      if(availableBars < numBarsRequired){
         failureCount++;
         if(failureCount >= 3){
            Print("Failed to calculate sufficient bars in tlamCopyBuffer() after ", failureCount, " attempts (", symbolDescription, "/", indDesc, " - Required=", numBarsRequired, " Available=", availableBars, ")");
            return(false);
         }
         Print("Attempt ", failureCount, ": Insufficient bars calculated for ", symbolDescription, "/", indDesc, "(Required=", numBarsRequired, " Available=", availableBars, ")");
         //Sleep for 0.1s to allow time for price data to become usable
         Sleep(100);
      }
      else {
         success = true;         
         if(failureCount > 0) //only write success message if previous failures registered
            Print("Succeeded on attempt ", failureCount+1);
      }
   }
      
   ResetLastError(); 

   int numAvailableBars = CopyBuffer(ind_handle, buffer_num, firstCandle, numBarsRequired, localArray);
   if(numAvailableBars != numBarsRequired) { 
      Print("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to copy data from indicator. Bars required = ", numBarsRequired, " but bars copied = ", numAvailableBars);
      return(false); 
   } 
   //Ensure that elements indexed like in a timeseries (with index 0 being the current, 1 being one bar back in time etc.)
   ArraySetAsSeries(localArray, true);

   return(true); 
}

// Check Inputs 
bool CheckInputs() {
   // check for correct input from user
   if (MagicNumber <= 0)                                                      { Alert ("Magicnumber <= 0"); return false; }
   
   if (InpLotMode == LOT_MODE_FIXED && (InpLots <= 0 || InpLots > 5))         { Alert ("Lots <= 0 or > 5"); return false; }
   if (InpLotMode == LOT_MODE_MONEY && (InpLots <= 0 || InpLots > 500))       { Alert ("Money <= 0 or > 500"); return false; }
   if (InpLotMode == LOT_MODE_PCT_ACCOUNT && (InpLots <= 0 || InpLots > 2))   { Alert ("Percent <= 0 or > 2"); return false; }   
   /*
   if ((InpLotMode == LOT_MODE_MONEY || InpLotMode == LOT_MODE_PCT_ACCOUNT) && InpStopLoss == 0){ Alert ("Selected lot mode needs a stop loss"); return false; }        
   if (InpStopLoss < 0 || InpStopLoss > 1000){ Alert ("Stop Loss <= 0 or > 1000"); eturn false; }   
   if (InpTakeProfit < 0 || InpTakeProfit > 1000){ Alert ("Take profit <= 0 or > 1000"); return false; }
   */

   if (InpAtrPeriod <= 0)     { Alert("ATR Period <= 0"); return false;}
   if (AtrLossMulti <= 0)     { Alert("AtrLossMulti <= 0"); return false;}
   if (AtrProfitMulti <= 0)   { Alert("AtrProfitMulti <= 0");  return false;}
   //if (AtrProfitMulti < AtrLossMulti)   { Alert("AtrProfitMulti < AtrLossMulti");  return false;}

   if (InpKPeriod <= 0)       { Alert("Stochastic %K <= 0"); return false;}
   if (InpDPeriod <= 0)       { Alert("Stochastic %D <= 0"); return false;}
   if (InpSlowing <= 0)       { Alert("Stochastic %K Slowing factor <= 0"); return false;}
   if (InpStochOB <= 0 || InpStochOB >= 100) { Alert("Stochastic OverBought out of range"); return false;}
   if (InpStochOS <= 0 || InpStochOS >= 100) { Alert("Stochastic OverSold out of range"); return false;}

   if (InpFastMA <= 0)         { Alert("Fast MA <= 0"); return false;}
   if (InpSlowMA <= 0)         { Alert("Slow MA <= 0"); return false;}
   if (InpUSlowMA <= 0)        { Alert("Ultra Slow MA <= 0"); return false;}

   if (InpRangeStart < 0 || InpRangeStart >= 1440) {
      Alert ("Range start < 0 or >= 1440"); 
      return false;
      }   
   if (InpRangeDuration < 0 || InpRangeDuration >= 1440) { 
      Alert ("Range duration < 0 or >= 1440"); 
      return false; 
      } 
   
   // Start + Duration Can be bigger than 1 day, so use % to compare that open and close are not the same
   if (InpRangeClose < -1 || InpRangeClose >= 1440 || (InpRangeStart + InpRangeDuration) % 1440 == InpRangeClose) { 
      Alert ("Range close < 0 or >= 1440 or end time == close time");
      return false;
   }

   return true;
}

// Determine which bar we will used (0 or 1) to perform processing of data
int setProcessingBar(ENUM_BAR_PROCESSING_METHOD BarProcMethod, int iBarForProc){
   if(BarProcMethod == PROCESS_ALL_DELIVERED_TICKS)                   //Process data every tick that is 'delivered' to the EA
      iBarForProc = 0;                                                //The rationale here is that it is only worth processing every tick if you are actually going to use bar 0 from the trade TF, the value of which changes throughout the bar in the Trade TF                                          //The rationale here is that we want to use values that are right up to date - otherwise it is pointless doing this every 10 seconds   
   else if(BarProcMethod == ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR)       //Process trades based on 'any' TF, every minute.
      iBarForProc = 0;                                                //The rationale here is that it is only worth processing every minute if you are actually going to use bar 0 from the trade TF, the value of which changes throughout the bar in the Trade TF      
   else if(BarProcMethod == ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR) //Process when a new bar appears in the TF being used. So the M15 TF is processed once every 15 minutes, the TF60 is processed once every hour etc...
      iBarForProc = 1;                                                //The rationale here is that if you only process data when a new bar in the trade TF appears, then it is better to use the indicator data etc from the last 'completed' bar, which will not subsequently change. (If using indicator values from bar 0 these will change throughout the evolution of bar 0) 
   Print("EA using " + EnumToString(BarProcMethod) + " processing method and indicators will use bar " + IntegerToString(iBarForProc));
   return iBarForProc;
}

// Control Tick Processing
bool TickProcessingMultiSymbol(bool ProcessThisIteration, int SymbolLoop, string CurrentSymbol){
   if(BarProcessingMethod == PROCESS_ALL_DELIVERED_TICKS) ProcessThisIteration = true;      
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR){                    // Process trades from any TF, every minute.
      if(TimeLastTickProcessed[SymbolLoop] != iTime(CurrentSymbol, PERIOD_M1, 0)){
         ProcessThisIteration = true;
         TimeLastTickProcessed[SymbolLoop] = iTime(CurrentSymbol, PERIOD_M1, 0);
      }
   }
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR){              // Process when a new bar appears in the TF being used. So the M15 TF is processed once every 15 minutes, the TF60 is processed once every hour etc...
      if(TimeLastTickProcessed[SymbolLoop] != iTime(CurrentSymbol, TradeTimeframe, 0)){   // TimeLastTickProcessed contains the last Time[0] we processed for this TF. If it's not the same as the current value, we know that we have a new bar in this TF, so need to process 
         ProcessThisIteration = true;
         TimeLastTickProcessed[SymbolLoop] = iTime(CurrentSymbol, TradeTimeframe, 0);
      }
   }
   return ProcessThisIteration;
}

string Time_Filter_Signals(){

   string CurrentFilterTime = "";
   //Get current time
   datetime CurrentTime = TimeCurrent();
   MqlDateTime MyCurrentTime;
   TimeToStruct(CurrentTime, MyCurrentTime);
   //Actual Minutes 
   int CurrentMinutes = MyCurrentTime.hour * 60 + MyCurrentTime.min;
   
   if(CurrentMinutes >= InpRangeStart && CurrentMinutes < (InpRangeStart + InpRangeDuration)){
      CurrentFilterTime = "Time ok";
   } 
   else if(CurrentMinutes < InpRangeStart){
      CurrentFilterTime = "No Trade";
   }
   else if(CurrentMinutes >= InpRangeClose && InpRangeClose >= 0){
      CurrentFilterTime = "Close by Time";
   }  
   return(CurrentFilterTime);
}

///////////////////////////////////////////////////////////

// Resize Core Arrays for multi-symbol EA
void ResizeCoreArrays(){
   ArrayResize(OpenTradeOrderTicket,  NumberOfTradeableSymbols);
   ArrayResize(OpenTradePositionTicket,  NumberOfTradeableSymbols);
   ArrayResize(OpenTradePositionID, NumberOfTradeableSymbols);

   ArrayResize(SymbolMetrics,         NumberOfTradeableSymbols);
   ArrayResize(TicksProcessed,        NumberOfTradeableSymbols); 
   ArrayResize(TimeLastTickProcessed, NumberOfTradeableSymbols);   

   ArrayResize(FlagStochastic, NumberOfTradeableSymbols);
   //ArrayResize(FlagAroon, NumberOfTradeableSymbols);
   ArrayResize(StochasticCurrentK, NumberOfTradeableSymbols);
   ArrayResize(StochasticPrevK, NumberOfTradeableSymbols);
   ArrayResize(StochasticCurrentD, NumberOfTradeableSymbols);
   ArrayResize(StochasticPrevD, NumberOfTradeableSymbols);
   ArrayResize(StochasticK_Dir, NumberOfTradeableSymbols);
   ArrayResize(StochasticD_Dir, NumberOfTradeableSymbols);
   ArrayResize(ConsecutiveOB, NumberOfTradeableSymbols);
   ArrayResize(ConsecutiveOS, NumberOfTradeableSymbols);

   ArrayResize(FastMA_Dir, NumberOfTradeableSymbols);
   ArrayResize(TripleMA, NumberOfTradeableSymbols);
   ArrayResize(HHLLsequence, NumberOfTradeableSymbols);
   ArrayResize(RSIvalue, NumberOfTradeableSymbols);
   ArrayResize(EfficiencyRatio, NumberOfTradeableSymbols);
   ArrayResize(Candlesequence, NumberOfTradeableSymbols);
   ArrayResize(CandlesequencePrev, NumberOfTradeableSymbols);
   ArrayResize(AtrDirection,NumberOfTradeableSymbols);
   ArrayResize(AtrvsMA,NumberOfTradeableSymbols);

}

// Resize Indicator for multi-symbol EA
void ResizeIndicatorArrays(){
   //Indicator Handle Arrays
   ArrayResize(StochHandle, NumberOfTradeableSymbols);  
   ArrayResize(fast_MA_Handle, NumberOfTradeableSymbols);   
   ArrayResize(slow_MA_Handle, NumberOfTradeableSymbols);   
   ArrayResize(uslow_MA_Handle, NumberOfTradeableSymbols);   
   ArrayResize(kama_Handle, NumberOfTradeableSymbols);
   ArrayResize(ama_Handle, NumberOfTradeableSymbols);
   ArrayResize(AtrHandle, NumberOfTradeableSymbols);      
   ArrayResize(ERHandle, NumberOfTradeableSymbols); 
   //ArrayResize(AroonHandle, NumberOfTradeableSymbols); 
   ArrayResize(StochHandle2, NumberOfTradeableSymbols);  
   //ArrayResize(RSIStochHandle, NumberOfTradeableSymbols); 
   ArrayResize(RSIHandle, NumberOfTradeableSymbols); 
}

// Set up required indicator handles (arrays because of multi-symbol capability in EA)
bool SetUpIndicatorHandles(){
   string indicator = "";
   //Set up Stochastic Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++){
      //Reset any previous error codes so that only gets set if problem setting up indicator handle
      ResetLastError();
      indicator = "Stochastic";
      StochHandle[SymbolLoop] = iStochastic(SymbolArray[SymbolLoop],TradeTimeframe,InpKPeriod,InpDPeriod,InpSlowing,MODE_SMA, STO_LOWHIGH); 
      if(StochHandle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   
   //Set up Fast MA Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "Fast MA";
      fast_MA_Handle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],TradeTimeframe,InpFastMA,0,InpMethodFastMA,PRICE_CLOSE); 
      if(fast_MA_Handle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 

   //Set up Slow MA Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "Slow MA";
      slow_MA_Handle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],TradeTimeframe,InpSlowMA,0,InpMethodSlowMA,PRICE_CLOSE); 
      if(slow_MA_Handle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 

   //Set up Ultra Slow MA Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "Ultra Slow MA";
      uslow_MA_Handle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],TradeTimeframe,InpUSlowMA,0,InpMethodUSlowMA,PRICE_CLOSE); 
      if(uslow_MA_Handle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   
   
   //Set up ATR Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "ATR";
      AtrHandle[SymbolLoop] = iATR(SymbolArray[SymbolLoop],TradeTimeframe,InpAtrPeriod); 
      if(AtrHandle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   
   //Set up ER Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "Efficiency Ratio";
      ERHandle[SymbolLoop] = iCustom(SymbolArray[SymbolLoop], TradeTimeframe, ERName, InpERPeriod, InpERlimit); 
      if(ERHandle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++){
      //Reset any previous error codes so that only gets set if problem setting up indicator handle
      ResetLastError();
      indicator = "RSI";
      RSIHandle[SymbolLoop] = iRSI(SymbolArray[SymbolLoop], TradeTimeframe, InpRSIPeriod,PRICE_CLOSE); 
      if(RSIHandle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }

/*//Set up AMA Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "Adaptive MA";
      ama_Handle[SymbolLoop] = iAMA(SymbolArray[SymbolLoop], TradeTimeframe, InpKAMA, 2, 30, 0, PRICE_CLOSE);
      if(ama_Handle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   
   //Set up KAMA Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      indicator = "KAMA";
      kama_Handle[SymbolLoop] = iCustom(SymbolArray[SymbolLoop], TradeTimeframe, KAMAName, InpKAMA, PRICE_CLOSE, 2, 30);
      if(kama_Handle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   */
   //Set up Slow Stochastic Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++){
      //Reset any previous error codes so that only gets set if problem setting up indicator handle
      ResetLastError();
      indicator = "Slow Stochastic";
      StochHandle2[SymbolLoop] = iStochastic(SymbolArray[SymbolLoop],TradeTimeframe,InpKPeriod2,InpDPeriod2,InpSlowing2,MODE_SMA, STO_LOWHIGH); 
      if(StochHandle2[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   /*
   //Set up RSIStochastic Handle for Multi-Symbol EA
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++){
      //Reset any previous error codes so that only gets set if problem setting up indicator handle
      ResetLastError();
      indicator = "RSI Stochastic";
      RSIStochHandle[SymbolLoop] = iCustom(SymbolArray[SymbolLoop],TradeTimeframe,RSIStochasticName,InpRSIPeriod, PRICE_CLOSE, InpStoRSIPeriod, 1, InpRSIStochSmoothing, InpRSIStochOB, InpRSIStochOS); 
      if(RSIStochHandle[SymbolLoop] == INVALID_HANDLE){
         InvalidHandleErrorMessageBox(SymbolArray[SymbolLoop], indicator);
         return false; // Don't proceed
      }
   }
   Print("Handle for " + indicator + " for all Symbols successfully created"); 
   */

   return true;
}

// Release indicator handles from Metatrader cache for multi-symbol EA
void ReleaseIndicatorHandles(){
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      IndicatorRelease(StochHandle[SymbolLoop]);
      IndicatorRelease(fast_MA_Handle[SymbolLoop]);
      IndicatorRelease(slow_MA_Handle[SymbolLoop]);
      IndicatorRelease(uslow_MA_Handle[SymbolLoop]);
      //IndicatorRelease(kama_Handle[SymbolLoop]);
      //IndicatorRelease(ama_Handle[SymbolLoop]);
      IndicatorRelease(AtrHandle[SymbolLoop]);
      IndicatorRelease(ERHandle[SymbolLoop]); 
      //IndicatorRelease(AroonHandle[SymbolLoop]);
      IndicatorRelease(StochHandle2[SymbolLoop]);
      //IndicatorRelease(RSIStochHandle[SymbolLoop]);
      IndicatorRelease(RSIHandle[SymbolLoop]);
   }
   Print("Handle released for all symbols");   
}

///////////////////////////////////////////////////////////

bool ResetOpenOrders(int SymbolLoop, int OrderTimer) {
   ResetLastError();
   if (OrderTimer < 0) return false;
   
   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  order_ticket     = OpenTradeOrderTicket[SymbolLoop];

   if (order_ticket == 0) return false; 

   // INCLUDE PRE-CLOSURE CHECKS HERE
   if (!OrderSelect(order_ticket)) { 
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to select order by ticket for ticket ", order_ticket, " - ", CurrentSymbol); 
      OpenTradeOrderTicket[SymbolLoop] = 0;
      return false;  
   } 
   long magicnumber = 0;
   if (!OrderGetInteger(ORDER_MAGIC, magicnumber)) { // Gets the value of POSITION_MAGIC and puts it in magicnumber 
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to get position magicnumber"); 
      return false; 
   } 
   if (magicnumber != MagicNumber) return false;

   //Get current time
   datetime CurrentTime = TimeCurrent();
   MqlDateTime MyCurrentTime;
   TimeToStruct(CurrentTime, MyCurrentTime);
   //Actual Minutes 
   int CurrentMinutes = MyCurrentTime.day * 24 * 60 + MyCurrentTime.hour * 60 + MyCurrentTime.min;
 
   long OrderOpenTime = OrderGetInteger(ORDER_TIME_SETUP);
   MqlDateTime MyOpenTime;
   TimeToStruct(OrderOpenTime,MyOpenTime);
      
   int OpenMinutes = MyOpenTime.day * 24 * 60 + MyOpenTime.hour*60 + MyOpenTime.min;
   int roundOpenMin = OpenMinutes / OrderTimer;  // se divide entre 15 para saber el numero de vela desde el inicio del dia, 
   OpenMinutes = roundOpenMin * OrderTimer;      // se vuelve al minuto inicial de la vela de apertura

   if (OpenTradeOrderTicket[SymbolLoop] != 0 && CurrentMinutes-OpenMinutes >= OrderTimer) {
      Trade.OrderDelete(order_ticket);
      Print ("### Cierro orden ", CurrentSymbol, " por expiracion de tiempo: ",order_ticket, " tiempo apertura: ", OpenMinutes);
      OpenTradeOrderTicket[SymbolLoop] = 0;
   }   
   /*
   if (OpenTradeOrderTicket[SymbolLoop] != 0 && !OrderSelect(order_ticket)) { 
      Print (CurrentSymbol, " - ",  order_ticket, " Ticket not found. Reset OpenTrade Array");
      OpenTradeOrderTicket[SymbolLoop] = 0; 
   }*/
   return true;
}


/*// Calculate Value at Risk
bool VaRCalc(string CurrentSymbol, double ProposedPosSize){
   
   // If there is no VaR limit skip calculations
   double LimitVaR = AccountInfoDouble(ACCOUNT_EQUITY) * InpVaRPercent/100;
   if (InpVaRPercent == 100) return true; 

   // Count the number of non-zero elements in the original array
   int nonZeroCount = 0;
   for (int i = 0; i < NumberOfTradeableSymbols; i++) {
      if (OpenTradeOrderTicket[i] != 0) {
         nonZeroCount++;
      }
   }

   if(nonZeroCount>0){
      // Create a new arrays with non-zero values
      string CurrPortAssets[];  
      double CurrPortLotSizes[];
      long   CurrPortDirection[];

      ArrayResize(CurrPortAssets, nonZeroCount);
      ArrayResize(CurrPortLotSizes, nonZeroCount);
      ArrayResize(CurrPortDirection, nonZeroCount);

      // Copy non-zero values from the original array to the new array
      for (int i = 0, j = 0; i < NumberOfTradeableSymbols; i++) {
         if (OpenTradeOrderTicket[i] != 0) {
            CurrPortAssets[j] = SymbolArray[i];
            PositionSelectByTicket(OpenTradeOrderTicket[i]);
            PositionGetDouble(POSITION_VOLUME, CurrPortLotSizes[j]);
            PositionGetInteger(POSITION_TYPE, CurrPortDirection[j]);
            if(CurrPortDirection[j] == POSITION_TYPE_SELL)
               CurrPortLotSizes[j] = -MathAbs(CurrPortLotSizes[j]);
            j++;
         }
      }

      //CALCULATE THE INITIAL VaR BEFORE PROPOSED POSITION
      PortfolioRisk.CalculateVaR(CurrPortAssets, CurrPortLotSizes);  
      double currValueAtRisk = PortfolioRisk.MultiPositionVaR;
     
      //CREATE PROPOSED POSITION ARRAY AND ADD PROPOSED POSITION 
      string ProposedPortAssets[];
      double ProposedPorLotSizes[];
      ArrayResize(ProposedPortAssets, nonZeroCount + 1);
      ArrayResize(ProposedPorLotSizes, nonZeroCount + 1);
      
      ArrayCopy(ProposedPortAssets, CurrPortAssets);
      ArrayCopy(ProposedPorLotSizes, CurrPortLotSizes);
               
      ProposedPortAssets[ArraySize(ProposedPortAssets)-1]   = CurrentSymbol;
      ProposedPorLotSizes[ArraySize(ProposedPorLotSizes)-1] = ProposedPosSize;
      
      //POSITION DIAGNOSTIOCS
      string posDiagnostics = "";
      for(int i=0; i<ArraySize(ProposedPortAssets); i++){
         string posType = (i==ArraySize(ProposedPortAssets)-1)?"PROPOSED":"EXISTING";
         posDiagnostics += "Pos " + IntegerToString(i) + " " + ProposedPortAssets[i] + " " + DoubleToString(ProposedPorLotSizes[i], 2) + "  (" + posType + ")\n";
      }   
      
      //CALCULATE THE PROPOSED VaR IF NEW POSITION WERE ALLOWED TO OPEN
      PortfolioRisk.CalculateVaR(ProposedPortAssets, ProposedPorLotSizes);
      double proposedValueAtRisk = PortfolioRisk.MultiPositionVaR;
      
      //CALCULATE INCREMENTAL VaR
      double incrVaR = proposedValueAtRisk - currValueAtRisk;
      
      //MessageBox(posDiagnostics + "\n" +
      //         "CURRENT VaR: " + DoubleToString(currValueAtRisk, 2) + "\n" +
      //         "PROPOSED VaR: " + DoubleToString(proposedValueAtRisk, 2) + "\n" +
      //         "INCREMENTAL VaR: " + DoubleToString(incrVaR, 2)); 
               
      Print(posDiagnostics + "\n" +
               "CURRENT VaR: " + DoubleToString(currValueAtRisk, 2) + "\n" +
               "PROPOSED VaR: " + DoubleToString(proposedValueAtRisk, 2) + "\n" +
               "INCREMENTAL VaR: " + DoubleToString(incrVaR, 2) + "\n" +
               "LimitVaR: " + DoubleToString(LimitVaR, 2)+ "\n"); 

      if(proposedValueAtRisk > LimitVaR) 
         return false;
   }
   return true;
}

*/

// Create Diagnostic File inline
void DiagnosticFileInline(int DiagnosticLogLevel,int &outputFileHandle, string comment){
if(DiagnosticLogLevel >= 1){
   string outputFileName = "DEAL_DIAGNOSTIC_INFO\\deal_log_inline_"+comment+".csv";
   outputFileHandle = FileOpen(outputFileName, FILE_WRITE|FILE_CSV, "\t");
   //FileWrite(outputFileHandle, "LIST OF DEALS IS BACKTEST");   
   FileWrite(outputFileHandle, "DEAL_TICKET", "ORDER_TICKET", "DEAL_POSITION_ID", "DEAL_SYMBOL", "DEAL_TYPE", "OPEN_POSITIONS", 
                                 "DEAL_ENTRY", "DEAL_REASON", "DEAL_OPEN_TIME", "DEAL_CLOSE_TIME", "DEAL_OPEN_TIME_HOUR", "DEAL_CLOSE_TIME_HOUR", "DEAL_DURATION(HR)", "DEAL_OPEN_DAY_OF_WEEK", "DEAL_CLOSE_DAY_OF_WEEK", 
                                 "DEAL_VOLUME", "DEAL_PRICE", "DEAL_SL", "DEAL_TP", "DEAL_COMMISSION", "DEAL_SWAP", "DEAL_PROFIT", "DEAL_NET_PROFIT", "TRADE_RESULT",
                                 "DEAL_R_MULTIPLE", "DEAL_MAGIC", "DEAL_COMMENT", "POSITION_DIRECTION",
                                 "STOCHASTIC_PrevK", "STOCHASTIC_CurrK", "STOCHASTIC_PrevD", "STOCHASTIC_CurrD", "STOCHASTIC_K_Direction", "STOCHASTIC_D_Direction", "STOCHASTIC_CONSEC_OB", "STOCHASTIC_CONSEC_OS",
                                  "FAST_MA", "TRIPLE_MA_DIR", "RSI", "HHLL_DIR", "CANDLE_PATTERN", "CANDLE_PATTERN_PREV", "KAUFFMAN_ER", "ATR_DIRECTION", "ATR_vs_MA"
                                  );
   Print("OPEN Log File ", outputFileName);
   }
}

// Close data file inline
void CloseDiagnosticFileInline(int DiagnosticLogLevel,int &outputFileHandle){
   if(DiagnosticLoggingLevel >= 1)
      FileClose(outputFileHandle);   
      Print("CLOSE Log File ");
}

// Output main data to file inline
void OutputMainDataInline(int DiagnosticLogLevel, int outputFileHandle, ulong dealTicket, int SymbolLoop){
   if(DiagnosticLogLevel >= 1){

      ulong dealTicketIN   = 0;
      ulong dealTicketOUT  = 0;

      HistoryDealSelect(dealTicket);

      long  dealPositionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID); 
      string CurrentSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      int currentTrades    = PositionsTotal();      
      double tradeNetProfit = 0;
      double Rmultiple     = 0;
      string resultTrade   = "NO RESULT";
      string TradeDirection = "";

      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) TradeDirection = "LONG";
      else if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_SELL) TradeDirection = "SHORT";
      else if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT && HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) TradeDirection = "SHORT";
      else if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT && HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_SELL) TradeDirection = "LONG";

      if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN){
         dealTicketIN = dealTicket;
         dealTicketOUT = dealTicketIN;
      }
      else if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         dealTicketOUT = dealTicket;
         if(!HistorySelectByPosition(dealPositionID)) 
            Print("Failed to HistorySelectByPosition ", dealPositionID, " for symbol ", CurrentSymbol); 
         else{
            for (int i = 0; i < HistoryDealsTotal(); i++){
               if(HistoryDealGetInteger(HistoryDealGetTicket(i), DEAL_ENTRY) == DEAL_ENTRY_IN){
                  dealTicketIN = HistoryDealGetTicket(i);
                  break;
               }
            }
         }
      }

      HistoryDealSelect(dealTicketOUT);
      tradeNetProfit = HistoryDealGetDouble(dealTicketOUT, DEAL_PROFIT) +
                       HistoryDealGetDouble(dealTicketOUT, DEAL_SWAP) + 
                       (2 * HistoryDealGetDouble(dealTicketOUT, DEAL_COMMISSION));  //*2 BASED ON ENTRY AND EXIT COMMISSION MODEL 

      double exitprice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);

      HistoryDealSelect(dealTicketIN);                                   // To select the (entry) IN deal 
      double entryprice = HistoryDealGetDouble(dealTicketIN, DEAL_PRICE);
      double originalSLprice = HistoryDealGetDouble(dealTicketIN, DEAL_SL);        
      
      Rmultiple = (dealTicket - entryprice) / (entryprice - originalSLprice);
      
      long openTime = 0;
      long closeTime = 0;
      long duration = 0;
      ENUM_DAY_OF_WEEK open_day_of_week = 0;
      ENUM_DAY_OF_WEEK close_day_of_week = 0;
      MqlDateTime dealTimeOpen;
      MqlDateTime dealTimeClose;
      
      HistoryDealSelect(dealTicketIN);                                    // To select the (entry) IN deal (entry order = entry deal = position id)
      openTime = HistoryDealGetInteger(dealTicketIN, DEAL_TIME);
      TimeToStruct(openTime, dealTimeOpen);
      open_day_of_week = ENUM_DAY_OF_WEEK (dealTimeOpen.day_of_week);

      HistoryDealSelect(dealTicketOUT);                                        // To select the OUT deal again
      closeTime = HistoryDealGetInteger(dealTicketOUT, DEAL_TIME);
      duration = (closeTime - openTime) /3600;                       // Divided by 3600 to convert from seconds to hours
      TimeToStruct(closeTime, dealTimeClose);        
      close_day_of_week = ENUM_DAY_OF_WEEK (dealTimeClose.day_of_week);
      

      HistoryDealSelect(dealTicketOUT);
      if (HistoryDealGetDouble(dealTicketOUT, DEAL_PROFIT) > 0)      resultTrade = "WIN";
      else if (HistoryDealGetDouble(dealTicketOUT, DEAL_PROFIT) < 0) resultTrade = "LOSS";
      else if (HistoryDealGetDouble(dealTicketOUT, DEAL_PROFIT) == 0 && dealTicketIN != dealTicketOUT) resultTrade = "BREAK EVEN";

      HistoryDealSelect(dealTicketOUT);
      FileWrite(outputFileHandle, IntegerToString(dealTicketOUT), 
                                 IntegerToString(HistoryDealGetInteger(dealTicketOUT, DEAL_ORDER)),
                                 IntegerToString(dealPositionID),
                                 CurrentSymbol,
                                 EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicketOUT, DEAL_TYPE)),
                                 IntegerToString(currentTrades),

                                 EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicketOUT, DEAL_ENTRY)),
                                 EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicketOUT, DEAL_REASON)),
                                 TimeToString((datetime)openTime, TIME_DATE|TIME_SECONDS),
                                 TimeToString((datetime)closeTime, TIME_DATE|TIME_SECONDS),
                                 IntegerToString(dealTimeOpen.hour),
                                 IntegerToString(dealTimeClose.hour),
                                 IntegerToString(duration),
                                 EnumToString(open_day_of_week),
                                 EnumToString(close_day_of_week),

                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_VOLUME), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_PRICE), (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)),
                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_SL), (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)),
                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_TP), (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)),

                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_COMMISSION), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_SWAP), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicketOUT, DEAL_PROFIT), 2),
                                 DoubleToString(tradeNetProfit, 2),
                                 resultTrade, 

                                 DoubleToString(Rmultiple, 2),
                                 IntegerToString(HistoryDealGetInteger(dealTicketOUT, DEAL_MAGIC)),
                                 HistoryDealGetString(dealTicketOUT, DEAL_COMMENT),
                                 
                                 TradeDirection,
                                 DoubleToString(StochasticPrevK[SymbolLoop], 2),
                                 DoubleToString(StochasticCurrentK[SymbolLoop], 2),
                                 DoubleToString(StochasticPrevD[SymbolLoop], 2),
                                 DoubleToString(StochasticCurrentD[SymbolLoop], 2),
                                 StochasticK_Dir[SymbolLoop] ,
                                 StochasticD_Dir[SymbolLoop] ,
                                 ConsecutiveOB[SymbolLoop],
                                 ConsecutiveOS[SymbolLoop],

                                 FastMA_Dir[SymbolLoop],
                                 TripleMA[SymbolLoop],
                                 RSI_Direction(SymbolLoop),
                                 HHLLsequence[SymbolLoop],
                                 Candlesequence[SymbolLoop],
                                 CandlesequencePrev[SymbolLoop],
                                 DoubleToString(EfficiencyRatio[SymbolLoop], 2),
                                 AtrDirection[SymbolLoop],
                                 AtrvsMA[SymbolLoop]
                                 );
   }
}


void SetStochasticArrays(int SymbolLoop, int candle){
   StochasticCurrentK[SymbolLoop] = Stochastic_K(SymbolLoop, candle);
   StochasticCurrentD[SymbolLoop] = Stochastic_D(SymbolLoop, candle);
   StochasticPrevK[SymbolLoop] = Stochastic_K(SymbolLoop, candle + 1);
   StochasticPrevD[SymbolLoop] = Stochastic_D(SymbolLoop, candle + 1);
   
   double CurrK = StochasticCurrentK[SymbolLoop];
   double CurrD = StochasticCurrentD[SymbolLoop];
   double PrevK = StochasticPrevK[SymbolLoop];
   double PrevD = StochasticPrevD[SymbolLoop];
   string dirK = "";
   string dirD = "";

   if(PrevK < CurrK && CurrK < InpStochOS)                                                        dirK = "UP_InsideOS";
   else if(PrevK < CurrK && CurrK >= InpStochOS && CurrK < InpStochOB && PrevK < InpStochOS)      dirK = "OUT_OverSOLD";
   else if(PrevK < CurrK && CurrK < InpStochOB && PrevK >= InpStochOS)                            dirK = "UP";
   else if(PrevK < InpStochOS && CurrK >= InpStochOB)                                             dirK = "OS_to_OB";
   else if(PrevK >= InpStochOS && PrevK < InpStochOB && CurrK >= InpStochOB)                      dirK = "IN_OverBOUGHT";
   else if(PrevK < CurrK && PrevK >= InpStochOB)                                                  dirK = "UP_InsideOB";
   else if(PrevK >= CurrK && CurrK >= InpStochOB)                                                 dirK = "DOWN_InsideOB";

   else if(PrevK >= CurrK && CurrK < InpStochOB && CurrK >= InpStochOS && PrevK >= InpStochOB)    dirK = "OUT_OverBOUGHT";
   else if(PrevK >= CurrK && PrevK < InpStochOB && CurrK >= InpStochOS)                           dirK = "DOWN";
   else if(PrevK >= InpStochOB && CurrK < InpStochOS)                                             dirK = "OB_to_OS";
   else if(PrevK >= InpStochOS && PrevK < InpStochOB && CurrK < InpStochOS)                       dirK = "IN_OverSOLD";
   else if(PrevK >= CurrK && PrevK < InpStochOS)                                                  dirK = "DOWN_InsideOB";

   if(PrevD < CurrD && CurrD < InpStochOS)                                                        dirD = "UP_InsideOS";
   else if(PrevD < CurrD && CurrD >= InpStochOS && CurrD < InpStochOB && PrevD < InpStochOS)      dirD = "OUT_OverSOLD";
   else if(PrevD < CurrD && CurrD < InpStochOB && PrevD >= InpStochOS)                            dirD = "UP";
   else if(PrevD < InpStochOS && CurrD >= InpStochOB)                                             dirD = "OS_to_OB";
   else if(PrevD >= InpStochOS && PrevD < InpStochOB && CurrD >= InpStochOB)                      dirD = "IN_OverBOUGHT";
   else if(PrevD < CurrD && PrevD >= InpStochOB)                                                  dirD = "UP_InsideOB";
   else if(PrevD >= CurrD && CurrD >= InpStochOB)                                                 dirD = "DOWN_InsideOB";

   else if(PrevD >= CurrD && CurrD < InpStochOB && CurrD >= InpStochOS && PrevD >= InpStochOB)    dirD = "OUT_OverBOUGHT";
   else if(PrevD >= CurrD && PrevD < InpStochOB && CurrD >= InpStochOS)                           dirD =  "DOWN";
   else if(PrevD >= InpStochOB && CurrD < InpStochOS)                                             dirD = "OB_to_OS";
   else if(PrevD >= InpStochOS && PrevD < InpStochOB && CurrD < InpStochOS)                       dirD = "IN_OverSOLD";
   else if(PrevD >= CurrD && PrevD < InpStochOS)                                                  dirD = "DOWN_InsideOB";

   StochasticK_Dir[SymbolLoop] = dirK;
   StochasticD_Dir[SymbolLoop] = dirD;

   int countOB = 0;
   int countOS = 0;
   for (int i = candle + 1; i < 7; i++){
      if(Stochastic_K(SymbolLoop, i) > InpStochOB) countOB++;
   }
   for (int i = candle + 1; i < 7; i++){
      if(Stochastic_K(SymbolLoop, i) < InpStochOS) countOS++;
   }

   ConsecutiveOB[SymbolLoop] = countOB;
   ConsecutiveOS[SymbolLoop] = countOS;

}

void SetMAArrays(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error
   double Close         = NormalizeDouble(iClose(CurrentSymbol, TradeTimeframe,candle),SymbolDigits);

   if(GetFastMAValue(SymbolLoop, candle) > Close)
      FastMA_Dir[SymbolLoop] = "OVER_FAST_MA";
   else if (GetFastMAValue(SymbolLoop, candle) <= Close)
      FastMA_Dir[SymbolLoop] = "UNDER_FAST_MA";

   if(GetFastMAValue(SymbolLoop, candle) > GetSlowMAValue(SymbolLoop, candle) && GetSlowMAValue(SymbolLoop, candle) > GetUSlowMAValue(SymbolLoop, candle))
      TripleMA[SymbolLoop] = "LONG";
   else if(GetFastMAValue(SymbolLoop, candle) < GetSlowMAValue(SymbolLoop, candle) && GetSlowMAValue(SymbolLoop, candle) < GetUSlowMAValue(SymbolLoop, candle))
      TripleMA[SymbolLoop] = "SHORT";
   else 
      TripleMA[SymbolLoop] = "NO TREND";
}

void SetERArray(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   EfficiencyRatio[SymbolLoop] = GetERValue(SymbolLoop, candle);
}

void SetRSIArray(int SymbolLoop, int candle){
   RSIvalue[SymbolLoop] = RSI_Value(SymbolLoop, candle);
}

string RSI_Direction(int SymbolLoop){
   if (RSIvalue[SymbolLoop]      < InpRSIOS)                                return "OVERSOLD";
   else if (RSIvalue[SymbolLoop] >= InpRSIOS && RSIvalue[SymbolLoop] < 50 ) return "UNDER 50";
   else if (RSIvalue[SymbolLoop] < InpRSIOB && RSIvalue[SymbolLoop] >= 50 ) return "OVER 50";
   else if (RSIvalue[SymbolLoop] >= InpRSIOB)                               return "OVERBOUGHT";
   else return "?";
}

void SetHHLLArray(int SymbolLoop, int candle){
   HHLLsequence[SymbolLoop] = HHLL_Sequence(SymbolLoop);  
}

void SetCandleSequenceArray(int SymbolLoop, int candle){
   Candlesequence[SymbolLoop] = Candle_Sequence(SymbolLoop, candle);  
   CandlesequencePrev[SymbolLoop] = Candle_Sequence(SymbolLoop, candle + 1);  
}

void SetAtrArrays(int SymbolLoop, int candle){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   double CurrentAtr = GetAtrValue(SymbolLoop, candle);
   double PrevAtr = GetAtrValue(SymbolLoop, candle + 1);
   double sumAtr = 0;
   int bars = 10;
   
   for (int i = candle; i < candle + bars; i++){
      sumAtr += GetAtrValue(SymbolLoop, i);
   }
   double averageAtr = sumAtr / bars;

   if (CurrentAtr >= averageAtr) AtrvsMA[SymbolLoop] = "ATR_OVER_MA";
   else AtrvsMA[SymbolLoop] = "ATR_UNDER_MA";

   if (CurrentAtr >= PrevAtr) AtrDirection[SymbolLoop] = "UP";
   else AtrDirection[SymbolLoop] = "DOWN"; 
}
// Get open positions tickets
void GetOpenPositionTickets() {
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
      string CurrentSymbol = SymbolArray[SymbolLoop];
      if(PositionSelect(CurrentSymbol) == true){
         OpenTradePositionTicket[SymbolLoop] = PositionGetInteger(POSITION_TICKET);
         //Print("#### Array de posicion ", SymbolLoop, OpenTradePositionTicket[SymbolLoop]);
      }
      else OpenTradePositionTicket[SymbolLoop] = 0;
      
   }
}

