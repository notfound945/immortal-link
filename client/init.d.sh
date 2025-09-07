#!/bin/sh /etc/rc.common

# Service name and description
NAME="immortal-link"
DESCRIPTION="Starts and stops the immortal-link service"

# Startup priority (99 means starting late, ensuring system services are ready)
START=99
# Shutdown priority
STOP=10

# Define script path
SCRIPT_PATH="$HOME/immortal-link/start.sh"

start() {
    echo "Starting $NAME..."
    
    # Check if script exists and is executable
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: $SCRIPT_PATH not found!"
        return 1
    fi
    
    if [ ! -x "$SCRIPT_PATH" ]; then
        echo "Error: $SCRIPT_PATH is not executable!"
        chmod +x "$SCRIPT_PATH"
        echo "Made $SCRIPT_PATH executable"
    fi
    
    # Start the script and run in background
    $SCRIPT_PATH &
    echo "$NAME started successfully"
}

stop() {
    echo "Stopping $NAME..."
    
    # Find and terminate related processes
    if pgrep -f "$SCRIPT_PATH" > /dev/null; then
        pkill -f "$SCRIPT_PATH"
        echo "$NAME stopped successfully"
    else
        echo "$NAME is not running"
    fi
}

# Restart function
restart() {
    stop
    sleep 2
    start
}
