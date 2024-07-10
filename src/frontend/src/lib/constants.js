export const ICP_LEDGER_CANISTER_ID = 'ryjl3-tyaaa-aaaaa-aaaba-cai';
export const DEFUND_CANISTER_ID = 'gncpj-jyaaa-aaaan-qagta-cai';
export const ICP_TOKEN_DECIMALS = 100_000_000;


export const EXPLORER_ICP_TX = "https://dashboard.internetcomputer.org/transaction/"
export const EXPLORER_PRINCIPAL = "https://ic.house/ICP/address/";

export const getTokenNameByID = (tokenId) => {
    switch (tokenId) {
        case ICP_LEDGER_CANISTER_ID:
            return "ICP";
            default: {
                return tokenId;
     }
    }
}
    