# MQL5-Lab
A repository to test a trading strategy
//+------------------------------------------------------------------+
//| UltraCapitalProtector_Scalper_85Protect_ATR_Advanced.mq5         |
//| تم التعديل لإضافة حماية الأرباح (Breakeven)                      |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

//--- إعدادات المستخدم
input double RiskPercent = 1.0;
input ENUM_TIMEFRAMES TF = PERIOD_M15;
input int FastMA = 5;
input int SlowMA = 20;
input int TakeProfitATRMult = 3;
input double MinLot = 0.02;

input int ATRPeriod = 14;
input double ATRStopMult = 2.0;

input bool EnableATRTrail = true;
input double TrailATRMult = 1.0;

// --- تعديل: إضافة إعدادات حماية الربح (Breakeven)
input bool EnableBreakeven = true;      // تفعيل/تعطيل حماية الربح
input int  BreakevenPips = 20;          // عدد نقاط الربح لتفعيل الحماية
input int  LockInPips = 5;              // عدد نقاط الربح لتأمينها فوق سعر الدخول

input double MaxDailyDrawdownPct= 1.0;
input int MagicNumber = 12345;

input double LotMultiplier = 1.5;
input int MaxTrades = 20;
input double SuccessThreshold = 50.0;

//--- حماية رأس المال
double ProtectedCapital = 0.0;
bool Initialized = false;

double LastTradeResult = 0.0;

datetime DayStart;
double DayHighEquity;
double DayLowEquity;

//--- الذاكرة
struct TradeMemory { string dir; double fma; double sma; double result; };
TradeMemory memoryBuffer[];

int fastHandle = INVALID_HANDLE, slowHandle = INVALID_HANDLE, atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit(){
   fastHandle = iMA(_Symbol,TF,FastMA,0,MODE_EMA,PRICE_CLOSE);
   slowHandle = iMA(_Symbol,TF,SlowMA,0,MODE_EMA,PRICE_CLOSE);
   atrHandle = iATR(_Symbol,TF,ATRPeriod);
   if(fastHandle==INVALID_HANDLE||slowHandle==INVALID_HANDLE||atrHandle==INVALID_HANDLE) return INIT_FAILED;

   ProtectedCapital = AccountInfoDouble(ACCOUNT_BALANCE)*0.85;
   DayStart = iTime(_Symbol, PERIOD_D1, 0);
   DayHighEquity = DayLowEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   Initialized = true;
   PrintFormat(" حماية رأس المال 85%% مبدئياً: %.2f",ProtectedCapital);
   return INIT_SUCCEEDED;
}

