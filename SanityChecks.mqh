//+------------------------------------------------------------------+
//|                                                 SanityChecks.mqh |
//|                                                          AC_2024 |
//|                                                                  |
//+------------------------------------------------------------------+

// Based on codes found in https://www.mql5.com/en/articles/2555

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
//||||||||||||||||||||||||| GENERAL CHECKS||||||||||||||||||||||||||||
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Stop Levels                                                |
//+------------------------------------------------------------------+  
// check for stop level (some brokers have a stop level so you cannot set the sl too close to the current price)
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
//+------------------------------------------------------------------+
//| Check if Enough Money                                            |
//+------------------------------------------------------------------+  
  
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


//+------------------------------------------------------------------+
//| Check the correctness of the order volume                        |
//+------------------------------------------------------------------+
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

  
//+------------------------------------------------------------------+
//| Check if another order can be placed                             |
//+------------------------------------------------------------------+
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
  
//+------------------------------------------------------------------+
//| IS TRADE ALLOWED? ||||||||||||||||||||||||||||||||||||||||||||||||
//+------------------------------------------------------------------+

// Check 4 things. The functions are int thar correspond to true/false so I convert it to bool
bool IsTradeAllowed() {
   return ( (bool)MQLInfoInteger     (MQL_TRADE_ALLOWED)       // Trading allowed in input dialog
         && (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)  // Trading allowed in terminal
         && (bool)AccountInfoInteger (ACCOUNT_TRADE_ALLOWED)   // Is account able to trade,
         && (bool)AccountInfoInteger (ACCOUNT_TRADE_EXPERT)    // Is account able to auto trade
         ); 
}        
         
//+------------------------------------------------------------------+
//| IS MARKET OPEN |||||||||||||||||||||||||||||||||||||||||||||||||||
//+------------------------------------------------------------------+

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
          