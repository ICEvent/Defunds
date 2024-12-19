import type { Grant } from "../../declarations/backend/backend.did";
import { get } from "svelte/store";
import { getDecimalsByCurrency } from "./currency.utils";

export function parseApplication(application: Grant) {
    return {
        ...application,
        grantStatus: application.grantStatus ? Object.keys(application.grantStatus)[0] : 'Unknown',
        currency: application.currency ? Object.keys(application.currency)[0] : 'Unknown',
        amount: Number(application.amount) / (10 ** getDecimalsByCurrency(Object.keys(application.currency)[0])),
        votingStatus: application.votingStatus && application.votingStatus.length > 0 ? {
            ...application.votingStatus[0],
            votes: application.votingStatus[0]?.votes.map(vote => ({
                ...vote,
                voteType: Object.keys(vote.voteType)[0]
            }))
        } : null
        
    }
}