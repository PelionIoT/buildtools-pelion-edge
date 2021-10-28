#!/usr/bin/env bash

hash pv
haspv=$?

if [[ -t 1 ]]; then 
	hasterm=1;
else
	hasterm=0;
fi

_error(){
	echo "ERROR: $1"
	exit 1
}

_umount(){
	disk=$1
	if [ "$(uname)" == "Darwin" ]; then
		echo "forcing the unmount"
		sudo diskutil unmountDisk force $disk
	else
		sudo unmount -f $disk
	fi
}

streamburn(){
	file="$1"
	rdisk="$2"
	exte="$3"
	remoteHost=$(echo $file| awk -F ':' '{print $1}');
	remoteFile=$(echo $file| awk -F ':' '{print $2}');
	echo ssh $remoteHost "du -sbL $remoteFile | cut -f1" 
	bytes=$(ssh $remoteHost "du -sbL $remoteFile | cut -f1" )
	mb=$(echo "$(( ${bytes%% *} / 1024))")
	mb+="m"
	if [[ $exte = "bz2" ]]; then
		echo "bz2 detected, writting $bytes byetes ($mb)"
		if [[ $terminal -eq 1 && haspv -eq 0 ]]; then
			time scp $file /dev/stdout | pv -s $mb | bzip2 -cd | sudo dd bs=4m of="$rdisk" 
		else
			time scp $file /dev/stdout | bzip2 -cd | sudo dd bs=4m of="$rdisk" 
		fi
	else
		echo "gz detected, writting $bytes byetes ($mb)"
		if [[ $terminal -eq 1 && haspv -eq 0 ]]; then
			time scp $file /dev/stdout | pv -s $mb | gunzip | sudo dd bs=4m of="$rdisk" conv=sync
		else
			time scp $file /dev/stdout | gunzip | sudo dd bs=4m of="$rdisk" conv=sync
		fi
	fi
}

fileburn(){
	file="$1"
	rdisk="$2"
	exte="$3"
	bytes=$(gzip -l $(realpath $file) | awk '{print $2}' | tail -1)
	mb=$(echo "$(( ${bytes%% *} * 25 / 10 / 1024 / 1024))")
	mb+="m"
	echo "writing $mb to $rdisk [$file]"
	if [[ $exte = "bz2" ]]; then
		time bzip2 -dc "$file"| pv -s $mb | sudo dd bs=4m of="$rdisk" 
	else
		time gunzip -c "$file"| pv -s $mb | sudo dd bs=4m of="$rdisk" 
	fi
}

main(){
	FPATH="$1"
	FDEV="$2"
	FILENAME=$(basename -- "$FPATH")
	EXTENSION="${FILENAME##*.}"
	if [[ -e $FDEV ]]; then
		_umount $FDEV
		if [[ -e $FPATH ]]; then
			fileburn $FPATH $FDEV $EXTENSION
		else
			streamburn $FPATH $FDEV $EXTENSION
		fi
	else
		_error "$FDEV does not exist"
	fi
}


useage() { 
	echo -e "USEAGE:\t$0 <path|scppath> <device>"
	echo -e "ABOUT:\tBurns an SD card from a local path or from a remote path."
	echo -e "\tRemote path files do not download to the local machine."
	echo -e "\tRemote path files write direct to the SD card"
	echo -e "DEFINITIONS"
	echo -e "\t<path>:\tan absolute or relative path to a image"
	echo -e "\t<scppath>:\t a scp style path to the remote file."
	echo -e "\t<device>:\t the device to burn to"
	echo -e "EXAMPLES"
	echo -e "\t1) Write direct from a cloud hosted machine to a sd card"
	echo -e "\t\t$0 remotemachine:~/result.wic.gz /dev/disk15"
	echo -e "\t2) Write from a local file to a sd card"
	echo -e "\t\t$0 /path/to/a/file/result.wic.gz /dev/rdisk9"
	exit 1; 
}

while getopts ":h" o; do
	case "${o}" in
		h) useage; ;;
		#
		\?)  echo -e \n"Option -${BOLD}$OPTARG${NORM} not allowed."; useage; ;;
		#
	esac
done
shift $((OPTIND-1))

if [[ $# -lt 2 ]]; then
	useage
else
	main "$@"
fi