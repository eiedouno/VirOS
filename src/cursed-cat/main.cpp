#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <ctime>

int main(int argc, char* argv[]) {
    std::srand(std::time(nullptr));
    if (argc < 2) {
        std::cerr << "Usage: cat <file>\n";
        return 1;
    }
    std::ifstream f(argv[1]);
    if (!f) {
        std::cerr << "cat: " << argv[1] << ": No such file or directory\n";
        return 1;
    }
    std::string line;
    while (std::getline(f, line)) {
        for (char& c : line) {
            if (std::rand() % 50 == 0 && std::isalpha(c))
                c = 'a' + std::rand() % 26;
        }
        std::cout << line << '\n';
    }
    return 0;
}
