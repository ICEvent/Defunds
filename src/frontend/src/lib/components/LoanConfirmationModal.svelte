<script>
  import { createEventDispatcher } from 'svelte';

  export let open = false;
  export let title = '';
  export let description = '';
  export let amount = '';
  export let reference = '';
  export let paymentDate = '';
  export let paymentMethod = '';
  export let confirmLabel = 'Confirm';
  export let pending = false;
  export let error = '';
  export let danger = false;

  const dispatch = createEventDispatcher();
  let modalRoot;

  function focusOnMount(node) {
    node.focus();
  }

  function handleKeydown(event) {
    if (!open) return;
    if (event.key === 'Escape' && !pending) {
      event.preventDefault();
      dispatch('cancel');
      return;
    }

    // Keep keyboard focus inside the open confirmation modal.
    if (event.key === 'Tab' && modalRoot) {
      const items = Array.from(modalRoot.querySelectorAll('button:not([disabled])'));
      if (!items.length) return;
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/75 p-4">
    <div
      bind:this={modalRoot}
      role="dialog"
      aria-modal="true"
      aria-labelledby="loan-confirm-title"
      aria-describedby="loan-confirm-description"
      class="w-full max-w-md rounded-2xl border border-slate-600 bg-slate-900 p-6 text-slate-100 shadow-2xl"
      data-testid="loan-confirmation-modal"
    >
      <h2 id="loan-confirm-title" class="text-xl font-semibold">{title}</h2>
      <p id="loan-confirm-description" class="mt-3 text-sm leading-relaxed text-slate-300">{description}</p>

      {#if amount}
        <div class="mt-4 rounded-lg bg-slate-800 p-4">
          <div class="text-xs text-slate-400">Transaction amount</div>
          <div class="mt-1 text-2xl font-bold" data-testid="loan-confirmation-amount">{amount}</div>
        </div>
      {/if}

      {#if paymentDate || paymentMethod}
        <dl class="mt-4 space-y-2 rounded-lg border border-slate-700 p-3 text-sm"
          data-testid="loan-confirmation-payment-details">
          {#if paymentDate}
            <div class="flex flex-wrap justify-between gap-2">
              <dt class="text-slate-400">Recorded payment date (UTC)</dt>
              <dd class="font-medium">{paymentDate}</dd>
            </div>
          {/if}
          {#if paymentMethod}
            <div class="flex flex-wrap justify-between gap-2">
              <dt class="text-slate-400">Recorded payment method</dt>
              <dd class="font-medium">{paymentMethod}</dd>
            </div>
          {/if}
        </dl>
      {/if}

      {#if reference}
        <div class="mt-3 text-xs text-slate-400">{reference}</div>
      {/if}

      {#if error}
        <p role="alert" class="mt-4 rounded-lg border border-red-700 p-3 text-sm text-red-200">{error}</p>
      {/if}

      <div class="mt-6 flex justify-end gap-3">
        <button type="button" disabled={pending} use:focusOnMount on:click={() => dispatch('cancel')}
          class="rounded-lg border border-slate-600 px-4 py-2 text-sm hover:bg-slate-800 disabled:opacity-50">
          Cancel
        </button>
        <button type="button" disabled={pending} on:click={() => dispatch('confirm')}
          class={danger
            ? 'rounded-lg bg-red-700 px-4 py-2 text-sm font-semibold hover:bg-red-600 disabled:opacity-50'
            : 'rounded-lg bg-sky-600 px-4 py-2 text-sm font-semibold hover:bg-sky-500 disabled:opacity-50'}>
          {pending ? 'Processing…' : confirmLabel}
        </button>
      </div>
    </div>
  </div>
{/if}
