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

//+------------------------------------------------------------------+
//| Expert Setup                                                     |
//+------------------------------------------------------------------+
//Libraries and Setup
#include  <Trade\Trade.mqh>             // Include MQL trade object functions
CTrade    Trade;                        // Declare Trade as pointer to CTrade class            

input group "==== General Inputs ===="
input int     MagicNumber   = 2000001;  // Unique identifier for this expert advisor for EA not get confused between each other
input string  TradeComment  = __FILE__; // Optional comment for trades
input bool CommentsOnScreen = false;    // Print comments on screen

//Multi-Symbol EA Variables
enum   MULTISYMBOL {Current, All, Selected_Symbols}; 
input  MULTISYMBOL InputMultiSymbol   = Current;
input string       TradeSymbols       = "AUDUSD|EURUSD|GBPUSD|USDCAD|USDCHF|USDJPY";   // Selected Symbols 
string             AllTradableSymbols = "AUDUSD|EURUSD|GBPUSD|USDCAD|USDCHF|USDJPY|AUDCAD|AUDCHF|AUDJPY|AUDNZD|CADCHF|CADJPY|CHFJPY|EURAUD|EURCAD|EURCHF|EURGBP|EURJPY|EURNZD|GBPAUD|GBPCAD|GBPCHF|GBPJPY|GBPNZD|NZDCAD|NZDCHF|NZDJPY|NZDUSD";
int                NumberOfTradeableSymbols;
string             SymbolArray[];

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

// TAKE INTO ACCOUNT
// The following issues do not apply in Live Trading since you are always receiving every Tick

// If I choose Processing Method = All Ticks, in the Backtester I have to select Modelling with Ticks
// If I choose Processing Method = New_M1_BAr, in the Backtester I have to select Modelling with Ticks or M1 OHLC (because I need to receive at least 1 tick every minute)
// If I choose Processing Method = New_Trade_TF_Bar in the Backtester I have to select a TF lower than that.     If Modelling TF is equal to "Trading Timeframe", errors occur and you miss trades.
//    Since I loop when a tick from the CURRENT Symbol arrives (ex. EURUSD), it may happen that the tick for the change of candle (ex. 10am) of another symbol (Ex. GBPUSD) hasn't arrived yet.
//    In that case I will only receive the tick of 10am of GBPUSD when the 11am tick of EURUSD arrives.
//    So if I use a lower timeframe in the tester, I get time for all symbols to "catch up"   

// RISK MODULE
#include "ACFunctions.mqh"
input double AtrProfitMulti    = 4.0;   // ATR Profit Multiple
input double AtrLossMulti      = 1.0;   // ATR Loss Multiple

// INCLUDES
//#include "TimeRange.mqh"
   // Para poder usar esta función, en el EA tengo que crear las siguientes variables:
   // MqlTick prevTick, lastTick;


// Indicator 1 Variables
input group "==== Stochastic Inputs ===="
string    IndicatorSignal1;
int       StochHandle[];
input int InpKPeriod = 14;           // %K for the Stochastic
input int InpDPeriod = 3;            // %D for the Stochastic
input int InpSlowing = 1;            // Slowing for the Stochastic
input int InpStochOB = 80;
input int InpStochOS = 20;

// Indicator 2 Variables
input group "==== MA Inputs ===="
string    IndicatorSignal2;
int fast_MA_Handle[];
int slow_MA_Handle[];
int uslow_MA_Handle[];
input int InpFastMA  = 10;    // fast period Base
input int InpSlowMA  = 20;    // slow period Base
input int InpUSlowMA = 50;    // ultra slow period Base

// Indicator 3 Variables
input group "==== ATR Inputs ===="
int       AtrHandle[];
input int InpAtrPeriod = 14;     // ATR Period

// OPEN TRADE ARRAYS
ulong    OpenTradeOrderTicket[];    //To store 'order' ticket for trades (1 cell per symbol. They are 0 unless there is an open Trade)
////////Place additional trade arrays here as required to assist with open trade management

//Expert Core Arrays
string SymbolMetrics[];

//Expert Variables
string ExpertComments = "";
string CloseSignalStatus = "";

