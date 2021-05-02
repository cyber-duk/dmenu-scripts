#!/bin/bash

# Pass dmenu options as arguments when running the script.
# If no parameter provided, then a sensible number of lines(10) and case insensitive search is used by default.
DMENU_OPTS="${@:--i -l 10}"

if ! which {dmenu,mpd,mpc} >/dev/null 2>&1; then
    printf "!!!Please make sure you have installed dmenu, mpd, mpc\n" | dmenu $DMENU_OPTS -p "Error"
    exit 1
elif ! mpc status >/dev/null 2>&1; then
    printf "Mpd not running...\n" | dmenu $DMENU_OPTS -p "Error:"
    exit 1
fi

function helper() {
    [[ ! -f $HOME/.cache/dmenu/mpd ]] && mkdir -p $HOME/.cache/dmenu && echo "mpd" > $HOME/.cache/dmenu/mpd
    help_options=("--------------- PLEASE READ CAREFULLY BEFORE EXITING THIS MENU ---------------- " \
        "type ':help' in dmenu to print this menu, in case the 'General Help and Information' option is not available anymore." \
        "action -> A custom input provided by typing inside dmenu. actions start with symbol ':'." \
        "':help' is also an action." \
        "custom inputs are provided in dmenu by typing and pressing 'Shift+Enter'. (Unless you have modified it in your dmenu build)" \
        "custom input '<<<' to go to previous menu. This is like the back key and works at any point." \
        "## Information about Actions -->")

    help_actions_list=("actions start with ':'. Example - ':help'. Actions work only on starting menu. Following are the actions currently available." \
        ":help    -> Prints the Help menu" \
        ":toggle  -> Toggle Play/Pause" \
        ":play    -> Play music if paused" \
        ":pause   -> Pause music if playing" \
        ":next    -> Play next song in queue" \
        ":prev    -> Play previous song in queue" \
        ":stop    -> Stop playback" \
        ":repeat  -> Toggle repeat mode" \
        ":random  -> Toggle random mode" \
        ":single  -> Toggle single mode" \
        ":consume -> Toggle consume mode" \
        ":clear   -> Clear current playlist" \
        ":update  -> Update mpd database" \
        ":rescan  -> Rescan mpd database" \
        ":save    -> Save current playlist as new playlist" \
        ":vol value  -> Change mpd volume to given value. Example - ':vol 50' -> Sets mpd volume to 50%, ':vol +10' -> Increase volume by 10%" \
        ":pos number -> Plays the song of the given position in Current Playlist. Example - ':pos 5' -> Plays the 5th song in playlist")

    help_opt_sel=$(printf '%s\n' "${help_options[@]}" | dmenu $DMENU_OPTS -p "Help:" | tail -n 1 | xargs)
    if [[ $help_opt_sel == "<<<" ]]; then
        main
    elif [[ $help_opt_sel == "## Information about Actions -->" ]]; then
        if [[ $(printf '%s\n' "${help_actions_list[@]}" | dmenu $DMENU_OPTS -p "Actions:" | tail -n 1 | xargs) == "<<<" ]]; then
            helper
        else
            exit
        fi
    else
        exit
    fi
}

function del_sel_song_from_cur_pl() {
    count=0
    while read line; do
        sel_sl_no=$(echo "$line" | awk '{print $1}' | xargs)
        sl_no_to_del=$(($sel_sl_no-$count))
        count=$(($count+1))
        mpc -q del $sl_no_to_del
    done <<< $(echo "$pl_song_sel")
}

function add_selected() {
    while read line; do
        mpc -q findadd "$1" "$line"
    done <<< $(echo "$2")
}

function insert_selected() {
    while read line; do
        selection_uri=$(mpc -q search "$1" "$line")
        while read uri; do
            mpc -q insert "$uri"
        done <<< $(echo "$selection_uri")
    done <<< $(echo "$2")
}

function save_new_playlist() {
    new_playlist_name=$(: | dmenu -p "Enter new Playlist name:")
    if [[ ! -z $new_playlist_name ]]; then
        mpc -q save "$new_playlist_name" >/dev/null 2>&1
    fi
    main
}

function move_position() {
    song_pos=$(echo $pl_song_sel | tail -n 1 | awk '{print $1}' | xargs)
    pos_to_move=$(mpc playlist | awk 'NF' | nl -s " " | dmenu $DMENU_OPTS -p "Move to Position:" | head -n 1 | awk '{print $1}' | xargs)
    if [[ $pos_to_move -ge 0 ]] && [[ $pos_to_move -le $(mpc playlist | wc -l) ]]; then
        mpc -q move "$song_pos" "$pos_to_move"
    fi
}

function list_sel_album_artist_songs() {
    list_titles=()
    while read line; do
        list_titles+=$(mpc list title "$items_type" "$line" | awk 'NF')
    done <<< $(echo "$items_sel")
}

