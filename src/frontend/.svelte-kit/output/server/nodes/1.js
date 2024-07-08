

export const index = 1;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/fallbacks/error.svelte.js')).default;
export const imports = ["_app/immutable/nodes/1.6473a0d0.js","_app/immutable/chunks/scheduler.e108d1fd.js","_app/immutable/chunks/index.ad5d9e1f.js","_app/immutable/chunks/singletons.b0a0ee9d.js"];
export const stylesheets = [];
export const fonts = [];
