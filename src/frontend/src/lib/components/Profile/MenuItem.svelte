<script>
    export let name;
    export let active;

    // Capitalize the first letter of the name
    $: displayName = name.charAt(0).toUpperCase() + name.slice(1);
</script>

<button
    type="button"
    class="menu-item"
    class:active
    on:click
    on:keydown={(e) => e.key === 'Enter' && e.target.click()}
>
    <span>{displayName}</span>
</button>

<style>
    .menu-item {
        width: 100%;
        text-align: left;
        padding: 12px 16px;
        border: none;
        background: none;
        cursor: pointer;
        border-radius: 8px;
        transition: all 0.2s ease;
    }

    .menu-item:hover {
        background-color: #f3f4f6;
    }

    .menu-item.active {
        font-weight: 600;
        background-color: #e5e7eb;
        color: #1a202c;
    }
</style>
