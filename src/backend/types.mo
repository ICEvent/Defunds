import Text "mo:base/Text";

module{
    //donation from donor to the fund
    public type Donation = {
        timestamp: Int;
        donor: Principal; // Represents the donor's principal ID
        amount: Nat; // Represents the donation amount
        currency: Text; // Represents the currency (e.g., "ICP", "BTC", "ETH", "USDC")
 
    };

    //grant fund to recipients
    type Status = {
        #approved;
        #rejected;
        #pending;
        #cancelled;
        #expired;        
    };

    public type Grant = {
        grantId: Int;
        submitime: Int;
        title: Text;
        description: Text;
        recipient: Principal;
        amount: Nat;
        currency: Text;        
        grantStatus: Status;
        grantType: Text; 
        reference: Text; //link to the support materials
    };
};