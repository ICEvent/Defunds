<script>
  import Dialog from "$lib/components/common/Dialog.svelte";
  import { AuthClient } from "@dfinity/auth-client";
  import { HttpAgent } from "@dfinity/agent";
  import { onMount, onDestroy } from "svelte";
  import { page } from "$app/stores";
  import { afterNavigate, goto } from "$app/navigation";

  import { globalStore, setAgent } from "$lib/store";
  import LoginForm from "$lib/components/LoginForm.svelte";
  import { HOST_MAINNET } from "$lib/constants";
  import { verifyConnection, disconnectPlug } from "$lib/utils/plug";
  import { disconnectOisy } from "$lib/utils/oisy";

  const navLinks = [
    { href: "/funds", label: "Funds" },
    { href: "/assets", label: "Assets" },
    { href: "/loans", label: "Loans" }
  ];

  let isAuthed = false;
  let authProvider = null;
  let loggingOut = false;
  let showLoginDialog = false;
  let isMobileMenuOpen = false;
  let menuButton;
  let authClient = null;
  let unsubscribe;

  const localLoanTest = import.meta.env.DEV &&
    import.meta.env.VITE_PERSONAL_LOAN_TEST_MODE === "true";
  const host = localLoanTest
    ? import.meta.env.VITE_PERSONAL_LOAN_HOST
    : HOST_MAINNET;

  const isActiveLink = (pathname, href) =>
    pathname === href || pathname.startsWith(href + "/");

  function closeMobileMenu() {
    isMobileMenuOpen = false;
  }

  function openLoginDialog() {
    closeMobileMenu();
    showLoginDialog = true;
  }

  function handleKeydown(event) {
    if (event.key === "Escape" && isMobileMenuOpen) {
      closeMobileMenu();
      menuButton?.focus();
    }
  }

  afterNavigate(closeMobileMenu);

  function activate({ agent, principal }, provider) {
    setAgent(agent);
    globalStore.update((store) => ({
      ...store, isAuthed: true, principal, authProvider: provider
    }));
  }

  onMount(async () => {
    unsubscribe = globalStore.subscribe((value) => {
      isAuthed = value.isAuthed;
      authProvider = value.authProvider;
    });
    try {
      authClient = await AuthClient.create({
        idleOptions: { disableIdle: true, disableDefaultIdleCallback: true }
      });
      const selected = sessionStorage.getItem("defunds.auth.provider");
      if (selected === "plug") {
        // No permission prompt on page load: only resume an approved Plug session.
        const connected = await verifyConnection();
        if (connected) activate(connected, "plug");
      } else if (selected !== "oisy" && await authClient.isAuthenticated()) {
        const identity = authClient.getIdentity();
        const agent = new HttpAgent({ identity, host });
        if (localLoanTest) await agent.fetchRootKey();
        activate({ agent, principal: identity.getPrincipal() }, "ii");
      }
      // OISY requires an explicit click after reload; it is not a II session.
      if (!isAuthed && selected) sessionStorage.removeItem("defunds.auth.provider");
    } catch (error) {
      console.warn("Could not restore Defunds session:", error);
    }
    if (window.ic?.plug?.onExternalDisconnect) {
      window.ic.plug.onExternalDisconnect(() => {
        if (authProvider === "plug") void handleLogout();
      });
    }
  });

  onDestroy(() => {
    if (unsubscribe) unsubscribe();
  });

  async function handleLogout() {
    if (loggingOut) return;
    loggingOut = true;
    closeMobileMenu();
    try {
      if (authProvider === "plug") await disconnectPlug();
      else if (authProvider === "oisy") await disconnectOisy();
      else if (authClient) await authClient.logout();
    } catch (error) {
      console.warn("Wallet disconnect was interrupted:", error);
    } finally {
      sessionStorage.removeItem("defunds.auth.provider");
      const anonymousAgent = new HttpAgent({ host });
      if (localLoanTest) await anonymousAgent.fetchRootKey();
      setAgent(anonymousAgent);
      globalStore.update((store) => ({
        ...store, isAuthed: false, principal: undefined, authProvider: null
      }));
      loggingOut = false;
      goto("/");
    }
  }

  function navigateToProfile() {
    closeMobileMenu();
    goto("/profile");
  }
</script>

<svelte:window on:keydown={handleKeydown} />

