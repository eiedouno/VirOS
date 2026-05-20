#include <iostream>
#include <cstdlib> // for system()
#include <string>

int main() {
    std::string folderName;
    std::cout << "What is your folder name?: "; // Added semicolon
    std::getline(std::cin, folderName);        // Fixed getline syntax

    int result = 0; // Declared outside the loop so it's in scope later

    for(int i = 0; i < 100; i++){
        // Used std::to_string(i) to properly concatenate the integer
        std::string command = "mkdir -p " + folderName + std::to_string(i);
        
        // Execute the command
        result = system(command.c_str());
    }
   
    // Now 'result' can be accessed here
    if (result == 0) {
        std::cout << "Directories created successfully.\n";
    } else {
        std::cerr << "Failed to create directories.\n";
    }

    return 0;
}
