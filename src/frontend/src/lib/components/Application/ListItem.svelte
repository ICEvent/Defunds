<script>
  export let app;
  import { getTokenNameByID } from "$lib/constants";

  let yesVotes = 0;
  let noVotes = 0;

  function voteYes() {
      yesVotes++;
      console.log("Voted Yes for", app.grantId);
  }

  function voteNo() {
    noVotes++;
      console.log("Voted No for", app.grantId);
  }
</script>

<div class="bg-white shadow-md rounded-md p-4 mb-4">
  <a href="/application/{app.grantId}" class="text-xl text-indigo-600 mb-2">{app.title}</a>
  <p class="text-lg font-semibold text-green-600">{app.amount} {getTokenNameByID(app.currency)}</p>
  <p class="mb-4 text-gray-700">{app.description}</p>
  
  <div class="flex justify-end space-x-2">
      <button on:click={voteYes} class="bg-green-500 hover:bg-green-600 text-white font-bold py-1 px-3 rounded text-sm">
          Yes ({yesVotes})
      </button>
      <button on:click={voteNo} class="bg-red-500 hover:bg-red-600 text-white font-bold py-1 px-3 rounded text-sm">
          No ({noVotes})
      </button>
  </div>
</div>
