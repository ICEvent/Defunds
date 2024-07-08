

export const index = 2;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/2.1facc13e.js","_app/immutable/chunks/scheduler.e108d1fd.js","_app/immutable/chunks/index.ad5d9e1f.js","_app/immutable/chunks/preload-helper.a4192956.js"];
export const stylesheets = ["_app/immutable/assets/2.66cd5266.css"];
export const fonts = [];
