# OmegaX Martingale

OmegaX Martingale is an experimental MetaTrader 5 Expert Advisor focused on grid/martingale recovery research, basket-state management, and risk-control improvements. This project is under active development and not recommended for live trading without extensive testing.

## Features

- **Grid Trading Strategy** - Multi-level grid-based trading with configurable entry points
- **Martingale Strategy** - Progressive lot sizing with loss recovery mechanism
- **Advanced Risk Management** - Built-in emergency guard system to prevent catastrophic losses
- **Flexible Direction Control** - Support for long-only, short-only, and bidirectional trading
- **Professional Architecture** - Modular, object-oriented design with reusable components
- **Optimized Lot Calculation** - Dynamic position sizing based on stop-loss and account equity
- **Custom Trade Utilities** - Comprehensive order management and price calculation tools

## Current Development Focus

Active research and engineering areas:
- Robust basket state machine implementation
- Recovery flow consistency under market stress
- Safe handling after failed order execution
- Margin-aware lot validation
- Stop-out prevention research
- Deterministic tester diagnostics and reproducibility

## Known Issues

⚠️ **Critical Areas Under Investigation:**

- **Recovery/Basket State Inconsistency**: Under high-pressure conditions (volatility spikes, rapid fills), the basket state may become inconsistent, leading to incorrect recovery calculations
- **Reset Loops**: Failed recovery conditions can trigger unexpected reset loops, potentially doubling positions unintentionally
- **Small Account Risk**: Accounts with deposits under $500 (especially $200) show high stop-out probability with current martingale parameters
- **Martingale Recovery Limitations**: Progressive lot sizing can still result in stop-out despite recovery mechanisms, particularly in ranging or trending markets
- **State Machine Fragility**: Current implementation lacks explicit state-machine control for basket lifecycle, making recovery logic vulnerable to edge cases
- **Order Rejection Handling**: Failed order executions may not properly update strategy state, causing cascading failures

## Project Structure

```
OmegaX_Martingale/
├── OmegaX_Martingale.mq5           # Main Expert Advisor
├── OmegaX_Martingale.ex5           # Compiled binary
├── OmegaCore/                      # Core library modules
│   ├── Defines.mqh                 # Constants and enums
│   ├── Strategy.mqh                # Base strategy class
│   ├── OmegaGridStrategy.mqh        # Grid trading implementation
│   ├── OmegaMartingaleStrategy.mqh  # Martingale implementation
│   ├── Guard.mqh                   # Emergency risk guard
│   ├── TradeUtils.mqh              # Trade execution utilities
│   ├── LotCalc.mqh                 # Position sizing calculator
│   ├── MathUtils.mqh               # Mathematical utilities
│   ├── OmegaTrade.mqh              # Trade data structures
│   └── OmegaGridStrategy.mqh        # Grid implementation
├── tester/                         # Backtesting reports
└── README.md                       # This file
```

## Core Components

### Strategy Base Class
Provides the foundation for all trading strategies with:
- Position lifecycle management
- Stop-loss and take-profit handling
- Magic number tracking
- Emergency guard protection

### Martingale Strategy
Implements progressive lot sizing:
- Automatic lot increase after losses
- Configurable recovery targets
- Safety guards to prevent excessive leverage

### Grid Strategy
Multi-level entry point system:
- Predefined grid levels
- Independent management of grid positions
- Flexible entry/exit conditions

### Guard System
Emergency protection mechanism:
- Automatic position closure on extreme conditions
- Liquidity preservation
- Maximum drawdown limits

## Parameters

Configurable in MetaTrader 5 settings:

- **Stop Loss (pips)** - Maximum risk per trade
- **Take Profit (pips)** - Target profit per position
- **Initial Lot Size** - Starting position volume
- **Leverage** - Account leverage setting
- **Direction** - Long only, Short only, or Bidirectional
- **Magic Number** - Unique identifier for strategy
- **Max Positions** - Maximum concurrent grid levels

## Installation

1. Copy the `OmegaX_Martingale.mq5` file to your MetaTrader 5 `Experts` folder
2. Copy the `OmegaCore/` folder to your MetaTrader 5 `Include` folder
3. Restart MetaTrader 5
4. Attach the expert advisor to your chart

## Usage

1. Open MetaTrader 5 terminal
2. Locate OmegaX_Martingale in the Experts list
3. Drag and drop onto your desired chart (preferably H1 or higher timeframe)
4. Configure parameters in the properties dialog
5. Enable "Allow automated trading" in options
6. Monitor positions in the Terminal window

## Risk Management

