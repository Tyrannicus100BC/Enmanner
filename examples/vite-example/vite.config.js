import { defineConfig } from 'vite';

export default defineConfig(async () => {
  // The example's pinned launcher predates the adapter and runs ordinary Vite.
  if (!process.env.ENMANNER_LIVE_UPDATES_FILE) return {};

  const adapterURL = new URL('./.enmanner/adapters/vite-live-updates.mjs', import.meta.url);
  const { enmannerLiveUpdates } = await import(adapterURL.href);
  return { plugins: [enmannerLiveUpdates()] };
});
