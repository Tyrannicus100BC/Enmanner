import http from "node:http";

const port = Number(process.env.PORT);
const server = http.createServer((_request, response) => {
  response.writeHead(200, { "content-type": "text/plain" });
  response.end("ready");
});

server.listen(port, "::1");
