#include <iostream>

#include "app.hpp"

int main() {
    std::cout << "Hello, World!" << std::endl;
    std::cout << app::exampleView.asString() << std::endl;
    std::cout << app::view(app::initialState).asString() << std::endl;
    return 0;
}