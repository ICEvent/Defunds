import { writable } from 'svelte/store';

const initialValue = {
    isAuthed: false,
    principal: undefined,
    notifications: [],
    loading: false
};

export const globalStore = writable(initialValue);
