#!/bin/bash

# SPDX-License-Identifier: MIT
# Maintainer: [NAZY-OS]
# This script kills all processes matching the given program names, including Flatpak (bwrap) processes.

# Usage: killall-ng <program-name1> <program-name2> ...

if [ -z "$1" ]; then
  echo "Please provide at least one program name."
  exit 1
fi

declare -A non_killable_pids  # Track non-killable PIDs
programs_found=false  # Flag to check if any process was found

# Function to check and kill a process
kill_process() {
  local prog="$1"
  
  # Get PIDs of the program using pidof
  local pids=$(pidof "$prog" 2>/dev/null)

  # Check for Flatpak processes (flatpak uses bwrap as a container executor)
  bwrap_pids=$(ps aux | grep "bwrap.*$prog" | grep -v "grep" | awk '{print $2}')
  pids="$pids $bwrap_pids"

  # Check if any process matching the program was found
  if [ -z "$pids" ]; then
    return 0  # No matching processes found
  fi

  programs_found=true  # Set flag to true since we found a process

  # If only one PID exists, validate its cmdline
  if [[ $(echo "$pids" | wc -w) -eq 1 ]]; then
    local pidonly=$(echo "$pids" | awk '{print $1}')
    local cmdline=$(cat /proc/$pidonly/cmdline 2>/dev/null | tr '\0' ' ')

    # Skip the PID if cmdline doesn't match the program name
    if [[ "$cmdline" != *"$prog"* ]]; then
      return 0
    fi
  fi

  # Loop through all PIDs and attempt to kill them
  for pid in $pids; do
    for attempt in {1..8}; do
      if ! kill -0 "$pid" 2>/dev/null; then
        break  # Process is already terminated
      fi

      kill -9 "$pid" 2>/dev/null

      if [ $? -eq 0 ]; then
        echo "PID $pid for '$prog': Successfully killed (attempt $attempt)."
        break
      else
        sleep 0.25  # Wait before trying again
      fi

      # After 8 attempts, add to non-killable list
      if [ $attempt -eq 8 ]; then
        non_killable_pids["$pid"]="$prog"
      fi
    done
  done
}

# Main loop: Kill processes for each program name provided
for prog in "$@"; do
  kill_process "$prog"
done

# Display summary at the end
if [ $programs_found == false ]; then
  echo -e "\nNo programs found, nothing to do. Done!"
elif [ ${#non_killable_pids[@]} -ne 0 ]; then
  echo -e "\n==================== SUMMARY ===================="
  echo -e "The following processes could not be terminated:\n"

  for pid in "${!non_killable_pids[@]}"; do
    echo "🔸 PID: $pid (Program: '${non_killable_pids[$pid]}')"
  done

  echo -e "\nConsider checking these processes manually."
  echo -e "================================================="
  exit 18  # Failure exit code if any process could not be killed
else
  echo -e "\n🎉 All specified processes have been successfully terminated."
  exit 0  # Success exit code
fi
