// ICP Index transactions expose created_at_time as an optional timestamp.
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
