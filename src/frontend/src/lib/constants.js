export const ICP_LEDGER_CANISTER_ID = 'ryjl3-tyaaa-aaaaa-aaaba-cai';
export const ckBTC_LEDGER_CANISTER_ID = 'mxzaz-hqaaa-aaaar-qaada-cai';
export const ckETH_LEDGER_CANISTER_ID = 'ss2fx-dyaaa-aaaar-qacoq-cai';
export const ckUSDC_LEDGER_CANISTER_ID = 'xevnm-gaaaa-aaaar-qafnq-cai';

export const DEFUND_CANISTER_ID = 'be2us-64aaa-aaaaa-qaabq-cai';
export const ICP_TOKEN_DECIMALS = 100_000_000;

export const HOST_MAINNET = "https://ic0.app";//"https://mainnet.dfinity.network";

export const EXPLORER_ICP_TX = "https://dashboard.internetcomputer.org/transaction/"
export const EXPLORER_PRINCIPAL = "https://ic.house/ICP/address/";

export const getTokenNameByID = (tokenId) => {
    switch (tokenId) {
        case ICP_LEDGER_CANISTER_ID:
            return "ICP";
        case ckBTC_LEDGER_CANISTER_ID:
            return "ckBTC";
        case ckETH_LEDGER_CANISTER_ID:
            return "ckETH";
        case ckUSDC_LEDGER_CANISTER_ID:
            return "ckUSDC";
        default: {
            return tokenId;
        }
    }
}
