#!/bin/bash
# Script that properly daemonizes and maintains a PID file

# Log execution
echo "$(date): process.sh main started" >> /results/process_execution.log

# Kill any existing instances of our process
if [ -f /tmp/process.pid ]; then
    OLD_PID=$(cat /tmp/process.pid 2>/dev/null)
    if [ -n "$OLD_PID" ]; then
        echo "$(date): Killing old process $OLD_PID" >> /results/process_execution.log
        kill $OLD_PID 2>/dev/null || true
    fi
    rm -f /tmp/process.pid
fi

# Launch the actual long-running process and record its PID
# Use setsid to create a new process group
setsid /bin/bash -c '
    # Write PID to file
    echo $$ > /tmp/process.pid

    # Log execution
    echo "$(date): process.sh daemon started with PID $$" >> /results/process_execution.log
    
    # Handle SIGTERM gracefully
    trap "echo \"$(date): process.sh received SIGTERM\" >> /results/process_execution.log; rm -f /tmp/process.pid; exit 0" TERM
    
    # Sleep for 30 min
    sleep 1800
    
    # Exit cleanly
    echo "$(date): process.sh daemon completed" >> /results/process_execution.log
    rm -f /tmp/process.pid
    exit 0
' >/dev/null 2>&1 &

# Wait briefly for the PID file to be created
sleep 1

# Verify the PID file exists and process is running
if [ -f /tmp/process.pid ] && kill -0 $(cat /tmp/process.pid) 2>/dev/null; then
    echo "$(date): process.sh daemon running with PID $(cat /tmp/process.pid)" >> /results/process_execution.log
    exit 0
else
    echo "$(date): ERROR: Failed to start daemon process" >> /results/process_execution.log
    exit 1
fi
