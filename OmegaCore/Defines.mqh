//+------------------------------------------------------------------+
//|                                               OmegaCore/Defines.mqh |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_DEFINES
#define OMEGA_DEFINES

// Whenever a Strategy is stopped, a Custom Chart Event will occur.
#define STRATEGY_STOP 8110

// Migrating from MQL4
#define OP_BUY  POSITION_TYPE_BUY
#define OP_SELL POSITION_TYPE_SELL

// The Decimal of the Volume
// (for some Securities the minimal Volume is 0.1, for others 0.01)
int Decimal = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.01 ? 2 : 1;

// The Directions Enum for a Grid Trading Strategy
enum e_Direction
{
   Longonly  = 0,
   Shortonly = 1,
   LongShort = 2
};

#endif // OMEGA_DEFINES