⚠️ **Current Safety Features (Experimental):**
- Built-in Guard system attempts to prevent excessive losses
- Configurable stop-loss on all positions
- Position size limits based on account equity
- Emergency closure protocol on margin call risk

### Critical Warnings for Testing

- **DO NOT USE ON LIVE ACCOUNTS** without full understanding of current limitations
- Start only with demo accounts and minimal risk parameters
- Enable Guard protection and use conservative settings
- Set stop-loss levels well above typical volatility (100+ pips for forex)
- Use long-only or short-only mode for testing
- Monitor account balance continuously
- Be prepared for unexpected stop-outs due to state inconsistencies
- Keep detailed logs of all trades for debugging

## Reproducible Test Case

To investigate current recovery/basket issues, use these exact parameters:

**Test Environment:**
- Symbol: XAUUSD (Gold)
- Timeframe: M1
- Test Period: 2026.05.01 to 2026.05.09
- Initial Deposit: $200
- Tick Model: Real ticks
- Spread: Realistic for period

**Expected Observations:**
- Recovery mechanism engages but fails under stress
- Basket state becomes unreliable after 3-4 consecutive losses
- Stop-out occurs before recovery completes
- Strategy state logs show inconsistent recovery flow

Use this test case for bug reports and engineering discussions.

## Engineering Goal

The primary objective is to design and implement a robust recovery engine that:

1. **Explicit Basket Lifecycle Tracking** - Maintain deterministic state for each basket from entry through resolution
2. **Prevention of Concurrent Resets** - Prevent new recovery cycles from initiating while an existing basket is unresolved
3. **Order Validation Pre-Execution** - Validate margin, lot size, and account state before submitting recovery orders
4. **Graceful Order Rejection Handling** - Manage rejected orders without corrupting internal strategy state
5. **Deterministic State Transitions** - Log and track every state change with clear entry/exit conditions
6. **Test Case Validation** - Reproduce and fix the failure mode identified in the test case above

## Internal Execution Flow

The strategy executes on every tick via the `OnTick()` event handler. The typical execution sequence is:

```
OnTick()
  ├─ Evaluate market signal (price, grid level, direction)
  ├─ Check existing basket state and open positions
  ├─ Decide: new entry, recovery, close, or reset
  ├─ Calculate lot size based on risk parameters and account equity
  ├─ Validate margin requirements and Guard constraints
  ├─ Submit order(s) to broker
  ├─ Update basket state and internal tracking
  ├─ Evaluate take-profit and stop-loss conditions
  └─ Decide basket closure or strategy reset
```

**Current Challenge**: These steps are not yet wrapped in explicit state-machine logic, leading to inconsistent behavior when orders fail or market conditions change rapidly.

## Basket Lifecycle

The intended lifecycle for each active basket is:

```
IDLE
  └─> FIRST_ORDER_OPENED
       └─> RECOVERY_PENDING (if first order hits SL)
            └─> RECOVERY_ACTIVE (recovery orders being placed)
                 └─> BASKET_CLOSING (TP or SL reached on basket)
                      └─> RESET (return to IDLE for new basket)
```

**State Descriptions:**
- **IDLE**: No active basket; ready for new entry signal
- **FIRST_ORDER_OPENED**: Initial grid level order filled; basket is now tracked
- **RECOVERY_PENDING**: First order hit stop-loss; recovery conditions being evaluated
- **RECOVERY_ACTIVE**: Recovery orders are being placed or managed
- **BASKET_CLOSING**: Basket has reached take-profit or final stop-loss; orders closing
- **RESET**: Basket fully closed and state cleared; strategy ready for new entry

**Current Status**: The code implements recovery logic and order management, but does **not yet enforce this lifecycle as a strict state machine**. Transitions can occur out-of-order or be skipped, especially under market stress or failed order execution.

## Where the Current Bug Happens

The primary failure occurs in the **recovery and basket state management subsystem**, particularly:

1. **State Consistency Under Pressure**: When multiple orders fail in rapid succession or during low liquidity, the internal basket state may not accurately reflect broker position state
2. **Recovery Reset Loops**: Failed or blocked recovery conditions may trigger unintended resets, causing the strategy to abandon a basket prematurely or re-open it incorrectly
3. **Incomplete Order Tracking**: If an order is rejected or partially filled, the strategy state may not synchronize with actual open positions
4. **Lot Calculation Races**: During recovery, lot calculations might not account for existing positions, resulting in over-leveraging or margin validation failures
5. **Guard Activation Side Effects**: When the Guard system closes emergency positions, the strategy state might not properly transition to a safe reset state

