import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
    // Cargar firebase-admin y levantar la app tarda más de los 10 s por defecto.
    hookTimeout: 90_000,
    testTimeout: 30_000,
  },
});
