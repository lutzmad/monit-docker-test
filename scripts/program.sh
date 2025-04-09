#!/bin/bash

# Script that runs and exits after 10 seconds
# Used for Monit's 'check program' test

# Check for zombie processes
ZOMBIES=$(ps -eo stat,pid,ppid,cmd | grep -c "^Z")
if [ $ZOMBIES -gt 0 ]; then
    echo "$(date): Error: $ZOMBIES zombie processes detected" >> /results/zombies_error.log
    echo "$(date): Zombie process details:" >> /results/zombies_details.log
    ps -eo stat,pid,ppid,cmd | grep "^Z" >> /results/zombies_details.log
    
    # Check if Monit is PID 1
    PID1_CMD=$(ps -p 1 -o comm=)
    echo "$(date): PID 1 is: $PID1_CMD" >> /results/zombies_details.log
fi

# Log execution time
echo "$(date): program.sh started" >> /results/program_execution.log

# Sleep for 10 seconds
sleep 10

# Exit with status 0 (success)
echo "$(date): program.sh completed" >> /results/program_execution.log
exit 0