// CUSTOM METRICS
#include "CustomMetrics.mqh"

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
      if(InputMultiSymbol == All) 
         TradeSymbolsToUse = AllTradableSymbols;
      else 
         TradeSymbolsToUse = TradeSymbols;
      
      //Convert TradeSymbolsToUse to the String array SymbolArray
      NumberOfTradeableSymbols = StringSplit(TradeSymbolsToUse, '|', SymbolArray);
      Print("EA will process ", NumberOfTradeableSymbols, " Symbols: ", TradeSymbolsToUse);
   }
      
   //Determine which bar we will used (0 or 1) to perform processing of data
   if(BarProcessingMethod == PROCESS_ALL_DELIVERED_TICKS)                   //Process data every tick that is 'delivered' to the EA
      iBarForProcessing = 0;                                                //The rationale here is that it is only worth processing every tick if you are actually going to use bar 0 from the trade TF, the value of which changes throughout the bar in the Trade TF                                          //The rationale here is that we want to use values that are right up to date - otherwise it is pointless doing this every 10 seconds   
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR)       //Process trades based on 'any' TF, every minute.
      iBarForProcessing = 0;                                                //The rationale here is that it is only worth processing every minute if you are actually going to use bar 0 from the trade TF, the value of which changes throughout the bar in the Trade TF      
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR) //Process when a new bar appears in the TF being used. So the M15 TF is processed once every 15 minutes, the TF60 is processed once every hour etc...
      iBarForProcessing = 1;                                                //The rationale here is that if you only process data when a new bar in the trade TF appears, then it is better to use the indicator data etc from the last 'completed' bar, which will not subsequently change. (If using indicator values from bar 0 these will change throughout the evolution of bar 0) 
   Print("EA using " + EnumToString(BarProcessingMethod) + " processing method and indicators will use bar " + IntegerToString(iBarForProcessing));

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

   //Set Up Multi-Symbol Handles for Indicators
   if (!SetUpIndicatorHandles()) return(INIT_FAILED);
   
   if (OnInitCustomMetrics() != 0) return INIT_PARAMETERS_INCORRECT;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   //Release Indicator Arrays
   ReleaseIndicatorHandles();
   Comment("");
}

void OnTick(){
   // Quick check if trading is possible
   if (!IsTradeAllowed()) return;      

   //Declare comment variables
   ExpertComments="";
   TicksReceived++;
  
   //Run multi-symbol loop   
   for(int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {      
      //Store Current Symbol
      string CurrentSymbol = SymbolArray[SymbolLoop];
      // Exit if the market may be closed // https://youtu.be/GejPtodJow
      if( !IsMarketOpen(CurrentSymbol, TimeCurrent())) return;
      
      //###############################################################
      //Control EA so that we only process trades at required intervals (Either 'Every Tick', 'TF Open Prices' or 'M1 Open Prices')
      //###############################################################      
      bool ProcessThisIteration = false;     //Set to false by default and then set to true below if required
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

      // Process Trades if appropriate
      if(ProcessThisIteration == true){
         TicksProcessed[SymbolLoop]++; 
         // Indicator 1 - Trigger
         IndicatorSignal1  = Stochastic_SignalOpen(SymbolLoop);     
         // Indicator 2 - Filter
         IndicatorSignal2  = MA_SignalOpen(SymbolLoop);  

         // Reset OpenTradeOrderTicket values to account for SL and TP executions
         ResetOpenTrades();

         // Close Signal
         CloseSignalStatus = Stochastic_SignalClose(SymbolLoop);
         // Close Trades
         if ((CloseSignalStatus == "Close_Long" || CloseSignalStatus == "Close_Short") && OpenTradeOrderTicket[SymbolLoop] != 0)
            ProcessTradeClose(SymbolLoop, CloseSignalStatus);

         //Enter Trades
         if (OpenTradeOrderTicket[SymbolLoop] == 0){
            if(IndicatorSignal1 == "Long" && IndicatorSignal2 == "Long")
               ProcessTradeOpen(CurrentSymbol, SymbolLoop, ORDER_TYPE_BUY);
            else if(IndicatorSignal1 == "Short" && IndicatorSignal2 == "Short")
               ProcessTradeOpen(CurrentSymbol, SymbolLoop, ORDER_TYPE_SELL);
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

   OnTickCustomMetrics();         
}

//+------------------------------------------------------------------+
//| Expert custom functions                                          |
//+------------------------------------------------------------------+
// Resize Core Arrays for multi-symbol EA
void ResizeCoreArrays(){
   ArrayResize(OpenTradeOrderTicket,  NumberOfTradeableSymbols);
   ArrayResize(SymbolMetrics,         NumberOfTradeableSymbols);
   ArrayResize(TicksProcessed,        NumberOfTradeableSymbols); 
   ArrayResize(TimeLastTickProcessed, NumberOfTradeableSymbols);
}

// Resize Indicator for multi-symbol EA
void ResizeIndicatorArrays(){
   //Indicator Handle Arrays
   ArrayResize(StochHandle, NumberOfTradeableSymbols);  
   ArrayResize(fast_MA_Handle, NumberOfTradeableSymbols);   
   ArrayResize(slow_MA_Handle, NumberOfTradeableSymbols);   
   ArrayResize(uslow_MA_Handle, NumberOfTradeableSymbols);   
   ArrayResize(AtrHandle, NumberOfTradeableSymbols);      
}

// Release indicator handles from Metatrader cache for multi-symbol EA
void ReleaseIndicatorHandles(){
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      IndicatorRelease(StochHandle[SymbolLoop]);
      IndicatorRelease(fast_MA_Handle[SymbolLoop]);
      IndicatorRelease(slow_MA_Handle[SymbolLoop]);
      IndicatorRelease(uslow_MA_Handle[SymbolLoop]);
      IndicatorRelease(AtrHandle[SymbolLoop]);
   }
   Print("Handle released for all symbols");   
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
      fast_MA_Handle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],TradeTimeframe,InpFastMA,0,MODE_SMA,PRICE_CLOSE); 
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
      slow_MA_Handle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],TradeTimeframe,InpSlowMA,0,MODE_SMA,PRICE_CLOSE); 
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
      uslow_MA_Handle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],TradeTimeframe,InpFastMA,0,MODE_SMA,PRICE_CLOSE); 
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
   return true;
}
 
