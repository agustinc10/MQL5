//+------------------------------------------------------------------+
//|                                                CustomMetrics.mqh |
//|                                                          AC_2024 |
//|                                Based on Darwinex / Tlam Template |
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

// Files generated during the Strategy Tester are saved in
// MetaQuotes/Tester/(number - hash of installation)/Agent/MQL5/Files/

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+

#include <StdLibErr.mqh>
#include <Math\Stat\Stat.mqh>          // Required for MathStandardDeviation() and MathCorrelationPearson()
#include <_Agustin\LogFile_functions.mqh>        // Required to generate the Deal Log File
//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+
/*
input group "==== Risk Mode ===="
enum LOT_MODE_ENUM {
   LOT_MODE_FIXED,                     // fixed lots
   LOT_MODE_MONEY,                     // lots based on money
   LOT_MODE_PCT_ACCOUNT                // lots based on % of account   
};
input LOT_MODE_ENUM InpLotMode = LOT_MODE_FIXED; // lot mode
input double        InpLots    = 0.10;           // lots / money / percent
*/

enum ENUM_CUSTOM_PERF_CRITERIUM_METHOD
{
   NO_CUSTOM_METRIC,                            // No Custom Metric
   STANDARD_PROFIT_FACTOR,                      // Standard Profit Factor
   MODIFIED_PROFIT_FACTOR,                      // Modified Profit Factor
   CAGR_OVER_MEAN_DD,                           // CAGR/MeanDD
   COEFF_CORRELATION_R                          // Coefficient of Correlation (r)
};

input group "==== Optimization Mode ===="
input ENUM_CUSTOM_PERF_CRITERIUM_METHOD   CustomPerfCriterium    = COEFF_CORRELATION_R;      //Custom Performance Criterium
input int                                 minTradesToConsider    = 250;                      //Min Trades to consider results

//Globals
int      PreviousHourlyTasksRun  = -1;          // Set to -1 so that hourly tasks run immediately
double   EquityHistoryArray[];                  // Used to store equity at intermittent time intervals when using the Strategy Tester in order to calculate CAGR/MeanDD perf metric
double   StartingEquity;                        // Stores the Starting Equity (i.e. the deposit amount at the beginning of the backtest)
datetime BackTestFirstDate;                     // Used in the CAGR/MeanDD Calc
datetime BackTestFinalDate;                     // Used in the CAGR/MeanDD Calc

int OnInitCustomMetrics(){
   //## YOUR OWN CODE HERE ##

   //THE FOLLOWING CODE SEGMENT IS SUPPLIED AS AN ILLUSTRATION OF HOW AN INITIAL SANITY CHECK CAN BE PERFORMED TO ENSURE THAT YOUR 
   //CHOSEN POSITION SIZING METHOD IS PROPERLY ALIGNED TO THE CHOSEN PERFORMANCE METRIC
   if(MQLInfoInteger(MQL_TESTER)){
      if(InpLotMode == LOT_MODE_PCT_ACCOUNT && CustomPerfCriterium == STANDARD_PROFIT_FACTOR){
         Print("ERROR: Attempted to test EA in Strategy Tester using a RELATIVE_LOT_SIZE, not compatible with STANDARD_PROFIT_FACTOR (Trades when equity is high have a disproportionate effect on the Profit Factor calculation than trades taken when equity is low)");
         return(INIT_PARAMETERS_INCORRECT);
      }
      else if((InpLotMode == LOT_MODE_FIXED || InpLotMode == LOT_MODE_MONEY) && CustomPerfCriterium == CAGR_OVER_MEAN_DD){
         Print("ERROR: Attempted to test EA in Strategy Tester using " + EnumToString((LOT_MODE_ENUM)InpLotMode) + ", not compatible with CAGR_OVER_MEAN_DD (The CAGR/MeanDD calculation requires position sizing relative to equity, in order to produce proportional drawdowns throughout the entire backtest)");
         return(INIT_PARAMETERS_INCORRECT);                                        
      }
   }
   
   //SET UP EQUITY HISTORY ARRAY AND FIRST DATE - USED TO CALCULATE CAGR/MeanDD
   if(MQLInfoInteger(MQL_TESTER)){
      BackTestFirstDate = TimeCurrent();
      ArrayResize(EquityHistoryArray, 1);    
      EquityHistoryArray[0] = AccountInfoDouble(ACCOUNT_EQUITY); 
      StartingEquity = EquityHistoryArray[0];
   }   
   return 0;
}

