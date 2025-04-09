#!/bin/bash

# Helper script to check for zombie processes and Monit status
# Can be run manually inside the container

echo "===== Container Process Information ====="
echo "PID 1 process: $(ps -p 1 -o comm=)"
echo "Monit version: $(monit -V | head -1)"
echo "Monit status summary:"
monit summary

echo -e "\n===== Checking for zombie processes ====="
ZOMBIES=$(ps -eo stat,pid,ppid,cmd | grep -c "^Z")
echo "Number of zombies: $ZOMBIES"

if [ $ZOMBIES -gt 0 ]; then
    echo -e "\nDetails of zombie processes:"
    ps -eo stat,pid,ppid,cmd | grep "^Z"
    
    echo -e "\nParent processes of zombies:"
    # Extract parent PIDs of zombies and show those processes
    ZOMBIE_PARENTS=$(ps -eo stat,pid,ppid,cmd | grep "^Z" | awk '{print $3}' | sort -u)
    for ppid in $ZOMBIE_PARENTS; do
        ps -p $ppid -o pid,ppid,stat,cmd
    done
    
    exit 1
else
    echo "No zombie processes found."
    
    echo -e "\n===== Recent process executions ====="
    echo "Program execution log (last 5 entries):"
    tail -5 /results/program_execution.log 2>/dev/null || echo "No log found"
    
    echo -e "\nProcess execution log (last 5 entries):"
    tail -5 /results/process_execution.log 2>/dev/null || echo "No log found"
    
    exit 0
fi
