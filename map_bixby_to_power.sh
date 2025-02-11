#!/bin/sh

# Create a named pipe
pipe="/tmp/getevent_pipe"
if [ ! -p "$pipe" ]; then
  mkfifo "$pipe"
fi

# getevent should listen on the "gpio_keys" device file
getevent -l /dev/input/event1 > "$pipe" &
getevent_pid=$! # the PID of the most recent background command 

cleanup() {
    kill "$getevent_pid" 
    rm "$pipe"
    exit 0
}
trap "cleanup" EXIT SIGINT SIGTERM

restart_getevent() {
    kill "$getevent_pid"
    getevent -l /dev/input/event1 > "$pipe" &
    getevent_pid=$!
}

bixby_pressed=false
while true; do
    # Check if getevent was killed, and restart it appropriately
    if ! kill -0 "$getevent_pid"; then
        restart_getevent
    fi

    # Reads a single line from the pipe's stdout into the "event"variable.
    # If no data is available with one second, do nothing, and the loop continues.
    if read -t 1 event < "$pipe"; then
        # Check the button's "DOWN" event
        if echo "$event" | grep -q "EV_KEY.*02bf.*DOWN"; then
            bixby_pressed=true
        fi
        # When the "UP" event is detected, the keypress is done and we can lock the screen
        if echo "$event" | grep -q "EV_KEY.*02bf.*UP"; then
            if $bixby_pressed; then
                # Apparently, this keyevent triggers the same action as single pressing the power button (waking or putting the screen to sleep)
                input keyevent 26
                bixby_pressed=false
            fi
        fi
    fi
done
