//+------------------------------------------------------------------+
//|                                                  ACFunctions.mqh |
//|                                                          AC_2024 |
//|                                                                  |
//+------------------------------------------------------------------+

// Sanity Checks based on codes found in https://www.mql5.com/en/articles/2555 &&
// Risk Calculations based on codes found in https://www.orchardforex.com

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

//+------------------------------------------------------------------+
//||||||||||||||||||||||||||||| INPUTS |||||||||||||||||||||||||||||||
//+------------------------------------------------------------------+

input group "==== Risk Mode ===="
enum LOT_MODE_ENUM {
   LOT_MODE_FIXED,                     // fixed lots
   LOT_MODE_MONEY,                     // lots based on money
   LOT_MODE_PCT_ACCOUNT                // lots based on % of account   
};
input LOT_MODE_ENUM InpLotMode = LOT_MODE_FIXED; // lot mode
input double        InpLots    = 0.10;           // lots / money / percent

//||||||||||||||||||||||| ORDERS & POSITIONS |||||||||||||||||||||||||
//+------------------------------------------------------------------+

// Get Position Ticket for 1 EA
bool GetPosTicket(int i, ulong ticket, int EAMagicNumber){      
   if (ticket <= 0) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to get position ticket!"); return false; }
   if (!PositionSelectByTicket(ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to select position by ticket"); return false; } // "I like to selectPosition again (...) This updates the position data so we make sure we get a fresh position data"
   long magicnumber;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber == EAMagicNumber)
      return true;
   return true;
}

// Get Order Ticket for 1 EA
bool GetOrTicket(int i, ulong ticket, int EAMagicNumber){      
   if (ticket <= 0) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to get order ticket!"); return false; }
   if (!OrderSelect(ticket)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to select order by ticket"); return false; } // "I like to selectPosition again (...) This updates the position data so we make sure we get a fresh position data"
   long magicnumber;
   if (!OrderGetInteger(ORDER_MAGIC, magicnumber)) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to get order magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber == EAMagicNumber)
      return true;
   return true;
}
         
// Count Positios for 1 EA
int CountOpenPosition(int EAMagicNumber)
{
   int counter = 0;
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);   // Select position
      if(GetPosTicket(i, ticket, EAMagicNumber)) counter++;  
   }
   return counter;
}

