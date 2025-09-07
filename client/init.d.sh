#!/bin/sh /etc/rc.common
# Copyright (C) 2006 OpenWrt.org

# Service configuration
NAME="immortal-link"
DESCRIPTION="Service for managing immortal-link application"
START=99
STOP=10

# Make it run as a daemon
USE_PROCD=1 

# Path to the main script
SCRIPT_PATH="/root/immortal-link/start.sh"

# Validate script existence and executability
validate_script() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: $SCRIPT_PATH not found"
        return 1
    fi
    
    if [ ! -x "$SCRIPT_PATH" ]; then
        echo "Error: $SCRIPT_PATH is not executable, fixing permissions"
        chmod +x "$SCRIPT_PATH" || return 1
    fi
    return 0
}

# Start service
start_service() {
    validate_script || return 1
    echo "Starting $NAME..."
    $SCRIPT_PATH &
    echo "$NAME started"
}

# Stop service
stop_service() {
    echo "Stopping $NAME..."
    if pgrep -f "$SCRIPT_PATH" > /dev/null; then
        pkill -f "$SCRIPT_PATH"
        echo "$NAME stopped"
    else
        echo "$NAME is not running"
    fi
}

# Restart service
restart_service() {
    stop_service
    sleep 2
    start_service
}
