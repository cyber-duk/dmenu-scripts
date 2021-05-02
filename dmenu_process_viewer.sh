#!/bin/bash

DMENU_OPTS="${@:--i -l 10}"

function process_manager() {
    process_cmd="ps -a -u $USER --no-headers -o pid,%cpu,rss,args"
    processes_selected="$($process_cmd | dmenu $DMENU_OPTS -p "Process")"
    if [[ ! -z $processes_selected ]]; then
        manage_sel_processes="$(echo -e "Yes\nNo" | dmenu $DMENU_OPTS -p "Kill selected process(s)?")"
        if [[ $manage_sel_processes == "Yes" ]]; then
            while read line; do
                kill -9  $(echo "$line" | awk '{print $1}' | xargs) >/dev/null 2>&1
            done <<< $(echo "$processes_selected")
            process_manager
        else
            process_manager
        fi
    fi
}

process_manager
