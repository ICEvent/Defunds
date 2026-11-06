import adapter from '@sveltejs/adapter-static';
// import adapter from '@sveltejs/adapter-node';
import sveltePreprocess from 'svelte-preprocess';


/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: sveltePreprocess({
    scss: {
      // You can add any SASS options here
    }
  }),
  kit: {
    adapter: adapter({
      pages: 'dist',
      assets: 'dist',
      fallback: 'index.html',
      precompress: false,
      strict: true,
    }),
    prerender: {
      entries: [
        '/',
        '/about',
        '/applications',
        '/application/[id]',
        '/dao',
        '/donations',
        '/profile'
      ]
    },
    alias: {
			$declarations: '../declarations'
		}
  },
};export default config;
