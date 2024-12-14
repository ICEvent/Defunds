export const getDecimalsByCurrency = (currency: string): number => {
    const decimalsMap: Record<string, number> = {
        'ICP': 8,
        'ckBTC': 8,
        'ckETH': 18,
        'USDC': 6
    }
    return decimalsMap[currency] || 8
}

export const getCurrencyObjectByName = (currency: string) => {
    const currencyMap: Record<string, { [key: string]: null }> = {
        'ICP': { ICP: null },
        'ckBTC': { ckBTC: null },
        'ckETH': { ckETH: null },
        'ckUSDC': { ckUSDC: null }
    }
    return currencyMap[currency] || { ICP: null }
}
