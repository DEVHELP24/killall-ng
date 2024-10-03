#include <iostream>
#include <vector>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>

// SPDX-License-Identifier: MIT
// Maintainer: [NAZY-OS]
// This program kills all processes that match the given program names.
// Usage: killall-ng <program-name1> <program-name2> ...

// Function to kill processes of the specified program name
void killProcesses(const std::string& program) {
    std::string command = "pidof " + program; // Command to find process IDs
    FILE* pipe = popen(command.c_str(), "r"); // Open a pipe to execute the command

    if (!pipe) {
        std::cerr << "Failed to run command: " << command << std::endl;
        return;
    }

    char buffer[128];
    std::string result;
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer; // Collect output
    }
    pclose(pipe); // Close the pipe

    // Check if any PIDs were found
    if (result.empty()) {
        std::cout << "No process found for '" << program << "'." << std::endl;
        return;
    }

    // Parse the PIDs and kill them
    char* token = std::strtok(&result[0], " \n");
    while (token != nullptr) {
        pid_t pid = std::atoi(token);
        if (kill(pid, SIGKILL) == 0) {
            std::cout << "Successfully killed process(es) for '" << program << "'." << std::endl;
        } else {
            std::cerr << "Failed to kill process(es) for '" << program << "'." << std::endl;
        }
        token = std::strtok(nullptr, " \n");
    }
}

int main(int argc, char* argv[]) {
    // Check if at least one program name is provided
    if (argc < 2) {
        std::cerr << "Please provide at least one program name." << std::endl;
        return 1;
    }

    bool allKilled;
    // Loop until all specified processes are killed
    do {
        allKilled = true; // Assume all processes are killed

        for (int i = 1; i < argc; ++i) {
            std::string program = argv[i];
            std::string command = "pidof " + program;
            FILE* pipe = popen(command.c_str(), "r"); // Open a pipe to execute pidof

            if (!pipe) {
                std::cerr << "Failed to run command: " << command << std::endl;
                continue;
            }

            char buffer[128];
            std::string result;
            while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
                result += buffer; // Collect output
            }
            pclose(pipe); // Close the pipe

            // Check if any PIDs were found for the program
            if (!result.empty()) {
                killProcesses(program); // Attempt to kill found processes
                allKilled = false; // Mark that not all processes are killed
            } else {
                std::cout << "No process found for '" << program << "'." << std::endl;
            }
        }

        // Optional: Wait for a moment before checking again
        sleep(1);
    } while (!allKilled);

    std::cout << "All specified processes have been killed." << std::endl;
    return 0;
}
