#!/bin/sh

# Create a named pipe
pipe="/tmp/getevent_pipe"
if [ ! -p "$pipe" ]; then
  mkfifo "$pipe"
fi

# On my Samsung device, the "gpio_keys" device
# is at this special file. Redirect its events
# to the pipe and detach from it (non blocking).
getevent -l /dev/input/event1 > "$pipe" &

# Define a cleanup function to capture and handle common termination signals
getevent_pid=$! # the PID of the most recent background command 
cleanup() {
    kill "$getevent_pid" 2>/dev/null
    rm -f "$pipe"
    exit 0
}
trap "cleanup" EXIT SIGINT SIGTERM

# Function to restart the getevent background process
restart_getevent() {
    killall getevent 2>/dev/null
    getevent -l /dev/input/event1 > "$pipe" &
    getevent_pid=$!
}


# Initially the Bixby button (code 02bf on my device) isn't pressed
press_detected=false
while true; do
    # Check if getevent was killed, and restart it appropriately
    if ! kill -0 "$getevent_pid" 2>/dev/null; then
        restart_getevent
    fi

    # Reads a single line from the pipe's stdout into the "event"variable.
    # If no data is available with one second, do nothing, and the loop continues.
    if read -t 1 event < "$pipe"; then
        # Check the button's "DOWN" event
        if echo "$event" | grep -q "EV_KEY.*02bf.*DOWN"; then
            press_detected=true
        fi
        # When the "UP" event is detected, the keypress is done and we can lock the screen
        if echo "$event" | grep -q "EV_KEY.*02bf.*UP"; then
            if $press_detected; then
                # Apparently, this keyevent triggers the same action as single pressing the power button (waking or putting the screen to sleep)
                input keyevent 26
                press_detected=false
            fi
        fi
    fi
done
