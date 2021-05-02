#!/bin/bash

DMENU_OPTS="${@:--i -l 10}"
CLIPBOARD_CMD="greenclip"   # clipboard command
CLIP_COPY_PARM="print"      # clipboard command parameter to add input text as newest history
CLIP_HISTORY_PARM="print"   # clipboard command parameter to print clipboard history line by line

if ! which {dmenu,$CLIPBOARD_CMD} >/dev/null 2>&1; then
    printf "!!!Please make sure you have installed dmenu, $CLIPBOARD_CMD\n" | dmenu -p "Error"
    exit 1
fi

clipboard_selection=$("${CLIPBOARD_CMD}" "${CLIP_HISTORY_PARM}" | awk 'NF' | dmenu $DMENU_OPTS -p "Clipboard")
if [[ ! -z $clipboard_selection ]]; then
    "${CLIPBOARD_CMD}" "${CLIP_COPY_PARM}" "$(echo "$clipboard_selection" | xargs -r -d'\n')"
fi
