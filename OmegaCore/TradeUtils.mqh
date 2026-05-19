//+------------------------------------------------------------------+
//|                                          OmegaCore/TradeUtils.mqh |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_TRADEUTILS
#define OMEGA_TRADEUTILS

#include "Defines.mqh"
#include "MathUtils.mqh"
#include "OmegaTrade.mqh"
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

// MQL4 compatibility — DoubleToStr
string DoubleToStr(double double_Val, int digits = 8)
{
   return DoubleToString(double_Val, digits);
}

// MQL4 compatibility — AccountBalance
double AccountBalance()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

// Closes all orders and positions for a given symbol and Magic Number.
// Pass MagicNumber = -1 to close all regardless of magic.
void CloseAllOrders(const string symbol, int MagicNumber = -1)
{
   CTrade        Trade;
   CPositionInfo PosInfo;
   COrderInfo    OrderInfo;

   for(int a = 0; a < 3; a++)
   {
      int i = OrdersTotal() - 1;
      for(i; i >= 0; i--)
      {
         bool MagicPass = false;
         if(MagicNumber == -1) MagicPass = true;
         OrderInfo.SelectByIndex(i);
         if((OrderInfo.Magic() == MagicNumber || MagicPass) && OrderInfo.Symbol() == symbol)
            Trade.OrderDelete(OrderInfo.Ticket());
      }
      i = PositionsTotal() - 1;
      for(i; i >= 0; i--)
      {
         bool MagicPass = false;
         if(MagicNumber == -1) MagicPass = true;
         PosInfo.SelectByIndex(i);
         if((PosInfo.Magic() == MagicNumber || MagicPass) && PosInfo.Symbol() == symbol)
            Trade.PositionClose(PosInfo.Ticket());
      }
   }
}

// Returns the total floating profit of all open positions for a symbol with a given Magic Number
double OpenOrderProfits(int MagicNumber, const string symbol)
{
   CPositionInfo PosInfo;
   double cnt = 0;
   for(int i = PositionsTotal(); i >= 0; i--)
   {
      PosInfo.SelectByIndex(i);
      if(PosInfo.Symbol() == symbol && PosInfo.Magic() == MagicNumber)
         cnt += PosInfo.Profit();
   }
   return cnt;
}

// Returns the real monetary value of 1 lot in the account's base currency.
// Pass Price = 0 to use current bid.
double LotSize(double Price = 0.0)
{
   double ret;
   if(Price == 0 || AccountInfoString(ACCOUNT_CURRENCY) == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE))
      ret = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * SymbolInfoDouble(_Symbol, SYMBOL_BID);
   else
      ret = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * Price;
   return ret;
}

// Returns the theoretical profit of an order.
// Direction: OP_BUY or OP_SELL (MQL4 migrated)
double TheoreticalProfits(const string symbol, double Lotamount, int Direction, double StartPrice, double EndPrice)
{
   if(Lotamount <= 0)  return 0.0;
   if(StartPrice == 0 || EndPrice == 0) return 0.0;
   double Moneyin = LotSize(StartPrice) * Lotamount;
   if(Direction == OP_BUY)
      return Moneyin * (EndPrice / StartPrice - 1);
   else
      return Moneyin * (1 - EndPrice / StartPrice);
}

#endif // OMEGA_TRADEUTILS
