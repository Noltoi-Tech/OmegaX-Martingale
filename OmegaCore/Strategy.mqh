//+------------------------------------------------------------------+
//|                                           OmegaCore/Strategy.mqh |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_STRATEGY
#define OMEGA_STRATEGY

#include "Defines.mqh"
#include "MathUtils.mqh"
#include "TradeUtils.mqh"
#include "Guard.mqh"

class Strategy
{
private:
   double      m_StopLossAmount;    // The StopLoss in monetary amount
   double      m_TakeProfitAmount;  // The TakeProfit in monetary amount
   int         m_MagicNumber;       // Strategy's Magic Number

   double      m_StartPrice;        // The StartPrice of the strategy
   bool        m_IsRunning;         // Is the strategy running?

   bool        m_StopafterClose;    // If true, strategy stops after hitting TP/SL; otherwise it restarts
   string      m_Name;              // Name of the Strategy
   double      m_Lots;              // The volume the strategy may use (in Lots)
   int         m_Leverage;          // The Leverage the strategy is working with
   
   Guard       m_Guard;             // Emergency Rescue Guard

// Visible to derived classes
protected:
   bool        m_ReachedStart;  // Is the start price reached?
   double      m_Vol;           // The volume for the next trade
   string      m_Symbol;        // The symbol of the strategy

public:
            Strategy();
   bool     Run();
   bool     IsRunning()                    { return m_IsRunning; }
   void     StopLoss(double Sl)            { m_StopLossAmount = Sl; }
   double   StopLoss()                     { return m_StopLossAmount; }
   void     TakeProfit(double Tp)          { m_TakeProfitAmount = Tp; }
   double   TakeProfit()                   { return m_TakeProfitAmount; }
   void     onTick();
   void     Name(string name)              { m_Name = name; }
   string   Name()                         { return m_Name; }
   void     Stop();
   void     SetParams(const string symbol, int magic, double Startprice, double Lots,
                      double TakeProfit, double StopLoss, bool StopafterClose, int Leverage);
   double   RiskLots()                     { return m_Lots; }
   void     RiskLots(double Lots)          { m_Lots = Lots; }
   int      Magic()                        { return m_MagicNumber; }
   void     Magic(int MagicNum)            { m_MagicNumber = MagicNum; }
   double   StartPrice()                   { return m_StartPrice; }
   void     StartPrice(double Price)       { m_StartPrice = Price; }
   void     StopAtClose(bool flag)         { m_StopafterClose = flag; }
   bool     StopAtClose()                  { return m_StopafterClose; }
   int      Leverage()                     { return m_Leverage; }
   double   Profits()                      { return OpenOrderProfits(m_MagicNumber, m_Symbol); }

protected:
   virtual bool BuySignal()    { return false; }   // Buy signal called in onTick(). If true -> opens buy with m_Vol
   virtual bool SellSignal()   { return false; }   // Sell signal called in onTick(). If true -> opens sell with m_Vol
   virtual void OnBuySignal()  = 0;                // Pure virtual — not instantiable
   virtual void OnSellSignal() { return; }
   virtual void OnRestart()
   {
      m_StartPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      m_ReachedStart = true;
   }
};

Strategy::Strategy()
{
   m_IsRunning        = false;
   m_StartPrice       = 0;
   m_ReachedStart     = false;
   m_StopLossAmount   = 0;
   m_TakeProfitAmount = 0;
   m_StopafterClose   = true;
   m_Lots             = 0;
   m_Vol              = 0;
}

void Strategy::SetParams(const string symbol, int magic, double Startprice, double Lots,
                         double TakeProfit, double StopLoss, bool StopafterClose, int leverage)
{
   m_StartPrice       = Startprice;
   m_Symbol           = symbol;
   m_MagicNumber      = magic;
   m_Lots             = Lots;
   m_TakeProfitAmount = TakeProfit;
   m_StopLossAmount   = StopLoss;
   m_StopafterClose   = StopafterClose;
   m_Leverage         = leverage;
   m_Guard.Init(magic, symbol); // Guard inicializohet automatikisht
}

bool Strategy::Run()
{
   if(m_StopLossAmount == 0 || m_TakeProfitAmount == 0 || m_StartPrice == 0 || m_MagicNumber == 0 || m_Lots == 0)
   {
      MessageBox("Could not run strategy, not enough information");
      return false;
   }
   if((m_StopLossAmount + LotSize() * m_Lots / m_Leverage) > AccountBalance())
   {
      MessageBox("The stop loss + the volume has to be smaller than the accountbalance");
      return false;
   }
   m_IsRunning = true;
   return true;
}

void Strategy::Stop()
{
   CloseAllOrders(m_Symbol, m_MagicNumber);
   m_ReachedStart = false;
   m_IsRunning    = false;
   CloseAllOrders(m_Symbol, m_MagicNumber);
   EventChartCustom(ChartID(), STRATEGY_STOP, 0, 0.0, Name());
}

void Strategy::onTick()
{
   if(!m_IsRunning) return;

   double currentProfit = OpenOrderProfits(m_MagicNumber, m_Symbol);

   double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

   if(!m_ReachedStart)
   {
      if((ask > m_StartPrice && bid < m_StartPrice) ||
         (ask - 10 * Point() < m_StartPrice && ask + 10 * Point() > m_StartPrice) ||
         (bid - 10 * Point() < m_StartPrice && bid + 10 * Point() > m_StartPrice))
         m_ReachedStart = true;
   }

   if(currentProfit > m_TakeProfitAmount)
   {
      Print("Closing out the " + m_Name + " Strategy on: " + m_Symbol +
            " with profits of:" + DoubleToString(currentProfit, 2));
      CloseAllOrders(m_Symbol, m_MagicNumber);
      if(m_StopafterClose) { Stop(); return; }
      OnRestart();
      return;
   }

   if(currentProfit < -m_StopLossAmount)
   {
      Print("Closing out the " + m_Name + " Strategy on: " + m_Symbol +
            " with a loss of:" + DoubleToString(currentProfit, 2));
      if(m_StopafterClose) { Stop(); return; }

      // Safe mode: no forced close, but also no restart-loop under deep drawdown.
      // Keep existing positions as they are and stop opening new ones.
      m_IsRunning = false;
      Print("SAFE MODE: Strategy paused after stop-loss to avoid restart loop and giveback.");
      return;
   }

   // === GUARD EMERGENCY RESCUE SYSTEM ===
   // Aktivizo Guard vetem kur basket afrohet te SL, jo ne cdo humbje te vogel.
   if(currentProfit <= -0.8 * m_StopLossAmount && m_Guard.onTick(currentProfit))
      return;

   // === NORMAL STRATEGY SIGNALS (vetëm nëse Guard nuk është aktiv) ===
   CTrade Trade;
   Trade.SetExpertMagicNumber(m_MagicNumber);
   Trade.SetDeviationInPoints(50);

   if(BuySignal())
   {
      double Vol = RoundtoLots(m_Vol);
      Trade.SetDeviationInPoints(50);
      if(CheckVolumeValue(Vol))
         Trade.Buy(Vol, m_Symbol, ask, 0, 0);
      else
         Print("Invalid Volume");
      OnBuySignal();
   }

   if(SellSignal())
   {
      double Vol = RoundtoLots(m_Vol);
      Trade.SetDeviationInPoints(50);
      if(CheckVolumeValue(Vol))
         Trade.Sell(Vol, m_Symbol, bid, 0, 0);
      else
         Print("Invalid Volume");
      OnSellSignal();
   }
}

#endif // OMEGA_STRATEGY
