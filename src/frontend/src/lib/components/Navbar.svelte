<script>
  import Dialog from '$lib/components/common/Dialog.svelte';
  import { AuthClient } from '@dfinity/auth-client';
  import { HttpAgent } from '@dfinity/agent';
  import { onMount, onDestroy } from 'svelte';
  import { globalStore, setAgent } from '$lib/store';
  import { goto } from '$app/navigation';
  import LoginForm from '$lib/components/LoginForm.svelte';
  import { HOST_MAINNET } from '$lib/constants';
  import { verifyConnection, disconnectPlug } from '$lib/utils/plug';
  import { disconnectOisy } from '$lib/utils/oisy';

  let isAuthed = false;
  let principal = null;
  let authProvider = null;
  let showLoginDialog = false;
  let authClient = null;
  let unsubscribe;
  let loggingOut = false;

  const localLoanTest = import.meta.env.DEV &&
    import.meta.env.VITE_PERSONAL_LOAN_TEST_MODE === 'true';
  const host = localLoanTest
    ? import.meta.env.VITE_PERSONAL_LOAN_HOST
    : HOST_MAINNET;

  function activate({ agent, principal }, provider) {
    setAgent(agent);
    globalStore.update(store => ({ ...store, isAuthed: true, principal, authProvider: provider }));
  }

  onMount(async () => {
    unsubscribe = globalStore.subscribe(value => {
      isAuthed = value.isAuthed;
      principal = value.principal;
      authProvider = value.authProvider;
    });
    try {
      authClient = await AuthClient.create({
        idleOptions: { disableIdle: true, disableDefaultIdleCallback: true }
      });
      // Only restore the wallet selected for this tab. OISY requires the user
      // to reopen the signer on a click, not an unsolicited popup during mount.
      const selected = sessionStorage.getItem('defunds.auth.provider');
      if (selected === 'plug') {
        const connected = await verifyConnection();
        if (connected) activate(connected, 'plug');
      } else if (selected !== 'oisy' && await authClient.isAuthenticated()) {
        const identity = authClient.getIdentity();
        const agent = new HttpAgent({ identity, host });
        if (localLoanTest) await agent.fetchRootKey();
        activate({ agent, principal: identity.getPrincipal() }, 'ii');
      }
      // Clear orphaned selections so the next Login click starts fresh.
      if (!isAuthed && selected) sessionStorage.removeItem('defunds.auth.provider');
    } catch (error) {
      console.warn('Unable to restore Defunds authentication:', error);
    }
    if (window.ic?.plug?.onExternalDisconnect) {
      window.ic.plug.onExternalDisconnect(() => {
        if (authProvider === 'plug') void handleLogout();
      });
    }
  });

  onDestroy(() => { if (unsubscribe) unsubscribe(); });

  async function handleLogout() {
    if (loggingOut) return;
    loggingOut = true;
    try {
      if (authProvider === 'plug') await disconnectPlug();
      else if (authProvider === 'oisy') await disconnectOisy();
      else if (authClient) await authClient.logout();
    } catch (error) {
      console.warn('Wallet disconnect was interrupted:', error);
    } finally {
      sessionStorage.removeItem('defunds.auth.provider');
      const anonymousAgent = new HttpAgent({ host });
      if (localLoanTest) await anonymousAgent.fetchRootKey();
      setAgent(anonymousAgent);
      globalStore.update(store => ({
        ...store, isAuthed: false, principal: undefined, authProvider: null
      }));
      loggingOut = false;
      goto('/');
    }
  }
  function navigateToProfile() { goto('/profile'); }
</script>
<nav class="border-b border-slate-800/80 bg-slate-950/95 py-4 backdrop-blur">
   <div class="container mx-auto flex items-center justify-between px-4">
	   <a
		   href="/"
		   class="flex items-center text-2xl font-semibold tracking-tight text-slate-100"
	   >
		   <img
			   src="/defund_logo.jpg"
			   alt="Defund Logo"
			   class="mr-2 h-8 w-8 rounded-md ring-1 ring-sky-400/30"
		   />
		   Defunds
	   </a>
	   <div class="flex items-center space-x-4 text-sm font-medium">
		   <a href="/funds" class="text-slate-300 hover:text-sky-300">Funds</a>
		   <a href="/assets" class="text-slate-300 hover:text-sky-300">Assets</a>
		   <a href="/loans" class="text-slate-300 hover:text-sky-300">Loans</a>
		   <!-- <a href="/ai-agent-fund" class="text-slate-300 hover:text-sky-300">AI Agent</a> -->
		   {#if isAuthed}
			   <button
				   class="text-slate-300 hover:text-sky-300 focus:outline-none"
				   on:click={navigateToProfile}
			   >
				   Profile
			   </button>
			   <button
				   class="rounded-lg border border-slate-700 bg-slate-900 px-4 py-2 text-slate-100 shadow-finance hover:border-sky-500/60 hover:text-sky-200"
				   on:click={handleLogout}
			   >
				   Logout
			   </button>
		   {:else}
			   <button
				   class="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white shadow-finance hover:bg-sky-500"
				   on:click={() => (showLoginDialog = true)}
			   >
				   Login
			   </button>
		   {/if}
	   </div>
   </div>
</nav>

<Dialog
	isOpen={showLoginDialog}
	on:close={() => (showLoginDialog = false)}
>
	<LoginForm closeLoginForm={() => (showLoginDialog = false)} />
</Dialog>
