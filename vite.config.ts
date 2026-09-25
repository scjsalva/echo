/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// vite-plugin-ruby aliases "@/" to app/frontend.
export default defineConfig({
  plugins: [RubyPlugin(), vue(), tailwindcss()],
  test: {
    environment: 'jsdom',
    include: ['**/*.test.ts'],
  },
})
