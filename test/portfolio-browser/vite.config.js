import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from 'tailwindcss';
import autoprefixer from 'autoprefixer';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../..', import.meta.url));
export default defineConfig({
 root: fileURLToPath(new URL('.',import.meta.url)),
 plugins: [svelte({configFile:false})],
 resolve: {alias: {'$lib': `${root}/src/frontend/src/lib`}},
 css:{postcss:{plugins:[tailwindcss({content:[`${root}/src/frontend/src/**/*.{html,js,svelte,ts}`,`${root}/test/portfolio-browser/*.svelte`]}),autoprefixer()]}},
 server: {host:'127.0.0.1',port:4182,strictPort:true,fs:{allow:[root]}},
});
