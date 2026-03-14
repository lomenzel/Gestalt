const iterations = parseInt(process.argv[2]) || 100;
const inputM = parseInt(process.argv[3]) || 3;
const inputN = parseInt(process.argv[4]) || 7;

function ackermann(m, n) {
  if (m === 0) return n + 1;
  if (n === 0) return ackermann(m - 1, 1);
  return ackermann(m - 1, ackermann(m, n - 1));
}

// Warmup
ackermann(inputM, inputN);

const start = performance.now();
let result;
for (let i = 0; i < iterations; i++) {
  result = ackermann(inputM, inputN);
}
const end = performance.now();

process.stderr.write(`result=${result}\n`);
console.log(Math.round((end - start) * 1000));
