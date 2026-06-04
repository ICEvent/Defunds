export const getCurrencyName = (currency: any): string => {
    if (!currency) return 'Unknown';
    if (typeof currency === 'string') return currency;
    if (typeof currency !== 'object') return 'Unknown';

    if ('ICRC' in currency && typeof currency.ICRC === 'string') {
        return currency.ICRC;
    }

    const keys = Object.keys(currency);
    return keys.length > 0 ? keys[0] : 'Unknown';
};

export const getDecimalsByCurrency = (currency: string | any): number => {
    const currencyName = getCurrencyName(currency);
    const decimalsMap: Record<string, number> = {
        ICP: 8,
        ckBTC: 8,
        ckETH: 18,
        ckUSDC: 6,
        USDC: 6,
    };
    return decimalsMap[currencyName] || 8;
};

export const getCurrencyObjectByName = (currency: string) => {
    const currencyMap: Record<string, { [key: string]: null }> = {
        ICP: { ICP: null },
        ckBTC: { ckBTC: null },
        ckETH: { ckETH: null },
        ckUSDC: { ckUSDC: null },
    };

    if (currencyMap[currency]) {
        return currencyMap[currency];
    }

    return { ICRC: currency };
};
