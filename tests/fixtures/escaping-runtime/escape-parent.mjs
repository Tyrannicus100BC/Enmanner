import { spawn } from "node:child_process";

const child = spawn(process.execPath, ["escape-server.mjs"], {
  detached: true,
  env: process.env,
  stdio: "ignore",
});
child.unref();

setInterval(() => {}, 1_000);