// Count Open Orders for 1 EA
int CountOpenOrders(int EAMagicNumber)
{
   int counter = 0;
   int total = OrdersTotal();
   for (int i = total - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if (ticket <= 0) { Print ("Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError()), ". Failed to get order ticket"); return -1; }
      if(GetOrTicket(i, ticket, EAMagicNumber)) counter++;      
   }
   return counter;
}

// Returns runtime error code description
string getErrorDesc(int err_code) {
   switch(err_code) {
      //--- Constant Description
      case ERR_SUCCESS:                      return("The operation completed successfully");
      case ERR_INTERNAL_ERROR:               return("Unexpected internal error");
      case ERR_WRONG_INTERNAL_PARAMETER:     return("Wrong parameter in the inner call of the client terminal function");
      case ERR_INVALID_PARAMETER:            return("Wrong parameter when calling the system function");
      case ERR_NOT_ENOUGH_MEMORY:            return("Not enough memory to perform the system function");
      case ERR_STRUCT_WITHOBJECTS_ORCLASS:   return("The structure contains objects of strings and/or dynamic arrays and/or structure of such objects and/or classes");
      case ERR_INVALID_ARRAY:                return("Array of a wrong type, wrong size, or a damaged object of a dynamic array");
      case ERR_ARRAY_RESIZE_ERROR:           return("Not enough memory for the relocation of an array, or an attempt to change the size of a static array");
      case ERR_STRING_RESIZE_ERROR:          return("Not enough memory for the relocation of string");
      case ERR_NOTINITIALIZED_STRING:        return("Not initialized string");
      case ERR_INVALID_DATETIME:             return("Invalid date and/or time");
      case ERR_ARRAY_BAD_SIZE:               return("Requested array size exceeds 2 GB");
      case ERR_INVALID_POINTER:              return("Wrong pointer");
      case ERR_INVALID_POINTER_TYPE:         return("Wrong type of pointer");
      case ERR_FUNCTION_NOT_ALLOWED:         return("System function is not allowed to call");
      //--- Charts      
      case ERR_CHART_WRONG_ID:               return("Wrong chart ID");
      case ERR_CHART_NO_REPLY:               return("Chart does not respond");
      case ERR_CHART_NOT_FOUND:              return("Chart not found");
      case ERR_CHART_NO_EXPERT:              return("No Expert Advisor in the chart that could handle the event");
      case ERR_CHART_CANNOT_OPEN:            return("Chart opening error");
      case ERR_CHART_CANNOT_CHANGE:          return("Failed to change chart symbol and period");
      case ERR_CHART_CANNOT_CREATE_TIMER:    return("Failed to create timer");
      case ERR_CHART_WRONG_PROPERTY:         return("Wrong chart property ID");
      case ERR_CHART_SCREENSHOT_FAILED:      return("Error creating screenshots");
      case ERR_CHART_NAVIGATE_FAILED:        return("Error navigating through chart");
      case ERR_CHART_TEMPLATE_FAILED:        return("Error applying template");
      case ERR_CHART_WINDOW_NOT_FOUND:       return("Subwindow containing the indicator was not found");
      case ERR_CHART_INDICATOR_CANNOT_ADD:   return("Error adding an indicator to chart");
      case ERR_CHART_INDICATOR_CANNOT_DEL:   return("Error deleting an indicator from the chart");
      case ERR_CHART_INDICATOR_NOT_FOUND:    return("Indicator not found on the specified chart");
      //--- Graphical Objects   
      case ERR_OBJECT_ERROR:                 return("Error working with a graphical object");
      case ERR_OBJECT_NOT_FOUND:             return("Graphical object was not found");
      case ERR_OBJECT_WRONG_PROPERTY:        return("Wrong ID of a graphical object property");
      case ERR_OBJECT_GETDATE_FAILED:        return("Unable to get date corresponding to the value");
      case ERR_OBJECT_GETVALUE_FAILED:       return("Unable to get value corresponding to the date");
      //--- MarketInfo  
      case ERR_MARKET_UNKNOWN_SYMBOL:        return("Unknown symbol");
      case ERR_MARKET_NOT_SELECTED:          return("Symbol is not selected in MarketWatch");
      case ERR_MARKET_WRONG_PROPERTY:        return("Wrong identifier of a symbol property");
      case ERR_MARKET_LASTTIME_UNKNOWN:      return("Time of the last tick is not known (no ticks)");
      case ERR_MARKET_SELECT_ERROR:          return("Error adding or deleting a symbol in MarketWatch");
      //--- History Access      
      case ERR_HISTORY_NOT_FOUND:            return("Requested history not found");
      case ERR_HISTORY_WRONG_PROPERTY:       return("Wrong ID of the history property");
      //--- Global_Variables    
      case ERR_GLOBALVARIABLE_NOT_FOUND:     return("Global variable of the client terminal is not found");
      case ERR_GLOBALVARIABLE_EXISTS:        return("Global variable of the client terminal with the same name already exists");
      case ERR_MAIL_SEND_FAILED:             return("Email sending failed");
      case ERR_PLAY_SOUND_FAILED:            return("Sound playing failed");
      case ERR_MQL5_WRONG_PROPERTY:          return("Wrong identifier of the program property");
      case ERR_TERMINAL_WRONG_PROPERTY:      return("Wrong identifier of the terminal property");
      case ERR_FTP_SEND_FAILED:              return("File sending via ftp failed");
      case ERR_NOTIFICATION_SEND_FAILED:     return("Error in sending notification");
      //--- Custom Indicator Buffers
      case ERR_BUFFERS_NO_MEMORY:            return("Not enough memory for the distribution of indicator buffers");
      case ERR_BUFFERS_WRONG_INDEX:          return("Wrong indicator buffer index");
      //--- Custom Indicator Properties
      case ERR_CUSTOM_WRONG_PROPERTY:        return("Wrong ID of the custom indicator property");
      //--- Account
      case ERR_ACCOUNT_WRONG_PROPERTY:       return("Wrong account property ID");
      case ERR_TRADE_WRONG_PROPERTY:         return("Wrong trade property ID");
      case ERR_TRADE_DISABLED:               return("Trading by Expert Advisors prohibited");
      case ERR_TRADE_POSITION_NOT_FOUND:     return("Position not found");
      case ERR_TRADE_ORDER_NOT_FOUND:        return("Order not found");
      case ERR_TRADE_DEAL_NOT_FOUND:         return("Deal not found");
      case ERR_TRADE_SEND_FAILED:            return("Trade request sending failed");
      //--- Indicators  
      case ERR_INDICATOR_UNKNOWN_SYMBOL:     return("Unknown symbol");
      case ERR_INDICATOR_CANNOT_CREATE:      return("Indicator cannot be created");
      case ERR_INDICATOR_NO_MEMORY:          return("Not enough memory to add the indicator");
      case ERR_INDICATOR_CANNOT_APPLY:       return("The indicator cannot be applied to another indicator");
      case ERR_INDICATOR_CANNOT_ADD:         return("Error applying an indicator to chart");
      case ERR_INDICATOR_DATA_NOT_FOUND:     return("Requested data not found");
      case ERR_INDICATOR_WRONG_HANDLE:       return("Wrong indicator handle");
      case ERR_INDICATOR_WRONG_PARAMETERS:   return("Wrong number of parameters when creating an indicator");
      case ERR_INDICATOR_PARAMETERS_MISSING: return("No parameters when creating an indicator");
      case ERR_INDICATOR_CUSTOM_NAME:        return("The first parameter in the array must be the name of the custom indicator");
      case ERR_INDICATOR_PARAMETER_TYPE:     return("Invalid parameter type in the array when creating an indicator");
      case ERR_INDICATOR_WRONG_INDEX:        return("Wrong index of the requested indicator buffer");
      //--- Depth of Market     
      case ERR_BOOKS_CANNOT_ADD:             return("Depth Of Market can not be added");
      case ERR_BOOKS_CANNOT_DELETE:          return("Depth Of Market can not be removed");
      case ERR_BOOKS_CANNOT_GET:             return("The data from Depth Of Market can not be obtained");
      case ERR_BOOKS_CANNOT_SUBSCRIBE:       return("Error in subscribing to receive new data from Depth Of Market");
      //--- File Operations
      case ERR_TOO_MANY_FILES:               return("More than 64 files cannot be opened at the same time");
      case ERR_WRONG_FILENAME:               return("Invalid file name");
      case ERR_TOO_LONG_FILENAME:            return("Too long file name");
      case ERR_CANNOT_OPEN_FILE:             return("File opening error");
      case ERR_FILE_CACHEBUFFER_ERROR:       return("Not enough memory for cache to read");
      case ERR_CANNOT_DELETE_FILE:           return("File deleting error");
      case ERR_INVALID_FILEHANDLE:           return("A file with this handle was closed, or was not opening at all");
      case ERR_WRONG_FILEHANDLE:             return("Wrong file handle");
      case ERR_FILE_NOTTOWRITE:              return("The file must be opened for writing");
      case ERR_FILE_NOTTOREAD:               return("The file must be opened for reading");
      case ERR_FILE_NOTBIN:                  return("The file must be opened as a binary one");
      case ERR_FILE_NOTTXT:                  return("The file must be opened as a text");
      case ERR_FILE_NOTTXTORCSV:             return("The file must be opened as a text or CSV");
      case ERR_FILE_NOTCSV:                  return("The file must be opened as CSV");
      case ERR_FILE_READERROR:               return("File reading error");
      case ERR_FILE_BINSTRINGSIZE:           return("String size must be specified, because the file is opened as binary");
      case ERR_INCOMPATIBLE_FILE:            return("A text file must be for string arrays, for other arrays - binary");
      case ERR_FILE_IS_DIRECTORY:            return("This is not a file, this is a directory");
      case ERR_FILE_NOT_EXIST:               return("File does not exist");
      case ERR_FILE_CANNOT_REWRITE:          return("File can not be rewritten");
      case ERR_WRONG_DIRECTORYNAME:          return("Wrong directory name");
      case ERR_DIRECTORY_NOT_EXIST:          return("Directory does not exist");
      case ERR_FILE_ISNOT_DIRECTORY:         return("This is a file, not a directory");
      case ERR_CANNOT_DELETE_DIRECTORY:      return("The directory cannot be removed");
      case ERR_CANNOT_CLEAN_DIRECTORY:       return("Failed to clear the directory (probably one or more files are blocked and removal operation failed)");
      case ERR_FILE_WRITEERROR:              return("Failed to write a resource to a file");
      //--- String Casting      
      case ERR_NO_STRING_DATE:               return("No date in the string");
      case ERR_WRONG_STRING_DATE:            return("Wrong date in the string");
      case ERR_WRONG_STRING_TIME:            return("Wrong time in the string");
      case ERR_STRING_TIME_ERROR:            return("Error converting string to date");
      case ERR_STRING_OUT_OF_MEMORY:         return("Not enough memory for the string");
      case ERR_STRING_SMALL_LEN:             return("The string length is less than expected");
      case ERR_STRING_TOO_BIGNUMBER:         return("Too large number, more than ULONG_MAX");
      case ERR_WRONG_FORMATSTRING:           return("Invalid format string");
      case ERR_TOO_MANY_FORMATTERS:          return("Amount of format specifiers more than the parameters");
      case ERR_TOO_MANY_PARAMETERS:          return("Amount of parameters more than the format specifiers");
      case ERR_WRONG_STRING_PARAMETER:       return("Damaged parameter of string type");
      case ERR_STRINGPOS_OUTOFRANGE:         return("Position outside the string");
      case ERR_STRING_ZEROADDED:             return("0 added to the string end, a useless operation");
      case ERR_STRING_UNKNOWNTYPE:           return("Unknown data type when converting to a string");
      case ERR_WRONG_STRING_OBJECT:          return("Damaged string object");
      //--- Operations with Arrays      
      case ERR_INCOMPATIBLE_ARRAYS:          return("Copying incompatible arrays. String array can be copied only to a string array, and a numeric array - in numeric array only");
      case ERR_SMALL_ASSERIES_ARRAY:         return("The receiving array is declared as AS_SERIES, and it is of insufficient size");
      case ERR_SMALL_ARRAY:                  return("Too small array, the starting position is outside the array");
      case ERR_ZEROSIZE_ARRAY:               return("An array of zero length");
      case ERR_NUMBER_ARRAYS_ONLY:           return("Must be a numeric array");
      case ERR_ONEDIM_ARRAYS_ONLY:           return("Must be a one-dimensional array");
      case ERR_SERIES_ARRAY:                 return("Timeseries cannot be used");
      case ERR_DOUBLE_ARRAY_ONLY:            return("Must be an array of type double");
      case ERR_FLOAT_ARRAY_ONLY:             return("Must be an array of type float");
      case ERR_LONG_ARRAY_ONLY:              return("Must be an array of type long");
      case ERR_INT_ARRAY_ONLY:               return("Must be an array of type int");
      case ERR_SHORT_ARRAY_ONLY:             return("Must be an array of type short");
      case ERR_CHAR_ARRAY_ONLY:              return("Must be an array of type char");
      //--- Operations with OpenCL      
      case ERR_OPENCL_NOT_SUPPORTED:         return("OpenCL functions are not supported on this computer");
      case ERR_OPENCL_INTERNAL:              return("Internal error occurred when running OpenCL");
      case ERR_OPENCL_INVALID_HANDLE:        return("Invalid OpenCL handle");
      case ERR_OPENCL_CONTEXT_CREATE:        return("Error creating the OpenCL context");
      case ERR_OPENCL_QUEUE_CREATE:          return("Failed to create a run queue in OpenCL");
      case ERR_OPENCL_PROGRAM_CREATE:        return("Error occurred when compiling an OpenCL program");
      case ERR_OPENCL_TOO_LONG_KERNEL_NAME:  return("Too long kernel name (OpenCL kernel)");
      case ERR_OPENCL_KERNEL_CREATE:         return("Error creating an OpenCL kernel");
      case ERR_OPENCL_SET_KERNEL_PARAMETER:  return("Error occurred when setting parameters for the OpenCL kernel");
      case ERR_OPENCL_EXECUTE:               return("OpenCL program runtime error");
      case ERR_OPENCL_WRONG_BUFFER_SIZE:     return("Invalid size of the OpenCL buffer");
      case ERR_OPENCL_WRONG_BUFFER_OFFSET:   return("Invalid offset in the OpenCL buffer");
      case ERR_OPENCL_BUFFER_CREATE:         return("Failed to create and OpenCL buffer");
      //--- User-Defined Errors 
      default: if(err_code>=ERR_USER_ERROR_FIRST && err_code<ERR_USER_ERROR_LAST)
                                             return("User error "+string(err_code-ERR_USER_ERROR_FIRST));
   }
   return("Unknown");
}

// Error handling for missing Symbol in MarketWatch
string InvalidHandleErrorMessageBox(string symbol, string indicator) {
   string OutputMessage = "";
   if(GetLastError() == 4302)
      OutputMessage = ". Symbol needs to be added to the MarketWatch";
   else  
      StringConcatenate(OutputMessage, ". Error Code ", GetLastError(), ". Desc : ", getErrorDesc(GetLastError())); 
   MessageBox("Failed to create handle for " + indicator + " indicator for " + symbol + OutputMessage +
               "\n\r\n\rEA will now terminate.");
   return OutputMessage; 
}

//	Has a new bar opened
/*bool NewBar( string symbol = NULL, int timeframe = 0, bool initToNow = false ) {

   datetime        currentBarTime  = iTime( symbol, ( ENUM_TIMEFRAMES )timeframe, 0 );
   static datetime previousBarTime = initToNow ? currentBarTime : 0;
   if ( previousBarTime == currentBarTime ) return ( false );
   previousBarTime = currentBarTime;
   return ( true );
}
*/

//||||||||||||||||||||||| RISK CALCULATIONS ||||||||||||||||||||||||||
//+------------------------------------------------------------------+

double DoubleToTicks( string symbol, double value ) {
   return ( value / SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_SIZE ) );
}

double TicksToDouble( string symbol, double ticks ) {
   return ( ticks * SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_SIZE ) );
}

