#!/usr/bin/env bash


downloaddir=$HOME/vdownload
safemode=1
VM=""
drive="/dev/rdisk5"
FAILEDBUILD=0

acommands="burn destroy destroy-all download halt halt-all up up-np new nosafe rebuild rsync-auto ssh status status-all"
declare -A acmd
acmd[burn]="burns the last downloaded image to the -d drive" 
acmd[destroy]="completely destroys the VM (calls vagrant -f destroy VM)"
acmd[destroy-all]="destroys all vagrantFile VM's (calls vagrant -f destroy)"
acmd[download]="downloads ~/result.wic.gz from the target VM"
acmd[halt]="halts the vm.  (calls vagrant halt VM)"
acmd[halt-all]="halts all vms defined in vagrantFile (calls vagrant halt VM)"
acmd[up]="brings up and first time only provisions (calls vagrant up VM)"
acmd[up-np]="up with no provisioners (calls vagrant up --no-provision VM)"
acmd[up-fp]="up force provisioners (calls vagrant up --provioson VM"
acmd[new]="Macro: destroy,up"
acmd[rebuild]="Macro: halt,up-fp"
acmd[rsync-auto]="rsync mapped dir changes to target (calls vagrant rsync-auto VM)"
acmd[ssh]="ssh into VM (calls vagrant ssh VM)"
acmd[status]="displays status of the VM (calls vagrant status VM)"
acmd[status-all]="displays status for all vagrantFile VMs (calls vagrant status)"

NORM="$(tput sgr0)"
BOLD="$(tput bold)"
REV="$(tput smso)"
UND="$(tput smul)"
BLACK="$(tput setaf 0)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 90)"
MAGENTA1="$(tput setaf 91)"
MAGENTA2="$(tput setaf 92)"
MAGENTA3="$(tput setaf 93)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
ORANGE="$(tput setaf 172)"
ERROR="${REV}Error:${NORM}"

