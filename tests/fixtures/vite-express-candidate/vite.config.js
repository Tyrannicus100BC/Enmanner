const apiPort = process.env.API_PORT;

export default {
  server: {
    proxy: {
      "/api": `http://127.0.0.1:${apiPort}`,
    },
  },
};
