import Text "mo:base/Text";

module {

    public type Currency = {
        #ICP;
        #ckUSDC;
        #ckBTC;
        #ckETH;
    };

    public type Donation = {
        donorId : Principal;
        amount : Nat;
        currency : Currency;
        txid : Text;
        timestamp : Int;
    };

    public type VotingPower = {
        userId : Principal;
        totalPower : Nat;
        powerHistory : [PowerChange];
    };

    public type PowerChange = {
        amount : Nat;
        timestamp : Int;
        source : Donation;        
    };
};
