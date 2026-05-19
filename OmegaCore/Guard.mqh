//+------------------------------------------------------------------+
//|                                             OmegaCore/Guard.mqh  |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
// GUARD - Emergency Rescue System
// Aktivizohet automatikisht kur basket ka humbje
// Hap nje order rescue me volum maksimal te brokerit
// Llogarit dinamikisht sa pips duhen per te rikuperuar humbjen
// Dallon rescue order me comment "GUARD_RESCUE"
// Nuk ka parametra external - gjithe logjika eshte dinamike
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Emergency Rescue System"

#ifndef OMEGA_GUARD
#define OMEGA_GUARD

#include "Defines.mqh"
#include "TradeUtils.mqh"
#include "MathUtils.mqh"

#define GUARD_COMMENT "GUARD_RESCUE"

class Guard
{
private:
   int      m_Magic;          // Magic i strategjise (i njejte - rescue dallohet me comment)
   string   m_Symbol;

public:
   Guard()                    { m_Magic = 0; m_Symbol = ""; }
   void     Init(int magic, string symbol) { m_Magic = magic; m_Symbol = symbol; }
   bool     IsRescueOpen();   // Kontrollon nese eshte hapur rescue order
   bool     onTick(double BasketProfit);  // True = rescue aktiv, bllokon strategjine

private:
   bool     OpenRescue(double BasketLoss);
   void     CloseRescue();
   double   RescueProfit();
   double   CalcRescueVolume(double BasketLoss, double PipsNeeded);
   double   CalcPipsNeeded(double BasketLoss, double Volume);
   double   CalcMaxAffordableVolume(int Direction, double Price);
   int      TrendDirection();
};


//--- Kontrollon nese rescue order eshte hapur (identifikohet me comment GUARD_RESCUE)
bool Guard::IsRescueOpen()
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      pos.SelectByIndex(i);
      if(pos.Symbol() == m_Symbol && pos.Magic() == m_Magic && pos.Comment() == GUARD_COMMENT)
         return true;
   }
   return false;
}

//--- Kthen fitimin/humbjen e rescue order
double Guard::RescueProfit()
{
   CPositionInfo pos;
   double profit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      pos.SelectByIndex(i);
      if(pos.Symbol() == m_Symbol && pos.Magic() == m_Magic && pos.Comment() == GUARD_COMMENT)
         profit += pos.Profit();
   }
   return profit;
}

//--- Trend: krahason Close[1] me Close[10]
int Guard::TrendDirection()
{
   double c1  = iClose(m_Symbol, PERIOD_CURRENT, 1);
   double c10 = iClose(m_Symbol, PERIOD_CURRENT, 10);
   return (c1 > c10) ? OP_BUY : OP_SELL;
}

