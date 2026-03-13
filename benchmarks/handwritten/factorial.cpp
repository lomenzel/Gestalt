#include <chrono>
#include <cstdlib>
#include <iostream>

long long factorial(long long n) {
    if (n < 2) return 1;
    return n * factorial(n - 1);
}

int main(int argc, char* argv[]) {
    int iterations = argc > 1 ? std::atoi(argv[1]) : 10000;
    int input = argc > 2 ? std::atoi(argv[2]) : 20;

    // Warmup
    factorial(input);

    auto start = std::chrono::high_resolution_clock::now();
    volatile long long result = 0;
    for (int i = 0; i < iterations; i++) {
        result = factorial(input);
    }
    auto end = std::chrono::high_resolution_clock::now();

    auto time_us = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
    std::cerr << "result=" << result << std::endl;
    std::cout << time_us << std::endl;
    return 0;
}
