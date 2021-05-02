#!/bin/bash
##################################################################################
# SIMPLE DMENU FILE MANAGER (Fully compatible with dmenu multi-select patch)
# Requirements:
#   dmenu
#   xdg-open(optional: file opener) (xdg-utils)
#   trash(optional: for moving files to trash instead of removing permanently) (trash-cli)
# Bookmarks: (type the expression and press Shift+Enter)
#   '~' : go to HOME directory
#   '/' : go to root directory
#   Create your own bookmarks if needed
##################################################################################
# Exit if dmenu not installed
if ! which dmenu >/dev/null 2>&1; then
    printf "!!!Please make sure you have installed dmenu\n" | dmenu -p "Error"
    exit 1
fi
##################################################################################
# Configuration
DMENU_OPTS="${*:--i -l 15}" # Default parameters for dmenu
TERMINAL="${TERMINAL:-st}"  # Change this according to your terminal emulator
EXPLORER="st -e nnn -ea"    # Change this according to your file explorer
FILE_OPENER="file-opener"      # requires xdg-utils to be installed
TRASH_CMD="trash"           # requires trash-cli program to be installed
SHOW_HIDDEN=0               # hidden files not shown, can be toggled at runtime
ENABLE_HISTORY=1            # start where you left before
##################################################################################
##################################################################################
if [[ ! -f $HOME/.cache/dmenu/dfm ]] && [[ $ENABLE_HISTORY -eq 1 ]]; then
    [[ ! -d $HOME/.cache/dmenu ]] && mkdir "$HOME/.cache/dmenu"
    echo "$HOME" > "$HOME/.cache/dmenu/dfm"
fi
LISTCMD="dir -1pQ --quoting-style=literal --group-directories-first"
LISTCMDALL="$LISTCMD -A"
SELECTION_BUFFER=0
dmenu_selection=0
HISTORY=$(xargs < "$HOME/.cache/dmenu/dfm")
[[ $ENABLE_HISTORY -eq 1 ]] && cd "$HISTORY" || exit 1

function custom_action_menu() {
    action_list=("Toggle Hidden Files" \
        "Create New File" \
        "Create New Directory" \
        "Rename File or Directory" \
        "Open Terminal Here" \
        "Open File Explorer Here" \
        "Select Multiple Items")
            [[ $SELECTION_BUFFER -eq 1 ]] && action_list+=("Copy Selected Items in Current Directory" "Move Selected Items in Current Directory" "Trash Selected Items")
            action_sel=$(printf '%s\n' "${action_list[@]}" | dmenu $DMENU_OPTS -p "Choose:" | tail -n 1 | xargs)

            case "$action_sel" in
                "Toggle Hidden Files")
                    SHOW_HIDDEN=$((1-SHOW_HIDDEN))
                    ;;
                "Create New File")
                    new_fname=$(: | dmenu -p "Enter file name:")
                    [[ $new_fname != '' ]] && [[ ! -f "$(pwd)/$new_fname" ]] && touch "$(pwd)/$new_fname"
                    ;;
                "Create New Directory")
                    new_dname=$(: | dmenu -p "Enter directory name:")
                    [[ $new_dname != '' ]] && [[ ! -d "$(pwd)/$new_dname" ]] && mkdir "$(pwd)/$new_dname"
                    ;;
                "Rename File or Directory")
                    if [[ $SHOW_HIDDEN -eq 1 ]]; then
                        rename_sel=$($LISTCMDALL | dmenu $DMENU_OPTS -p "$(basename "$(pwd)")" | tail -n 1 | xargs)
                    else
                        rename_sel=$($LISTCMD | dmenu $DMENU_OPTS -p "$(basename "$(pwd)")" | tail -n 1 | xargs)
                    fi
                    if [[ $rename_sel != '' ]]; then
                        new_file_name=$(: | dmenu -p "Enter name:")
                        if [[ -n $new_file_name ]] || [[ $new_file_name != '' ]]; then
                            mv "$(pwd)/$rename_sel" "$(pwd)/$new_file_name"
                        fi
                    fi
                    ;;
                "Open Terminal Here")
                    $TERMINAL >/dev/null 2>&1 &
                    ;;
                "Open File Explorer Here")
                    $EXPLORER "$(pwd)" >/dev/null 2>&1 &
                    ;;
                "Select Multiple Items")
                    if [[ $SHOW_HIDDEN -eq 1 ]]; then
                        selected_items=$($LISTCMDALL | dmenu $DMENU_OPTS -p "$(basename "$(pwd)")")
                    else
                        selected_items=$($LISTCMD | dmenu $DMENU_OPTS -p "$(basename "$(pwd)")")
                    fi
                    if [[ -z $selected_items ]]; then
                        custom_action_menu
                    else
                        selected_items_path=()
                        while read -r line; do
                            selected_items_path+=("$(pwd)/$line")
                        done <<< "$selected_items"
                        SELECTION_BUFFER=1
                    fi
                    ;;
                "Copy Selected Items in Current Directory")
                    while read -r line; do
                        cp -rf "$line" "$(pwd)/"
                    done <<< "$(printf '%s\n' "${selected_items_path[@]}")"
                    SELECTION_BUFFER=0
                    ;;
                "Move Selected Items in Current Directory")
                    while read -r line; do
                        mv -f "$line" "$(pwd)/"
                    done <<< "$(printf '%s\n' "${selected_items_path[@]}")"
                    SELECTION_BUFFER=0
                    ;;
                "Trash Selected Items")
                    while read -r line; do
                        $TRASH_CMD "$line" >/dev/null 2>&1
                    done <<< "$(printf '%s\n' "${selected_items_path[@]}")"
                    SELECTION_BUFFER=0
                    ;;
            esac
        }

