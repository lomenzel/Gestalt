#include <iostream>

#include "app.hpp"

int main() {
  std::cout << app::meta["name"].asString();
  return 0;
}