double PointsToDouble( string symbol, int points ) {
   return ( points * SymbolInfoDouble( symbol, SYMBOL_POINT ) );
}

double EquityPercent( double value ) {
   return ( AccountInfoDouble( ACCOUNT_EQUITY ) * value ); // Value is actually a decimal
}

double PercentSLSize( string symbol, double riskPercent,       // Given de % risk, returns the size in price of the SL (not in ticks)
                      double lots ) { // Risk percent is a decimal (1%=0.01)
   return ( RiskSLSize( symbol, EquityPercent( riskPercent ), lots ) );
}

double PercentRiskLots( string symbol, double riskPercent,     //slSize is the price movement you are risking
                        double slSize ) { // Risk percent is a decimal (1%=0.01)
   return ( RiskLots( symbol, EquityPercent( riskPercent ), slSize ) );
}

double RiskLots( string symbol, double riskAmount, double slSize ) { // Amount in account currency

   double ticks     = DoubleToTicks( symbol, slSize );
   double tickValue = SymbolInfoDouble (symbol, SYMBOL_TRADE_TICK_VALUE ); // value of 1 tick for 1 lot
   double lotRisk   = ticks * tickValue;
   double riskLots  = riskAmount / lotRisk;//NormalizeDouble(riskAmount / lotRisk, 2);
   return ( riskLots );
}

