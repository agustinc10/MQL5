//+------------------------------------------------------------------+
//|                                                  ACFunctions.mqh |
//|                                                          AC_2024 |
//|                                                                  |
//+------------------------------------------------------------------+

// Based on code found in https://www.youtube.com/watch?v=jbYrB360bCM&list=PLGjfbI-PZyHW4fWaAYrSo4gRpCGNPH-ae&index=3

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
//| FUNCTIONS IN THIS FILE |||||||||||||||||||||||||||||||||||||||||||
//+------------------------------------------------------------------+ 

/*
- CalculateRange()
- DrawObjects()             //Necessary for CalculateRange()
*/

//+------------------------------------------------------------------+
//| CALCULATE TIME RANGE |||||||||||||||||||||||||||||||||||||||||||||
//+------------------------------------------------------------------+    

// Para poder usar esta función, en el EA tengo que crear las siguientes variables:
// MqlTick prevTick, lastTick;

input group "==== Range Inputs ===="
input int InpRangeStart     = 120;     // range start time in minutes (after midnight). (ex: 600min is 10am)
input int InpRangeDuration  = 1260;    // range duration in minutes (ex: 120min = 2hs)
input int InpRangeClose     = 1410;    // range close time in minutes (ex: 1200min = 20hs) (-1 = off)

input group "==== Day of week filter ===="
input bool InpMonday    = true;        // range on Monday
input bool InpTuesday   = true;        // range on Tuesday
input bool InpWednesday = true;        // range on Wednesday
input bool InpThursday  = true;        // range on Thursday
input bool InpFriday    = true;        // range on Friday   

// "All the variables for the range we'll put them together in a structure"
struct RANGE_STRUCT
{
   datetime start_time;    // start of the range
   datetime end_time;      // end of the range
   datetime close_time;    // close time (where we will close the trades)
   //double high;            // high of the range             
   //double low;             // low of the range
   bool f_entry;           // flag if we are in the range 
   //bool f_high_breakout;   // flag if a high breakout occurred
   //bool f_low_breakout;    // flag if a low breakout occurred
   
   // "define a constructor for the structue, and here we just predifine our variables"
   RANGE_STRUCT(): start_time(0), end_time(0), close_time(0), f_entry(false) {};
};

RANGE_STRUCT trange;

bool CheckInputsTimeRange() {
   // check for correct input from user
   /*
   if (InpRangeClose < 0 && AtrLossMulti == 0) {      // AtrLossMulti as a ATR factor to culculate SL
      Alert ("Both close time and stop loss are off"); 
      return false;
      } 
   */     
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
   if (InpMonday + InpTuesday + InpWednesday + InpThursday + InpFriday == 0) { 
      Alert ("Range is prohibited on all days of the week"); 
      return false;
   }   
   
   return true;
}

void CalculateRange()
{
   // Reset all range variables 
   trange.start_time        = 0;
   trange.end_time          = 0;
   trange.close_time        = 0;
   trange.f_entry           = false; 

   // calculate range start time
   int time_cycle = 86400;                                                                   // seconds in a day
   trange.start_time = (lastTick.time - (lastTick.time % time_cycle)) + InpRangeStart * 60;   // calculates the start of each day and sums the InpRangeStart
   // for loop to shift the start time to the next working day (skipping saturday and sunday)
   for (int i = 0; i < 8; i++)                                                               
   {
      MqlDateTime tmp;                          // The date type structure contains eight fields of the int type
      TimeToStruct (trange.start_time, tmp);     // Converts a value of datetime type (number of seconds since 01.01.1970) into a structure variable MqlDateTime.
      int dow = tmp.day_of_week;
      if (lastTick.time >= trange.start_time || dow == 6 || dow == 0 
         || (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday) || (dow == 3 && !InpWednesday) || (dow == 4 && !InpThursday) || (dow == 5 && !InpFriday))
         trange.start_time += time_cycle;       
   }
   
   // calculate range end time
   trange.end_time = trange.start_time + InpRangeDuration * 60; // If the range end goes to another day and that day is weekend, we have to shift it to monday
   for (int i = 0; i < 2; i++)
   {
      MqlDateTime tmp;                        // The date type structure contains eight fields of the int type
      TimeToStruct (trange.end_time, tmp);     // Converts a value of datetime type (number of seconds since 01.01.1970) into a structure variable MqlDateTime.
      int dow = tmp.day_of_week;
      if (dow == 6 || dow == 0)
         trange.end_time += time_cycle;       
   }

   // calculate range close
   if(InpRangeClose >= 0)
   {
      trange.close_time = (trange.end_time - (trange.end_time % time_cycle)) + InpRangeClose * 60;   // calculates the close of each day and sums the InpRangeClose
      for (int i = 0; i < 3; i++)
      {
         MqlDateTime tmp;                        // The date type structure contains eight fields of the int type
         TimeToStruct (trange.close_time, tmp);     // Converts a value of datetime type (number of seconds since 01.01.1970) into a structure variable MqlDateTime.
         int dow = tmp.day_of_week;
         if (trange.close_time <= trange.end_time || dow == 6 || dow == 0)
            trange.close_time += time_cycle;       
      }
   }
   // draw object
   DrawObjects();
} 


