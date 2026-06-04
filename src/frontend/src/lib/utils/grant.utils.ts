import type { Grant } from "../../declarations/backend/backend.did";
import { get } from "svelte/store";
import { getCurrencyName, getDecimalsByCurrency } from "./currency.utils";

export function parseApplication(application: Grant) {
    const currencyName = getCurrencyName(application.currency);
    return {
        ...application,
        grantStatus: application.grantStatus ? Object.keys(application.grantStatus)[0] : 'Unknown',
        currency: currencyName,
        amount: Number(application.amount) / (10 ** getDecimalsByCurrency(currencyName)),
        votingStatus: application.votingStatus && application.votingStatus.length > 0 ? {
            ...application.votingStatus[0],
            votes: application.votingStatus[0]?.votes.map(vote => ({
                ...vote,
                voteType: Object.keys(vote.voteType)[0]
            }))
        } : null
        
    }
}