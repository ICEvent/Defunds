<script>
    export let app;
  </script>
  
<div class="bg-white shadow-md rounded-md p-4 mb-4">
    <a href="/details/{app.id}" class="text-xl font-bold text-indigo-600 mb-2">{app.name}</a>
    <p class="mb-4 text-gray-700">{app.description}</p>
</div>