void OnTickCustomMetrics(){
   if(MQLInfoInteger(MQL_TESTER)){ //Only run in live account
      MqlDateTime currentDateTime;
      TimeCurrent(currentDateTime);
      
      if(currentDateTime.hour != PreviousHourlyTasksRun){
         int currentArraySize = ArraySize(EquityHistoryArray);
         ArrayResize(EquityHistoryArray, currentArraySize + 1);  
         EquityHistoryArray[currentArraySize] = AccountInfoDouble(ACCOUNT_EQUITY);
      }
      
      PreviousHourlyTasksRun = currentDateTime.hour;
   }
}

double OnTester(){
   double customPerformanceMetric;  
   
   if(CustomPerfCriterium == STANDARD_PROFIT_FACTOR){
      customPerformanceMetric = TesterStatistics(STAT_PROFIT_FACTOR);
   }
   else if(CustomPerfCriterium == MODIFIED_PROFIT_FACTOR){
      int numTrades = ModifiedProfitFactor(customPerformanceMetric);
      
      //IF NUMBER OF TRADES < minTradesToConsider THEN NO STATISTICAL SIGNIFICANCE, SO DISREGARD RESULTS (PROBABLE THAT GOOD 
      //RESULTS CAUSED BY RANDOM CHANCE / LUCK, THAT WOULD NOT BE REPEATABLE IN FUTURE PERFORMANCE).
      //IF THE TRADING SYSTEM USUALLY GENERATES A NUMBER OF TRADES GREATLY IN EXCESS OF THIS THEN ADVISABLE TO INCREASE THIS THRESHOLD VALUE
      if(numTrades < minTradesToConsider)
         customPerformanceMetric = 0.0;
   } 
   else if(CustomPerfCriterium == CAGR_OVER_MEAN_DD){
      int numTrades = CagrOverMeanDD(customPerformanceMetric);
      if(numTrades < minTradesToConsider)
         customPerformanceMetric = 0.0;
   }
   else if(CustomPerfCriterium == COEFF_CORRELATION_R){
      int numTrades = CoeffCorrelation(customPerformanceMetric);
      if(numTrades < minTradesToConsider)
         customPerformanceMetric = 0.0;
   }
   else if(CustomPerfCriterium == NO_CUSTOM_METRIC){
      customPerformanceMetric = 0.0;
   }
   else{
      Print("Error: Custom Performance Criterium requested (", EnumToString(CustomPerfCriterium), ") not implemented in OnTester()");
      customPerformanceMetric = 0.0;
   }
   
   Print("Custom Perfromance Metric = ", DoubleToString(customPerformanceMetric, 3));
   
   return customPerformanceMetric;
}