double RiskSLSize( string symbol, double riskAmount, double lots ) { // Amount in account currency

   double tickValue = SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_VALUE ); // value of 1 tick for 1 lot
   double ticks     = riskAmount / ( lots * tickValue );
   double slSize    = TicksToDouble( symbol, ticks );
   return ( slSize );
}

// Calculate Lots - https://www.youtube.com/watch?v=UFFTlc0Ysy4&list=PLGjfbI-PZyHW4fWaAYrSo4gRpCGNPH-ae&index=10
double CalculateLots(string symbol, double slDistance)      // Pass lots as a reference (&) so we can modify it inside the function
{
   double mylots = 0.0;
   if(InpLotMode == LOT_MODE_FIXED) {
      mylots = InpLots;
   }   
   else
   {
      double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);         // https://www.mql5.com/en/articles/2555#invalid_lot
              
      // Calculate risk based off entry and stop loss level by pips
      double Riskpercent = InpLotMode == LOT_MODE_MONEY ? InpLots / AccountInfoDouble(ACCOUNT_EQUITY) : InpLots * 0.01;
      double RiskAmount  = InpLotMode == LOT_MODE_MONEY ? InpLots : AccountInfoDouble(ACCOUNT_EQUITY) * InpLots * 0.01;

      mylots = NormalizeDouble(PercentRiskLots(symbol, Riskpercent, slDistance ), 2);
      
      mylots = (int)MathFloor(mylots/volume_step) * volume_step;
                         
   }   
   // check calculated lots
   string desc;
   if (!CheckVolumeValue(mylots, desc)) return false;
   
   return mylots;
}

