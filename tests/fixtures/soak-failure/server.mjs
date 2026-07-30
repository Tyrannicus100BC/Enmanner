import http from "node:http";

const server = http.createServer((_request, response) => {
  response.writeHead(200, { "content-type": "text/plain" });
  response.end("ready");
});

server.listen(Number(process.env.PORT), "127.0.0.1");

process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
