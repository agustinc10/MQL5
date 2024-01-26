//+------------------------------------------------------------------+
//|                                                      LogFile.mqh |
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

#include <_Agustin\LogFile_functions.mqh>        // Required to generate the Deal Log File

double OnTester(){
   if(DiagnosticLoggingLevel < 1) return false;

   HistorySelect(0, TimeCurrent());   
   int numDeals = HistoryDealsTotal();  

   // Create Diagnostic File
   int outputFileHandle = INVALID_HANDLE;
   DiagnosticFile(DiagnosticLoggingLevel, outputFileHandle);
   for(int dealID = 0; dealID < numDeals; dealID++){ 
      ulong dealTicket = HistoryDealGetTicket(dealID); 
      // Output main data to file
      OutputMainData(DiagnosticLoggingLevel, outputFileHandle, dealTicket);    
   }  
   // Close data file   
   CloseDiagnosticFile(DiagnosticLoggingLevel, outputFileHandle);
   return true;
}