//||||||||||||||||||||||||| GENERAL CHECKS||||||||||||||||||||||||||||
//+------------------------------------------------------------------+

// Check Stop Levels    
// (some brokers have a stop level so you cannot set the sl too close to the current price)
bool Checkstoplevels(double sldistance, double tpdistance){
   long level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if (level != 0 && sldistance <= level * _Point) {
      Print("ERROR_ac: Failed to place sl because it is inside stop level");
      return false;                                                        // return para que salga de la función y no cree la orden sin sl o sin tp 
   }
   if (level != 0 && tpdistance <= level * _Point) {
      Print("ERROR_ac: Failed to place tp because it is inside stop level");
      return false;
   }
   return true;
}        

// Check if Enough Money 
bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
//--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   //--- call of the checking function
   if(!OrderCalcMargin(type,symb,lots,price,margin))
     {
      //--- something went wrong, report and return false
      Print("ERROR_ac: Error in ",__FUNCTION__," code=",GetLastError());
      return(false);
     }
   //--- if there are insufficient funds to perform the operation
   if(margin>free_margin)
     {
      //--- report the error and return false
      Print("ERROR_ac: Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      return(false);
     }
//--- checking successful
   return(true);
  } 


// Check the correctness of the order volume
bool CheckVolumeValue(double volume,string &description)
  {
//--- minimal allowed volume for trade operations
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }
//--- maximal allowed volume of trade operations
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }
//--- get minimal step of volume changing
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      description=StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                               volume_step,ratio*volume_step);
      return(false);
     }
   description="Correct volume value";
   return(true);
  }

