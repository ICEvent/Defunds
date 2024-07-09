<script>
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
</script>
<div class="bg-white shadow-md rounded-md p-4 mb-4">
    <p class="text-gray-700">{donation.amount} {donation.currency} from {donation.donor} at {formattedTimestamp}</p>
</div>