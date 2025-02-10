#!/bin/sh

log_file="/tmp/getevent_debug.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

pipe="/tmp/getevent_pipe"
if [ ! -p "$pipe" ]; then
    mkfifo "$pipe"
    log_msg "Created named pipe: $pipe"
else
    log_msg "Named pipe already exists: $pipe"
fi

restart_getevent() {
    log_msg "Restarting getevent..."
    killall getevent 2>/dev/null
    getevent -l /dev/input/event1 > "$pipe" &
    getevent_pid=$!
    log_msg "getevent restarted with PID $getevent_pid"
}

log_msg "Starting getevent on /dev/input/event1"
getevent -l /dev/input/event1 > "$pipe" &
getevent_pid=$!
log_msg "getevent started with PID $getevent_pid"

cleanup() {
    log_msg "Cleanup triggered. Stopping getevent (PID $getevent_pid)..."
    kill "$getevent_pid" 2>/dev/null
    rm -f "$pipe"
    log_msg "Pipe removed. Exiting script."
    exit 0
}
trap "cleanup" EXIT SIGINT SIGTERM

press_detected=false
last_event_time=$(date +%s)

log_msg "Event monitoring loop started."

while true; do
    # Check if getevent has died
    if ! kill -0 "$getevent_pid" 2>/dev/null; then
        log_msg "getevent process $getevent_pid is NOT running! Restarting..."
        restart_getevent
        last_event_time=$(date +%s)
    fi

    if read -t 1 event < "$pipe"; then
        log_msg "Event received: $event"
        last_event_time=$(date +%s)

        if echo "$event" | grep -q "EV_KEY.*02bf.*DOWN"; then
            press_detected=true
            log_msg "Bixby button DOWN detected."
        fi

        if echo "$event" | grep -q "EV_KEY.*02bf.*UP"; then
            if $press_detected; then
                log_msg "Bixby button UP detected. Sending keyevent 26..."
                input keyevent 26
                press_detected=false
                log_msg "Screen lock triggered."
            fi
        fi
    fi
done
