import { writable } from 'svelte/store';

export const progressStore = writable({
    show: false
});

export const showProgress = () => progressStore.set({ show: true });
export const hideProgress = () => progressStore.set({ show: false });
