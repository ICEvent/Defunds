<script>
  export let closeLoginForm = () => {};

  import { onMount } from 'svelte';
  import { HttpAgent } from '@dfinity/agent';
  import { AuthClient } from '@dfinity/auth-client';
  import { connectPlug } from '$lib/utils/plug';
  import { connectOisy } from '$lib/utils/oisy';
  import { globalStore, setAgent } from '$lib/store';
  import { DERIVATION_ORIGION, HOST_MAINNET, IDENTITY_PROVIDER } from '$lib/constants';

  const localLoanTest = import.meta.env.DEV &&
    import.meta.env.VITE_PERSONAL_LOAN_TEST_MODE === 'true';
  let authError = '';
  let busy = false;
  let windowFeatures;

  onMount(() => {
    if (window.innerWidth > 768) {
      const width = 500, height = 600;
      const left = window.screenX + (window.innerWidth - width) / 2;
      const top = window.screenY + (window.innerHeight - height) / 2;
      windowFeatures = `left=${left},top=${top},width=${width},height=${height}`;
    }
  });

  function activate({ agent, principal }, provider) {
    if (!agent || !principal || principal.isAnonymous?.()) {
      throw new Error('Wallet did not provide a valid authenticated principal.');
    }
    setAgent(agent);
    globalStore.update(store => ({
      ...store,
      isAuthed: true,
      principal,
      authProvider: provider
    }));
    // Store the method only, never credentials or private keys.
    sessionStorage.setItem('defunds.auth.provider', provider);
    busy = false;
    closeLoginForm();
  }

  async function handleWalletConnect(provider) {
    if (busy) return;
    authError = '';
    busy = true;
    try {
      // Start the signer handshake before yielding the button's click gesture.
      const connectionPromise = provider === 'plug' ? connectPlug() : connectOisy();
      const session = await connectionPromise;
      // Do not allow a previously saved Internet Identity delegation to
      // silently replace the wallet principal on a future page load.
      const client = await AuthClient.create({
        idleOptions: { disableIdle: true, disableDefaultIdleCallback: true }
      });
      if (await client.isAuthenticated()) await client.logout();
      activate(session, provider);
    } catch (error) {
      authError = error?.message || String(error);
      busy = false;
    }
  }

  async function handleIILogin() {
    if (busy) return;
    authError = '';
    busy = true;
    try {
      const authClient = await AuthClient.create({
        idleOptions: { disableIdle: true, disableDefaultIdleCallback: true }
      });
      const provider = localLoanTest
        ? import.meta.env.VITE_PERSONAL_LOAN_IDENTITY_PROVIDER
        : IDENTITY_PROVIDER;
      if (!provider) throw new Error('Internet Identity provider URL is not configured.');
      const options = {
        identityProvider: provider,
        windowOpenerFeatures: windowFeatures,
        onSuccess: async () => {
          try {
            const identity = authClient.getIdentity();
            const host = localLoanTest
              ? import.meta.env.VITE_PERSONAL_LOAN_HOST
              : HOST_MAINNET;
            if (!host) throw new Error('Local test is missing VITE_PERSONAL_LOAN_HOST');
            const agent = new HttpAgent({ identity, host });
            if (localLoanTest) await agent.fetchRootKey();
            activate({ agent, principal: identity.getPrincipal() }, 'ii');
          } catch (error) {
            authError = error?.message || String(error);
            busy = false;
          }
        },
        onError: error => {
          authError = error?.message || String(error || 'Internet Identity login failed');
          busy = false;
        }
      };
      if (!localLoanTest) options.derivationOrigin = DERIVATION_ORIGION;
      await authClient.login(options);
    } catch (error) {
      authError = error?.message || String(error);
      busy = false;
    }
  }
</script>

<div class="flex flex-col items-center justify-center rounded-lg bg-white p-6 sm:p-8">
  <h2 class="mb-2 text-2xl font-bold text-gray-800">Welcome to Defunds</h2>
  <p class="mb-6 text-center text-sm text-gray-500">Choose how to connect your ICP identity or wallet.</p>
  <div class="flex w-full max-w-sm flex-col gap-3">
    <button type="button" disabled={busy}
      class="flex items-center justify-center gap-3 rounded-lg bg-blue-600 px-5 py-3 font-semibold text-white hover:bg-blue-700 disabled:cursor-wait disabled:opacity-60"
      on:click={handleIILogin}>
      <img src="/ii_logo.png" alt="" class="h-6 w-10 object-contain" />
      Internet Identity
    </button>

    <button type="button" disabled={busy}
      class="flex items-center justify-center gap-3 rounded-lg border border-slate-300 bg-white px-5 py-3 font-semibold text-slate-800 hover:bg-slate-100 disabled:cursor-wait disabled:opacity-60"
      on:click={() => handleWalletConnect('plug')}>
      <span aria-hidden="true">🔌</span>
      Plug Wallet
    </button>

    <button type="button" disabled={busy}
      class="flex items-center justify-center gap-3 rounded-lg border border-slate-300 bg-white px-5 py-3 font-semibold text-slate-800 hover:bg-slate-100 disabled:cursor-wait disabled:opacity-60"
      on:click={() => handleWalletConnect('oisy')}>
      <span aria-hidden="true">◈</span>
      OISY Wallet
    </button>
  </div>
  {#if busy}<p role="status" class="mt-4 text-sm text-slate-600">Waiting for authentication approval…</p>{/if}
  {#if authError}<p role="alert" class="mt-4 max-w-sm text-sm text-red-600">{authError}</p>{/if}
  <p class="mt-5 max-w-sm text-center text-xs text-gray-500">
    Wallet connections use the wallet's Principal, which may be different from your Internet Identity account.
    OISY may request approval for each signed action.
  </p>
</div>