// Get Stochastic Open Signals
string Stochastic_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 3; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
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
   double    CurrentK = NormalizeDouble(BufferK[iBarForProcessing], SymbolDigits);
   double    CurrentD = NormalizeDouble(BufferD[iBarForProcessing], SymbolDigits);
   double    PriorK   = NormalizeDouble(BufferK[iBarForProcessing + 1], SymbolDigits);
   double    PriorD   = NormalizeDouble(BufferD[iBarForProcessing + 1], SymbolDigits);

   //Return Stochastic Long and Short Signal
   if(PriorK < InpStochOS && CurrentK > InpStochOS)
      return   "Long";
   else if (PriorK > InpStochOB && CurrentK < InpStochOB)
      return   "Short";
   else
      return   "No Trade";   
}

// Get Stochastic Open Signals
string Stochastic_SignalClose(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol and indicator buffers
   int    StartCandle     = 0;
   int    RequiredCandles = 3; // How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
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
   double    CurrentK = NormalizeDouble(BufferK[iBarForProcessing], SymbolDigits);
   double    CurrentD = NormalizeDouble(BufferD[iBarForProcessing], SymbolDigits);
   double    PriorK   = NormalizeDouble(BufferK[iBarForProcessing + 1], SymbolDigits);
   double    PriorD   = NormalizeDouble(BufferD[iBarForProcessing + 1], SymbolDigits);

   //Return Stochastic Long and Short Signal
   if(CurrentK > InpStochOB)
      return   "Close_Long";
   else if (CurrentK < InpStochOS)
      return   "Close_Short";
   else
      return   "No_Close_Signal";   
}

// Get MA Signals
string MA_SignalOpen(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
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

   //Get last confirmed candle price. NOTE:Use last value as this is when the candle is confirmed. Ask/bid gives some errors.
   //double CurrentClose = NormalizeDouble(iClose(CurrentSymbol, TradeTimeframe,iBarForProcessing), SymbolDigits);

   //Submit MA Long and Short Trades
   if(CurrentFastMA > CurrentSlowMA)
      return("Long");
   else if (CurrentFastMA < CurrentSlowMA)
      return("Short");
   else
      return("No Trade");
}

// Get ATR Values
double GetAtrValue(int SymbolLoop){
   string CurrentSymbol = SymbolArray[SymbolLoop];
   int    SymbolDigits  = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error

   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int Index           = 0; //ATR Line
   double    BufferAtr[];         //Capture 2 candles for ATR [0,1]

   //Populate buffers for ATR
   bool FillAtr   = tlamCopyBuffer(AtrHandle[SymbolLoop], Index, StartCandle, RequiredCandles, BufferAtr, CurrentSymbol, "ATR");
   if(FillAtr == false) return false;

   //Find required ATR value
   double CurrentAtr = NormalizeDouble(BufferAtr[iBarForProcessing], SymbolDigits);

   return CurrentAtr;
}

