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

// Create Diagnostic File 
void DiagnosticFile(int DiagnosticLogLevel,int &outputFileHandle){
if(DiagnosticLogLevel >= 1){
   string outputFileName = "DEAL_DIAGNOSTIC_INFO\\deal_log.csv";
   outputFileHandle = FileOpen(outputFileName, FILE_WRITE|FILE_CSV, "\t");
   FileWrite(outputFileHandle, "LIST OF DEALS IS BACKTEST");   
   FileWrite(outputFileHandle, "TICKET", "DEAL_ORDER", "DEAL_POSITION_ID", "DEAL_SYMBOL", "DEAL_TYPE", "OPEN_POSITIONS", 
                                 "DEAL_ENTRY", "DEAL_REASON", "DEAL_TIME", "DEAL_DAY_OF_WEEK", "DEAL_VOLUME", "DEAL_PRICE", 
                                 "DEAL_SL", "DEAL_TP", "DEAL_COMMISSION", "DEAL_SWAP", "DEAL_PROFIT", "DEAL_NET_PROFIT", "TRADE_RESULT",
                                 "DEAL_RR_FACTOR", "DEAL_MAGIC", "DEAL_COMMENT");
   }
}

// Close data file   
void CloseDiagnosticFile(int DiagnosticLogLevel,int &outputFileHandle){
   if(DiagnosticLoggingLevel >= 1)
      FileClose(outputFileHandle);   
      Print("LOG FILE deal_log.csv WRITTEN");
}

// Output main data to file
void OutputMainData(int DiagnosticLogLevel, int outputFileHandle, ulong dealTicket){
   if(DiagnosticLogLevel >= 1){
      string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      double tradeNetProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                              HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                              (2 * HistoryDealGetDouble(dealTicket, DEAL_COMMISSION));  //*2 BASED ON ENTRY AND EXIT COMMISSION MODEL 

      static int currentTrades = 0;      
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetDouble(dealTicket, DEAL_VOLUME) != 0)
         currentTrades++;       
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT && HistoryDealGetDouble(dealTicket, DEAL_VOLUME) != 0)
         currentTrades--;       

      long tmp;
      MqlDateTime dealTime;
      HistoryDealGetInteger(dealTicket, DEAL_TIME, tmp);
      TimeToStruct(tmp, dealTime);
      int dow = dealTime.day_of_week;
      ENUM_DAY_OF_WEEK day_of_week = ENUM_DAY_OF_WEEK (dow);

      long dealPositionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      double Rfactor = 0;
      if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         Rfactor = (HistoryDealGetDouble(dealTicket, DEAL_PRICE) - HistoryDealGetDouble(dealPositionID, DEAL_PRICE)) / 
                   (HistoryDealGetDouble(dealPositionID, DEAL_PRICE) - HistoryDealGetDouble(dealTicket, DEAL_SL));
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
                                 TimeToString((datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME), TIME_DATE|TIME_SECONDS),
                                 EnumToString((ENUM_DAY_OF_WEEK)day_of_week),

                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_VOLUME), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_PRICE), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_SL), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_TP), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),

                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_COMMISSION), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_SWAP), 2),
                                 DoubleToString(HistoryDealGetDouble(dealTicket, DEAL_PROFIT), 2),
                                 DoubleToString(tradeNetProfit, 2),
                                 resultTrade, 

                                 DoubleToString(Rfactor, 2),
                                 IntegerToString(HistoryDealGetInteger(dealTicket, DEAL_MAGIC)),
                                 HistoryDealGetString(dealTicket, DEAL_COMMENT)
                                 );
   }
}