set_sourcedirs(){
	SOURCE="${BASH_SOURCE[0]}"
	while [ -h "$SOURCE" ]; do
		DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
		SOURCE="$(readlink "$SOURCE")"
		[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
	done
	THISDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}
set_sourcedirs

_say(){
	if [[ $silent -ne 1 ]]; then
		say "$@"
	else
		echo "say is silent: $1"
	fi
}

cmdValidate(){
	okoverall=0
	for cmd in "$@"; do
		okcmd=0;
		for a in $acommands; do
		#echo "$cmd = $a"
		if [[ $cmd = "$a" ]]; then
			okcmd=1;
		fi
	done
	if [[ $okcmd -eq 0 ]]; then
		echo "($cmd) is not valid"
		okoverall=1
	fi
done
if [[ $okoverall -eq 1 ]]; then
	useage
fi
}

_getstate(){
	running=1
	while [[ running -eq 1 ]]; do
		echo "checking vagrant status"
		vagrant status $1 | grep stopped
		if [[ $? -eq 0 ]]; then
			echo "its really down"
			running=0
		fi
		echo "waiting for it to stop"
	done	
}
_stopwait(){
	running=1
	echo -en "Ensuring it stops"
	while [[ running -eq 1 ]]; do
		vagrant status $VM | grep "stopped (aws)" >> /dev/null 2>&1
		if [[ $? -eq 0 ]]; then
			running=0
		fi
		echo -n "."
	done
	echo  " stoped!"
}

_setcompletion(){
	md5cur=$(md5sum Vagrantfile)
	if [[ -e .VAGMD5 ]]; then
		md5old=$(cat .VAGMD5)
	else
		md5old=xxx
	fi
	if [[ "$md5cur" != "$md5old" ]]; then
		echo "Vagrant file has changed, rebuilding completions"
		cat Vagrantfile | grep -B 1 -A0 vm.define > .VAGstatus
		echo "$md5cur" > .VAGMD5
	fi
	readarray -t vstatus <<< "$(cat .VAGstatus)"
	compound=""
	vstatus_len=${#vstatus[@]}
	for (( i = 0; i < $vstatus_len; i+=3 )); do
		l1=${vstatus[$i]}
		l2=${vstatus[$(($i + 1))]}
		l2=$(echo "$l2" | awk -F '"' '{print $2}')
		echo "$l1" | grep each >> /dev/null
		if [[ $? -eq 0 ]]; then
			count_START=$(echo "$l1" | grep each | awk -F "." '{print $1}' | awk -F "(" '{print $2}')
			count_END=$(echo "$l1" | grep each | awk -F "." '{print $3}' | awk -F ")" '{print $1}')
			count_END=$(( $count_END + 1 ))
			for (( incr = $count_START; incr < $count_END; incr++ )); do
				NEWVAR="${l2//\#\{i\}/$incr}"
				compound+="$NEWVAR "
			done
		else
			compound+="$l2 "
		fi
	done
	echo complete -W \""$compound"\"  vcmd.sh > .vcmd-completion.bash
	echo export HAVESOURCEDVCMD=1 >> .vcmd-completion.bash
	if [[ $HAVESOURCEDVCMD -ne 1 ]]; then
		echo "${CYAN}|--------------------------------------------------------------------|${NORM}"
		echo "${CYAN}|                               NOTICE                               |${NORM}"
		echo "${CYAN}|                                                                    |${NORM}"
		echo "${CYAN}|${NORM}        vcmd.sh supports completions with machine names from        ${CYAN}|${NORM}"
		echo "${CYAN}|${NORM}        the VagrantFile.  To use these completions, run the         ${CYAN}|${NORM}"
		echo "${CYAN}|${NORM}                  following command in this terminal.               ${CYAN}|${NORM}"
		echo "${CYAN}|${NORM}                     ${YELLOW}source .vcmd-completion.bash${NORM}                   ${CYAN}|${NORM}"
		echo "${CYAN}|                                                                    |${NORM}"
		echo "${CYAN}|--------------------------------------------------------------------|${NORM}"
	fi
}

_setcompletionOld(){
	md5cur=$(md5sum Vagrantfile)
	if [[ -e .VAGMD5 ]]; then
		md5old=$(cat .VAGMD5)
	else
		md5old=xxx
	fi
	if [[ "$md5cur" != "$md5old" ]]; then
		echo "Vagrant file has changed, rebuilding completions"
		vagrant status | tail -n +3 > .VAGstatus
		echo "$md5cur" > .VAGMD5
	fi
	readarray -t vstatus <<< "$(cat .VAGstatus)"
	compound=""
	for line in "${vstatus[@]}"; do
		if [[ "$line" = "" ]]; then
			break;
		fi
		name=$(echo $line| awk -F ' ' '{print $1}');
		compound+="$name "
	done
	echo complete -W \""$compound"\"  vcmd.sh > .vcmd-completion.bash
	echo "source .vcmd-completion.bash to have completions work"
}

runcmd(){
	cmd="$1"
	if [[ $cmd = "burn" ]]; then
		if [[ $FAILEDBUILD -eq 1 ]]; then
			echo "will not burn, as the build failed"
		else
			cd triggers
			echo ./sdburn.sh "$downloaddir/$VM/latest.tar.gz" $drive
			./sdburn.sh "$downloaddir/$VM/latest.tar.gz" $drive
			cd ../
		fi
	elif [[ $cmd = "destroy" ]]; then
		vagrant destroy -f "$VM"

	elif [[ $cmd = "destroy-all" ]]; then
		vagrant destroy -f

	elif [[ $cmd = "download" ]]; then
		mkdir -p $downloaddir/$VM/
		DT=$(date '+%h-%d_%H:%M')
		vagrant up --no-provision "$VM"
		vagrant scp $VM:~/result.about /tmp/
		source /tmp/result.about
		targetfile=$downloaddir/$VM/$MACHINE-$DT".tar.gz"
		echo "the target: $targetfile"
		if [[ $LASTBUILD != "failed" ]]; then
			vagrant scp $VM:~/result.wic.gz $downloaddir/$VM/
			mv $downloaddir/$VM/result.wic.gz $targetfile
			rm -rf $downloaddir/$VM/latest.tar.gz
			ln -s $targetfile $downloaddir/$VM/latest.tar.gz
		else
			echo "failed build, will not burn or download"
			FAILEDBUILD=1;
		fi
	elif [[ $cmd = "halt" ]]; then
		vagrant halt "$VM"
		_stopwait

	elif [[ $cmd = "halt-all" ]]; then
		vagrant -v
		vagrant halt
		safemode=0

	elif [[ $cmd = "new" ]]; then
		vagrant destroy -f "$VM"
		vagrant up "$VM"

	elif [[ $cmd = "rebuild" ]]; then
		vagrant halt "$VM"
		_stopwait
		sleep 1
		vagrant up --provision "$VM"

	elif [[ $cmd = "rsync-auto" ]]; then
		vagrant rsync-auto "$VM"
		safemode=0;
	elif [[ $cmd = "ssh" ]]; then
		vagrant up --no-provision "$VM"
		vagrant ssh "$VM"

	elif [[ $cmd = "status" ]]; then
		if [[ $VM = "status" ]]; then
			vagrant status
			safemode=0
		else
			vagrant status "$VM"
			safemode=0
		fi
	elif [[ $cmd = "status-all" ]]; then
		vagrant status
		safemode=0

	elif [[ $cmd = "up" ]]; then
		vagrant up "$VM"

	elif [[ $cmd = "up-only" || $cmd = "up-np" ]]; then
		vagrant up --no-provision "$VM"
	fi
}


main(){
	VM="$1"
	shift;
	cmdValidate "$@"
	state=""
	startTime=$(date +%s)
	pushd . >> /dev/null
	cd $THISDIR
	echo "Processing $@"
	for value in "$@"; do
		runcmd "${value}"
		lastcmd="${value}"
	done
	if [[ $safemode -eq 1 && $lastcmd != "halt" && $lastcmd != "destroy" ]]; then
		runcmd halt
	fi

	popd >> /dev/null
	endTime=$(date +%s)
	startTimeH=$(printf "%(%H:%m)T" $startTime)
	endTimeH=$(printf "%(%H:%m)T" $endTime)
	elapsedTimesec=$(( $endTime - $startTime ))
	elapsedTimemin=$(( $elapsedTimesec / 60 ))
	echo -e "Started:\t$startTimeH" 
	echo -e "Ended:\t$endTimeH"
	echo -e "Elapsed:\t$elapsedTimemin"

	_say "The computer needs your attention"
}



useage() { 
	echo "${BOLD}USEAGE:${NORM} $0 [-d drive] [-h help] [-s safemodeoff] <vagrant name> <list of commands>"
	echo ""
	echo -e "${BOLD}OPTIONS${NORM}"
	echo -e "   ${BOLD}-d${NORM} drive for burning e.g. /dev/disk5"
	echo -e "   ${BOLD}-h${NORM} help"
	echo -e "   ${BOLD}-i${NORM} image"
	echo -e "   ${BOLD}-m${NORM} machine"
	echo -e "   ${BOLD}-s${NORM} disables safemode, which auto-halts the machine each time to save money!"
	echo -e "   ${BOLD}-S${NORM} disables sound"
	echo ""
	echo -e "${BOLD}LIST OF COMMANDS${NORM}"
	mapfile -d '' sorted < <(printf '%s\0' "${!acmd[@]}" | sort -z)

	for KEY in "${sorted[@]}"; do
		VALUE="${acmd[$KEY]}"
		echo -e "   ${BOLD}$KEY${NORM}: $VALUE"
	done
	exit 1;
}

while getopts ":b:d:i:m:hsS" o; do
	case "${o}" in
		b) export BRANCH=$OPTARG; ;;
		#
		B) export BUILDMODE=$OPTARG; ;;
		#
		d) drive=${OPTARG}; ;;
		#
		h) useage; ;;
		#
		i) export IMAGE=$OPTARG; ;;
		#
		m) export MACHINE=$OPTARG; ;;
		#
		s) safemode=0; ;;
		#
		S) silent=1; ;;
		#
		\?)  echo -e \n"Option -${BOLD}$OPTARG${NORM} not allowed."; useage; ;;
		#
	esac
done
shift $((OPTIND-1))



_setcompletion
if [[ $# -lt 1 ]]; then
	useage
else
	main $@
fi