//--- Sa pips duhen me volumin e dhene per te rikuperuar humbjen
double Guard::CalcPipsNeeded(double BasketLoss, double Volume)
{
   if(Volume <= 0) return 0;
   double TickVal  = SymbolInfoDouble(m_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double TickSize = SymbolInfoDouble(m_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double Pt       = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
   double ProfitPerPip = (TickVal / TickSize) * Pt * Volume;
   if(ProfitPerPip <= 0) return 0;
   return MathCeil(MathAbs(BasketLoss) / ProfitPerPip);
}

//--- Llogarit volumin: fillon me MaxVolume te brokerit
double Guard::CalcRescueVolume(double BasketLoss, double PipsNeeded)
{
   double MaxVol = SymbolInfoDouble(m_Symbol, SYMBOL_VOLUME_MAX);
   double MinVol = SymbolInfoDouble(m_Symbol, SYMBOL_VOLUME_MIN);
   double TickVal  = SymbolInfoDouble(m_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double TickSize = SymbolInfoDouble(m_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double Pt       = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
   double ProfitPerPip = (TickVal / TickSize) * Pt;
   double Required = MathAbs(BasketLoss) / (ProfitPerPip * PipsNeeded);
   double Vol = MathMin(RoundtoLots(Required), MaxVol);
   return MathMax(Vol, MinVol);
}

//--- Volumi maksimal qe mund te hapet sipas free margin (jo thjesht max i brokerit)
double Guard::CalcMaxAffordableVolume(int Direction, double Price)
{
   double marginPerLot = 0.0;
   if(!OrderCalcMargin((ENUM_ORDER_TYPE)Direction, m_Symbol, 1.0, Price, marginPerLot))
      return 0.0;

   if(marginPerLot <= 0.0)
      return 0.0;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin <= 0.0)
      return 0.0;

   double maxByMargin = freeMargin / marginPerLot;
   return RoundtoLots(maxByMargin);
}

//--- Hap rescue order
bool Guard::OpenRescue(double BasketLoss)
{
   int    Direction   = TrendDirection();
   double Ask         = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
   double Bid         = SymbolInfoDouble(m_Symbol, SYMBOL_BID);
   double EntryPrice  = (Direction == OP_BUY) ? Ask : Bid;

   // Max volumi real = min(max broker, max sipas free margin)
   double brokerMax   = SymbolInfoDouble(m_Symbol, SYMBOL_VOLUME_MAX);
   double marginMax   = CalcMaxAffordableVolume(Direction, EntryPrice);
   double MaxVol      = MathMin(brokerMax, marginMax);
   double MinVol      = SymbolInfoDouble(m_Symbol, SYMBOL_VOLUME_MIN);

   if(MaxVol < MinVol)
   {
      PrintFormat("GUARD: Not enough margin for rescue. FreeMargin=%.2f, MinVol=%.2f", AccountInfoDouble(ACCOUNT_MARGIN_FREE), MinVol);
      return false;
   }

   double PipsNeeded  = CalcPipsNeeded(BasketLoss, MaxVol);
   if(PipsNeeded <= 0)
      return false;

   double Volume      = CalcRescueVolume(BasketLoss, PipsNeeded);
   Volume             = MathMin(Volume, MaxVol);
   if(Volume < MinVol)
      return false;

   // TP ne cmim
   double Pt          = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
   double TP          = (Direction == OP_BUY) ? Ask + PipsNeeded * Pt : Bid - PipsNeeded * Pt;

   CTrade Trade;
   Trade.SetExpertMagicNumber(m_Magic);
   Trade.SetDeviationInPoints(50);

   bool ok = false;
   if(Direction == OP_BUY)
      ok = Trade.Buy(Volume, m_Symbol, Ask, 0, TP, GUARD_COMMENT);
   else
      ok = Trade.Sell(Volume, m_Symbol, Bid, 0, TP, GUARD_COMMENT);

   if(ok)
      PrintFormat("GUARD RESCUE %s opened | Vol=%.2f | Pips=%.0f | BasketLoss=%.2f",
                  Direction == OP_BUY ? "BUY" : "SELL", Volume, PipsNeeded, BasketLoss);
   else
      Print("GUARD: Failed to open rescue order");

   return ok;
}

//--- Mbyll vetem rescue order (jo basket)
void Guard::CloseRescue()
{
   CTrade        Trade;
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      pos.SelectByIndex(i);
      if(pos.Symbol() == m_Symbol && pos.Magic() == m_Magic && pos.Comment() == GUARD_COMMENT)
      {
         Trade.PositionClose(pos.Ticket());
         PrintFormat("GUARD: Rescue closed | Profit=%.2f", pos.Profit());
      }
   }
}

//--- Thirrjet kryesore ne cdo tick
//    Kthen TRUE nese rescue eshte aktiv (strategjia normale bllokohet)
bool Guard::onTick(double BasketProfit)
{
   if(m_Magic == 0) return false; // Guard nuk eshte inicializuar

   // Nese rescue eshte hapur, monitoro
   if(IsRescueOpen())
   {
      double Total = BasketProfit + RescueProfit();
      if(Total >= 0)
      {
         PrintFormat("GUARD SUCCESS: Total=%.2f (Basket=%.2f + Rescue=%.2f). Closing rescue.",
                     Total, BasketProfit, RescueProfit());
         CloseRescue();
         return false; // Rescue u mbyll, strategjia vazhdon
      }
      return true; // Rescue aktiv, bllokon strategjine
   }

   // Nese basket ka humbje dhe nuk ka rescue te hapur, hap rescue
   if(BasketProfit < 0)
   {
      Print("GUARD ACTIVATED: BasketLoss=" + DoubleToString(BasketProfit, 2));
      return OpenRescue(BasketProfit);
   }

   return false;
}

#endif // OMEGA_GUARD
