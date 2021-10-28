#!/usr/bin/env bash
CMDS="${1:-base}"
EXTRAINSTALLS="${2}"
echo -e "USER:\t$USER"
echo -e "SCRIPT:\t${CYAN}ubuntu20_setup.sh${NORM}"
echo -e "\t\t- CMDS: $CMDS"
echo -e "\t\t- EXTRAINSTALLS: $EXTRAINSTALLS"
echo -e "PASTE:\t${CYAN}ubuntu20_setup.sh $@ ${NORM}"
echo -e "--------------------------------------------------------"

base(){
	apt-get update
	if [[ ! -e /usr/bin/python ]]; then
		ln -s $(which python3) /usr/bin/python
	fi
	cd ~
	curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo
	chmod a+x /usr/local/bin/repo
}

lmpOnHost(){
	apt-get -y install android-sdk-libsparse-utils android-sdk-ext4-utils binutils build-essential  ca-certificates chrpath cpp coreutils cpio debianutils diffstat gawk g++ gcc git-core gcc-multilib  iputils-ping  libc-dev-bin openjdk-11-jre python2.7 python3 python3-pip python3-pexpect libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libelf-dev socat texinfo unzip whiptail wget xterm xz-utils
}


main(){
	functions_to_run="$1"
	extra_apt_get_installs="$2"

	for func in $functions_to_run; do
		echo "Calling function: $func"
		$func
	done

	for extra in $extra_apt_get_installs; do
		apt-get -y install $extra
	done
}

main "$CMDS" "$EXTRAINSTALLS"