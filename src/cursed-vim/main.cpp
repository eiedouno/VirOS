#include <iostream>
#include <cstdlib>
#include <ctime>
#include <string>

int main(int argc, char* argv[]) {
	std::cout << "You said: ";
    for(int i = 1; i < argc; i++){
    	std::cout << argv[i];
    }
    std::cout << "\nBut I say: \n";

    while (1) {
        std::cout << "NO!\n";
    }

    return 0;
}
