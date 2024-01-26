//+------------------------------------------------------------------+
//|                                                       AlgoA1.mq5 |
//|                                                          AC_2024 |
//|              Based on Darwinex / Trade like a machine Templates  |
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
#property description   "AlgoA1"
#property version       "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>                      // Include MQL trade object functions
CTrade   trade;                                 // Declare Trade as an object of the CTrade class in the stack  

// INPUT VARIABLES
input group "==== General Inputs ===="
input int                  InpMagicNumber  = 2000001;       // Unique identifier for this expert advisor for EA not get confused between each other
input string               InpTradeComment = __FILE__;      // Optional comment for trades
//input ENUM_APPLIED_PRICE   InpAppliedPrice = PRICE_CLOSE;   // Applied price for indicators

// RISK MODULE
#include <_Agustin\ACFunctions.mqh>
input double AtrProfitMulti    = 4.0;   // ATR Profit Multiple
input double AtrLossMulti      = 1.0;   // ATR Loss Multiple

input double puntos_entrada = 0;        // puntos de desfasaje en Entrada
input double puntos_salida  = 0;        // puntos de desfasaje en Salida

// INCLUDES
#include <Indicators/Trend.mqh>
#include <Indicators/Oscilators.mqh> 
#include <_Agustin\TimeRange.mqh>
   // Para poder usar esta función, en el EA tengo que crear las siguientes variables:
       MqlTick prevTick, lastTick;

input group "==== Bar Processing ===="
enum ENUM_BAR_PROCESSING_METHOD
{
   PROCESS_ALL_DELIVERED_TICKS,               //Process All Delivered Ticks
   ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR,        //Only Process Ticks From New M1 Bar
   ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR   //Only Process Ticks From New Bar in Trade TF
};

input ENUM_TIMEFRAMES            TradeTimeframe      = PERIOD_H1;                                 //Trading Timeframe
input ENUM_BAR_PROCESSING_METHOD BarProcessingMethod = ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR;  //EA Bar Processing Method

int      TicksReceivedCount      = 0;                    //Number of ticks received by the EA
int      TicksProcessedCount     = 0;                    //Number of ticks processed by the EA (will depend on the BarProcessingMethod being used)
datetime TimeLastTickProcessed   = D'1971.01.01 00:00';  //Used to control the processing of trades so that processing only happens at the desired intervals (to allow like-for-like back testing between the Strategy Tester and Live Trading) - Seeded with a past date before any backtesting will ever be run

int      iBarToUseForProcessing;        //This will either be bar 0 or bar 1, and depends on the BarProcessingMethod - Set in OnInit()

input group "==== Stochastic Inputs ===="
CiStochastic* Stochastic;

input int InpStochKPeriod = 14;                           // %K for the Stochastic
input int InpStochDPeriod = 3;                            // %D for the Stochastic
input int InpStochSlowing = 1;                            // Slowing for the Stochastic
input int InpStochOB = 80;
input int InpStochOS = 20;

input group "==== MA Inputs ===="
CiMA* Fast_MA;
CiMA* Slow_MA;
CiMA* USlow_MA;

input int InpFastMA          = 10;    // fast period Base
input int InpSlowMA          = 20;    // slow period Base
input int InpUSlowMA         = 50;    // ultra slow period Base

input group "==== Aroon Inputs ===="
input int InpAroonPeriod = 100;                          // period of the Aroon Indicator
input int InpAroonShift  = 0;                            // horizontal shift of the indicator in bars
input double AroonMin= 70;       // Valor de Aroon para indicar tendencia.
input double AroonMax= 100;       // Valor max de Aroon para habilitar entrada.
int Aroon_Handle;
double AroonUp_Buffer[];    
double AroonDown_Buffer[];  

input group "==== Atr Inputs ===="
input int InpAtrPeriod = 14;     // ATR Period
int Atr_Handle;
double Atr_Buffer[];
double AtrCurrent;

// input int InpPosTimer= 600;    // Minutes for Position close 

// CUSTOM METRICS
#include <_Agustin\CustomMetrics.mqh>
const string IndicatorName = "Agustin\\AC_Aroon"; // Credit to Darwinex / TradeLikeAMachine

//+------------------------------------------------------------------+
//| Other Global variables                                           |
//+------------------------------------------------------------------+

