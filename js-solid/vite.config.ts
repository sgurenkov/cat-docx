import { defineConfig } from 'vite'
import UnoCSS from 'unocss/vite'
import solidPlugin from 'vite-plugin-solid'
// import devtools from 'solid-devtools/vite';

export default defineConfig({
  publicDir: './public/',
  base: '',
  plugins: [
    /* 
    Uncomment the following line to enable solid-devtools.
    For more info see https://github.com/thetarnav/solid-devtools/tree/main/packages/extension#readme
    */
    // devtools(),
    UnoCSS(),
    solidPlugin()
  ],
  server: {
    port: 3000
  },
  build: {
    target: 'esnext',
    outDir: '../docs'
  }
})
