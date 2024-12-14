export function parseApplication(application) {
    console.log("application:", application)
    return {
        ...application,
        grantStatus: application.grantStatus ? Object.keys(application.grantStatus)[0] : 'Unknown',
        currency: application.currency ? Object.keys(application.currency)[0] : 'Unknown',
        amount: Number(application.amount) / (10 ** 6),
        votingStatus: application.votingStatus?.length > 0 ? {
            ...application.votingStatus[0],
            votes: application.votingStatus[0].votes.map(vote => ({
                ...vote,
                voteType: Object.keys(vote.voteType)[0]
            }))
        } : []
    }
}
