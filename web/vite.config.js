import { defineConfig } from 'vite';
import { readFileSync, existsSync } from 'node:fs';

// Served at https://iossmelltest.web.app/check/ from ../site/public/check (Firebase Hosting serves the
// web config at /__/firebase/init.json). For local dev, the same config comes from init.local.json,
// which is git-ignored: `firebase apps:sdkconfig WEB <appId> --project iossmelltest`.
const localInit = () => ({
  name: 'local-firebase-init',
  configureServer(server) {
    server.middlewares.use('/__/firebase/init.json', (_req, res) => {
      if (!existsSync('init.local.json')) { res.statusCode = 404; return res.end(); }
      res.setHeader('Content-Type', 'application/json');
      res.end(readFileSync('init.local.json'));
    });
  },
});

export default defineConfig({
  base: '/check/',
  plugins: [localInit()],
  build: { outDir: '../site/public/check', emptyOutDir: true, target: 'es2024' },
  server: { port: 5173 },
});