int CagrOverMeanDD(double& CAGRoverAvgDD){
   HistorySelect(0, TimeCurrent());   
   int numTrades = 0;
   int numDeals = HistoryDealsTotal();  

   // Create Diagnostic File
   int outputFileHandle = INVALID_HANDLE;
   //if(DiagnosticLoggingLevel >= 1) 
      DiagnosticFile(DiagnosticLoggingLevel, outputFileHandle);

   //##########################
   //ASCERTAIN NUMBER OF TRADES (USED TO ELIMINATE PARAMETER VALUES WITH STATISTICAL SIGNIFCANCE ISSUES)
   //##########################
   
   for(int dealID = 0; dealID < numDeals; dealID++){ 
      ulong dealTicket = HistoryDealGetTicket(dealID); 
      
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         numTrades++;       
      // Output main data to file
      OutputMainData(DiagnosticLoggingLevel, outputFileHandle, dealTicket);                    
   }  
   
   //###################################
   //CAGR OVER MEAN DRAWDOWN CALCULATION
   //###################################
   
   int numEquityValues     = ArraySize(EquityHistoryArray);
   double finalEquity      = EquityHistoryArray[numEquityValues-1];  
   double currentEquity    = StartingEquity;   //Gets overwritten as loop below progresses
   double maxEquity        = StartingEquity;   //Gets overwritten as loop below progresses
   double sumDDValues      = 0.0;
   int    numDDValues      = 0;
   
   //Loop through equity array in time order
   for(int arrayLoop = 1; arrayLoop < numEquityValues; arrayLoop++){
      currentEquity = EquityHistoryArray[arrayLoop];
      
      if(currentEquity > maxEquity)
         maxEquity = currentEquity;
      
      sumDDValues += ((maxEquity - currentEquity) / maxEquity) * 100.0;
      numDDValues++;
   }
   
   finalEquity = currentEquity;
   
   //On rare occasions, MetaTrader allows the final equity to pass below zero and become negative before the test ceases. When this happens it causes major issues with the CAGR calculation. So we set to zero manually when this is the case.
   if(finalEquity < 0.0)
      finalEquity = 0.0;
   
   BackTestFinalDate = TimeCurrent();

   double BackTestDuration = double(BackTestFinalDate - BackTestFirstDate);        //This is the back test duration in seconds, but cast to double to avoid problems below...
   BackTestDuration = ((((BackTestDuration / 60.0) / 60.0) / 24.0) / 365.0);       //... so convert to years
   
   double cagr = (MathPow((finalEquity / StartingEquity), (1 / BackTestDuration)) - 1) * 100.0;
   double meanDD = 0.0;
   
   if(numDDValues != 0)
      meanDD = sumDDValues / numDDValues;
   
   //Remember CAGRoverAvgDD passed in by ref
   CAGRoverAvgDD = 0.0;
   
   if(meanDD != 0.0)
      CAGRoverAvgDD = cagr / meanDD;

   // Close data file   
   if(DiagnosticLoggingLevel >= 1)
      FileClose(outputFileHandle);   

   return numTrades;
}  

