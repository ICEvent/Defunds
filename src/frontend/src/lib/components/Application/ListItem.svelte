<script>
  export let app;
</script>

<div class="bg-white shadow-md rounded-md p-4 mb-4">
  <h3 class="text-xl text-gray-900 mb-2">{app.title}</h3>
  <p class="text-lg font-semibold text-green-600">{app.amount} {app.currency}</p>
  <p class="mb-4 text-gray-700">{app.description}</p>
  
  <div class="flex justify-end">
    <a href="/application/{app.grantId}" class="text-sm text-indigo-600 hover:text-indigo-800">
      View Details →
    </a>
  </div>
</div>
