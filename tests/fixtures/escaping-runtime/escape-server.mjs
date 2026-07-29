import { writeFileSync } from "node:fs";
import { createServer } from "node:http";

const port = Number(process.env.ENMANNER_PORT);
writeFileSync("runtime-child.pid", String(process.pid));

const server = createServer((_request, response) => {
  response.writeHead(200, { "Content-Type": "text/plain" });
  response.end("escaping fixture");
});
server.listen(port, "0.0.0.0");

setTimeout(() => server.close(), 15_000);