// Reset values OpenTradeOrderTicket array to account for SL and TP executions
void ResetOpenTrades() {
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
      string CurrentSymbol    = SymbolArray[SymbolLoop];
      ulong  position_ticket  = OpenTradeOrderTicket[SymbolLoop];
      if (OpenTradeOrderTicket[SymbolLoop] != 0 && !PositionSelectByTicket(position_ticket)) { 
         Print (CurrentSymbol, " - ",  position_ticket, " Ticket not found. SL or TP executed. Reset OpenTrade Array");
         OpenTradeOrderTicket[SymbolLoop] = 0; 
      }
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
     
      double CurrentAtr     = GetAtrValue(SymbolLoop);
      double StopLossSize   = NormalizeDouble(CurrentAtr * AtrLossMulti, SymbolDigits); 
      double TakeProfitSize = NormalizeDouble(CurrentAtr * AtrProfitMulti, SymbolDigits);

      double Price           = 0;
      double StopLossPrice   = 0;
      double TakeProfitPrice = 0;

      double LotSize = CalculateLots(CurrentSymbol, StopLossSize);
      if (LotSize == 0) return false;

      //Open buy or sell orders
      if (OrderType == ORDER_TYPE_BUY) {
         Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), SymbolDigits);
         StopLossPrice   = NormalizeDouble(Price - StopLossSize, SymbolDigits);
         TakeProfitPrice = NormalizeDouble(Price + TakeProfitSize, SymbolDigits);
      } 
      else if (OrderType == ORDER_TYPE_SELL) {
         Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), SymbolDigits);
         StopLossPrice   = NormalizeDouble(Price + StopLossSize, SymbolDigits);
         TakeProfitPrice = NormalizeDouble(Price - TakeProfitSize, SymbolDigits);
      }
      bool success = Trade.PositionOpen(CurrentSymbol, OrderType, LotSize, Price, StopLossPrice, TakeProfitPrice, __FILE__);
      //--- if the result fails - try to find out why 

      if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we closed the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to open position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
   }
      // Set OpenTradeOrderTicket to prevent future trades being opened until this is closed
      OpenTradeOrderTicket[SymbolLoop] = Trade.ResultDeal();   
      /*// Print Array status
      string Output = "";
      for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
         Output += SymbolArray[SymbolLoop] + " - T: " + (string) OpenTradeOrderTicket[SymbolLoop] + " / ";
      }      
      Print(Output);
      */

      // Print successful
      Print("Trade Processed For ", CurrentSymbol," OrderType ", OrderType, " Lot Size ", LotSize);
   }  
   return(true);
}

bool ProcessTradeClose(int SymbolLoop, string CloseDirection) {
   ResetLastError();

   string CurrentSymbol    = SymbolArray[SymbolLoop];
   ulong  position_ticket  = OpenTradeOrderTicket[SymbolLoop];

   // INCLUDE PRE-CLOSURE CHECKS HERE
   // Print ("Position ticket to close: ", position_ticket, " - ", CurrentSymbol);
   if (!PositionSelectByTicket(position_ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to select position by ticket for ticket ", position_ticket, " - ", CurrentSymbol); return false; } 
   long magicnumber = 0;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber != MagicNumber) return false;

   //SETUP CTrade tradeObject HERE

   if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && CloseDirection == "Close_Long"){
      Trade.PositionClose(position_ticket);
   }
   else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && CloseDirection == "Close_Short"){
      Trade.PositionClose(position_ticket);
   }
   else return false;

   //CHECK FOR ERRORS AND HANDLE EXCEPTIONS HERE
   if (Trade.ResultRetcode() != TRADE_RETCODE_DONE){   // To check the result of the operation, to make sure we closed the position correctly
      Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()),". Failed to close position. Result " + (string)Trade.ResultRetcode() + ":" + Trade.ResultRetcodeDescription());
      return false;     
   }

   // Set OpenTradeOrderTicket to 0 to allow future tradesto be opened
   OpenTradeOrderTicket[SymbolLoop] = 0;
   /*// Print Array status
   string Output = "";
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++) {
      Output += SymbolArray[SymbolLoop] + " - T: " + (string) OpenTradeOrderTicket[SymbolLoop] + " / ";
   }      
   Print(Output);
   */

   Print (CloseDirection, " successful");
   return true;
}

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

   if (InpKPeriod <= 0)       { Alert("Stochastic %K <= 0"); return false;}
   if (InpDPeriod <= 0)       { Alert("Stochastic %D <= 0"); return false;}
   if (InpSlowing <= 0)       { Alert("Stochastic %K Slowing factor <= 0"); return false;}
   if (InpStochOB <= 0 || InpStochOB >= 100) { Alert("Stochastic OverBought out of range"); return false;}
   if (InpStochOS <= 0 || InpStochOS >= 100) { Alert("Stochastic OverSold out of range"); return false;}

   if (InpFastMA <= 0)         { Alert("Fast MA <= 0"); return false;}
   if (InpSlowMA <= 0)         { Alert("Slow MA <= 0"); return false;}
   if (InpUSlowMA <= 0)        { Alert("Ultra Slow MA <= 0"); return false;}

   return true;
}
