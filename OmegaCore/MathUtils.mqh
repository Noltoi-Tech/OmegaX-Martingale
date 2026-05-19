//+------------------------------------------------------------------+
//|                                            OmegaCore/MathUtils.mqh |
//|                                          Copyright 2024, Noltoi  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Noltoi"
#property link      "https://www.mql5.com"
#property description "Omega Grid X"

#ifndef OMEGA_MATHUTILS
#define OMEGA_MATHUTILS

#include "Defines.mqh"

// Basic round: 0.5 -> 1,  0.49 -> 0
double Round(double value, int decimals)
{
   double timesten, truevalue;
   if(decimals < 0)
   {
      Print("Wrong decimals input parameter, parameter cant be below 0");
      return 0;
   }
   timesten = value * MathPow(10, decimals);
   timesten = MathRound(timesten);
   truevalue = timesten / MathPow(10, decimals);
   return truevalue;
}

// Rounds a double value up — example: RoundUp(2.4351, 3) -> 2.436
double RoundUp(double val, int decim)
{
   if(Round(val, decim) < val) return Round(val, decim) + MathPow(10, -decim);
   else return Round(val, decim);
}

// Rounds a double value down — example: RoundDown(3.1417, 3) -> 3.141
double RoundDown(double val, int decim)
{
   if(Round(val, decim) > val) return Round(val, decim) - MathPow(10, -decim);
   else return Round(val, decim);
}

// Rounds the parameter to a valid Lot amount
double RoundtoLots(double Val)
{
   Val = Round(Val, 6);
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.01)
      return RoundDown(Val, 2);
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.1)
      return RoundDown(Val, 1);
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0.001)
      return RoundDown(Val, 3);
   return RoundDown(Val, 0);
}

// Checks if a volume is a valid volume for the current symbol
bool CheckVolumeValue(double volume)
{
   //--- minimal allowed volume for trade operations
   double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(volume < min_volume)
      return(false);

   //--- maximal allowed volume of trade operations
   double max_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if(volume > max_volume)
      return(false);

   //--- get minimal step of volume changing
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   int ratio = (int)MathRound(volume / volume_step);
   if(MathAbs(ratio * volume_step - volume) > 0.0000001)
      return(false);

   return(true);
}

#endif // OMEGA_MATHUTILS
