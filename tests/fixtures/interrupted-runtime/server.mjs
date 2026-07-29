import http from "node:http";
import fs from "node:fs";

const port = Number(process.env.ENMANNER_PORT);
const server = http.createServer((_request, response) => {
  response.writeHead(503, { "content-type": "text/plain" });
  response.end("starting");
});

server.listen(port, "127.0.0.1", () => {
  fs.writeFileSync("runtime-server.pid", String(process.pid));
});

process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