//+------------------------------------------------------------------+
//| DRAW OBJECTS |||||||||||||||||||||||||||||||||||||||||||||||||||||
//+------------------------------------------------------------------+    

void DrawObjects()
{
   // start time
   ObjectDelete(NULL, "range start");     // We always want to draw a new start time
   if (trange.start_time > 0)               // Check if there is a start time calculated
   {
      ObjectCreate(NULL, "range start", OBJ_VLINE, 0, trange.start_time, 0);         // Create a vertical line in the current chart named "range start" at range.start_time
      ObjectSetString(NULL, "range start", OBJPROP_TOOLTIP, "start of the range \n" + TimeToString(trange.start_time, TIME_DATE|TIME_MINUTES));  // Set description for the object
      ObjectSetInteger(NULL, "range start", OBJPROP_COLOR, clrBlue);                // Change Color
      ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 2);                      // Change width of drawing
      ObjectSetInteger(NULL, "range start", OBJPROP_BACK, true);                    // Set object to background                 
   }
   
   // end time
   ObjectDelete(NULL, "range end");     // We always want to draw a new end time
   if (trange.end_time > 0)               // Check if there is a end time calculated
   {
      ObjectCreate(NULL, "range end", OBJ_VLINE, 0, trange.end_time, 0);           // Create a vertical line in the current chart named "range end" at range.end_time
      ObjectSetString(NULL, "range end", OBJPROP_TOOLTIP, "end of the range \n" + TimeToString(trange.end_time, TIME_DATE|TIME_MINUTES));  // Set description for the object
      ObjectSetInteger(NULL, "range end", OBJPROP_COLOR, clrBlue);                // Change Color
      ObjectSetInteger(NULL, "range end", OBJPROP_WIDTH, 2);                      // Change width of drawing
      ObjectSetInteger(NULL, "range end", OBJPROP_BACK, true);                    // Set object to background                 
   }   

   // close time
   ObjectDelete(NULL, "range close");     // We always want to draw a new close time
   if (trange.close_time > 0)               // Check if there is a close time calculated
   {
      ObjectCreate(NULL, "range close", OBJ_VLINE, 0, trange.close_time, 0);         // Create a vertical line in the current chart named "range close" at range.close_time
      ObjectSetString(NULL, "range close", OBJPROP_TOOLTIP, "close of the range \n" + TimeToString(trange.close_time, TIME_DATE|TIME_MINUTES));  // Set description for the object
      ObjectSetInteger(NULL, "range close", OBJPROP_COLOR, clrRed);                 // Change Color
      ObjectSetInteger(NULL, "range close", OBJPROP_WIDTH, 2);                      // Change width of drawing
      ObjectSetInteger(NULL, "range close", OBJPROP_BACK, true);                    // Set object to background                 
   }   

   // refresh chart
   ChartRedraw();
   
} 