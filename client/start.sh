#!/bin/sh

# Define target working directory
WORK_DIR="/root/immortal-link"
# Define process identification keyword (unique to avoid killing wrong processes)
PROCESS_KEY="lua client.lua --host ls"
# Define client startup command (using relative path after changing directory)
START_CMD="lua client.lua --host ls &"
# Define log file path (relative to working directory)
LOG_FILE="start.log"

# Check if process exists and get its PID
get_pid() {
    ps | grep -v grep | grep "$PROCESS_KEY" | awk '{print $1}'
}

# Kill the old process if it exists
kill_old_process() {
    local pid=$(get_pid)
    if [ -n "$pid" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Old process found, PID: $pid, killing..." >> "$LOG_FILE" 2>&1
        kill -9 "$pid" 2>/dev/null
        sleep 1
        # Check again if the old process was successfully killed
        if [ -n "$(get_pid)" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Failed to kill old process!" >> "$LOG_FILE" 2>&1
            return 1
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Old process killed" >> "$LOG_FILE" 2>&1
            return 0
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No running process found" >> "$LOG_FILE" 2>&1
        return 0
    fi
}

# Change to the target working directory
change_working_dir() {
    if [ -d "$WORK_DIR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Changing to working directory: $WORK_DIR" >> "$LOG_FILE" 2>&1
        cd "$WORK_DIR" || {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Failed to enter directory $WORK_DIR" >> "$LOG_FILE" 2>&1
            return 1
        }
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Directory $WORK_DIR does not exist!" >> "$LOG_FILE" 2>&1
        return 1
    fi
}

# Start the new process
start_new_process() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting new process..." >> "$LOG_FILE" 2>&1
    eval $START_CMD
    sleep 1
    # Verify if the new process started successfully
    if [ -n "$(get_pid)" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] New process started successfully, PID: $(get_pid)" >> "$LOG_FILE" 2>&1
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Failed to start new process!" >> "$LOG_FILE" 2>&1
        return 1
    fi
}

# Main workflow
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== Starting process handling =====" >> "$LOG_FILE" 2>&1
# Execute steps in sequence: change directory → kill old process → start new process
change_working_dir && kill_old_process && start_new_process
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== Process handling completed =====" >> "$LOG_FILE" 2>&1