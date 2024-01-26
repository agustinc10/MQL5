//+------------------------------------------------------------------+
//|                                            LogFile_functions.mqh |
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
//| Input variables                                                  |
//+------------------------------------------------------------------+

enum ENUM_DIAGNOSTIC_LOGGING_LEVEL
{
   DIAG_LOGGING_NONE,                           // NONE
   DIAG_LOGGING_LOW,                            // LOW - Major Diagnostics Only
   DIAG_LOGGING_MEDIUM,                         // MEDIUM - Medium level logging
   DIAG_LOGGING_HIGH                            // HIGH - All Diagnostics (Warning - Use with caution)
};

input group "==== Log Mode ===="
input ENUM_DIAGNOSTIC_LOGGING_LEVEL       DiagnosticLoggingLevel = DIAG_LOGGING_NONE;         //Diagnostic Logging Level

//Globals
int      PreviousHourlyTasksRun  = -1;          // Set to -1 so that hourly tasks run immediately
double   EquityHistoryArray[];                  // Used to store equity at intermittent time intervals when using the Strategy Tester in order to calculate CAGR/MeanDD perf metric
double   StartingEquity;                        // Stores the Starting Equity (i.e. the deposit amount at the beginning of the backtest)
datetime BackTestFirstDate;                     // Used in the CAGR/MeanDD Calc
datetime BackTestFinalDate;                     // Used in the CAGR/MeanDD Calc
int equityFileHandle = INVALID_HANDLE;          // Handle for Equity File

// Create Diagnostic File 
void DiagnosticFile(int DiagnosticLogLevel,int &outputFileHandle){
if(DiagnosticLogLevel >= 1){
   string outputFileName = "DEAL_DIAGNOSTIC_INFO\\deal_log.csv";
   outputFileHandle = FileOpen(outputFileName, FILE_WRITE|FILE_CSV, "\t");
   //FileWrite(outputFileHandle, "LIST OF DEALS IS BACKTEST");   
   FileWrite(outputFileHandle, "TICKET", "DEAL_ORDER", "DEAL_POSITION_ID", "DEAL_SYMBOL", "DEAL_TYPE", "OPEN_POSITIONS", 
                                 "DEAL_ENTRY", "DEAL_REASON", "DEAL_OPEN_TIME", "DEAL_CLOSE_TIME", "DEAL_OPEN_TIME_HOUR", "DEAL_CLOSE_TIME_HOUR", "DEAL_DURATION(MIN)", "DEAL_OPEN_DAY_OF_WEEK", "DEAL_CLOSE_DAY_OF_WEEK", 
                                 "DEAL_VOLUME", "DEAL_PRICE", "DEAL_SL", "DEAL_TP", "DEAL_COMMISSION", "DEAL_SWAP", "DEAL_PROFIT", "DEAL_NET_PROFIT", "TRADE_RESULT",
                                 "DEAL_R_MULTIPLE", "DEAL_MAGIC", "DEAL_COMMENT");
   Print("LOG FILE deal_log.csv OPENED");
   }
}

// Close data file   
void CloseDiagnosticFile(int DiagnosticLogLevel,int &outputFileHandle){
   if(DiagnosticLoggingLevel >= 1)
      FileClose(outputFileHandle);   
      Print("LOG FILE deal_log.csv CLOSED");
}

