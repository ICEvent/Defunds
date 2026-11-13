import { fileURLToPath, URL } from 'url';
import { resolvePersonalLoanBuildId } from './scripts/personal-loan-mainnet-id.js';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import environment from 'vite-plugin-environment';
import dotenv from 'dotenv';

dotenv.config({ path: '../../.env' });

// Automatically read only the IC mainnet ID when DFX builds with --ic.
// The user-maintained root canister_ids.json is never written to or committed.
// Existing VITE_ overrides (including isolated PocketIC tests) always win.
const loanId = resolvePersonalLoanBuildId({
  filePath: fileURLToPath(new URL('../../canister_ids.json', import.meta.url))
});
if (loanId.source === 'canister_ids.json') {
  process.env.VITE_PERSONAL_LOAN_CANISTER_ID = loanId.id;
  console.info('[Defunds] Mainnet Personal Loan ID loaded from canister_ids.json: ' + loanId.id);
} else if (process.env.DFX_NETWORK === 'ic' && !loanId.id) {
  console.warn('[Defunds] No personal_loan.ic in canister_ids.json. /loans will remain disconnected.');
}

export default defineConfig({
  build: {
    emptyOutDir: true,
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: "globalThis",
      },
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:4943",
        changeOrigin: true,
      },
    },
  },
  plugins: [
    sveltekit(),
    environment("all", { prefix: "CANISTER_" }),
    environment("all", { prefix: "DFX_" }),
  ],

  resolve: {
    alias: [
      {
        find: "declarations",
        replacement: fileURLToPath(
          new URL("../declarations", import.meta.url)
        ),
      },
    ],
  },
});