<nav aria-label="Main navigation" class="border-b border-slate-800/80 bg-slate-950/95 backdrop-blur">
  <div class="container mx-auto flex min-h-[64px] items-center justify-between gap-3 px-4 py-3 md:min-h-[72px] md:py-4">
    <a
      href="/"
      class="flex min-w-0 items-center text-xl font-semibold tracking-tight text-slate-100 focus-visible:rounded-lg focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400 md:text-2xl"
      on:click={closeMobileMenu}
    >
      <img
        src="/defund_logo.jpg"
        alt=""
        class="mr-2 h-8 w-8 shrink-0 rounded-md ring-1 ring-sky-400/30"
      />
      <span>Defunds</span>
    </a>

    <!-- Desktop navigation: keep all primary destinations visible. -->
    <div class="hidden items-center gap-1 md:flex">
      {#each navLinks as link (link.href)}
        <a
          href={link.href}
          aria-current={isActiveLink($page.url.pathname, link.href) ? "page" : undefined}
          class="rounded-lg px-3 py-2 text-sm font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400 {isActiveLink($page.url.pathname, link.href) ? 'bg-slate-800 text-sky-200' : 'text-slate-300 hover:bg-slate-800/70 hover:text-sky-200'}"
        >
          {link.label}
        </a>
      {/each}
      {#if isAuthed}
        <button
          type="button"
          class="ml-2 rounded-lg px-3 py-2 text-sm font-medium text-slate-300 hover:bg-slate-800/70 hover:text-sky-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
          on:click={navigateToProfile}
        >
          Profile
        </button>
        <button
          type="button"
          class="ml-1 rounded-lg border border-slate-700 bg-slate-900 px-4 py-2 text-sm font-medium text-slate-100 shadow-finance hover:border-sky-500/60 hover:text-sky-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
          on:click={handleLogout}
        >
          Logout
        </button>
      {:else}
        <button
          type="button"
          class="ml-2 rounded-lg bg-sky-600 px-4 py-2 text-sm font-semibold text-white shadow-finance hover:bg-sky-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
          on:click={openLoginDialog}
        >
          Login
        </button>
      {/if}
    </div>

    <!-- Mobile header: login stays one tap away; other links live in the menu. -->
    <div class="flex shrink-0 items-center gap-2 md:hidden">
      {#if !isAuthed}
        <button
          type="button"
          class="min-h-[44px] rounded-lg bg-sky-600 px-3 text-sm font-semibold text-white hover:bg-sky-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
          on:click={openLoginDialog}
        >
          Login
        </button>
      {/if}
      <button
        bind:this={menuButton}
        type="button"
        aria-label={isMobileMenuOpen ? "Close navigation menu" : "Open navigation menu"}
        aria-expanded={isMobileMenuOpen}
        aria-controls="mobile-primary-navigation"
        class="flex h-11 w-11 items-center justify-center rounded-lg border border-slate-700 bg-slate-900 text-slate-100 transition-colors hover:border-sky-500/60 hover:text-sky-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
        on:click={() => (isMobileMenuOpen = !isMobileMenuOpen)}
      >
        {#if isMobileMenuOpen}
          <svg aria-hidden="true" class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
        {:else}
          <svg aria-hidden="true" class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M4 7h16M4 12h16M4 17h16" />
          </svg>
        {/if}
      </button>
    </div>
  </div>

  <div
    id="mobile-primary-navigation"
    class="border-t border-slate-800 bg-slate-950 px-4 pb-4 pt-2 md:hidden {isMobileMenuOpen ? 'block' : 'hidden'}"
  >
    <div class="container mx-auto flex flex-col gap-1">
      {#each navLinks as link (link.href)}
        <a
          href={link.href}
          aria-current={isActiveLink($page.url.pathname, link.href) ? "page" : undefined}
          class="flex min-h-[44px] items-center rounded-lg px-4 py-2.5 text-sm font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400 {isActiveLink($page.url.pathname, link.href) ? 'bg-sky-500/15 text-sky-200' : 'text-slate-200 hover:bg-slate-800 hover:text-sky-200'}"
          on:click={closeMobileMenu}
        >
          {link.label}
        </a>
      {/each}
      {#if isAuthed}
        <div class="my-2 border-t border-slate-800"></div>
        <button
          type="button"
          class="flex min-h-[44px] items-center rounded-lg px-4 py-2.5 text-left text-sm font-medium text-slate-200 hover:bg-slate-800 hover:text-sky-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
          on:click={navigateToProfile}
        >
          Profile
        </button>
        <button
          type="button"
          class="flex min-h-[44px] items-center rounded-lg px-4 py-2.5 text-left text-sm font-medium text-slate-200 hover:bg-slate-800 hover:text-sky-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400"
          on:click={handleLogout}
        >
          Logout
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