double Open[];
double High[];
double Low[];
double Close[];

int FlagAroon = 0;  // Flag de Tendencia
int FlagOB = 0;         // Flag OverBought
int FlagOS = 0;         // Flag OverSold
int FlagMA = 0;         // Flag Orden de Medias Móviles

int FlagLastTrade = 0;

datetime OpenTradeTime; // Stores the last time a trade was opened

int OnInit(){ 
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   //################################
   //Determine which bar we will used (0 or 1) to perform processing of data
   //################################
   
   if(BarProcessingMethod == PROCESS_ALL_DELIVERED_TICKS)                        //Process data every tick that is 'delivered' to the EA
      iBarToUseForProcessing = 0;                                                //The rationale here is that it is only worth processing every tick if you are actually going to use bar 0 from the trade TF, the value of which changes throughout the bar in the Trade TF                                          
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR)            //Process trades based on 'any' TF, every minute.
      iBarToUseForProcessing = 0;                                                //The rationale here is that it is only worth processing every minute if you are actually going to use bar 0 from the trade TF, the value of which changes throughout the bar in the Trade TF
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR)      //Process when a new bar appears in the TF being used. So the M15 TF is processed once every 15 minutes, the TF60 is processed once every hour etc...
      iBarToUseForProcessing = 1;                                                //The rationale here is that if you only process data when a new bar in the trade TF appears, then it is better to use the indicator data etc from the last 'completed' bar, 
                                                                                 //which will not subsequently change. (If using indicator values from bar 0 these will change throughout the evolution of bar 0) 
   Print("EA USING " + EnumToString(BarProcessingMethod) + " PROCESSING METHOD AND INDICATORS WILL USE BAR " + IntegerToString(iBarToUseForProcessing));

   //Perform immediate update to screen so that if out of hours (e.g. at the weekend), the screen will still update (this is also run in OnTick())
   if(!MQLInfoInteger(MQL_TESTER))
      OutputStatusToScreen(); 

   //## YOUR OWN CODE HERE ##
   if (!CheckInputs()) return INIT_PARAMETERS_INCORRECT; // check correct input from user
   trade.SetExpertMagicNumber(InpMagicNumber);           // set magicnumber   

   if (!InstantiateIndicators()) return (INIT_FAILED);   // instantiate indicators
   if (!SetHandles()) return INIT_FAILED;                // set handles of other indicators

   ArraySetAsSeries(AroonUp_Buffer,true);                
   ArraySetAsSeries(AroonDown_Buffer,true);
   ArraySetAsSeries(Atr_Buffer,true);
   
   ArraySetAsSeries(Open,true);
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(Close,true);

   if (_UninitReason == REASON_PARAMETERS && CountOpenPosition(InpMagicNumber) == 0) CalculateRange();                            
   DrawObjects();    // If we change timeframes, I want the objects to appear in the new timeframe

   if (OnInitCustomMetrics() != 0) return INIT_PARAMETERS_INCORRECT;
   return(INIT_SUCCEEDED);     
}

void OnDeinit(const int reason){
   if (Aroon_Handle    != INVALID_HANDLE) { IndicatorRelease(Aroon_Handle); }
   if (Atr_Handle      != INVALID_HANDLE) { IndicatorRelease(Atr_Handle); }
   
   Print("Handles released");

   delete Fast_MA;
   delete Slow_MA;
   delete USlow_MA;
   delete Stochastic;
   Print ("Free Indicators memory");
 
   // Delete objects
   ObjectsDeleteAll(NULL, "range");    // We can delete defining a prefix of the name of the objects   
 
   Comment("");
}