// Check if another order can be placed
bool IsNewOrderAllowed()
  {
//--- get the number of pending orders allowed on the account
   int max_allowed_orders=(int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);

//--- if there is no limitation, return true; you can send an order
   if(max_allowed_orders==0) return(true);

//--- if we passed to this line, then there is a limitation; find out how many orders are already placed
   int orders=OrdersTotal();

//--- return the result of comparing
   return(orders<max_allowed_orders);
  }
  
// Check if Trade is Allowed
// Check 4 things. The functions are int thar correspond to true/false so I convert it to bool
bool IsTradeAllowed() {
   return ( (bool)MQLInfoInteger     (MQL_TRADE_ALLOWED)       // Trading allowed in input dialog
         && (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)  // Trading allowed in terminal
         && (bool)AccountInfoInteger (ACCOUNT_TRADE_ALLOWED)   // Is account able to trade,
         && (bool)AccountInfoInteger (ACCOUNT_TRADE_EXPERT)    // Is account able to auto trade
         ); 
}        
         
// Check if Market is Open
bool IsMarketOpen() { return IsMarketOpen(_Symbol, TimeCurrent());}
bool IsMarketOpen(datetime time) { return IsMarketOpen(_Symbol, time); }
bool IsMarketOpen(string symbol, datetime time) {

	static string lastSymbol = "";
	static bool isOpen = false;
	static datetime sessionStart = 0;
	static datetime sessionEnd = 0;

	if (lastSymbol==symbol && sessionEnd>sessionStart) {
		if ( (isOpen && time>=sessionStart && time<=sessionEnd)
		      || (!isOpen && time>sessionStart && time<sessionEnd) ) return isOpen;
	}
		
	lastSymbol = symbol;

	MqlDateTime mtime;
	TimeToStruct(time, mtime);
	datetime seconds = mtime.hour*3600+mtime.min*60+mtime.sec;
	
	mtime.hour = 0;
	mtime.min = 0;
	mtime.sec = 0;
	datetime dayStart = StructToTime(mtime);
	datetime dayEnd = dayStart + 86400;
	
	datetime fromTime;
	datetime toTime;
	
	sessionStart = dayStart;
	sessionEnd = dayEnd;
	
	for(int session = 0;;session++) {
	
		if (!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)mtime.day_of_week, session, fromTime, toTime)) {
			sessionEnd = dayEnd;
			isOpen = false;
			return isOpen;
		}
		
		if (seconds<fromTime) { // not inside a session
			sessionEnd = dayStart + fromTime;
			isOpen = false;
			return isOpen;
		}
		
		if (seconds>toTime) { // maybe a later session
			sessionStart = dayStart + toTime;
			continue;
		}
		
		// at this point must be inside a session
		sessionStart = dayStart + fromTime;
		sessionEnd = dayStart + toTime;
		isOpen = true;
		return isOpen;

	}
	
	return false;
	
}


