import { writable } from 'svelte/store';

type NotificationType = 'info' | 'error' | 'success';

interface Notification {
    type: NotificationType;
    message: string;
    show: boolean;
}

export const notificationStore = writable<Notification>({
    type: 'info',
    message: '',
    show: false
});

export const showNotification = (message: string, type: NotificationType = 'info') => {
    notificationStore.set({ message, type, show: true });
    setTimeout(() => {
        notificationStore.set({ message: '', type: 'info', show: false });
    }, 3000);
};