void OnTick(){
   // Quick check if trading is possible
   if (!IsTradeAllowed()) return;      
   // Also exit if the market may be closed
   // https://youtu.be/GejPtodJow
   if( !IsMarketOpen(_Symbol, TimeCurrent())) return;

   TicksReceivedCount++;
      
   //########################################################
   //Control EA so that we only process at required intervals (Either 'Every Tick', 'Open Prices' or 'M1 Open Prices')
   //######################################################## 
   bool ProcessThisIteration = false;     //Set to false by default and then set to true below if required
   if(BarProcessingMethod == PROCESS_ALL_DELIVERED_TICKS)
      ProcessThisIteration = true;
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR){   //Process trades from any TF, every minute.
      if(TimeLastTickProcessed != iTime(Symbol(), PERIOD_M1, 0)){
         ProcessThisIteration = true;
         TimeLastTickProcessed = iTime(Symbol(), PERIOD_M1, 0);
      }
   }     
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR){ //Process when a new bar appears in the TF being used. So the M15 TF is processed once every 15 minutes, the TF60 is processed once every hour etc...
      if(TimeLastTickProcessed != iTime(Symbol(), TradeTimeframe, 0)){       // TimeLastTickProcessed contains the last Time[0] we processed for this TF. If it's not the same as the current value, we know that we have a new bar in this TF, so need to process 
         ProcessThisIteration = true;
         TimeLastTickProcessed = iTime(Symbol(), TradeTimeframe, 0);
      }
   }
   //#############################
   //Process Trades if appropriate
   //#############################

   if(ProcessThisIteration == true)
   {
      TicksProcessedCount++;
      copy_buffers();         // Copy buffers 
      
      Fast_MA.Refresh(-1);    // Update indicator data
      Slow_MA.Refresh(-1);
      USlow_MA.Refresh(-1);
      Stochastic.Refresh(-1);

      // Get current tick
      prevTick = lastTick;
      SymbolInfoTick(_Symbol, lastTick); 

      // Close Positions if old
      // ClosePositionByTimer();

      // Close positions if out of RangeClose
      if(lastTick.time >= trange.start_time && lastTick.time < trange.end_time)
         trange.f_entry = true; // set flag (we know we had a tick in the trange)
      else trange.f_entry = false;
         
      if (InpRangeClose >= 0 && lastTick.time >= trange.close_time) {
         if(!ClosePositions()) return;
         else Print ("Close because out of trange");
      }  

      flagAroon();
      flagMA();

      ClosePositions(POSITION_TYPE_BUY);   
      ClosePositions(POSITION_TYPE_SELL);   

      // Calculate new trange if...
      if (((InpRangeClose >= 0 && lastTick.time >= trange.close_time)                     // close time reached
         || (trange.end_time == 0)                                                        // trange not calculated yet
         || (trange.end_time != 0 && lastTick.time > trange.end_time && !trange.f_entry))   // there was a trange calculated but no tick inside
         && (CountOpenPosition(InpMagicNumber) == 0))
      {
         CalculateRange();      
      }
      // DeleteOrders(ORDER_TYPE_BUY_STOP);
      // DeleteOrders(ORDER_TYPE_SELL_STOP);
      // Open position
      createorder();
      // ProcessTradeClosures();
      // ProcessTradeOpens();
      
      // Only for diagnostics purposes, no need for this in a production EA
      // Alert("PROCESSING " + Symbol() + " ON " + EnumToString(TradeTimeframe) + " CHART");

      //to display the values on the screen
      comments();
   }
   
   //############################################
   //OUTPUT INFORMATION AND METRICS TO THE SCREEN (DO NOT OUTPUT ON EVERY TICK IN PRODUCTION, FOR PERFORMANCE REASONS - DONE HERE FOR ILLUSTRATIVE PURPOSES ONLY)
   //############################################
   
   if(!MQLInfoInteger(MQL_TESTER))
      OutputStatusToScreen();

   //## YOUR OWN CODE HERE ##
   
   OnTickCustomMetrics();
}

void ProcessTradeClosures()
{
   double localBuffer[];
   ArrayResize(localBuffer, 3);
   
   //Use CopyBuffer here to copy indicator buffer to local buffer...
   
   ArraySetAsSeries(localBuffer, true);
   
   double currentIndValue  = localBuffer[iBarToUseForProcessing];
   double previousIndValue = localBuffer[iBarToUseForProcessing + 1];
}

void ProcessTradeOpens()
{
   double localBuffer[];
   ArrayResize(localBuffer, 3);
   
   //Use CopyBuffer here to copy indicator buffer to local buffer...
   
   ArraySetAsSeries(localBuffer, true);
   
   double currentIndValue  = localBuffer[iBarToUseForProcessing];
   double previousIndValue = localBuffer[iBarToUseForProcessing + 1];
}

