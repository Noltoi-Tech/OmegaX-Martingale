//+------------------------------------------------------------------+
//|                           OmegaCore/OmegaMartingaleStrategy.mqh  |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_MARTINGALESTRATEGY
#define OMEGA_MARTINGALESTRATEGY

#include "Strategy.mqh"
#include "LotCalc.mqh"

class OmegaMartingaleStrategy : public Strategy
{
private:
   double m_BuyLevel;   // The buy trigger price level
   double m_SellLevel;  // The sell trigger price level
   double m_Range;      // Range: Buy TP = StartPrice + Range, Sell TP = StartPrice - Range
   double m_SellLots;   // Accumulated lots used for sell orders
   double m_BuyLots;    // Accumulated lots used for buy orders
   int    m_Maxorders;  // Maximum number of orders allowed
   int    m_Orders;     // Number of trades opened so far

public:
   // Sets the Martingale-specific parameters
   void     SetMartinGale(double Range, double BuyLevel, double SellLevel);
   bool     Run();
   double   Range()           { return m_Range; }
   void     Range(double range) { m_Range = range; }
   double   SellPrice()       { return m_SellLevel; }
   double   BuyPrice()        { return m_BuyLevel; }

protected:
   virtual bool BuySignal();     // True when ask > m_BuyLevel
   virtual bool SellSignal();    // True when bid < m_SellLevel
   virtual void OnBuySignal();   // Increases m_Orders, adds to m_BuyLots
   virtual void OnSellSignal();  // Increases m_Orders, adds to m_SellLots
   virtual void OnRestart();     // Resets and reruns the strategy
};

void OmegaMartingaleStrategy::SetMartinGale(double Range, double BuyLevel, double SellLevel)
{
   m_Range     = Range;
   m_SellLevel = SellLevel;
   m_BuyLevel  = BuyLevel;
   m_BuyLots   = 0;
   m_SellLots  = 0;
   m_Maxorders = 0;
   m_Orders    = 0;
}

bool OmegaMartingaleStrategy::Run()
{
   if(!m_Range || !m_BuyLevel || !m_SellLevel)
   {
      MessageBox("Could not start strategy need all following informations: Range, Buylevel, SellLevel");
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED))
   {
      MessageBox("This Account does not allow Hedging");
      return false;
   }
   m_BuyLots  = 0;
   m_SellLots = 0;
   m_Orders   = 0;
   m_Vol = CalcLotWithTP(OP_BUY, TakeProfit(), StartPrice(), StartPrice() + m_Range, Leverage());
   if(m_Vol < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      MessageBox("The starting volume is too little to execute the strategy with the given parameters");
      return false;
   }
   if(m_Vol > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX))
   {
      MessageBox("The starting volume is too big to execute the strategy with the given parameters");
      return false;
   }
   m_Maxorders = CalcMaxOrders(m_BuyLevel, StartPrice() + m_Range,
                                m_SellLevel, StartPrice() - m_Range,
                                RiskLots(), StopLoss(), TakeProfit(), Leverage());
   PrintFormat("Amount of maximum orders: %d", m_Maxorders);
   if(m_Maxorders < 2)
   {
      MessageBox("Can not start Martin gale strategy, amount of orders would be less than 2");
      return false;
   }
   return Strategy::Run();
}

bool OmegaMartingaleStrategy::BuySignal()
{
   if(m_SellLots < m_BuyLots) return false;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(m_ReachedStart && ask > m_BuyLevel && m_Orders < m_Maxorders)
   {
      m_Vol = CalcLotWithTP(OP_BUY, TakeProfit() - Profits(), ask, StartPrice() + m_Range, Leverage());
      m_Vol = MathMin(m_Vol, RiskLots());
      return true;
   }
   return false;
}

bool OmegaMartingaleStrategy::SellSignal()
{
   if(m_BuyLots < m_SellLots) return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(m_ReachedStart && bid < m_SellLevel && m_Orders < m_Maxorders)
   {
      m_Vol = CalcLotWithTP(OP_SELL, TakeProfit() - Profits(), bid, StartPrice() - m_Range, Leverage());
      m_Vol = MathMin(m_Vol, RiskLots());
      return true;
   }
   return false;
}

void OmegaMartingaleStrategy::OnBuySignal()
{
   m_Orders++;
   m_BuyLots += m_Vol;
}

void OmegaMartingaleStrategy::OnSellSignal()
{
   m_Orders++;
   m_SellLots += m_Vol;
}

void OmegaMartingaleStrategy::OnRestart()
{
   double BuyStartDiff  = m_BuyLevel  - StartPrice();
   double SellStartDiff = StartPrice() - m_SellLevel;
   Strategy::OnRestart();
   m_SellLevel = StartPrice() - SellStartDiff;
   m_BuyLevel  = StartPrice() + BuyStartDiff;
   if(!Run())
   {
      MessageBox("Could not restart Martin Gale Strategy on " + m_Symbol);
      return;
   }
   else
   {
      Print("Reset Martin Gale strategy: " + _Symbol);
      PrintFormat("StartPrice : %lf, Range : %lf, Risk : %lf, BuyPrice : %lf,  SellPrice :%lf",
                  StartPrice(), Range(), RiskLots(), BuyPrice(), SellPrice());
      PrintFormat("TakeProfit : %lf, StopLoss : %lf", TakeProfit(), StopLoss());
   }
}

#endif // OMEGA_MARTINGALESTRATEGY
