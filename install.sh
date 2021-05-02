#!/bin/bash

install() {
	echo
	echo "Insatlling dmenu scripts in $HOME/.local/bin/"
	echo "Make sure $HOME/.local/bin/ is in your PATH"
	echo
	cp -f ./dmenu_clipboard.sh ~/.local/bin/dclip
	echo "dmenu_clipboard.sh --------> dclip"
	cp -f ./dmenu_file_browser.sh ~/.local/bin/dfm
	echo "dmenu_file_browser.sh -----> dfm"
	cp -f ./dmenu_manpage_finder.sh ~/.local/bin/dman
	echo "dmenu_manpage_finder.sh ---> dman"
	cp -f ./dmenu_mpd_manager.sh ~/.local/bin/dmpd
	echo "dmenu_mpd_manager.sh ------> dmpd"
	### For iwd users
	cp -f ./dmenu_iwd.sh ~/.local/bin/dwifi
	echo "dmenu_iwd.sh --> dwifi"
	### For Network Manager users
	# cp -f ./dmenu_network_manager.sh ~/.local/bin/dwifi
	# echo "dmenu_network_manager.sh --> dwifi"
	cp -f ./dmenu_process_viewer.sh ~/.local/bin/dproc
	echo "dmenu_process_viewer.dh ---> dproc"
	echo
	echo "Successfully installed all dmenu scripts."
	echo
}

uninstall() {
	echo
	echo "Removing all dmenu scripts..."
	echo
	rm -f ~/.local/bin/dclip
	rm -f ~/.local/bin/dfm
	rm -f ~/.local/bin/dman
	rm -f ~/.local/bin/dmpd
	rm -f ~/.local/bin/dwifi
	rm -f ~/.local/bin/dproc
	echo "Successfully removed all dmenu scripts."
	echo
}

case "$1" in
	install|--install|-i)
		install
		;;
	uninstall|--uninstall|-u)
		uninstall
		;;
	*)
		echo "Invalid parameters"
		exit 1
		;;
esac