void OutputStatusToScreen()
{      
   double offsetInHours = (TimeCurrent() - TimeGMT()) / 3600.0;
   
   string OutputText = "\n\r";
  
   OutputText += "MT5 SERVER TIME: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " (OPERATING AT UTC/GMT" + StringFormat("%+.1f", offsetInHours) + ")\n\r\n\r";
   
   OutputText += Symbol() + " TICKS RECEIVED:   " + IntegerToString(TicksReceivedCount) + "\n\r";  
   OutputText += Symbol() + " TICKS PROCESSED:   " + IntegerToString(TicksProcessedCount) + "\n\r";
   OutputText += "PROCESSING METHOD:   " + EnumToString(BarProcessingMethod) + "\n\r";
   OutputText += EnumToString(TradeTimeframe) + " BAR USED FOR PROCESSING INDICATORS / PRICE:   " + IntegerToString(iBarToUseForProcessing) + "\n\r";
   OutputText += "SYMBOL BEING TRADED:   " + Symbol() + "\n\r"; 
   OutputText += "TRADING TIMEFRAME:   " + EnumToString(TradeTimeframe) + "\n\r\n\r";
   
   Comment(OutputText);

   return;
}

// COMMENTS
void comments(){
   Comment("       Open   /   High   /   Low   /   Close\n",
           "[0]:   ", NormalizeDouble(Open[0], _Digits), "   /   ", NormalizeDouble(High[0], _Digits), "   /   ", NormalizeDouble(Low[0], _Digits), "   /   ", NormalizeDouble(Close[0], _Digits),"\n",
           "[1]:   ", NormalizeDouble(Open[1], _Digits), "   /   ", NormalizeDouble(High[1], _Digits), "   /   ", NormalizeDouble(Low[1], _Digits), "   /   ", NormalizeDouble(Close[1], _Digits),"\n",
           "[2]:   ", NormalizeDouble(Open[2], _Digits), "   /   ", NormalizeDouble(High[2], _Digits), "   /   ", NormalizeDouble(Low[2], _Digits), "   /   ", NormalizeDouble(Close[2], _Digits),"\n",
           "[3]:   ", NormalizeDouble(Open[3], _Digits), "   /   ", NormalizeDouble(High[3], _Digits), "   /   ", NormalizeDouble(Low[3], _Digits), "   /   ", NormalizeDouble(Close[3], _Digits),"\n\n",           
           "OpenOrder?       ", openorder(),"\n\n",
           "OpenPositions:   ", CountOpenPosition(InpMagicNumber), "\n",
           "%K =              ", NormalizeDouble(Stochastic.Main(1), 2), "\n",
           "%D =              ", NormalizeDouble(Stochastic.Signal(1), 2),"\n");
}

// CHECK INPUTS 
bool CheckInputs() {
   // check for correct input from user
   if (InpMagicNumber <= 0)                                                   { Alert ("Magicnumber <= 0"); return false; }
   if (InpLotMode == LOT_MODE_FIXED && (InpLots <= 0 || InpLots > 5))         { Alert ("Lots <= 0 or > 5"); return false; }
   if (InpLotMode == LOT_MODE_MONEY && (InpLots <= 0 || InpLots > 500))       { Alert ("Money <= 0 or > 500"); return false; }
   if (InpLotMode == LOT_MODE_PCT_ACCOUNT && (InpLots <= 0 || InpLots > 5))   { Alert ("Percent <= 0 or > 2"); return false; }   
   /*if ((InpLotMode == LOT_MODE_MONEY || InpLotMode == LOT_MODE_PCT_ACCOUNT) && InpStopLoss == 0){ Alert ("Selected lot mode needs a stop loss"); return false; }        
   if (InpStopLoss < 0 || InpStopLoss > 1000){ Alert ("Stop Loss <= 0 or > 1000"); eturn false; }   
   if (InpTakeProfit < 0 || InpTakeProfit > 1000){ Alert ("Take profit <= 0 or > 1000"); return false; }
   */
   if (AtrLossMulti <= 0)     { Alert("AtrLossMulti <= 0"); return false;}
   if (AtrProfitMulti <= 0)   { Alert("AtrProfitMulti <= 0");  return false;}
   
   return true;
}

