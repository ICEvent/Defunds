import LPStrategy "./lpstrategy";
import Debug "mo:base/Debug";

// -----------------------------
// Actor - LP Strategy Bot
// -----------------------------
actor LPStrategyBot {

    type Price = LPStrategy.Price;
    type StrategyState = LPStrategy.StrategyState;

    stable var state : StrategyState = {
        bBuyTarget = 3100.0;
        bSellTarget = 3300.0;
        bBuyFunds = 10000.0;
        bSellFunds = 10000.0;
        volatility = 0.03;
        riskFactor = 1.2;
        activeOrders = [];
        tradeHistory = [];
    };

    // Query current state
    public query func getState() : async StrategyState {
        state
    };

    // Execute strategy with current price
    public func run(currentPrice: Price) : async StrategyState {
        state := LPStrategy.executeStrategy(state, currentPrice);
        return state;
    };

    // Update strategy parameters
    public func updateParameters(
        bBuyTarget: ?Price,
        bSellTarget: ?Price,
        bBuyFunds: ?LPStrategy.Funds,
        bSellFunds: ?LPStrategy.Funds,
        volatility: ?Float,
        riskFactor: ?Float
    ) : async StrategyState {
        state := {
            bBuyTarget = switch (bBuyTarget) { case (?val) val; case null state.bBuyTarget };
            bSellTarget = switch (bSellTarget) { case (?val) val; case null state.bSellTarget };
            bBuyFunds = switch (bBuyFunds) { case (?val) val; case null state.bBuyFunds };
            bSellFunds = switch (bSellFunds) { case (?val) val; case null state.bSellFunds };
            volatility = switch (volatility) { case (?val) val; case null state.volatility };
            riskFactor = switch (riskFactor) { case (?val) val; case null state.riskFactor };
            activeOrders = state.activeOrders;
            tradeHistory = state.tradeHistory;
        };
        return state;
    };

    // Get active orders
    public query func getActiveOrders() : async [LPStrategy.LPOrder] {
        state.activeOrders
    };

    // Get trade history
    public query func getTradeHistory() : async [LPStrategy.TradeHistory] {
        state.tradeHistory
    };

    // Reset strategy (clear orders and history)
    public func resetStrategy() : async StrategyState {
        state := {
            bBuyTarget = state.bBuyTarget;
            bSellTarget = state.bSellTarget;
            bBuyFunds = state.bBuyFunds;
            bSellFunds = state.bSellFunds;
            volatility = state.volatility;
            riskFactor = state.riskFactor;
            activeOrders = [];
            tradeHistory = [];
        };
        return state;
    };
};
