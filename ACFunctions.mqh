//+------------------------------------------------------------------+
//|                                                  ACFunctions.mqh |
//|                                                          AC_2024 |
//|                                                                  |
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

//+------------------------------------------------------------------+
//| GET POSITION TICKET FOR 1 EA                                     |
//+------------------------------------------------------------------+ 
bool GetPosTicket(int i, ulong ticket, int EAMagicNumber){      
   if (ticket <= 0) { Print ("ERROR_ac: Failed to get position ticket!"); return false; }
   if (!PositionSelectByTicket(ticket)) { Print ("ERROR_ac: Failed to select position by ticket"); return false; } // "I like to selectPosition again (...) This updates the position data so we make sure we get a fresh position data"
   long magicnumber;
   if (!PositionGetInteger(POSITION_MAGIC, magicnumber)) { Print ("ERROR_ac: Failed to get position magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber == EAMagicNumber)
      return true;
   return true;
}

//+------------------------------------------------------------------+
//| GET ORDER TICKET FOR 1 EA                                        |
//+------------------------------------------------------------------+ 
bool GetOrTicket(int i, ulong ticket, int EAMagicNumber){      
   if (ticket <= 0) { Print ("ERROR_ac: Failed to get order ticket!"); return false; }
   if (!OrderSelect(ticket)) { Print ("ERROR_ac: Failed to select order by ticket"); return false; } // "I like to selectPosition again (...) This updates the position data so we make sure we get a fresh position data"
   long magicnumber;
   if (!OrderGetInteger(ORDER_MAGIC, magicnumber)) { Print ("ERROR_ac: Failed to get order magicnumber"); return false; } // Gets the value of POSITION_MAGIC and puts it in magicnumber
   if (magicnumber == EAMagicNumber)
      return true;
   return true;
}
         
//+------------------------------------------------------------------+
//| COUNT POSITIONS FOR 1 EA                                         |
//+------------------------------------------------------------------+ 
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

//+------------------------------------------------------------------+
//| COUNT OPEN ORDERS FOR 1 EA                                       |
//+------------------------------------------------------------------+ 
int CountOpenOrders(int EAMagicNumber)
{
   int counter = 0;
   int total = OrdersTotal();
   for (int i = total - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if (ticket <= 0) { Print ("ERROR_ac: Failed to get order ticket"); return -1; }
      if(GetOrTicket(i, ticket, EAMagicNumber)) counter++;      
   }
   return counter;
}