// Instantiate new instance of indicators 
bool InstantiateIndicators(){
   // ### Declare and initialise indicator handle ###
   ResetLastError();
   //INSTATIATE NEW INSTANCE OF MA CLASS
   Fast_MA = new CiMA();   
   if(!Fast_MA.Create(_Symbol, TradeTimeframe, InpFastMA, 0, MODE_SMA, PRICE_CLOSE)) {
      MessageBox("Failed to create new class instance (error code: " + IntegerToString(GetLastError()) + ")");
      //Don't proceed
      return false;
   }      
   Slow_MA = new CiMA();   
   if(!Slow_MA.Create(_Symbol, TradeTimeframe, InpSlowMA, 0, MODE_SMA, PRICE_CLOSE)) {
      MessageBox("Failed to create new class instance (error code: " + IntegerToString(GetLastError()) + ")");
      //Don't proceed
      return false;
   }      
   USlow_MA = new CiMA();   
   if(!USlow_MA.Create(_Symbol, TradeTimeframe, InpUSlowMA, 0, MODE_SMA, PRICE_CLOSE)) {
      MessageBox("Failed to create new class instance (error code: " + IntegerToString(GetLastError()) + ")");
      //Don't proceed
      return false;
   }      
   Print("MA instances successfully created");
   
   Stochastic = new CiStochastic();   
   if(!Stochastic.Create(_Symbol, TradeTimeframe, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH)) {
      MessageBox("Failed to create new class instance (error code: " + IntegerToString(GetLastError()) + ")");
      //Don't proceed
      return false;
   }      
   Print("Stochastic instance successfully created");
   return true;
}

// SET HANNDLES 
bool SetHandles() {
   // set Handles only once in the OnInit function and check if function failed      
   Aroon_Handle = iCustom(Symbol(), TradeTimeframe, IndicatorName, InpAroonPeriod, InpAroonShift);
   if (Aroon_Handle == INVALID_HANDLE) { Alert("Failed to create Aroon Handle"); return false; }

   Atr_Handle = iATR(Symbol(), TradeTimeframe, InpAtrPeriod);
   if (Atr_Handle == INVALID_HANDLE) { Alert("Failed to create Atr Handle"); return false; }     

   return true;   
}   

// COPY BUFFERS 
void copy_buffers(){   

   // Set symbol string and indicator buffers
   const int StartCandle      = 0;
   const int RequiredCandles  = 5; // How many candles are required to be stored in Expert - [current confirmed, not confirmed] if StartCandle=0
   const int Index            = 0; 
   
   //Get indicator values
   int values = CopyBuffer(Aroon_Handle, 0, StartCandle, RequiredCandles, AroonUp_Buffer);  
   if (values != RequiredCandles){ Print("Not enough data for AroonUp"); return;}

   values = CopyBuffer(Aroon_Handle, 1, StartCandle, RequiredCandles, AroonDown_Buffer);  
   if (values != RequiredCandles){ Print("Not enough data for AroonDown"); return;}

   values = CopyBuffer(Atr_Handle, 0, StartCandle, RequiredCandles, Atr_Buffer);  
   if (values!= RequiredCandles){ Print("Not enough data for ATR"); return;}
   AtrCurrent = NormalizeDouble(Atr_Buffer[1], _Digits);

   values = CopyClose(_Symbol, TradeTimeframe, StartCandle, RequiredCandles, Close);
   if (values!= RequiredCandles){ Print("Not enough data for Close"); return;}
   values = CopyOpen(_Symbol, TradeTimeframe, StartCandle, RequiredCandles, Open);
   // if (values!= RequiredCandles){ Print("Not enough data for Open"); return;}   
   values = CopyHigh(_Symbol, TradeTimeframe, StartCandle, RequiredCandles, High);
   // if (values!= RequiredCandles){ Print("Not enough data for High"); return;}
   values = CopyLow(_Symbol, TradeTimeframe, StartCandle, RequiredCandles, Low);
   // if (values!= RequiredCandles){ Print("Not enough data for Low"); return;}   
}

