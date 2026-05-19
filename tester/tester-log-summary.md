# Tester Log Summary

The original `.log` file was too large to upload to GitHub.

## Main observed issue
During XAUUSD M1 real-tick backtesting with $200 initial deposit, the recovery/basket system becomes unstable under stress.

Observed behavior:
- repeated basket reset cycles
- failed or blocked recovery conditions
- inconsistent close/reopen behavior
- margin pressure during recovery
- final account collapse / stop-out

## Full log
The full tester log is available locally and can be provided on request.
