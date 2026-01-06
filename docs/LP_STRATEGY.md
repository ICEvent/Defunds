# LP Strategy Bot Service

## Overview

The LP Strategy Bot is a canister service that implements an automated Liquidity Provider (LP) investment strategy. It manages liquidity positions with dynamic rebalancing based on market price movements and volatility.

## Features

### Core Functionality

1. **Dynamic LP Range Calculation**
   - Calculates optimal liquidity ranges based on target prices, volatility, and risk factors
   - Adjusts positions dynamically based on current market conditions

2. **Layer C Logic (Rebalancing & Take Profit)**
   - Automatic take profit when price increases by ≥5%
   - Automatic rebalancing (adding 50% more funds) when price decreases by ≥5%

3. **Weighted Liquidity Deployment**
   - Deploys liquidity based on distance from target price
   - Maximum weight at the midpoint of the range
   - Zero weight outside the specified range

4. **Profit Tracking**
   - Records profit/loss for each order
   - Maintains historical trade data with timestamps

## Architecture

### Modules

#### `lpstrategy.mo` (Module)
Contains the core LP strategy logic and types:

- **Types:**
  - `Price`: Float - Price point
  - `Funds`: Float - Amount of funds
  - `LPOrder`: Record of LP position with range and deployment price
  - `TradeHistory`: Historical profit/loss record
  - `StrategyState`: Complete state of the strategy

- **Functions:**
  - `calculateLPRange()`: Computes price range for LP deployment
  - `liquidityWeight()`: Calculates deployment weight based on price position
  - `deployLP()`: Creates new LP order
  - `layerCAdjust()`: Implements rebalancing and take-profit logic
  - `recordProfit()`: Updates profit history
  - `executeStrategy()`: Main execution function

#### `lpstrategybot.mo` (Actor/Canister)
The deployable canister that manages strategy state:

- **State Variables:**
  - `bBuyTarget`: Target price for buy-side liquidity (default: 3100.0)
  - `bSellTarget`: Target price for sell-side liquidity (default: 3300.0)
  - `bBuyFunds`: Funds allocated for buying (default: 10000.0)
  - `bSellFunds`: Funds allocated for selling (default: 10000.0)
  - `volatility`: Market volatility factor (default: 0.03)
  - `riskFactor`: Risk adjustment multiplier (default: 1.2)
  - `activeOrders`: Current LP positions
  - `tradeHistory`: Historical trade records

## API Methods

### Query Methods

#### `getState() : async StrategyState`
Returns the complete current state of the strategy.

**Returns:**
```motoko
{
  bBuyTarget: Float;
  bSellTarget: Float;
  bBuyFunds: Float;
  bSellFunds: Float;
  volatility: Float;
  riskFactor: Float;
  activeOrders: [LPOrder];
  tradeHistory: [TradeHistory];
}
```

#### `getActiveOrders() : async [LPOrder]`
Returns all currently active LP orders.

**Returns:** Array of LPOrder records

#### `getTradeHistory() : async [TradeHistory]`
Returns the complete trade history.

**Returns:** Array of TradeHistory records

### Update Methods

#### `run(currentPrice: Float) : async StrategyState`
Executes the strategy with the provided current price.

**Parameters:**
- `currentPrice`: Current market price

**Returns:** Updated strategy state

**Process:**
1. Calculates LP ranges for buy and sell targets
2. Computes liquidity weights
3. Deploys new LP orders
4. Applies Layer C adjustments (rebalancing/take-profit)
5. Records profit/loss
6. Returns updated state

#### `updateParameters(...) : async StrategyState`
Updates strategy parameters.

**Parameters:** (all optional)
- `bBuyTarget: ?Float`
- `bSellTarget: ?Float`
- `bBuyFunds: ?Float`
- `bSellFunds: ?Float`
- `volatility: ?Float`
- `riskFactor: ?Float`

**Returns:** Updated strategy state

#### `resetStrategy() : async StrategyState`
Clears all active orders and trade history while preserving parameters.

**Returns:** Reset strategy state

## Usage Example

```motoko
// Query current state
let state = await LPStrategyBot.getState();

// Execute strategy with current price
let updatedState = await LPStrategyBot.run(3150.0);

// Update parameters
let newState = await LPStrategyBot.updateParameters(
  ?3200.0,  // new buy target
  ?3400.0,  // new sell target
  null,     // keep current buy funds
  null,     // keep current sell funds
  ?0.04,    // increase volatility
  null      // keep current risk factor
);

// Get active orders
let orders = await LPStrategyBot.getActiveOrders();

// Get trade history
let history = await LPStrategyBot.getTradeHistory();

// Reset strategy
let resetState = await LPStrategyBot.resetStrategy();
```

## Deployment

The LP Strategy Bot is configured in `dfx.json`:

```json
{
  "lpstrategybot": {
    "declarations": {
      "node_compatibility": true
    },
    "main": "src/backend/lpstrategybot.mo",
    "type": "motoko"
  }
}
```

Deploy with:
```bash
dfx deploy lpstrategybot
```

## Strategy Logic

### LP Range Calculation
```
delta = target * volatility * riskFactor
range = (target - delta, target + delta)
```

### Liquidity Weight
```
if current_price outside [lower, upper]: weight = 0
else:
  mid = (lower + upper) / 2
  weight = 1.0 - |current - mid| / (mid - lower)
```

### Layer C Triggers
- **Take Profit**: Price change ≥ +5% from deployment price
- **Rebalance**: Price change ≤ -5% from deployment price (adds 50% more funds)

### Profit Calculation
```
profit = (current_price - deployed_price) / deployed_price * amount
```

## Integration with Main Defunds Service

The LP Strategy Bot can be integrated with the main Defunds service to:
1. Automatically manage liquidity for treasury funds
2. Optimize returns on idle charitable donations
3. Provide additional income stream for the platform

Example integration:
```motoko
// In main.mo, add LP strategy management
public shared func deployLiquidity(amount: Nat64, currentPrice: Float) : async Result.Result<(), Text> {
  if (_available_funds >= amount) {
    // Deploy to LP strategy
    ignore await LPStrategyBot.run(currentPrice);
    #ok()
  } else {
    #err("Insufficient available funds")
  }
}
```

## License

This code is part of the Defunds project and follows the same license.
