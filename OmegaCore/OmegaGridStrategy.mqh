//+------------------------------------------------------------------+
//|                                  OmegaCore/OmegaGridStrategy.mqh |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_GRIDSTRATEGY
#define OMEGA_GRIDSTRATEGY

#include "Strategy.mqh"
#include "LotCalc.mqh"
#include "MathUtils.mqh"

class OmegaGridStrategy : public Strategy
{
private:
   e_Direction m_Direction;      // Direction of the strategy
   int         m_Density;        // Number of orders to place within the Range
   double      m_Range;          // Price range the strategy operates within
   double      m_Buyprice;       // Current buy trigger price level
   double      m_Sellprice;      // Current sell trigger price level
   double      m_OrderPriceDiff; // Price difference between each level
   double      m_OrderStep;      // Lot multiplier between orders
   int         m_TotalOrders;    // Number of orders already opened

public:
   void     Density(int density)         { m_Density = density; }
   int      Density()                    { return m_Density; }
   double   Range()                      { return m_Range; }
   void     Range(double range)          { m_Range = range; }
   double   OrderStep()                  { return m_OrderStep; }
   void     OrderStep(double step)       { m_OrderStep = step; }

   // Validates that the current settings are executable
   bool     Check();

   // Sets all grid-specific parameters
   void     SetGridParams(int density, double range, double step, e_Direction Direction)
   {
      m_Density   = density;
      m_Range     = range;
      m_OrderStep = step;
      m_Direction = Direction;
   }

   bool     Run();

protected:
   virtual bool BuySignal();     // True when ask <= m_Buyprice
   virtual bool SellSignal();    // True when bid >= m_Sellprice
   virtual void OnBuySignal();   // Increases TotalOrders, multiplies m_Vol, moves Buyprice to next level
   virtual void OnSellSignal();  // Increases TotalOrders, multiplies m_Vol, moves Sellprice to next level
   virtual void OnRestart();     // Resets and reruns the grid
};

bool OmegaGridStrategy::Run()
{
   if(m_Density == 0 || m_Range == 0)
   {
      MessageBox("The density or the range is 0");
      return false;
   }
   m_OrderPriceDiff = m_Range / (m_Density - 1);
   if(m_Direction == Longonly)
      m_Buyprice = StartPrice();
   if(m_Direction == Shortonly)
      m_Sellprice = StartPrice();
   if(m_Direction == LongShort)
   {
      m_OrderPriceDiff = m_Range / m_Density;
      m_Buyprice       = StartPrice() - m_OrderPriceDiff;
      m_Sellprice      = StartPrice() + m_OrderPriceDiff;
   }
   m_TotalOrders = 0;
   m_Vol = StartLotInGrid(RiskLots(), m_OrderStep, m_Density);
   if(m_Vol < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      m_Vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(!Check())
      return false;
   bool flag = Strategy::Run();
   if(Exceeding_SL_in_Grid_trading(StartPrice(), m_Range, m_Density, m_OrderStep, m_Vol, m_Direction, StopLoss(), Leverage()))
      Print("The Stop loss may be hit before all the orders are executed.");
   return flag;
}

bool OmegaGridStrategy::BuySignal()
{
   if(m_Direction == Shortonly) return false;
   double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
   if(m_ReachedStart && ask <= m_Buyprice && m_TotalOrders < m_Density &&
      (m_Direction == Longonly || m_Sellprice == StartPrice() + m_OrderPriceDiff))
   {
      PrintFormat("BuySignal , Pricediff: %lf, Range : %lf,  density : %d, Startprice :% lf , BuyPrice %lf",
                  m_OrderPriceDiff, m_Range, m_Density, StartPrice(), m_Buyprice);
      return true;
   }
   return false;
}

bool OmegaGridStrategy::SellSignal()
{
   if(m_Direction == Longonly) return false;
   double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);
   if(m_ReachedStart && bid >= m_Sellprice && m_TotalOrders < m_Density &&
      (m_Direction == Shortonly || m_Buyprice == StartPrice() - m_OrderPriceDiff))
      return true;
   return false;
}

void OmegaGridStrategy::OnBuySignal()
{
   m_Vol *= m_OrderStep;
   m_Vol = MathMin(m_Vol, RiskLots());
   m_Buyprice -= m_OrderPriceDiff;
   m_TotalOrders++;
}

void OmegaGridStrategy::OnSellSignal()
{
   m_Vol *= m_OrderStep;
   m_Vol = MathMin(m_Vol, RiskLots());
   m_Sellprice += m_OrderPriceDiff;
   m_TotalOrders++;
}

bool OmegaGridStrategy::Check()
{
   double RiskLots  = RiskLots();
   int    Density   = Density();
   double OrderStep = OrderStep();
   double MinVol    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double MaxVol    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(OrderStep == 1 && RiskLots / Density < MinVol)
   {
      MessageBox("The volume is not enough to execute the strategy with the current density");
      return false;
   }
   double StartLot = OrderStep == 1
                     ? RiskLots / Density
                     : RiskLots / (MathPow(OrderStep, (double)Density) - 1) * (OrderStep - 1);
   StartLot = RoundtoLots(StartLot);

   if(StartLot > MaxVol || MathPow(OrderStep, (double)(Density - 1)) * StartLot > MaxVol)
   {
      MessageBox("The volume is too big to execute the strategy");
      return false;
   }
   if(MinVol > (StartLot * MathPow(OrderStep, (double)(Density - 1))) && OrderStep < 1)
   {
      MessageBox("The volume will become less than the minimal allowed volume for this symbol");
      return false;
   }
   if(!EnoughStart_GridSettings(RiskLots, OrderStep, Density))
   {
      double Min_Risk = RiskLots;
      while(!EnoughStart_GridSettings(Min_Risk, OrderStep, Density))
         Min_Risk += RoundtoLots(MinVol);
      double Validstep = OrderStep;
      while(!EnoughStart_GridSettings(RiskLots, Validstep, Density))
      {
         Validstep -= 0.01;
         if(Validstep < 0.3) { Validstep = 0; break; }
      }
      Validstep = Round(Validstep, 2);
      MessageBox(StringFormat(
         "Maximum orderstep for the current Density and Volume: %.2lf. "
         "Minimum Risk amount in Lots for the current Density and OrderStep : %.3lf",
         Validstep, RoundtoLots(Min_Risk)));
      return false;
   }
   return true;
}

void OmegaGridStrategy::OnRestart()
{
   Strategy::OnRestart();
   Range(m_Range);
   Density(m_Density);
   if(!Run())
      MessageBox("Could not restart Grid Strategy on " + m_Symbol);
   else
   {
      Print("Reset Grid strategy " + _Symbol);
      PrintFormat("StartPrice : %lf, Range : %lf, Risk : %lf, OrderStep : %lf, density :%d",
                  StartPrice(), Range(), RiskLots(), OrderStep(), Density());
      PrintFormat("TakeProfit : %lf, StopLoss : %lf", TakeProfit(), StopLoss());
   }
}

#endif // OMEGA_GRIDSTRATEGY
