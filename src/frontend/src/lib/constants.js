export const ICP_LEDGER_CANISTER_ID = 'ryjl3-tyaaa-aaaaa-aaaba-cai';
export const ICP_INDEX_CANISTER_ID = 'qhbym-qaaaa-aaaaa-aaafq-cai';
export const ckBTC_LEDGER_CANISTER_ID = 'mxzaz-hqaaa-aaaar-qaada-cai';
export const ckETH_LEDGER_CANISTER_ID = 'ss2fx-dyaaa-aaaar-qacoq-cai';
export const ckUSDC_LEDGER_CANISTER_ID = 'xevnm-gaaaa-aaaar-qafnq-cai';

export const DEFUND_CANISTER_ID = 'ixuio-siaaa-aaaam-qacxq-cai';
export const GOVERNANCE_CANISTER_ID = 'vg3po-ix777-77774-qaafa-cai'; // Local governance canister ID
export const DEFUND_TREASURY_ACCOUNT = "https://dashboard.internetcomputer.org/account/940bf5d45976b003f3c747e9f65cc0c3b06547057daa5e800180860f7fe197af";
 
export const VOTE_POWER_DECIMALS = 100_000_000;
export const ICP_TOKEN_DECIMALS = 100_000_000;


export const HOST_MAINNET = "https://ic0.app";//"https://mainnet.dfinity.network";

export const DERIVATION_ORIGION = "https://32pz7-5qaaa-aaaag-qacra-cai.raw.ic0.app";
export const IDENTITY_PROVIDER = 'https://identity.ic0.app';

export const EXPLORER_ICP_TX = "https://dashboard.internetcomputer.org/transaction/"
export const EXPLORER_PRINCIPAL = "https://ic.house/ICP/address/";
export const EXPLORER_ACCOUNT = "https://dashboard.internetcomputer.org/account/";

export const ONE_WEEK_SEC = 7 * 24 * 60 * 60;
export const ONE_WEEK_NS = BigInt(ONE_WEEK_SEC * 1e9);


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
