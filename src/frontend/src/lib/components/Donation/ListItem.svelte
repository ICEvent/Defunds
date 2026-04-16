<script>
	import { EXPLORER_ACCOUNT, EXPLORER_ICP_TX, EXPLORER_PRINCIPAL,getTokenNameByID } from "$lib/constants";
  import { Principal } from "@dfinity/principal";
    export let donation;
    const formattedTimestamp = new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    timeZone: 'UTC'
  }).format(new Date(Number(donation.timestamp)/1000000));
  const transactionId = donation.txid;
  
</script>
<div class="mb-4 w-full max-w-full overflow-hidden rounded-xl border border-slate-700/80 bg-slate-900 p-4 shadow-finance">
  <p class="break-words whitespace-normal text-slate-300">
      received
      <a
          href="{EXPLORER_ICP_TX}{transactionId}"
          target="_blank"
          rel="noopener noreferrer"
          class="text-sky-300 hover:text-sky-200"
      >
          {Number(donation.amount)/100000000} {getTokenNameByID(donation.currency)}
      </a>
      from
      <a
          href="{EXPLORER_ACCOUNT}{donation.donor}"
          target="_blank"
          rel="noopener noreferrer"
          class="text-sky-300 hover:text-sky-200"
      >
          {`${donation.donor.slice(0, 5)}...${donation.donor.slice(-5)}`}
      </a>
      at {formattedTimestamp}
  </p>
</div>
