#include <iostream>
#include <cstdlib> // for system()
#include <string>

int main() {
	std::string folderName;
	std::cout << "What is your folder name?: "
	std::getline(std::cin) >> folderName;

	for(int i = 0; i < 100; i++){
		std::string command = "mkdir -p " + folderName + i;
		 // Execute the command
    	int result = system(command.c_str());
	}
   

    if (result == 0) {
        std::cout << "Directory created successfully.\n";
    } else {
        std::cerr << "Failed to create directory.\n";
    }

    return 0;
}