function handle_sel_album_artist_songs() {
    list_sel_album_artist_songs
    titles_sel=$(echo "$list_titles" | dmenu $DMENU_OPTS -p "Titles:")
    if [[ -z $titles_sel ]]; then
        exit 0
    elif [[ ! -z $titles_sel ]]; then
        if [[ $titles_sel == "<<<" ]]; then
            manage_opt_sel
        else
            ans=$(printf "Play Now\nPlay Next\nAdd to Queue\n" | dmenu $DMENU_OPTS -p "Choose Action:" | tail -n 1 | xargs)
            if [[ -z $ans ]]; then
                handle_sel_album_artist_songs
            elif [[ $ans == "Play Now" ]]; then
                mpc -q clear
                add_selected title "$titles_sel"
                mpc -q play
                handle_sel_album_artist_songs
            elif [[ $ans == "Play Next" ]]; then
                insert_selected title "$titles_sel"
                handle_sel_album_artist_songs
            elif [[ $ans == "Add to Queue" ]]; then
                add_selected title "$titles_sel"
                handle_sel_album_artist_songs
            fi
        fi
    fi
}

function handle_mpd_controls() {
    CURRENT_STATE="$(mpc status | awk 'FNR==2{print toupper($1)}' | xargs)"
    CURRENT_SONG_STATE="[NOW: $(mpc current)]    [NEXT: $(mpc queued)]"
    CURRENT_VOLUME="[$(mpc volume | awk -F":" '{print $2}' | xargs)]"
    REPEAT_STATE="[$(mpc status | awk -F"repeat:" '{print $2}' | awk 'NF {print toupper($1)}' | xargs)]"
    RANDOM_STATE="[$(mpc status | awk -F"random:" '{print $2}' | awk 'NF {print toupper($1)}' | xargs)]"
    SINGLE_STATE="[$(mpc status | awk -F"single:" '{print $2}' | awk 'NF {print toupper($1)}' | xargs)]"
    CONSUME_STATE="[$(mpc status | awk -F"consume:" '{print $2}' | awk 'NF {print toupper($1)}' | xargs)]"
    control_actions=("TOGGLE  $CURRENT_STATE" "VOLUME  $CURRENT_VOLUME"\
        "REPEAT  $REPEAT_STATE" "RANDOM  $RANDOM_STATE" "SINGLE  $SINGLE_STATE" "CONSUME $CONSUME_STATE" "$CURRENT_SONG_STATE")
    control_action_sel=$(printf '%s\n' "${control_actions[@]}" | dmenu $DMENU_OPTS -p "MPD:" | tail -n 1)
    if [[ -z $control_action_sel ]]; then
        exit
    else
        if [[ $control_action_sel == "<<<" ]]; then
            main
        elif [[ $control_action_sel =~ "TOGGLE" ]]; then
            mpc -q toggle
            handle_mpd_controls
        elif [[ $control_action_sel =~ "VOLUME" ]]; then
            set_vol=$(: | dmenu -p "Enter Volume:")
            if [[ $set_vol -ge 0 ]] || [[ $set_vol -le 100 ]]; then
                mpc -q volume $set_vol
            fi
            handle_mpd_controls
        elif [[ $control_action_sel =~ "REPEAT" ]]; then
            mpc -q repeat
            handle_mpd_controls
        elif [[ $control_action_sel =~ "RANDOM" ]]; then
            mpc -q random
            handle_mpd_controls
        elif [[ $control_action_sel =~ "SINGLE" ]]; then
            mpc -q single
            handle_mpd_controls
        elif [[ $control_action_sel =~ "CONSUME" ]]; then
            mpc -q consume
            handle_mpd_controls
        elif [[ $control_action_sel =~ "NOW: " ]] && [[ $control_action_sel =~ "NEXT: " ]]; then
            menu_opt_sel="Manage Current Playlist"
            manage_opt_sel
        fi
    fi
}

