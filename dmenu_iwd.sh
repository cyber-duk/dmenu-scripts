#!/bin/bash

# Dmneu wrapper for iwd wireless network manager
# Features:
#		Connect to a Network (WPA,WPS,Hidden Network)
#		Disconnect current Network
#		Enable/Disable wifi
#		Delete saved networks
# Bugs : 
#		Removing a saved network doesn't work if the network SSID consists of '.' character

if ! which {dmenu,iwctl} >/dev/null 2>&1; then
	printf "!!!Please make sure you have installed dmenu, iwctl(iwd)\n" | dmenu -l 1 -p "Error"
    exit 1
fi

DEFAULT_DEVICE="wlan0"

network_status() {
	DEVICE_STATUS=$(iwctl device "$DEFAULT_DEVICE" show | grep "Powered" | head -1 | awk '{print $NF}' | xargs)
	STATION_STATUS=$(iwctl station "$DEFAULT_DEVICE" show | grep "State" | head -1 | awk '{print $NF}' | xargs)
	CONNECTION_ID=
}

get_selected_option() {
	network_status
	if [[ $DEVICE_STATUS == "off" ]]; then
		OPTIONS="Enable Wireless Networking"
	elif [[ $DEVICE_STATUS == "on" ]]; then
		OPTIONS="Connect to a Network\nConnect to a Hidden Network"
		if [[ $STATION_STATUS == "connected" ]]; then
			CONNECTION_ID=$(iwctl station "$DEFAULT_DEVICE" show | grep "Connected network" | xargs | cut -d ' ' -f3-)
			OPTIONS="$OPTIONS\nDisconnect Current Network"
		fi
		OPTIONS="$OPTIONS\nDelete Saved Networks\nScan for new Networks\nDisable Wireless Networking"
	fi

	if [[ ! -z $CONNECTION_ID ]]; then
		CONNECTION_ID="($CONNECTION_ID)"
	fi
	OPTION_SELECTED=$(printf "$OPTIONS" | dmenu -l 10 -p "Wifi $CONNECTION_ID" | tail -n 1)
	handle_selected_option
}

handle_hidden_network() {
	HIDDEN_NETWORK_SSID="$(: | dmenu -p 'Enter Network SSID ')"
	[[ $HIDDEN_NETWORK_SSID == "" ]] && get_selected_option
	HIDDEN_NETWORK_PASS="$(: | dmenu -p 'Enter Network Passphrase ')"
	[[ $HIDDEN_NETWORK_PASS == "" ]] && get_selected_option
	CONNECTION_RESULT=$(iwctl --passphrase "$HIDDEN_NETWORK_PASS" station "$DEFAULT_DEVICE" connect-hidden "$HIDDEN_NETWORK_SSID")
	if [[ $CONNECTION_RESULT != "" ]]; then
		printf "$CONNECTION_RESULT" | cat -A | sed 's/\^\[\[[0-9;]*[JKmsu]//g' | tr -d '$'| dmenu -l 10 -p "Connection Status"
		get_selected_option
	else
		printf "Successfully established connection to $HIDDEN_NETWORK_SSID" | dmenu -l 10 -p "Connection Status"
		exit 0
	fi
}

handle_selected_network() {
	network_security="$(echo "$network_selected" | awk '{print $NF}' | xargs)"
	network_selected="$(echo "$network_selected" | awk '{$NF=""; print}' | xargs)"
	if [[ $(echo "$network_selected" | awk '{print $1}' | xargs) == ">" ]]; then
		network_selected="$(echo "$network_selected" | awk '{$1=""; print}' | xargs)"
		CONNECTION_RESULT=$(iwctl station "$DEFAULT_DEVICE" connect "$network_selected")
	elif [[ $network_security == "open" ]] || [[ -f /var/lib/iwd/"$network_selected".psk ]]; then
		CONNECTION_RESULT=$(iwctl station "$DEFAULT_DEVICE" connect "$network_selected")
	else
		NETWORK_PASS="$(: | dmenu -p "Enter Network Passphrase ")"
		CONNECTION_RESULT=$(iwctl --passphrase "$NETWORK_PASS" station "$DEFAULT_DEVICE" connect "$network_selected")
	fi
	if [[ $CONNECTION_RESULT != "" ]]; then
		printf "$CONNECTION_RESULT" | cat -A | sed 's/\^\[\[[0-9;]*[JKmsu]//g' | tr -d '$'| dmenu -l 10 -p "Connection Status"
		handle_selected_option
	else
		printf "Successfully established connection to $network_selected" | dmenu -l 10 -p "Connection Status"
		exit 0
	fi
}

remove_selected_saved_network() {
	selected_saved_network=$(echo $selected_saved_network | awk '{$NF=""; print}' | xargs)
	confirm=$(printf "No\nYes" | dmenu -l 2 -p "Do want to remove $selected_saved_network?" | tail -n 1 | xargs)
	[[ $confirm == "Yes" ]] && iwctl known-networks "$selected_saved_network" forget
	handle_selected_option
}

handle_selected_option() {
	case "$OPTION_SELECTED" in
		"Enable Wireless Networking")
			iwctl device "$DEFAULT_DEVICE" set-property Powered on
			get_selected_option
			;;
		"Disable Wireless Networking")
			iwctl device "$DEFAULT_DEVICE" set-property Powered off
			get_selected_option
			;;
		"Connect to a Hidden Network")
			handle_hidden_network
			;;
		"Disconnect Current Network")
			iwctl station "$DEFAULT_DEVICE" disconnect
			get_selected_option
			;;
		"Connect to a Network")
			network_selected=$(iwctl station wlan0 get-networks | awk 'NF' | sed '1,4d' | cat -A | \
				sed 's/\^\[\[[0-9;]*[JKmsu]//g' | tr -d '$' | awk '{gsub("****", "");print}' | \
				dmenu -l 10 -p "Available Networks $CONNECTION_ID" | tail -n 1)
			case "$network_selected" in
				"<<"|"<<<")
					get_selected_option
					;;
				"")
					exit
					;;
				*)
					handle_selected_network
					;;
			esac
			;;
		"Scan for new Networks")
			iwctl station "$DEFAULT_DEVICE" scan
			get_selected_option
			;;
		"Delete Saved Networks")
			selected_saved_network=$(ls -p /var/lib/iwd/ | grep -v / | awk -F "." '{print $1 " [" $2 "]"}' | dmenu -l 10 -p "Saved Networks" | tail -n 1)
			case "$selected_saved_network" in
				"<<"|"<<<")
					get_selected_option
					;;
				"")
					exit
					;;
				*)
					remove_selected_saved_network
					;;
			esac
			;;
		"<<"|"<<<")
			get_selected_option
			;;
		*)
			exit
			;;
	esac
}

get_selected_option