int CoeffCorrelation(double& dCustomPerformanceMetric)
{
   //########################################
   //CALCULATE COEFFICIENT OF CORRELATION (r) - Which produces an identical ranking to Coeff of Determination (R-Squared)
   //########################################

   //The coefficient of correlation gives a value between -1 and +1. The Coefficient of Determination (R-squared) is simply the coef of corr squared.
   //It therefore has a range of 0 to 1. However, for our purposes we would want to keep the sign so that we know whether the equity curve is rising or falling.
   //Values close to +1 mean very smooth risng curve. Values close to -1 mean very smooth falling curve (i.e. very bad). Values close to 0 mean break 
   //even system with a choppy equity curve. A value of say 0.6 means a profitable system but with a choppy curve.
   
   //THE TRADE NUMBER (STARTING AT 0 AND INCREMENTING IN 1's) IS USED FOR X VALUES.
   //THE NORMALISED CUMMULATIVE EQUITY IS USED FOR THE VALUES OF Y
   
   // r = ( n(SUM(xy)) - (SUM(x))(Sum(y)) ) / ( SQRT( n(SUM(x-squared) - SUM(x)squared)) *  SQRT(n(SUM(y-squared)) - SUM(y)squared) )

   // A +ve value for r means that the equity curve is rising - GOOD. The closer to +1 the more efficient it is at winning
   // A -ve value for r means that the equity curve is falling - BAD. The closer to -1 the more efficient it is at losing
   
   
   //SET STARTING EQUITY AS FIRST EQUITY VALUE
   int numEquityValues = 1;
   
   // Create Diagnostic File
   int outputFileHandle = INVALID_HANDLE;
   //if(DiagnosticLoggingLevel >= 1) 
      DiagnosticFile(DiagnosticLoggingLevel, outputFileHandle);

   double equityID[];
   double cumNormalisedNetProfit[];  //This array will effectively represent the normalised equity curve
   
   ArrayResize(equityID, 1);
   ArrayResize(cumNormalisedNetProfit, 1);
   
   equityID[0] = 1.0;                             //Effectively the x-value in the r calc
   cumNormalisedNetProfit[0] = StartingEquity;    //Effectively the y-value in the r calc
   
   //SELECT ALL DEALS IN BACKTEST
   HistorySelect(0, TimeCurrent());   
   int numDeals = HistoryDealsTotal();  
   
   //LOOP THROUGH DEALS IN DATETIME ORDER TO ASCERTAIN EACH TRADE'S NET PROFIT AND VOLUME 
   for(int dealID = 0; dealID < numDeals; dealID++){ 
      //GET THIS DEAL'S TICKET NUMBER 
      ulong dealTicket = HistoryDealGetTicket(dealID); 
      
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT){
         numEquityValues++;
         
         double tradeNetProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                                 HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                                 (2 * HistoryDealGetDouble(dealTicket, DEAL_COMMISSION));  //*2 BASED ON ENTRY AND EXIT COMMISSION MODEL     
         
         double tradeVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         
         ArrayResize(equityID, numEquityValues);
         ArrayResize(cumNormalisedNetProfit, numEquityValues);
         
         equityID[numEquityValues - 1] = (double)numEquityValues;
         cumNormalisedNetProfit[numEquityValues - 1] = cumNormalisedNetProfit[numEquityValues - 2] + (tradeNetProfit / tradeVolume); //Normalise net profit to 1.0 lot
      }     
      // Output main data to file
      OutputMainData(DiagnosticLoggingLevel, outputFileHandle, dealTicket);                    
   } 
   
   double coeffOfCorrelation = 0.0;
   /*
   //###########################################
   //CALCULATE COEFF OF CORRELATION r - MANUALLY
   //###########################################
   
   double sumX = 0.0;
   double sumY = 0.0;
   double sumXY = 0.0;
   double sumXsquared = 0.0;
   double sumYsquared = 0.0;
   
   for(int equityValueID = 0; equityValueID < numEquityValues; equityValueID++) 
   {
      sumX        += (double)equityValueID;
      sumY        += cumNormalisedNetProfit[equityValueID];
      sumXY       += (double)equityValueID * cumNormalisedNetProfit[equityValueID];
      sumXsquared += (double)(equityValueID * equityValueID);
      sumYsquared += cumNormalisedNetProfit[equityValueID] * cumNormalisedNetProfit[equityValueID];
   }

   double denominator = MathSqrt((numEquityValues * sumXsquared) - (sumX * sumX)) * MathSqrt((numEquityValues * sumYsquared) - (sumY * sumY));

   if(denominator != 0.0)
      coeffOfCorrelation = ((numEquityValues * sumXY) - (sumX * sumY)) / denominator;
   */
   
   //########################################################
   //CALCULATE COEFF OF CORRELATION r USING BUILT IN FUNCTION - USES <Math\Stat\Stat.mqh>
   //########################################################
   
   if(!MathCorrelationPearson(equityID, cumNormalisedNetProfit, coeffOfCorrelation))
      coeffOfCorrelation = 0.0;
   
   //Set dCustomPerformanceMetric which was passed into this function by ref
   dCustomPerformanceMetric = coeffOfCorrelation;

   // Close diagnostic data file   
   if(DiagnosticLoggingLevel >= 1)
      FileClose(outputFileHandle);

   return numEquityValues-1;
}  

//######################
//MODIFIED PROFIT FACTOR
//######################

