#include <chrono>
#include <cstdlib>
#include <iostream>

long long ackermann(long long m, long long n) {
  if (m == 0)
    return n + 1;
  if (n == 0)
    return ackermann(m - 1, 1);
  return ackermann(m - 1, ackermann(m, n - 1));
}

int main(int argc, char *argv[]) {
  int iterations = argc > 1 ? std::atoi(argv[1]) : 1000;
  int input_m = argc > 2 ? std::atoi(argv[2]) : 3;
  int input_n = argc > 3 ? std::atoi(argv[3]) : 7;

  // Warmup
  ackermann(input_m, input_n);

  auto start = std::chrono::high_resolution_clock::now();
  volatile long long result = 0;
  for (int i = 0; i < iterations; i++) {
    result = ackermann(input_m, input_n);
  }
  auto end = std::chrono::high_resolution_clock::now();

  auto time_us =
      std::chrono::duration_cast<std::chrono::microseconds>(end - start)
          .count();
  std::cerr << "result=" << result << std::endl;
  std::cout << time_us << std::endl;
  return 0;
}
