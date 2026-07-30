console.error("worker started and will fail after readiness");

setTimeout(() => {
  console.error("worker delayed failure");
  process.exit(23);
}, 750);
