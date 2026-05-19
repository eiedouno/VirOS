#include <iostream>
#include <cstdlib> // Required for system()
#include <string>

int main() {
    // Hardcode your Linux path here
    const std::string targetPath = "/URMOM";

    // Combine mkdir and cd into a single Bash command string
    // 'mkdir -p' creates the directory
    // '&&' ensures 'cd' only runs if the directory creation succeeded
    // '; bash' spawns a new shell so the terminal stays open in that directory
    std::string command = "mkdir -p " + targetPath + " && cd " + targetPath + " && bash";

    std::cout << "Creating directory and launching shell at: " << targetPath << "\n";

    // Execute the Bash command line
    int result = std::system(command.c_str());

    if (result != 0) {
        std::cerr << "Something went wrong executing the command.\n";
    }

    return 0;
}