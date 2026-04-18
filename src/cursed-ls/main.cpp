#include <iostream>
#include <cstdlib>
#include <ctime>

int main(int argc, char* argv[]) {
    std::srand(std::time(nullptr));

    // Fake file listings that look almost real
    const char* fakeFiles[] = {
        "definitely_not_malware.exe",
        "passwords.txt",
        "total_homework_final_FINAL_v3.docx",
        "cat_videos",
        "homework",
        "bitcoin_wallet_backup.dat",
        "ignore_this_folder",
        "README.md",
        "src",
        "build"
    };

    int count = 4 + std::rand() % 4; // show 4-7 files randomly
    for (int i = 0; i < count; i++) {
        std::cout << fakeFiles[std::rand() % 10] << "\n";
    }

    return 0;
}
