#!/bin/bash

if ! which {dmenu,nmcli} >/dev/null 2>&1; then
    printf "!!!Please make sure you have installed dmenu, nmcli(NetworkManager)\n" | dmenu -l 1 -p "Error"
    exit 1
fi

DMENU_PASSWORD_MODE=0   # 1 means, passwords will be hidden as '*' in dmenu. Requires dmenu with password patch

function wifi_status () {
    station=$(nmcli device | grep "wifi " | awk '{ printf $1 }')
    state=$(nmcli -fields WIFI g | sed -n 2p | xargs) # Wifi enbaled or disabled
    connection=$(nmcli connection show --active | grep "wifi" | awk -F "wifi" '{ print $1 }' | sed -e '1{s/[^ ]\+\s*$//}' | xargs)
}

function choose_network_option() {
    network_options=" "
    wifi_status
    if [[ "$state" == "enabled" ]]; then
        if [ -z "$connection" ]; then
            network_options="Connect to a Network\nConnect to a Hidden Network\nDisable Wifi\nDelete Connection\nRefresh"
        elif [ ! -z "$connection" ]; then
            network_options="Connect to a Network\nConnect to a Hidden Network\nDisconnect Current Network\nDisable Wifi\nDelete Connection\nRefresh"
        fi
    elif [[ "$state" =~ "disabled" ]]; then
        network_options="Enable Wifi\nDelete Connection\nRefresh"
    fi
    chosen_network_option=$(echo -en "$network_options" | dmenu -l 10 -p "Network")
}

function get_network_pass() {
    if [[ $DMENU_PASSWORD_MODE == 1 ]]; then
        network_pass=$(dmenu -P -p "Enter Network Passkey")
    else
        network_pass=$(: | dmenu -p "Enter Network Passkey")
    fi
}

function handle_selected_network() {
    SSID=$(echo "$network_sel" | head -n 1 | cut -b 28- | xargs)
    BSSID=$(echo "$network_sel" | head -n 1 | cut -b 2- | awk '{ print $1 }' | xargs)
    SECURITY=$(nmcli -f BSSID,SECURITY device wifi | grep "$BSSID" | awk -F "  " '{print $2}' | xargs)
    if [[ $(nmcli -f NAME con show | grep -o -m 1 "$SSID") == "$SSID" ]]; then
        nmcli connection up "$SSID" | dmenu -l 10 -p "Connection Status"
        exit 0
    elif [[ "$SECURITY" =~ "--" ]] || [ -z "$SECURITY" ]; then
        nmcli device wifi connect "$BSSID" | dmenu -l 10 -p "Connection Status"
        exit 0
    elif [[ "$SECURITY" =~ "WPA" ]] || [ "$SECURITY" =~ "WEP" ]; then
        get_network_pass
        if [[ -z $network_pass ]]; then
            chosen_network_option="Connect to a Network"
            handle_chosen_network_option
        else
            nmcli device wifi connect "$SSID" password "$network_pass" | dmenu -l 10 -p "Connection Status"
            exit 0
        fi
    fi
}

function handle_hidden_network() {
    get_network_pass
    if [[ -z $network_pass ]]; then
        main
    else # Connecting to hidden network, generally fails the first time; try again to quickly recoonect
        nmcli device wifi connect "$network_name" password "$network_pass" hidden yes >/dev/null 2>&1
        conStatus=$?
        if [ $conStatus -ne 0 ]; then
            ask=$(echo -en "Yes\nNo\n" | dmenu -l 10 -p "Connection failed! Try again ?")
            if [[ $ask == "Yes" ]]; then
                sleep 3s
                nmcli device wifi connect "$network_name" password "$network_pass" hidden yes >/dev/null 2>&1
                conStatus=$?
                if [ $conStatus -ne 0 ]; then
                    echo "Connection failed! Check your network" | dmenu -l 10 -p "Connection Status"
                    exit 1
                else
                    echo "Successfully established connection to $network_name" | dmenu -l 10 -p "Connection Status"
                    exit 0
                fi
            else
                main
            fi
        else
            echo "Successfully established connection to $network_name" | dmenu -l 10 -p "Connection Status"
            exit 0
        fi
    fi
}

function handle_chosen_network_option() {
    case $chosen_network_option in
        "Connect to a Network")
            nmcli device wifi rescan
            network_sel=$(printf "$(nmcli -f IN-USE,BSSID,SSID device wifi list)\n=> Refresh Available Networks" | sed '1d' | dmenu -l 10 -p "Available Networks")
            if [[ ! -z $network_sel ]]; then
                if [[ $network_sel == "<<<" ]]; then
                    main
                elif [[ $network_sel == "=> Refresh Available Networks" ]]; then
                    nmcli device wifi rescan
                    chosen_network_option="Connect to a Network"
                    handle_chosen_network_option
                else
                    handle_selected_network
                fi
            fi
            ;;
        "Connect to a Hidden Network")
            network_name=$(: | dmenu -l 10 -p "Enter Network SSID")
            if [[ ! -z $network_name ]]; then
                handle_hidden_network
            else
                main
            fi
            ;;
        "Disconnect Current Network")
            con_uuid=$(nmcli connection show --active | grep "wifi" | awk -F "wifi" '{print $1}' | awk '{print $NF}' | xargs)
            nmcli connection down "$con_uuid" > /dev/null 2>&1
            main
            ;;
        "Disable Wifi")
            nmcli radio wifi off >/dev/null 2>&1
            main
            ;;
        "Delete Connection")
            con_del=$(nmcli --fields UUID,TYPE,NAME con show | grep wifi | dmenu -l 10 -p "Saved Connections")
            if [[ ! -z $con_del ]]; then
                if [[ $con_del == "<<<" ]]; then
                    main
                else
                    connection_uuid=$(echo "$con_del" | awk '{print $1}')
                    nmcli connection delete uuid "$connection_uuid" >/dev/null 2>&1
                    chosen_network_option="Delete Connection"
                    handle_chosen_network_option
                fi
            fi
            ;;
        "Enable Wifi")
            nmcli radio wifi on >/dev/null 2>&1
            main
            ;;
        "Refresh")
            nmcli device wifi rescan >/dev/null 2>&1
            main
            ;;
        *)
            exit 1
            ;;
    esac
}

function main() {
    choose_network_option
    handle_chosen_network_option
}

main
