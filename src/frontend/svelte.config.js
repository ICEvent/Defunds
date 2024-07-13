// import adapter from '@sveltejs/adapter-static';
import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    // adapter-auto only supports some environments, see https://kit.svelte.dev/docs/adapter-auto for a list.
    // If your environment is not supported or you settled on a specific environment, switch out the adapter.
    // See https://kit.svelte.dev/docs/adapters for more information about adapters.
    // adapter: adapter({
    //   pages: 'dist',
    //   assets: 'dist',
    //   fallback: undefined,
    //   precompress: false,
    //   strict: true,
    // }),
    adapter: adapter({
      // default options are shown. You can adjust these as needed
      out: 'dist',  // The output directory for the built server
      precompress: false,  // Whether to precompress the output files (gzip)
    })
  },
};

export default config;