int ModifiedProfitFactor(double& dCustomPerformanceMetric)
{
   HistorySelect(0, TimeCurrent());   
   int numDeals = HistoryDealsTotal();  
   double sumProfit = 0.0;
   double sumLosses = 0.0;
   int numTrades = 0;
   
   // Create Diagnostic File
   int outputFileHandle = INVALID_HANDLE;
   //if(DiagnosticLoggingLevel >= 1) 
      DiagnosticFile(DiagnosticLoggingLevel, outputFileHandle);
   
   //LOOP THROUGH DEALS IN DATETIME ORDER 
   double positionNetProfit[];
   double positionVolume[];
   for(int dealID = 0; dealID < numDeals; dealID++) { 
      //GET THIS DEAL'S TICKET NUMBER
      ulong dealTicket = HistoryDealGetTicket(dealID); 
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT){
         numTrades++;   
         ArrayResize(positionNetProfit, numTrades);
         ArrayResize(positionVolume, numTrades);
         
         positionNetProfit[numTrades - 1] = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                                                HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                                                (2 * HistoryDealGetDouble(dealTicket, DEAL_COMMISSION));  //*2 BASED ON ENTRY AND EXIT COMMISSION MODEL     
         
         positionVolume[numTrades - 1] = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      }
      // Output main data to file
      OutputMainData(DiagnosticLoggingLevel, outputFileHandle, dealTicket);                    
   } 
   
   //###################################
   //1. CALCULATE STANDARD PROFIT FACTOR
   //###################################
   
   double sumOfProfit = 0;
   double sumOfLosses = 0;
   
   for(int positionNum = 1; positionNum <= numTrades; positionNum++){
      if(positionNetProfit[positionNum - 1] > 0)
         sumOfProfit += positionNetProfit[positionNum - 1];
      else
         sumOfLosses += positionNetProfit[positionNum - 1];
   }
   
   double standardProfitFactor = NULL;
   
   if(sumOfLosses != 0)
      standardProfitFactor = MathAbs(sumOfProfit / sumOfLosses);
   
   //###################################
   //2. CALCULATE RELATIVE PROFIT FACTOR (INTERMEDIATE STEP)
   //################################### 
   
   sumOfProfit = 0;
   sumOfLosses = 0;   
   
   for(int positionNum = 1; positionNum <= numTrades; positionNum++){
      positionNetProfit[positionNum - 1] /= positionVolume[positionNum - 1];
      
      if(positionNetProfit[positionNum - 1] > 0)
         sumOfProfit += positionNetProfit[positionNum - 1];
      else
         sumOfLosses += positionNetProfit[positionNum - 1];
   }                          
   
   double relativeProfitFactor = NULL;
   
   if(sumOfLosses != 0)
      relativeProfitFactor = MathAbs(sumOfProfit / sumOfLosses);
      
   //#########################
   //3. EXCLUDE EXTREME TRADES
   //#########################
   
   double MeanRelNetProfit = MathMean(positionNetProfit);
   double StdDevRelNetProfit = MathStandardDeviation(positionNetProfit);
   
   double stdDevExcludeMultiple = 4.0; //Exclude trades that have values in excess of 4SD from the mean
   int numExcludedTrades = 0;
   sumOfProfit = 0;
   sumOfLosses = 0;
   
   for(int positionNum = 1; positionNum <= numTrades; positionNum++){
      if(positionNetProfit[positionNum - 1] < MeanRelNetProfit-(stdDevExcludeMultiple*StdDevRelNetProfit)  ||  
         positionNetProfit[positionNum - 1] > MeanRelNetProfit+(stdDevExcludeMultiple*StdDevRelNetProfit))
      {
         numExcludedTrades++;
      }
      else{
         if(positionNetProfit[positionNum - 1] > 0)
            sumOfProfit += positionNetProfit[positionNum - 1];
         else
            sumOfLosses += positionNetProfit[positionNum - 1];
      }
   }
   
   dCustomPerformanceMetric = NULL;
   
   if(sumOfLosses != 0)
      dCustomPerformanceMetric = MathAbs(sumOfProfit / sumOfLosses);
      
   // Close diagnostic data file 
   if(DiagnosticLoggingLevel >= 1){
      FileWrite(outputFileHandle, "\nPROFIT FACTOR (STANDARD CALCULATION)", standardProfitFactor);
      FileWrite(outputFileHandle, "\nPROFIT FACTOR (MODIFIED CALCULATION)", relativeProfitFactor);
      
      FileWrite(outputFileHandle, "\nEXCLUDING EXTREME (NEWS AFFECTED) TRADES:");
      FileWrite(outputFileHandle, "TOTAL TRADES BEFORE EXCLUSIONS", numTrades);
      FileWrite(outputFileHandle, "MEAN RELATIVE NET PROFIT", MeanRelNetProfit);
      FileWrite(outputFileHandle, "STD DEV RELATIVE NET PROFIT", StdDevRelNetProfit);
      FileWrite(outputFileHandle, "NUM TRADES EXCLUDED (> " + DoubleToString(stdDevExcludeMultiple, 1) + " SD)", numExcludedTrades, DoubleToString(((double)numExcludedTrades/numTrades)*100.0) + "%");
      FileWrite(outputFileHandle, "MODIFIED PROFIT FACTOR", dCustomPerformanceMetric);
      
   }

   CloseDiagnosticFile(DiagnosticLoggingLevel, outputFileHandle);
   return numTrades;
}  