while [ "$dmenu_selection" ]; do
    SHOW_HIDDEN="${SHOW_HIDDEN:-0}"
    if [[ $SHOW_HIDDEN -eq 1 ]]; then
        dmenu_selection=$(printf '..\n.\n%s' "$($LISTCMDALL)" | dmenu $DMENU_OPTS -p "$(basename "$(pwd)")" | tail -n 1 | xargs)
    else
        dmenu_selection=$(printf '..\n.\n%s' "$($LISTCMD)" | dmenu $DMENU_OPTS -p "$(basename "$(pwd)")"| tail -n 1 | xargs)
    fi
    case "$dmenu_selection" in
        ".")
            custom_action_menu ;;
        "~"|"HOME")
            cd "$HOME" || return ;;
        "/"|"ROOT")
            cd / ;;
        *)
            CWD=$(pwd)
            if [ -d "$dmenu_selection" ]; then
                cd "$dmenu_selection" || exit 1
            elif [ -f "$dmenu_selection" ]; then
                FILE_NAME=$(basename "$dmenu_selection")
                ask=$(printf "Open File\nRename File\nTo Selection\nTrash File\nOpen With" | dmenu $DMENU_OPTS -p "Choose:" | tail -n 1 | xargs)
                case "$ask" in
                    "Open File")
                        $FILE_OPENER "$CWD/$FILE_NAME" >/dev/null 2>&1 &
                        unset dmenu_selection
                        ;;
                    "Trash File")
                        $TRASH_CMD "$CWD/$FILE_NAME" >/dev/null 2>&1
                        ;;
                    "To Selection")
                        selected_items_path=("$CWD/$FILE_NAME")
                        SELECTION_BUFFER=1
                        ;;
                    "Rename File")
                        new_file_name=$(: | dmenu -p "Enter name:")
                        if [[ -n $new_file_name ]]; then
                            mv "$CWD/$FILE_NAME" "$CWD/$new_file_name"
                        fi
                        ;;
                    "Open With")
                        opener_cmd=$(: | dmenu -p "Enter Opener cmd:")
                        if [[ -n $opener_cmd ]]; then
                            $opener_cmd "$CWD/$FILE_NAME" >/dev/null 2>&1 &
                            exit
                        fi
                        ;;
                esac
            fi
    esac
    [[ $ENABLE_HISTORY -eq 1 ]] && echo "$(pwd)" > "$HOME/.cache/dmenu/dfm"
done