// CHECK TENDENCIA 
int flagAroon(){
   if (AroonUp_Buffer[1] > AroonMin
      && AroonDown_Buffer[1] < AroonMin){
      FlagAroon = 1;                                     // Set Flag de tendencia alcista
   }
   if (AroonDown_Buffer[1] > AroonMin
      && AroonUp_Buffer[1] < AroonMin){
      FlagAroon = -1;                                    // Set Flag de tendencia bajista
   }   
   if (FlagAroon == 1 && (AroonUp_Buffer[1] < AroonMin || AroonDown_Buffer[1] > AroonMin)) {
      FlagAroon = 0;                                    // Reset Tendencia
      }   
   if (FlagAroon == -1 && (AroonDown_Buffer[1] < AroonMin || AroonUp_Buffer[1] > AroonMin)) {
      FlagAroon = 0;                                    // Reset Tendencia
      }         
   return FlagAroon;
}

void flagMA(){
   double Fast_MA1 = NormalizeDouble(Fast_MA.Main(1), _Digits);
   double Slow_MA1 = NormalizeDouble(Slow_MA.Main(1), _Digits);
   double USlow_MA1 = NormalizeDouble(USlow_MA.Main(1), _Digits);

   // Ordenadas Compra
   if (Fast_MA1 > Slow_MA1
      //&& slow_MA > uslow_MA
   )
      FlagMA = 1;                                    
   if (Fast_MA1 < Slow_MA1
      //&& slow_MA < uslow_MA
   )
      FlagMA = -1;                                    

   else FlagMA = 0;
}

string openorder(){
   double StochK1 = NormalizeDouble(Stochastic.Main(1), 2);
   double StochK2 = NormalizeDouble(Stochastic.Main(2), 2);
   double StochD1 = NormalizeDouble(Stochastic.Signal(1), 2);
   double StochD2 = NormalizeDouble(Stochastic.Signal(2), 2);
   
   // check BUY conditions   
   if (StochK2 < InpStochOS 
      && StochK1 > InpStochOS
      // && StochK2 < StochK1
      // && FlagAroon == 1      
      && FlagMA == 1
      // && High[1] < fast_MA
      )
      return "buy"; 
   else // check SELL conditions 
   if (StochK2 > InpStochOB
      && StochK1 < InpStochOB
      //&& StochK2 > StochK1 
      //&& FlagAroon == -1
      && FlagMA == -1
      // && Low[1] > fast_MA
      )
      return "sell"; 
   else
      return "no order";
}

// CONDICIONES CLOSE
bool closecondLONG(){
   double StochK1 = NormalizeDouble(Stochastic.Main(1), 2);
   double StochK2 = NormalizeDouble(Stochastic.Main(2), 2);
   double StochD1 = NormalizeDouble(Stochastic.Signal(1), 2);
   double StochD2 = NormalizeDouble(Stochastic.Signal(2), 2);
   if (StochK1 > InpStochOB 
      //|| StochK1 < InpStochOS
     // || (StochD2 > InpStochOS && StochD1 < InpStochOS)
      )
      return true;

   else return false;
}
bool closecondSHORT(){
   double StochK1 = NormalizeDouble(Stochastic.Main(1), 2);
   double StochK2 = NormalizeDouble(Stochastic.Main(2), 2);
   double StochD1 = NormalizeDouble(Stochastic.Signal(1), 2);
   double StochD2 = NormalizeDouble(Stochastic.Signal(2), 2);
   if (StochK1 < InpStochOS
      //|| StochK1 > InpStochOB
     // || (StochD2 < InpStochOB && StochD1 > InpStochOB)
      )
      return true;

   else return false;
}

