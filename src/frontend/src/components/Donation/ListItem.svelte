<script>
	import { EXPLORER_ICP_TX, EXPLORER_PRINCIPAL } from "$lib/constants";
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
<div class="bg-white shadow-md rounded-md p-4 mb-4">
    <p class="text-gray-700">{donation.amount} {donation.currency} from 
      
      <a
      href="{EXPLORER_PRINCIPAL}{donation.donor.toText()}"
      target="_blank"
      rel="noopener noreferrer"
      class="text-blue-500 hover:text-blue-700"
  >
      {`${donation.donor.toText().slice(0, 5)}...${donation.donor.toText().slice(-5)}`}
  </a>
      at {formattedTimestamp}</p>

        <a
            href="{EXPLORER_ICP_TX}{transactionId}"
            target="_blank"
            rel="noopener noreferrer"
            class="text-blue-500 hover:text-blue-700"
        >
            {`${transactionId.slice(0, 5)}...${transactionId.slice(-5)}`}
        </a>
   
</div>