import { defineConfig } from 'vite';
import { enmannerLiveUpdates } from './.enmanner/adapters/vite-live-updates.mjs';

export default defineConfig({ plugins: [enmannerLiveUpdates()] });
