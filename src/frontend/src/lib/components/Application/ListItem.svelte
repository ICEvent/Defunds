<script>
  export let app;
</script>

<div class="mb-4 rounded-xl border border-slate-700/80 bg-slate-900 p-4 shadow-finance">
  <h3 class="mb-2 text-xl text-slate-100">{app.title}</h3>
  <p class="text-lg font-semibold text-emerald-400">{app.amount} {app.currency}</p>
  <p class="mb-4 text-slate-300">{app.description}</p>
  
  <div class="flex justify-end">
    <a href="/application/{app.grantId}" class="text-sm font-medium text-sky-300 hover:text-sky-200">
      View Details →
    </a>
  </div>
</div>