// CREATE ORDERS
void createorder(){
   // Check general conditions
   if (IsNewOrderAllowed() && CountOpenPosition(InpMagicNumber) == 0 && trange.f_entry == true){ //  // && CountOpenOrders(InpMagicNumber) == 0) { // && ER_Buffer[1] >= InpERlimit     
         int digits    = _Digits;
         string symbol = _Symbol;
         double sldistance = NormalizeDouble(AtrCurrent * AtrLossMulti, digits);   
         double tpdistance = NormalizeDouble(AtrCurrent * AtrProfitMulti, digits);   

         // check BUY conditions   
         if (openorder() == "buy" 
            //&& FlagLastTrade != 1
            ){
            double price  = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            double sl    = NormalizeDouble(price - sldistance, digits); //  - puntos_salida*_Point, digits);
            // sldistance   = NormalizeDouble(MathAbs(price - sl), digits);
            double tp    = NormalizeDouble(price + tpdistance, digits); //- puntos_salida*_Point, digits);

            double mylots = CalculateLots(Symbol(), sldistance);
            if (mylots == 0) return;

            if (!Checkstoplevels(sldistance, sldistance * AtrProfitMulti - puntos_salida*_Point)) return;                                             
            if (!CheckMoneyForTrade(symbol, mylots, ORDER_TYPE_BUY)) return;
            
            double ask = lastTick.ask;           
            trade.Buy(mylots, symbol, 0, sl, tp, "BUY Market");
            //trade.BuyStop(mylots, price, symbol, sl, tp, ORDER_TIME_GTC, 0, "Orden BUY Stop");
            /*PrintFormat("BUY_STOP ORDER - price = %f, sl = %f, tp = %f, AroonUp = %f, AroonDown = %f",
                     price, sl, tp, AroonUp_Buffer[1], AroonDown_Buffer[1]);
            */
            OpenTradeTime = iTime(_Symbol, TradeTimeframe, 0);
            FlagLastTrade = 1;
         } else
         
         // check SELL conditions
         if (openorder() == "sell"
            //&& FlagLastTrade != -1
            ){
            double price  = SymbolInfoDouble(_Symbol,SYMBOL_BID);            
            double sl    = NormalizeDouble(price + sldistance, digits); // + puntos_salida*_Point, digits);
            // sldistance   = NormalizeDouble(MathAbs(price - sl), digits);
            double tp    = NormalizeDouble(price - tpdistance, digits); // + puntos_salida*_Point,digits);

            double mylots = CalculateLots(Symbol(), sldistance);
            if (mylots == 0) return;

            if (!Checkstoplevels(sldistance, tpdistance)) return;                                             
            if (!CheckMoneyForTrade(symbol, mylots, ORDER_TYPE_SELL)) return;         
            double bid = lastTick.bid;            
            trade.Sell(mylots, symbol, 0, sl, tp, "SELL Market");
            //trade.SellStop(mylots, price, symbol, sl, tp, ORDER_TIME_GTC, 0, "Orden SELL Stop");
            /*PrintFormat("BUY_STOP ORDER - price = %f, sl = %f, tp = %f, AroonUp = %f, AroonDown = %f",
                     price, sl, tp, AroonUp_Buffer[1], AroonDown_Buffer[1]);
            */  
            OpenTradeTime = iTime(_Symbol, TradeTimeframe, 0);
            FlagLastTrade = -1;
         }
      
   }
}