// https://www.youtube.com/watch?v=3-yKhOQlWvc

// Para buscar hacia los dos lados
int FindPeak(string symbol, int mode, int count, int startBar, ENUM_TIMEFRAMES Timeframe){
   if(mode != MODE_HIGH && mode != MODE_LOW) return -1;
   
   int currentBar = startBar;    // this will be the counter
   int foundBar = FindeNextPeak(symbol, mode, count*2+1, currentBar - count, Timeframe);      // count*2 to count to each side +1 to account for the currentbar
   while (foundBar != currentBar){
      currentBar = FindeNextPeak(symbol, mode, count, currentBar + 1, Timeframe);
      foundBar = FindeNextPeak(symbol, mode, count*2+1, currentBar - count, Timeframe);      // count*2 to count to each side +1 to account for the currentbar
   }
   return(currentBar);
}

//Search Peak in "count" bars to the left of startBar 
int FindeNextPeak(string symbol, int mode, int count, int startBar, ENUM_TIMEFRAMES Timeframe){
   if (startBar<0){     // to make sure you always start in bar 0
      count += startBar;
      startBar = 0;
   }   
   return((mode == MODE_HIGH) ?
            iHighest(symbol, Timeframe, (ENUM_SERIESMODE)mode, count, startBar) :
            iLowest(symbol, Timeframe, (ENUM_SERIESMODE)mode, count, startBar)
         );
}

