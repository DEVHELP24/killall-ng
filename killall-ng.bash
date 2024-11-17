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
exit_code=0  # Default success exit code

# Function to check and kill a process
kill_process() {
  local prog="$1"
  local pids=$(pgrep -f "$prog")  # Use pgrep to match Flatpak/bwrap processes as well

  if [ -z "$pids" ]; then
    echo "No process found for '$prog'."
    return 0
  fi

  for pid in $pids; do
    for attempt in {1..8}; do
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "PID $pid for '$prog': Already terminated."
        break
      fi

      kill -9 "$pid" 2>/dev/null

      if [ $? -eq 0 ]; then
        echo "PID $pid for '$prog': Successfully killed (attempt $attempt)."
        break
      else
        echo "PID $pid for '$prog': Failed to kill (attempt $attempt)."
        sleep 0.25
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

# Display non-killable PIDs if any
if [ ${#non_killable_pids[@]} -ne 0 ]; then
  echo -e "\nThe following processes could not be killed:"
  for pid in "${!non_killable_pids[@]}"; do
    echo "PID: $pid (Program: ${non_killable_pids[$pid]})"
  done
  exit_code=18  # Failure exit code
fi

exit $exit_code