void OnTick(){
   if(!Initialized) return;

   if(iTime(_Symbol,PERIOD_D1,0)>DayStart){
      DayStart = iTime(_Symbol,PERIOD_D1,0);
      DayHighEquity = DayLowEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   DayHighEquity = MathMax(DayHighEquity, equity);
   DayLowEquity = MathMin(DayLowEquity, equity);

   // حماية من الخسارة اليومية
   if((DayHighEquity - equity)/DayHighEquity * 100.0 > MaxDailyDrawdownPct){
      Print(" تم الوصول للحد الأقصى للخسارة اليومية، إيقاف التداول.");
      return;
   }

   // حماية من انخفاض الرصيد بنسبة كبيرة
   if(balance < ProtectedCapital * 0.80){
      Print(" توقف التداول: الرصيد انخفض عن 80%% من رأس المال المحمي.");
      return;
   }

   // تعزيز الحماية من الأرباح
   double profitBuffer = balance - ProtectedCapital;
   if(profitBuffer > 0){
      ProtectedCapital += profitBuffer * 0.30;
   }

   // حماية من التراجع الكبير في Equity
   if((DayHighEquity - equity)/DayHighEquity * 100.0 > 10.0){
      Print(" توقف التداول: خسارة كبيرة مقارنة بأعلى مستوى للجلسة.");
      return;
   }

   double newProt = balance * 0.85;
   if(newProt > ProtectedCapital)
      ProtectedCapital = newProt;

   ManageOpenPositions(); // تعديل: تم تغيير اسم الدالة

   double fastArr[1], slowArr[1], atrArr[1];
   if(CopyBuffer(fastHandle,0,0,1,fastArr)!=1||
      CopyBuffer(slowHandle,0,0,1,slowArr)!=1||
      CopyBuffer(atrHandle,0,0,1,atrArr)!=1) return;

   double fast=fastArr[0], slow=slowArr[0], atr=atrArr[0];

   if(fast > slow)
      OpenTrade(ORDER_TYPE_BUY, fast, slow, atr);
   else if(fast < slow)
      OpenTrade(ORDER_TYPE_SELL, fast, slow, atr);
}

void OpenTrade(int type,double fma,double sma,double atr){
   if(CountPositions(type)>=MaxTrades) return;
   double success=GetSignalSuccessRate(type==ORDER_TYPE_BUY?"buy":"sell",fma,sma);
   double slDist=atr*ATRStopMult;
   double tpDist=atr*TakeProfitATRMult;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double lot=CalcLotSize(slDist/tickSize, success);
   if(lot<=0) return;
   double price=(type==ORDER_TYPE_BUY?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double sl=(type==ORDER_TYPE_BUY?price-slDist:price+slDist);
   double tp=(type==ORDER_TYPE_BUY?price+tpDist:price-tpDist);
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(5);
   if(type==ORDER_TYPE_BUY) trade.Buy(lot,_Symbol,price,sl,tp);
   else trade.Sell(lot,_Symbol,price,sl,tp);
}

// تعديل: تم دمج وإضافة منطق حماية الربح (Breakeven)
void ManageOpenPositions(){
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol){
         long type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl_old = PositionGetDouble(POSITION_SL);

         // --- منطق حماية الربح (Breakeven) ---
         if(EnableBreakeven){
            double breakeven_price = open_price + (BreakevenPips * point * (type == POSITION_TYPE_BUY ? 1 : -1));
            double lock_in_price = open_price + (LockInPips * point * (type == POSITION_TYPE_BUY ? 1 : -1));

            bool should_breakeven = false;
            if(type == POSITION_TYPE_BUY && current_price >= breakeven_price && lock_in_price > sl_old){
               should_breakeven = true;
            }
            if(type == POSITION_TYPE_SELL && current_price <= breakeven_price && lock_in_price < sl_old){
               should_breakeven = true;
            }

            if(should_breakeven){
               // تعديل وقف الخسارة إلى نقطة تأمين الربح
               if(trade.PositionModify(ticket, lock_in_price, PositionGetDouble(POSITION_TP))){
                  PrintFormat("حماية الربح مفعلة للصفقة #%d: تم نقل وقف الخسارة إلى %.5f", ticket, lock_in_price);
                  // ننتقل للصفقة التالية لأن وقف الخسارة تم تعديله للتو
                  continue;
               }
            }
         }

         // --- منطق الوقف المتحرك (Trailing Stop) ---
         if(EnableATRTrail){
            double atr = GetCurrentATR() * TrailATRMult;
            double sl_new = (type == POSITION_TYPE_BUY) ? current_price - atr : current_price + atr;
           
            if((type == POSITION_TYPE_BUY && sl_new > sl_old) || (type == POSITION_TYPE_SELL && sl_new < sl_old)){
               if(trade.PositionModify(ticket, sl_new, PositionGetDouble(POSITION_TP))){
                  PrintFormat("وقف متحرك للصفقة #%d: تم تحديث وقف الخسارة إلى %.5f", ticket, sl_new);
               }
            }
         }
      }
   }
}


// دوال مساعدة

int CountPositions(int type){
   int cnt=0;
   for(int i=0;i<PositionsTotal();i++){
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)&&PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_TYPE)==type&&PositionGetInteger(POSITION_MAGIC)==MagicNumber)
         cnt++;
   }
   return cnt;
}

double GetSignalSuccessRate(string dir,double fma,double sma){
   int total=0,success=0;
   for(int i=0;i<ArraySize(memoryBuffer);i++){
      if(memoryBuffer[i].dir==dir&&MathAbs(memoryBuffer[i].fma-fma)<1.0&&MathAbs(memoryBuffer[i].sma-sma)<1.0){
         total++; if(memoryBuffer[i].result>0) success++;
      }
   }
   return total>0?(success*100.0/total):50.0;
}

double CalcLotSize(double stopLossUnits,double successRate){
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double freeProfit=balance-ProtectedCapital;
   if(freeProfit<=0) return 0.0;
   double risk=freeProfit*RiskPercent/100.0;
   double slValue=stopLossUnits*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lot=risk/slValue;
   if(successRate>=SuccessThreshold) lot*=LotMultiplier;
   int digits=(int)MathRound(-MathLog10(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)));
   lot=NormalizeDouble(lot,digits);
   lot=MathMax(lot,MinLot);
   return MathMin(lot,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
}

double GetCurrentATR(){
   double arr[1];
   if(CopyBuffer(atrHandle,0,0,1,arr)!=1) return 0.0;
   return arr[0];
}

void RecordTrade(string dir,double fma,double sma,double result){
   TradeMemory mem={dir,fma,sma,result};
   ArrayResize(memoryBuffer,ArraySize(memoryBuffer)+1);
   memoryBuffer[ArraySize(memoryBuffer)-1]=mem;
   LastTradeResult=result;
}