// Find Higher Highs and Higher Lows
int LastHigh(string symbol, ENUM_TIMEFRAMES Timeframe, int shoulder, string &H1, string &H2){
   int High1 = FindPeak(symbol, MODE_HIGH, shoulder, 1, Timeframe);
   int High2 = FindPeak(symbol, MODE_HIGH, shoulder, High1 + 1, Timeframe);
   int High3 = FindPeak(symbol, MODE_HIGH, shoulder, High2 + 1, Timeframe);
   double High1value = iHigh(symbol, Timeframe, High1);
   double High2value = iHigh(symbol, Timeframe, High2);
   double High3value = iHigh(symbol, Timeframe, High3);

   if(High1value > High2value)
      H1 = "HH";
   else 
      H1 = "LH"; 
   if(High2value > High3value)
      H2 = "HH";
   else 
      H2 = "LH";
   /*
   ObjectsDeleteAll(0, "arrowup");        
   ObjectCreate(0,"arrowup1",OBJ_ARROW_DOWN,0,iTime(symbol, Timeframe, High1),High1value); 
   ObjectSetInteger(0,"arrowup1",OBJPROP_ANCHOR,ANCHOR_BOTTOM); // set anchor type
   ObjectSetInteger(0,"arrowup1",OBJPROP_COLOR,clrLimeGreen);    // set a sign color 
   ObjectSetInteger(0,"arrowup1",OBJPROP_WIDTH,2);              // set the sign size  
   
   ObjectCreate(0,"arrowup2",OBJ_ARROW_DOWN,0,iTime(symbol, Timeframe, High2),High2value); 
   ObjectSetInteger(0,"arrowup2",OBJPROP_ANCHOR,ANCHOR_BOTTOM); 
   ObjectSetInteger(0,"arrowup2",OBJPROP_COLOR,clrLimeGreen); 
   ObjectSetInteger(0,"arrowup2",OBJPROP_WIDTH,2);

   ObjectCreate(0,"arrowup3",OBJ_ARROW_DOWN,0,iTime(symbol, Timeframe, High3),High3value); 
   ObjectSetInteger(0,"arrowup3",OBJPROP_ANCHOR,ANCHOR_BOTTOM); 
   ObjectSetInteger(0,"arrowup3",OBJPROP_COLOR,clrLimeGreen); 
   ObjectSetInteger(0,"arrowup3",OBJPROP_WIDTH,2);
   */
   return High1;
}

int LastLow(string symbol, ENUM_TIMEFRAMES Timeframe, int shoulder, string &L1, string &L2){

   int Low1 = FindPeak(symbol, MODE_LOW, shoulder, 1, Timeframe);
   int Low2 = FindPeak(symbol, MODE_LOW, shoulder, Low1 + 1, Timeframe);
   int Low3 = FindPeak(symbol, MODE_LOW, shoulder, Low2 + 1, Timeframe);
   
   double Low1value = iLow(symbol, Timeframe, Low1);
   double Low2value = iLow(symbol, Timeframe, Low2);
   double Low3value = iLow(symbol, Timeframe, Low3);      
   
   if(Low1value < Low2value)
      L1 = "LL";
   else 
      L1 = "HL"; 
   if(Low2value < Low3value)
      L2 = "LL";
   else 
      L2 = "HL";
   /*
   ObjectsDeleteAll(0, "arrowdown");        
   ObjectCreate(0,"arrowdown1",OBJ_ARROW_UP,0,iTime(symbol, Timeframe, Low1),Low1value); 
   ObjectSetInteger(0,"arrowdown1",OBJPROP_ANCHOR,ANCHOR_TOP); // set anchor type
   ObjectSetInteger(0,"arrowdown1",OBJPROP_COLOR,clrRed);    // set a sign color 
   ObjectSetInteger(0,"arrowdown1",OBJPROP_WIDTH,2);              // set the sign size  
   
   ObjectCreate(0,"arrowdown2",OBJ_ARROW_UP,0,iTime(symbol, Timeframe, Low2),Low2value); 
   ObjectSetInteger(0,"arrowdown2",OBJPROP_ANCHOR,ANCHOR_TOP); 
   ObjectSetInteger(0,"arrowdown2",OBJPROP_COLOR,clrRed); 
   ObjectSetInteger(0,"arrowdown2",OBJPROP_WIDTH,2);

   ObjectCreate(0,"arrowdown3",OBJ_ARROW_UP,0,iTime(symbol, Timeframe, Low3),Low3value); 
   ObjectSetInteger(0,"arrowdown3",OBJPROP_ANCHOR,ANCHOR_TOP); 
   ObjectSetInteger(0,"arrowdown3",OBJPROP_COLOR,clrRed); 
   ObjectSetInteger(0,"arrowdown3",OBJPROP_WIDTH,2);
   */
   return Low1;
}

