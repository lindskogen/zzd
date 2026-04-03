const buf = new Uint8Array(16);
const tick = () => {
  crypto.getRandomValues(buf);
  process.stdout.write(buf);
};

setInterval(tick, 1000);
tick();
