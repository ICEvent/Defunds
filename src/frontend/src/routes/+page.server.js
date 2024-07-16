
import { createActor } from "../../../declarations/backend";
import { DEFUND_CANISTER_ID, ICP_LEDGER_CANISTER_ID,ICP_TOKEN_DECIMALS } from '../lib/constants';
import * as ICPLEDGER from "../../../declarations/icrc1_ledger_canister";
import { HttpAgent } from "@dfinity/agent";
import { HOST_MAINNET } from '../lib/constants';
import { Principal } from "@dfinity/principal";

export async function load() {
    let donationHistory = [];
    let totalDonations = 0;

    let backend = createActor(DEFUND_CANISTER_ID, {
        agent: new HttpAgent({
            host: HOST_MAINNET
        })
    });
    let icpledger = ICPLEDGER.createActor(new HttpAgent({
        host: HOST_MAINNET
    }), ICP_LEDGER_CANISTER_ID, { actorOptions: {} });

    try {
        const response = await backend.getDonationHistory(0, 3, [], []);

        donationHistory = response.map(donation => ({
            ...donation,
            donor: donation.donor.toText() // Convert Principal to string
        }));


        let balance = await icpledger.icrc1_balance_of({
            owner: Principal.fromText(DEFUND_CANISTER_ID),
            subaccount: []
        });
        totalDonations = Number(balance) / ICP_TOKEN_DECIMALS;


    } catch (error) {
        console.error('Error fetching donation history:', error);
    }
    return { donationHistory, totalDonations };
}
