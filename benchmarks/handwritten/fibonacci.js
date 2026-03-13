const iterations = parseInt(process.argv[2]) || 10;
const input = parseInt(process.argv[3]) || 30;

function fibonacci(n) {
    if (n < 2) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Warmup
fibonacci(input);

const start = performance.now();
let result;
for (let i = 0; i < iterations; i++) {
    result = fibonacci(input);
}
const end = performance.now();

process.stderr.write(`result=${result}\n`);
console.log(Math.round((end - start) * 1000));
