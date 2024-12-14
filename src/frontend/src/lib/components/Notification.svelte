<script lang="ts">
    import { notificationStore } from '$lib/stores/notification';

    function getBackgroundColor(type: string): string {
        switch(type) {
            case 'error': return 'bg-red-500';
            case 'success': return 'bg-green-500';
            default: return 'bg-blue-500';
        }
    }
</script>

{#if $notificationStore.show}
    <div class="fixed bottom-4 right-4 z-[9999] animate-slide-up">
        <div class="rounded-lg shadow-lg p-4 min-w-[300px] {getBackgroundColor($notificationStore.type)}">
            <p class="text-white">{$notificationStore.message}</p>
        </div>
    </div>
{/if}

<style>
    .animate-slide-up {
        animation: slideUp 0.3s ease-out;
    }

    @keyframes slideUp {
        from {
            transform: translateY(100%);
            opacity: 0;
        }
        to {
            transform: translateY(0);
            opacity: 1;
        }
    }
</style>
