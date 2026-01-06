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
        depositedPrice: Price; // 部署时的价格，用于收益计算
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
        let maxWeight = 1.0;
        return maxWeight * (1.0 - abs(current - mid)/(mid - lower));
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
    // Layer C: 补仓 / 止盈逻辑
    // -----------------------------
    public func layerCAdjust(state: StrategyState, currentPrice: Price) : (StrategyState, [LPOrder]) {
        var adjustedOrders : [LPOrder] = [];

        for (order in state.activeOrders.vals()) {
            // 简化：如果价格涨跌超过 ±5% 则触发止盈或补仓
            let priceChange = (currentPrice - order.depositedPrice)/order.depositedPrice;
            if (priceChange >= 0.05) {
                // 止盈：卖出
                Debug.print("Trigger Take Profit for order at " # debug_show(order.depositedPrice));
            } else if (priceChange <= -0.05) {
                // 补仓：增加同等资金
                let additionalAmount = order.amount * 0.5;
                Debug.print("Trigger Rebalance / Add Funds: " # debug_show(additionalAmount));
                adjustedOrders := Array.append([deployLP(additionalAmount, order.lower, order.upper, currentPrice)], adjustedOrders);
            };
        };
        return (state, adjustedOrders);
    };

    // -----------------------------
    // 收益统计
    // -----------------------------
    public func recordProfit(state: StrategyState, currentPrice: Price) : StrategyState {
        var history : [TradeHistory] = state.tradeHistory;

        for (order in state.activeOrders.vals()) {
            // 简化：profit = 当前价格相对部署价格的变化 * amount
            let profit = (currentPrice - order.depositedPrice)/order.depositedPrice * order.amount;
            history := Array.append([{ 
                timestamp = Nat64.fromNat(Int.abs(Time.now())); 
                profit = profit 
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
    // 执行策略
    // -----------------------------
    public func executeStrategy(state: StrategyState, currentPrice: Price) : StrategyState {
        // 1. 计算 LP 区间
        let (buyLower, buyUpper) = calculateLPRange(state.bBuyTarget, state.volatility, state.riskFactor);
        let (sellLower, sellUpper) = calculateLPRange(state.bSellTarget, state.volatility, state.riskFactor);

        // 2. 计算权重
        let buyWeight = liquidityWeight(currentPrice, buyLower, buyUpper);
        let sellWeight = liquidityWeight(currentPrice, sellLower, sellUpper);

        // 3. 部署 LP
        var newOrders : [LPOrder] = [];
        let buyAmount = state.bBuyFunds * buyWeight;
        let sellAmount = state.bSellFunds * sellWeight;

        if (buyAmount > 0.0) {
            newOrders := Array.append([deployLP(buyAmount, buyLower, buyUpper, currentPrice)], newOrders);
        };
        if (sellAmount > 0.0) {
            newOrders := Array.append([deployLP(sellAmount, sellLower, sellUpper, currentPrice)], newOrders);
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

        // 4. Layer C 调整
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

        // 5. 更新收益历史
        newState := recordProfit(newState, currentPrice);

        return newState;
    };
};
