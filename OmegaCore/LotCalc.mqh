//+------------------------------------------------------------------+
//|                                            OmegaCore/LotCalc.mqh |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_LOTCALC
#define OMEGA_LOTCALC

#include "Defines.mqh"
#include "MathUtils.mqh"
#include "TradeUtils.mqh"

// Calculates the Lot size of a trade with a TakeProfit parameter in monetary amount
double CalcLotWithTP(int Direction, double TakeProfit, double StartPrice, double EndPrice, int leverage)
{
   if(StartPrice == EndPrice)
      return -1;
   double ProfitFact = Direction == OP_BUY ? (EndPrice / StartPrice - 1) : (1 - EndPrice / StartPrice);
   double MoneyAmount = TakeProfit / ProfitFact;
   double ret = MoneyAmount / LotSize(StartPrice);
   double roundedVal = 0.0;
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.01)
      roundedVal = Round(ret, 2) >= ret ? Round(ret, 2) : Round(ret, 2) + 0.01;
   else if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.1)
      roundedVal = Round(ret, 1) >= ret ? Round(ret, 1) : Round(ret, 1) + 0.1;
   else if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.001)
      roundedVal = Round(ret, 3) >= ret ? Round(ret, 3) : Round(ret, 3) + 0.001;
   else
      roundedVal = Round(ret, 0) >= ret ? Round(ret, 0) : Round(ret, 0) + 1;
   if(roundedVal < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   return roundedVal;
}

// Returns true if with the current starting lot size the Grid Strategy is executable
bool RightStartInGrid(double Startlot, double RiskLots, double OrderStep, int Density)
{
   double UsedLot = 0;
   for(int i = 0; i < Density; i++)
   {
      UsedLot += RoundtoLots(Startlot);
      Startlot *= OrderStep;
   }
   return UsedLot <= RiskLots;
}

// Returns the starting lot size for a Grid Strategy
double StartLotInGrid(double RiskLots, double OrderStep, int Density)
{
   double StartVol = OrderStep == 1 ? RiskLots / Density : RiskLots / (MathPow(OrderStep, Density) - 1) * (OrderStep - 1);
   if(StartVol < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      StartVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double Diff = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) / 1000;
   if(OrderStep == 1) return RoundtoLots(StartVol);
   while(RightStartInGrid(StartVol, RiskLots, OrderStep, Density))
   {
      StartVol += Diff;
   }
   StartVol -= Diff;
   return StartVol;
}

// Returns true if the RiskLots volume is enough to execute a Grid strategy
// with a given OrderStep multiplier and Density (amount of orders)
bool EnoughStart_GridSettings(double RiskLots, double OrderStep, int Density)
{
   double Startlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double UsedLot = 0;
   for(int i = 0; i < Density; i++)
   {
      UsedLot += RoundtoLots(Startlot);
      Startlot *= OrderStep;
   }
   return (UsedLot <= RiskLots);
}

// Returns true when the Stop Loss of a Grid Strategy may be hit before opening all orders
bool Exceeding_SL_in_Grid_trading(double Start, double Range, int Density, double OrderStep, double StartLot, e_Direction Direction, double SL, int leverage)
{
   double Theoretical_Loss = 0.0;
   if(Direction != Shortonly)
   {
      double End = Start - Range;
      for(int i = 0; i < Density; i++)
      {
         double trueval = LotSize() * RoundtoLots(StartLot);
         Theoretical_Loss += MathAbs(trueval - trueval * Start / End);
         StartLot *= OrderStep;
         Start -= Range / (Density - 1);
      }
   }
   if(Direction == Shortonly)
   {
      double End = Start + Range;
      for(int i = 0; i < Density; i++)
      {
         double trueval = LotSize() * RoundtoLots(StartLot);
         Theoretical_Loss += MathAbs(trueval - trueval * End / Start);
         StartLot *= OrderStep;
         Start += Range / (Density - 1);
      }
   }
   if(Theoretical_Loss >= MathAbs(SL))
      return true;
   return false;
}

// Calculates the maximum amount of orders for a Martingale Strategy
int CalcMaxOrders(double LongPrice, double LongTPPrice, double SellPrice, double SellTPPrice, double RiskAmount, double StopLoss, double TakeProfit, int leverage)
{
   double Used_Lots = MathMax(CalcLotWithTP(OP_BUY, TakeProfit, LongPrice, LongTPPrice, leverage),
                              CalcLotWithTP(OP_SELL, TakeProfit, SellPrice, SellTPPrice, leverage));
   double SellLots = 0.0, BuyLots = 0.0;
   if(CalcLotWithTP(OP_BUY, TakeProfit, LongPrice, LongTPPrice, leverage) <
      CalcLotWithTP(OP_SELL, TakeProfit, SellPrice, SellTPPrice, leverage))
      SellLots = Used_Lots;
   else
      BuyLots = Used_Lots;
   int ret = 0;
   while(RoundtoLots(Used_Lots) <= RiskAmount)
   {
      ret++;
      if(SellLots > BuyLots)
      {
         if(TheoreticalProfits(Symbol(), SellLots, OP_SELL, SellPrice, LongPrice) < -MathAbs(StopLoss)) break;
         BuyLots += CalcLotWithTP(OP_BUY,
                                  TakeProfit - (TheoreticalProfits(Symbol(), SellLots, OP_SELL, SellPrice, LongTPPrice) +
                                               TheoreticalProfits(Symbol(), BuyLots, OP_BUY, LongPrice, LongTPPrice)),
                                  LongPrice, LongTPPrice, leverage);
      }
      else
      {
         if(TheoreticalProfits(Symbol(), BuyLots, OP_BUY, LongPrice, SellPrice) < -MathAbs(StopLoss)) break;
         SellLots += CalcLotWithTP(OP_SELL,
                                   TakeProfit - (TheoreticalProfits(Symbol(), SellLots, OP_SELL, SellPrice, SellTPPrice) +
                                                TheoreticalProfits(Symbol(), BuyLots, OP_BUY, LongPrice, SellTPPrice)),
                                   SellPrice, SellTPPrice, leverage);
      }
      Used_Lots = SellLots + BuyLots;
   }
   return ret;
}

#endif // OMEGA_LOTCALC