// CLOSE POSITIONS
bool ClosePositions() // ENUM_POSITION_TYPE positiontype
{
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)      // Important to count down to close positions. Counting up can lead to leave positions open
   {
      if( total != PositionsTotal()) { total = PositionsTotal(); i = total; continue; }     // Check that during the loop no new positions were opened (by another EA for example)
      ulong ticket = PositionGetTicket(i);   // Select position
      if (GetPosTicket(i, ticket, InpMagicNumber)){
         trade.PositionClose(ticket);
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
         {
            Print ("ERROR_ac: Failed to close position. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
            return false;     
         }        
      }      
   }
   return true;
}
/////////////////////////////////////////////////
bool ClosePositions(ENUM_POSITION_TYPE positiontype) // ENUM_POSITION_TYPE positiontype
{
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)      // Important to count down to close positions. Counting up can lead to leave positions open
   {
      if( total != PositionsTotal()) { total = PositionsTotal(); i = total; continue; }     // Check that during the loop no new positions were opened (by another EA for example)
      ulong ticket = PositionGetTicket(i);   // Select position
      if (GetPosTicket(i, ticket, InpMagicNumber) ){           
            if (PositionGetInteger(POSITION_TYPE) == positiontype && positiontype == POSITION_TYPE_BUY){
               if (closecondLONG() == true){ 
                  trade.PositionClose(ticket);
                  if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
                  {
                     Print ("ERROR_ac: Failed to close position. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
                     return false;     
                  }
                  Print ("Close position in profit with Aroon < 70");
               }  
            }

            if (PositionGetInteger(POSITION_TYPE) == positiontype && positiontype == POSITION_TYPE_SELL){
               if (closecondSHORT() == true){ 
                  trade.PositionClose(ticket);
                  if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
                  {
                     Print ("ERROR_ac: Failed to close position. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
                     return false;     
                  }
                  Print ("Close position in profit with Aroon < 70");               
               }
            }
      }
      
   }
   return true;
}

// DELETE ORDERS    
bool DeleteOrders()
{
   int total = OrdersTotal();
   for (int i = total - 1; i >= 0; i--)      // Important to count down to close positions. Counting up can lead to leave positions open
   {
      if( total != OrdersTotal()) { total = OrdersTotal(); i = total; continue; }     // Check that during the loop no new positions were opened (by another EA for example)
      ulong ticket = OrderGetTicket(i);   // Select position
      if (GetOrTicket(i, ticket, InpMagicNumber)){
         trade.OrderDelete(ticket);
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
         {
            Print ("ERROR_ac: Failed to delete order. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
            return false;     
         }
      }
      
   }
   return true;
}
////////////////////////////////////////////
bool DeleteOrders(ENUM_ORDER_TYPE ordertype)
{
   int total = OrdersTotal();
   for (int i = total - 1; i >= 0; i--)      // Important to count down to close positions. Counting up can lead to leave positions open
   {
      if( total != OrdersTotal()) { total = OrdersTotal(); i = total; continue; }     // Check that during the loop no new positions were opened (by another EA for example)
      ulong ticket = OrderGetTicket(i);   // Select position
      if (GetOrTicket(i, ticket, InpMagicNumber)){
         if (OrderGetInteger(ORDER_TYPE) == ordertype && ordertype== ORDER_TYPE_BUY_STOP){
            if (AroonUp_Buffer[1] <= AroonMin || AroonDown_Buffer[1] > AroonMin){ 
               trade.OrderDelete(ticket);
               if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
               {
                  Print ("ERROR_ac: Failed to delete order. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
                  return false;     
               }
            }
         }
         if (OrderGetInteger(ORDER_TYPE) == ordertype && ordertype== ORDER_TYPE_SELL_STOP){
            if (AroonDown_Buffer[1] <= AroonMin|| AroonUp_Buffer[1] > AroonMin){ 
               trade.OrderDelete(ticket);
               if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
               {
                  Print ("ERROR_ac: Failed to delete order. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
                  return false;     
               }
            }
         }
      }      
   }
   return true;
}

// Position TIMER 
//Llamo a la funcion que cierra ordenes pendientes segun la hora
// Hay que pulir el cálculo de días para cuando agarra un fin de semana
/*void ClosePositionByTimer()   
{
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)      // Important to count down to close positions. Counting up can lead to leave positions open
   {
      if( total != PositionsTotal()) { total = PositionsTotal(); i = total; continue; }     // Check that during the loop no new positions were opened (by another EA for example)
      ulong ticket = PositionGetTicket(i);   // Select position
      if (GetPosTicket(i, ticket, InpMagicNumber)){
         //pido la fecha y hora de apertura
         datetime PositionOpenTime = (datetime) PositionGetInteger(POSITION_TIME);
         //creo estructura
         MqlDateTime MyOpenTime;   
         //Convierto la hora de apertura a esta esctructura
         TimeToStruct(PositionOpenTime, MyOpenTime);
         int OpenMinutes = MyOpenTime.day * 24 * 60 + MyOpenTime.hour * 60 + MyOpenTime.min;
         
         //pido la hora local
         datetime LocalTime = TimeLocal();
         //Creo estructura
         MqlDateTime MyLocalTime;
         //Convierto la hora local a esta esctructura
         TimeToStruct(LocalTime, MyLocalTime);
         //pido la hora y minutos local 
         int CurrentMinutes = MyLocalTime.day *24 * 60+ MyLocalTime.hour * 60 + MyLocalTime.min;
         
         //Ahora puedo calcular la diferencia de enteros.
         int Difference = CurrentMinutes - OpenMinutes;
      
               
         //Print ("### OrderTicket: ", ticket);
         //Print ("### OrderOpenTime: ",OrderOpenTime);
         //Print ("### LocalTime: ",LocalTime);
         //Print ("### Difference: ",Difference);
         
               
         if (MathAbs(Difference) >= InpPosTimer) {
            trade.PositionClose(ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)   // To check the result of the operation, to make sure we closed the position correctly
            {
               Print ("ERROR_ac: Failed to delete order by time. Result " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
               return;     
            }
            Print ("### Cierro orden por expiracion de tiempo: ", ticket);
         }
      }
   }
   return;         
}     
*/
