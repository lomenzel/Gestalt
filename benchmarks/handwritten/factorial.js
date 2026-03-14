const iterations = parseInt(process.argv[2]) || 1000;
const input = parseInt(process.argv[3]) || 20;

function factorial(n) {
  if (n < 2) return 1;
  return n * factorial(n - 1);
}

// Warmup
factorial(input);

const start = performance.now();
let result;
for (let i = 0; i < iterations; i++) {
  result = factorial(input);
}
const end = performance.now();

process.stderr.write(`result=${result}\n`);
console.log(Math.round((end - start) * 1000));
