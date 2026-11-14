import { sha224 } from '@noble/hashes/sha256';

// ICP AccountIdentifier: CRC32(SHA224(domain || owner || subaccount)) || hash.
export function icpDepositAddress(owner, subaccount) {
  if (subaccount?.length !== 32 || !Array.from(subaccount).every(b => Number.isInteger(b) && b >= 0 && b <= 255)) {
    throw new Error('Invalid fund subaccount');
  }
  const hash = sha224(new Uint8Array([
    10, ...new TextEncoder().encode('account-id'),
    ...owner.toUint8Array(), ...subaccount,
  ]));
  let crc = 0xffffffff;
  for (const byte of hash) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  crc = (crc ^ 0xffffffff) >>> 0;
  return [crc >>> 24, (crc >>> 16) & 255, (crc >>> 8) & 255, crc & 255, ...hash]
    .map(byte => byte.toString(16).padStart(2, '0')).join('');
}