function manage_opt_sel() {
    case "$menu_opt_sel" in
        "View All"*)
            if [[ $menu_opt_sel == "View All Titles" ]]; then
                items_sel=$(mpc list title | awk 'NF' | sort -n | dmenu $DMENU_OPTS -p "Songs:")
                items_type="title"
            elif [[ $menu_opt_sel == "View All Albums" ]]; then
                items_sel=$(mpc list album | awk 'NF' | sort -n | dmenu $DMENU_OPTS -p "Albums:")
                items_type="album"
            elif [[ $menu_opt_sel == "View All Artists" ]]; then
                items_sel=$(mpc list artist | awk 'NF' | sort -n | dmenu $DMENU_OPTS -p "Artists:")
                items_type="artist"
            elif [[ $menu_opt_sel == "View All Album Artists" ]]; then
                items_sel=$(mpc list albumartist | awk 'NF' | sort -n | dmenu $DMENU_OPTS -p "Album Artists:")
                items_type="albumartist"
            fi

            if [[ -z $items_sel ]]; then
                exit 0
            elif [[ ! -z $items_sel ]]; then
                if [[ $items_sel == "<<<" ]]; then
                    main
                else
                    if [[ $items_type == "title" ]]; then
                        ans=$(printf "Play Now\nPlay Next\nAdd to Queue\n" | dmenu $DMENU_OPTS -p "Choose Action:" | tail -n 1 | xargs)
                    else
                        ans=$(printf "Play Now\nPlay Next\nView Songs\nAdd to Queue\n" | dmenu $DMENU_OPTS -p "Choose Action:" | tail -n 1 | xargs)
                    fi
                    if [[ $ans == "Play Now" ]]; then
                        mpc -q clear
                        add_selected "$items_type" "$items_sel"
                        mpc -q play
                        manage_opt_sel
                    elif [[ $ans == "Play Next" ]]; then
                        insert_selected "$items_type" "$items_sel"
                        manage_opt_sel
                    elif [[ $ans == "View Songs" ]]; then
                        handle_sel_album_artist_songs
                    elif [[ $ans == "Add to Queue" ]]; then
                        add_selected "$items_type" "$items_sel"
                        manage_opt_sel
                    else
                        manage_opt_sel
                    fi
                fi
            fi
            ;;
        "Manage Current Playlist")
            pl_song_sel=$(mpc playlist | awk 'NF' | nl -s " " | dmenu $DMENU_OPTS -p "Current Playlist:" | sort -n)
            if [[ -z $pl_song_sel ]]; then
                exit 0
            elif [[ ! -z $pl_song_sel ]]; then
                if [[ $pl_song_sel == "<<<" ]]; then
                    main
                # elif [[ $menu_opt_sel == "Manage Current Playlist" ]]; then
                else
                    ans=$(printf "Play\nMove\nRemove\n" | dmenu $DMENU_OPTS -p "Choose:")
                    if [[ -z $ans ]] || [[ $ans == "<<<" ]]; then
                        manage_opt_sel
                    elif [[ $ans == "Play" ]]; then
                        mpc -q play $(echo $pl_song_sel | awk '{print $1}' | xargs)
                    elif [[ $ans == "Move" ]]; then
                        move_position
                        manage_opt_sel
                    elif [[ $ans == "Remove" ]]; then
                        del_sel_song_from_cur_pl
                        manage_opt_sel
                    fi
                fi
            fi
            ;;
        "Manage Saved Playlists")
            saved_pl_sel=$(mpc lsplaylists | sed '/.m3u/d' | awk 'NF' | dmenu $DMENU_OPTS -p "Saved Playlists:")
            if [[ -z $saved_pl_sel ]]; then
                exit 0
            elif [[ ! -z $saved_pl_sel ]]; then
                if [[ $saved_pl_sel == "<<<" ]]; then
                    main
                else
                    ans=$(printf "Load\nDelete\n" | dmenu $DMENU_OPTS -p "Choose:")
                    if [[ $ans == "Load" ]]; then
                        mpc -q clear
                        mpc -q load $(echo "$saved_pl_sel" | head -n 1) >/dev/null 2>&1
                        mpc -q play
                    elif [[ $ans == "Delete" ]]; then
                        while read line; do
                            mpc -q rm "$line"
                        done <<< $(echo "$saved_pl_sel")
                        manage_opt_sel
                    fi
                fi
            fi
            exit 0
            ;;
		"Play All Songs Available")
			mpc -q clear
			mpc -q listall | mpc -q add
			mpc -q play
			;;
        "General MPD Controls")
            handle_mpd_controls
            ;;
        ":toggle"|":play"|":pause"|":next"|":prev"|":stop"|":repeat"|":random"|":single"|":consume"|":clear"|":update"|":rescan")
            action=$(echo $menu_opt_sel | tr -d ":" | xargs)
            mpc -q "$action"
            main
            ;;
        ":save")
            save_new_playlist
            ;;
        ":vol"*)
            vol=$(echo $menu_opt_sel | awk -F":vol" '{print $2}' | xargs)
            mpc -q volume "$vol" 2>/dev/null
            main
            ;;
        ":pos"*)
            pos=$(echo $menu_opt_sel | awk -F":pos" '{print $2}' | xargs)
            mpc -q play "$pos" 2>/dev/null
            main
            ;;
        ":help"|"General Help and Information")
            helper
            ;;
        *)
            exit 1
            ;;
    esac
}

function manage_mpdmenu() {
    menu_opts=("View All Titles" "View All Albums" "View All Artists" "View All Album Artists" \
        "Manage Current Playlist" "Manage Saved Playlists" "Play All Songs Available" "General MPD Controls")

    if [[ ! -f $HOME/.cache/dmenu/mpd ]]; then
        menu_opts=("General Help and Information" "${menu_opts[@]}")
    fi

    menu_opt_sel=$(printf '%s\n' "${menu_opts[@]}" | dmenu $DMENU_OPTS -p "Music:" | tail -n 1 | xargs)
    manage_opt_sel
}

function main() {
    mpc -q update >/dev/null 2>&1
    manage_mpdmenu
}

main