// Output main data to file
void OutputMainData(int DiagnosticLogLevel, int outputFileHandle, ulong dealTicket){
   if(DiagnosticLogLevel >= 1){
      string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      long dealPositionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      double tradeNetProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                              HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                              (2 * HistoryDealGetDouble(dealTicket, DEAL_COMMISSION));  //*2 BASED ON ENTRY AND EXIT COMMISSION MODEL 

      static int currentTrades = 0;      
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetDouble(dealTicket, DEAL_VOLUME) != 0)
         currentTrades++;       
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT && HistoryDealGetDouble(dealTicket, DEAL_VOLUME) != 0)
         currentTrades--;       

      double Rmultiple = 0;
      if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         Rmultiple = (HistoryDealGetDouble(dealTicket, DEAL_PRICE) - HistoryDealGetDouble(dealPositionID, DEAL_PRICE)) / 
                   (HistoryDealGetDouble(dealPositionID, DEAL_PRICE) - HistoryDealGetDouble(dealTicket, DEAL_SL));
      }

      long openTime = 0;
      long closeTime = 0;
      long duration = 0;
      ENUM_DAY_OF_WEEK open_day_of_week = 0;
      ENUM_DAY_OF_WEEK close_day_of_week = 0;
      MqlDateTime dealTimeOpen;
      MqlDateTime dealTimeClose;
      if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
         openTime = HistoryDealGetInteger(dealTicket, DEAL_TIME);
         TimeToStruct(openTime, dealTimeOpen);
         open_day_of_week = ENUM_DAY_OF_WEEK (dealTimeOpen.day_of_week);
         close_day_of_week = open_day_of_week;
      }
      else{
         openTime = HistoryDealGetInteger(dealPositionID, DEAL_TIME);
         closeTime = HistoryDealGetInteger(dealTicket, DEAL_TIME);
         duration = (closeTime - openTime) /3600;                       // Divided by 3600 to convert from seconds to hours
         TimeToStruct(openTime, dealTimeOpen);
         open_day_of_week = ENUM_DAY_OF_WEEK (dealTimeOpen.day_of_week);
         TimeToStruct(closeTime, dealTimeClose);        
         close_day_of_week = ENUM_DAY_OF_WEEK (dealTimeClose.day_of_week);
      }

      string resultTrade;
      if (HistoryDealGetDouble(dealTicket, DEAL_PROFIT) > 0) resultTrade = "WIN";
      else if (HistoryDealGetDouble(dealTicket, DEAL_PROFIT) < 0) resultTrade = "LOSS";
      else resultTrade = "BE";

      FileWrite(outputFileHandle, IntegerToString(dealTicket), 
                                 IntegerToString(HistoryDealGetInteger(dealTicket, DEAL_ORDER)),
                                 IntegerToString(dealPositionID),
                                 symbol,
                                 EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE)),
                                 IntegerToString(currentTrades),

                                 EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY)),
                                 EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON)),
                                 TimeToString((datetime)openTime, TIME_DATE|TIME_SECONDS),
                                 TimeToString((datetime)closeTime, TIME_DATE|TIME_SECONDS),
                                 IntegerToString(dealTimeOpen.hour),
                                 IntegerToString(dealTimeClose.hour),
                                 IntegerToString(duration),
                                 EnumToString(open_day_of_week),
                                 EnumToString(close_day_of_week),

                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_VOLUME), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_PRICE), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_SL), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_TP), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),

                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_COMMISSION), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_SWAP), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_PROFIT), 2),
                                 DoubleToString(tradeNetProfit, 2),
                                 resultTrade, 

                                 DoubleToString(Rmultiple, 2),
                                 IntegerToString(HistoryDealGetInteger(dealTicket, DEAL_MAGIC)),
                                 HistoryDealGetString(dealTicket, DEAL_COMMENT)
                                 );
   }
}


//Set up Equity History array and first date
void OpenEquityFile(int DiagnosticLogLevel,int &eqFileHandle){
   if(MQLInfoInteger(MQL_TESTER) && DiagnosticLogLevel >= 1){
      BackTestFirstDate = TimeCurrent();
      ArrayResize(EquityHistoryArray, 1);    
      EquityHistoryArray[0] = AccountInfoDouble(ACCOUNT_EQUITY); 
      StartingEquity = EquityHistoryArray[0];
      
      string equityFileName = "DEAL_DIAGNOSTIC_INFO\\equity_log.csv";
      eqFileHandle = FileOpen(equityFileName, FILE_WRITE|FILE_CSV, "\t");
      FileWrite(eqFileHandle, "DATETIME", "HOUR_OF_DAY", "CURRENT_EQUITY", //"HIGH_WATERMARK", "RISK_TOLERANCE_LEVEL", "DRAWDOWN", 
                              "EQUITY_CHANGE_DURING_HOUR");
      Print("EQUITY FILE equity_log.csv OPENED");
   }  
}

// Close data file   
void CloseEquityFile(int DiagnosticLogLevel,int &eqFileHandle){
   if(MQLInfoInteger(MQL_TESTER) && DiagnosticLogLevel >= 1){
         FileClose(eqFileHandle);   
         Print("EQUITY FILE deal_log.csv CLOSED");
   }
}

// Output main data to Equity file
void EquityMainData(int DiagnosticLogLevel, int eqFileHandle){
   if(MQLInfoInteger(MQL_TESTER) && DiagnosticLogLevel >= 1){
      MqlDateTime currentDateTime;
      datetime CurrentTime = TimeCurrent();
      TimeToStruct(CurrentTime, currentDateTime);
      
      if(currentDateTime.hour != PreviousHourlyTasksRun){
         int currentArraySize = ArraySize(EquityHistoryArray);
         ArrayResize(EquityHistoryArray, currentArraySize + 1);  
         EquityHistoryArray[currentArraySize] = AccountInfoDouble(ACCOUNT_EQUITY);

         double prevEq = EquityHistoryArray[currentArraySize - 1];
         double currEq = AccountInfoDouble(ACCOUNT_EQUITY);
         double eqDiff = currEq - prevEq; 

         FileWrite(eqFileHandle, TimeToString(CurrentTime, TIME_DATE|TIME_SECONDS), 
                                 IntegerToString(currentDateTime.hour),
                                 DoubleToString(currEq, 2),
                                 DoubleToString(eqDiff, 2)
                                 );
      }
      PreviousHourlyTasksRun = currentDateTime.hour;
   }
}