<script>
    import { progressStore } from '$lib/stores/progress';
</script>

{#if $progressStore.show}
    <div class="fixed inset-0 bg-black/20 backdrop-blur-sm flex items-center justify-center z-[9999]">
        <div class="bg-white rounded-lg p-6 shadow-xl flex items-center gap-4">
            <div class="w-8 h-8 border-4 border-purple-600 border-t-transparent rounded-full animate-spin"></div>
            <span class="text-gray-700 font-medium">Processing ...</span>
        </div>
    </div>
{/if}