**Observed Pattern**: The failure typically manifests as the strategy entering an inconsistent state where it believes recovery is complete, but the basket is still exposed, leading to unexpected stop-outs or rapid equity depletion.

## Files to Inspect First

When investigating the basket state management issues, start with these core files:

1. **[OmegaX_Martingale.mq5](OmegaX_Martingale.mq5)** - Main entry point; review OnTick() flow and signal evaluation
2. **[OmegaCore/Strategy.mqh](OmegaCore/Strategy.mqh)** - Base strategy class; examine lifecycle management and state transitions
3. **[OmegaCore/OmegaMartingaleStrategy.mqh](OmegaCore/OmegaMartingaleStrategy.mqh)** - Martingale-specific logic; focus on recovery order placement and basket tracking
4. **[OmegaCore/LotCalc.mqh](OmegaCore/LotCalc.mqh)** - Lot sizing calculations; verify margin validation and account equity checks
5. **[OmegaCore/TradeUtils.mqh](OmegaCore/TradeUtils.mqh)** - Order execution utilities; inspect order submission, validation, and error handling
6. **[OmegaCore/Guard.mqh](OmegaCore/Guard.mqh)** - Emergency protection logic; review Guard activation conditions and state reset behavior

**Recommended Approach for Debugging:**
- Add logging statements in the basket state transition points
- Capture strategy state at each OnTick() call during test period
- Compare internal basket state with broker's actual open positions after each order action
- Trace recovery order placement logic to identify where validation fails

## Backtesting

Test reports are included in the `tester/` folder. Current backtests show:

- Mixed results across different market conditions
- Performance degradation under high volatility
- Recovery success rate varies significantly by account size

Before any testing:

1. Run backtest on historical data (minimum 1 year)
2. Document results and failure modes
3. Review tester diagnostics for state inconsistencies
4. Share findings for collaborative debugging

## Performance Considerations

- Designed for 4-digit and 5-digit quotes
- Supports variable lot decimals (0.01, 0.1)
- Optimized for H1-D1 timeframes
- Compatible with most forex and CFD brokers

## Contributors Wanted

We are actively seeking collaboration from:

- **MQL5 Developers** - Help optimize execution and reduce latency in order management
- **Risk Engine Developers** - Design robust position sizing and margin validation logic
- **Grid/Martingale Researchers** - Contribute to recovery algorithms and basket state management
- **State Machine Architecture Contributors** - Build deterministic lifecycle control for strategy states
- **Test Engineers** - Develop diagnostic tools and reproducible test cases

If interested in contributing, please open an issue describing your proposed improvements.

## Support & Troubleshooting

### Known Behaviors

**Behavior**: Guard activates frequently under normal trading
- Status: Under investigation - likely state inconsistency
- Workaround: Disable martingale and use grid-only mode

**Behavior**: Recovery orders rejected repeatedly
- Status: Likely margin validation issue
- Debug: Check account balance and lot size calculations

**Behavior**: Strategy stops responding
- Status: Possible infinite loop in recovery logic
- Action: Restart EA and review tester logs for state dump

## License

Copyright © 2024 Noltoi

## Disclaimer

**CRITICAL - EXPERIMENTAL SOFTWARE DISCLAIMER**

OmegaX Martingale is **EXPERIMENTAL RESEARCH CODE** in active development. Use only at your own risk.

**Key Points:**
- This Expert Advisor is NOT production-ready and contains known issues
- **NEVER use on live trading accounts** - High probability of total account loss
- Automated trading involves substantial risk of capital loss
- Grid and martingale strategies can lead to rapid, catastrophic drawdowns
- Past backtest performance does not guarantee future results
- Recovery algorithms may fail under market stress, resulting in stop-out
- Basket state management is not yet robust enough for reliable operation
- Market gaps, requotes, and liquidity issues can cause unexpected failures

**Only trade with funds you can afford to lose completely.** Before any trading:
1. Thoroughly test on a demo account for multiple market conditions
2. Understand every line of code and its failure modes
3. Maintain detailed logs of all behavior for debugging
4. Be prepared to lose 100% of capital used
5. Engage with the community to report issues and improvements

**The authors assume no responsibility for losses, damages, or other consequences of using this software.**

## References

- [MQL5 Documentation](https://www.mql5.com/en/docs)
- [MetaTrader 5 Trading API](https://www.mql5.com/en/reference)

---

**Last Updated**: May 2026  
**Version**: 1.0  
**Status**: Experimental / Under Active Development  
**Stability**: Not Recommended for Live Trading
