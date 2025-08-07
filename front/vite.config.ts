import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
// import { webcrypto as crypto } from 'node:crypto';

// globalThis.crypto = crypto as unknown as Crypto;

export default defineConfig({
  server: {
    host: '0.0.0.0',
    port: 5050,
  },
  plugins: [
    tailwindcss({
      config: './tailwind.config.js',
    }), 
    sveltekit()
  ]
});
