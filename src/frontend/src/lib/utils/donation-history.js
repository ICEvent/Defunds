// created_at_time is supplied by the sender and may be absent.
// Missing times are resolved from the ledger block timestamp below.
export function parseDonationTransactions(result, treasuryAccount, currency) {
    if (!result?.Ok) {
        throw new Error(result?.Err?.message || 'Invalid donation history response.');
    }
    return result.Ok.transactions.flatMap(({ id, transaction }) => {
        const transfer = transaction.operation.Transfer || transaction.operation.TransferFrom;
        if (!transfer || transfer.to !== treasuryAccount) return [];
        return [{
            txid: id,
            amount: transfer.amount.e8s,
            currency,
            timestamp: transaction.created_at_time?.[0]?.timestamp_nanos ?? null,
            donor: transfer.from
        }];
    });
}

// Resolve each missing time independently so an unavailable block/archive does not
// hide the donation list. Never substitute the current time for historical data.
export async function resolveDonationTimes(donations, ledger, queryArchive) {
    return Promise.all(donations.map(async (donation) => {
        if (donation.timestamp != null) return donation;
        try {
            const request = { start: donation.txid, length: 1n };
            const response = await ledger.query_blocks(request);
            const offset = donation.txid - response.first_block_index;
            let block = offset >= 0n && offset < BigInt(response.blocks.length)
                ? response.blocks[Number(offset)] : undefined;
            if (!block) {
                const archive = response.archived_blocks.find(({ start, length }) =>
                    donation.txid >= start && donation.txid < start + length);
                if (archive) {
                    const result = await queryArchive(archive.callback, request);
                    block = result.Ok?.blocks[0];
                }
            }
            return { ...donation, timestamp: block?.timestamp?.timestamp_nanos ?? null };
        } catch {
            return donation;
        }
    }));
}
