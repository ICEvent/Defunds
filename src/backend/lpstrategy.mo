import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Int "mo:base/Int";

module {
    // -----------------------------
    // Types
    // -----------------------------
    public type Price = Float;
    public type Funds = Float;

    public type LPOrder = {
        lower: Price;
        upper: Price;
        amount: Funds;
        depositedPrice: Price; // Price at deployment time, used for profit calculation
    };

    public type TradeHistory = {
        timestamp: Nat64;
        profit: Float;
    };

    public type StrategyState = {
        bBuyTarget: Price;
        bSellTarget: Price;
        bBuyFunds: Funds;
        bSellFunds: Funds;
        volatility: Float;
        riskFactor: Float;
        activeOrders: [LPOrder];
        tradeHistory: [TradeHistory];
    };

    // -----------------------------
    // Utils
    // -----------------------------
    public func abs(x: Float) : Float {
        if (x < 0.0) { -x } else { x };
    };

    public func calculateLPRange(target: Price, volatility: Float, riskFactor: Float) : (Price, Price) {
        let delta = target * volatility * riskFactor;
        return (target - delta, target + delta);
    };

    public func liquidityWeight(current: Price, lower: Price, upper: Price) : Float {
        if (current <= lower or current >= upper) {
            return 0.0;
        };
        let mid = (lower + upper) / 2.0;
        let range = mid - lower;
        // Protect against division by zero when lower equals upper
        if (range <= 0.0) {
            return 0.0;
        };
        let maxWeight = 1.0;
        return maxWeight * (1.0 - abs(current - mid)/range);
    };

    // -----------------------------
    // Core LP Deployment
    // -----------------------------
    public func deployLP(amount: Funds, lower: Price, upper: Price, currentPrice: Price) : LPOrder {
        let order : LPOrder = {
            lower = lower;
            upper = upper;
            amount = amount;
            depositedPrice = currentPrice;
        };
        Debug.print("Deploy LP: " # debug_show(order));
        return order;
    };

    // -----------------------------
    // Layer C: Rebalancing / Take-profit Logic
    // -----------------------------
    public func layerCAdjust(state: StrategyState, currentPrice: Price) : (StrategyState, [LPOrder]) {
        var adjustedOrders : [LPOrder] = [];

        for (order in state.activeOrders.vals()) {
            // Simplified: trigger take-profit or rebalancing if price changes by ±5%
            let priceChange = (currentPrice - order.depositedPrice)/order.depositedPrice;
            if (priceChange >= 0.05) {
                // Take profit: sell
                Debug.print("Trigger Take Profit for order at " # debug_show(order.depositedPrice));
            } else if (priceChange <= -0.05) {
                // Rebalancing: add additional funds
                let additionalAmount = order.amount * 0.5;
                Debug.print("Trigger Rebalance / Add Funds: " # debug_show(additionalAmount));
                adjustedOrders := Array.append([deployLP(additionalAmount, order.lower, order.upper, currentPrice)], adjustedOrders);
            };
        };
        return (state, adjustedOrders);
    };

    // -----------------------------
    // Profit Tracking
    // -----------------------------
    public func recordProfit(state: StrategyState, currentPrice: Price, timestamp: Nat64) : StrategyState {
        var history : [TradeHistory] = state.tradeHistory;

        // Only record profit once per execution by creating a single aggregate entry
        var totalProfit : Float = 0.0;
        for (order in state.activeOrders.vals()) {
            // Simplified: profit = (current price relative to deployment price change) * amount
            let profit = (currentPrice - order.depositedPrice)/order.depositedPrice * order.amount;
            totalProfit += profit;
        };
        
        // Add a single aggregated profit entry
        if (state.activeOrders.size() > 0) {
            history := Array.append([{ 
                timestamp = timestamp; 
                profit = totalProfit 
            }], history);
        };
        
        return {
            bBuyTarget = state.bBuyTarget;
            bSellTarget = state.bSellTarget;
            bBuyFunds = state.bBuyFunds;
            bSellFunds = state.bSellFunds;
            volatility = state.volatility;
            riskFactor = state.riskFactor;
            activeOrders = state.activeOrders;
            tradeHistory = history;
        };
    };

    // -----------------------------
    // Execute Strategy
    // -----------------------------
    public func executeStrategy(state: StrategyState, currentPrice: Price) : StrategyState {
        // 1. Calculate LP range
        let (buyLower, buyUpper) = calculateLPRange(state.bBuyTarget, state.volatility, state.riskFactor);
        let (sellLower, sellUpper) = calculateLPRange(state.bSellTarget, state.volatility, state.riskFactor);

        // 2. Calculate weights
        let buyWeight = liquidityWeight(currentPrice, buyLower, buyUpper);
        let sellWeight = liquidityWeight(currentPrice, sellLower, sellUpper);

        // 3. Deploy LP - keep existing orders and add new ones
        var newOrders : [LPOrder] = state.activeOrders;
        let buyAmount = state.bBuyFunds * buyWeight;
        let sellAmount = state.bSellFunds * sellWeight;

        if (buyAmount > 0.0) {
            newOrders := Array.append(newOrders, [deployLP(buyAmount, buyLower, buyUpper, currentPrice)]);
        };
        if (sellAmount > 0.0) {
            newOrders := Array.append(newOrders, [deployLP(sellAmount, sellLower, sellUpper, currentPrice)]);
        };

        var newState = {
            bBuyTarget = state.bBuyTarget;
            bSellTarget = state.bSellTarget;
            bBuyFunds = state.bBuyFunds;
            bSellFunds = state.bSellFunds;
            volatility = state.volatility;
            riskFactor = state.riskFactor;
            activeOrders = newOrders;
            tradeHistory = state.tradeHistory;
        };

        // 4. Layer C adjustment
        let (updatedState, additionalOrders) = layerCAdjust(newState, currentPrice);
        newState := {
            bBuyTarget = updatedState.bBuyTarget;
            bSellTarget = updatedState.bSellTarget;
            bBuyFunds = updatedState.bBuyFunds;
            bSellFunds = updatedState.bSellFunds;
            volatility = updatedState.volatility;
            riskFactor = updatedState.riskFactor;
            activeOrders = Array.append(newState.activeOrders, additionalOrders);
            tradeHistory = updatedState.tradeHistory;
        };

        // 5. Update profit history
        let timestamp = Nat64.fromNat(Int.abs(Time.now()));
        newState := recordProfit(newState, currentPrice, timestamp);

        return newState;
    };
};
