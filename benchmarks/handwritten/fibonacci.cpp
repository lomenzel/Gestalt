#include <chrono>
#include <cstdlib>
#include <iostream>

long long fibonacci(long long n) {
    if (n < 2) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main(int argc, char* argv[]) {
    int iterations = argc > 1 ? std::atoi(argv[1]) : 100;
    int input = argc > 2 ? std::atoi(argv[2]) : 30;

    // Warmup
    fibonacci(input);

    auto start = std::chrono::high_resolution_clock::now();
    volatile long long result = 0;
    for (int i = 0; i < iterations; i++) {
        result = fibonacci(input);
    }
    auto end = std::chrono::high_resolution_clock::now();

    auto time_us = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
    std::cerr << "result=" << result << std::endl;
    std::cout << time_us << std::endl;
    return 0;
}
