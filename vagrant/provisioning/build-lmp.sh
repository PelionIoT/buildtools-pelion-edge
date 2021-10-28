#!/usr/bin/env bash
CMDS="${1:-build}"
WORK="${2:-~/lmpbuild/}"
CMACHINE="${3:-imx8mmevk}"
CMACHINE="${3:-uz3eg-iocc}"
CIMAGE="${4:-console-image-lmp}"
fullwicpath=$WORK/build-lmp/deploy/images/$CMACHINE/console-image-lmp-$CMACHINE.wic.gz
while [[ $# -gt 0 ]]; do
	#when sourcing setup-environment this scripts argument stack conflicts with the sourced argument stack, thus lets remove this scripts arguments
	shift
done
echo -e "USER: $USER"
echo -e "SCRIPT: build-lmp.sh"
echo -e "\t\t- CMDS: $CMDS"
echo -e "\t\t- WORK: $WORK"
echo -e "\t\t- CMACHINE: $CMACHINE"
echo -e "\t\t- CIMAGE: $CIMAGE"
echo -e "\t\t- fullwicpath: $fullwicpath"
echo -e "PASTE:\t${CYAN}build-lmp.sh $@ ${NORM}"
echo -e "--------------------------------------------------------"

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


set_metadata(){
	local nvar="$1"
	local nval="$2"
	local nline="$1=$2"
	local found=0;
	metafile=$WORK/.metadata
	if [[ ! -e $metafile ]]; then
		echo "$nline" > $metafile
	else
		readarray -t metas <<< "$(cat $metafile)"
		rm -rf $metafile
		metas_len=${#metas[@]}
		for metaline in "${metas[@]}"; do
			mvar=$(echo $metaline| awk -F '=' '{print $1}');
			if [[ $mvar != "$nvar" ]]; then
				echo "$metaline" >> $metafile
			else
				found=1;
				echo "$nline" >> $metafile
			fi
		done
		if [[ $found -ne 1 ]]; then
			echo "$nline" >> $metafile
		fi
	fi
}

build(){
	cd $WORK
	BRANCH=$(repo info 2>/dev/null | grep -B0 "^Manifest branch" | awk -F ' ' '{print $3}')
	echo "MACHINE=$CMACHINE source setup-environment" > rebuild.sh
	echo "bitbake $CIMAGE" >> rebuild.sh
	chmod 777 rebuild.sh
	MACHINE="$CMACHINE" source setup-environment
	bitbake $CIMAGE

	if [[ $? -eq 0 ]]; then
		cp -L $fullwicpath ~/result.wic.gz || true
		set_metadata "LASTBUILD" "PASS"
	else
		set_metadata "LASTBUILD" "FAILED"
	fi
	cp $WORK/.metadata ~/result.about
}

pretendbuild(){
	cd $WORK
	cd layers
	ls -al
	echo "MACHINE=$CMACHINE source setup-environment"
	echo "bitbake $CIMAGE"
	echo "cp -L $fullwicpath ~/result.wic.gz || true"
	set_metadata "LASTBUILD" "PRETEND"
	cp $WORK/.metadata ~/result.about
}

set_metadata "MACHINE" "$CMACHINE"
set_metadata "IMAGE" "$CIMAGE"
for cmd in $CMDS; do
	$cmd
done