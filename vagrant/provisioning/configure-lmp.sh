#!/usr/bin/env bash
CMDS="${1:-lmpOnHost}"
NAME="${2:-generic}"
WORK="${3:-/home/ubuntu/lmpbuild}"
BRANCH="${4:-dev}"
GUSER=$5
GEMAIL=$6
PROTECT="$7"
MODE=""
echo -e "USER: $USER"
echo -e "SCRIPT: configure-lmp.sh"
echo -e "\t\t- CMDS: $CMDS [lmpOnHost promodeHost devmodeHost]"
echo -e "\t\t- WORK: $WORK"
echo -e "\t\t- BRANCH: $BRANCH"
echo -e "\t\t- GUSER: $GUSER"
echo -e "\t\t- GEMAIL: $GEMAIL"
echo -e "\t\t- PROTECT: $PROTECT"
echo -e "PASTE:\t${CYAN}/vagrant/provisioning/configure-lmp.sh "\"$CMDS\"" $WORK $BRANCH $GUSER $GEMAIL ""$PROTECT"" ${NORM}"
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

expandProtectedDirs(){
	dirs=""
	for i in $1; do
		if [[ $i = *"/*" ]]; then
			echo "a dir split found"
			dirs+="$(ls -d $i) "
		else
			dirs+="$i "
		fi
	done
	echo "$dirs"
}

protect_dirs(){
	for i in $1; do 
		echo "protecting $i"
		mv $i /tmp
	done
}

restore_dirs(){
	for i in $1; do 
		echo "removing $i"
		rm -rf $i
	done
	for i in $1; do 
		DIR=$(basename -- "$i")
		mv /tmp/$DIR $i
		echo "restoring $i"
	done
}

set_metadata(){
	local nvar="$1"
	local nval="$2"
	local nline="$1=$2"
	local found=0;
	metafile=$WORK/.metadata
	echo "metafile: $metafile"
	pwd
	ls -al
	whoami
	if [[ ! -e $metafile ]]; then
		echo "metafile doesn't exist, creating: $metafile"
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

lmpPrep(){
	if [[ ! -e ~/.configuredLmpPrep ]]; then
		mkdir -p ~/.ssh
		chmod 700 ~/.ssh
		ssh-keyscan -H github.com >> ~/.ssh/known_hosts
		ssh -T git@github.com || true
		cd ~
		sudo chown -R ubuntu:ubuntu *
		mkdir -p $WORK
		set_metadata "WORK" "$WORK"
		set_metadata "NAME" "$NAME"
		cd $WORK
		git config --global credential.helper cache
		git config --global user.name "$GUSER"
		git config --global user.email "$GEMAIL"
		PROTECT="$(expandProtectedDirs "$PROTECT")"
		echo "my protections: $PROTECT"
		set_metadata "PROTECTED" "\"$PROTECT\""
		set_metadata "BRANCH" "$BRANCH"
		if [[ $PROTECT = "" ]]; then
			set_metadata "DIRTY" 0
		else
			set_metadata "DIRTY" 1
		fi
		touch ~/.configuredLmpPrep
	else
		echo "Skipping lmpPrep init, already configured"
	fi


}

# This function configures the build environement one time while running as a normal user.  This script provides a unique developement feature for engineers who are working on the build system, in particiular the scripts that do the building.  After repo sync has been called, this script helps vagrant re-replace directories from your localhost to this build machine so that you can continually run rsync-auto keeping your local changes effective on the build machine.  Because we take advantage of vagrant's rsync-auto, this script provides a workaround for the out-of-sequence nature of vagrant and repo init.  The workflow is this:
#    1) vagrant up first rsyncs all the directories as defined in the vagrantFile from your localhost to the target build machine
#    2) This script moves the directories defined in the PROTECT varible to a temporary space.  (These directores are presumed to be the directories from your localhost that you mapped in the VagrantFile)
#    3) This script then calls repo init and populates the manifest
#    4) Next, this script replaces the moved "protected" directory back to their intended place (presumably overwritting the desired directories from repo init)
lmpMpe(){
	if [[ ! -e ~/.configuredMPE ]]; then
		protect_dirs "$PROTECT"
		repo init -u https://github.com/PelionIoT/manifest-lmp-pelion-edge.git -b $BRANCH -m pelion.xml || true
		repo sync -j"$(nproc)" --force-sync || true
		restore_dirs "$PROTECT"
		cat ${HOME}/.profile | grep pe-interactive.sh
		if [[ $? -ne 0 ]]; then
			echo "source /vagrant/pe-interactive.sh" >> ${HOME}/.profile
		fi
		touch ~/.configuredMPE
	else
		echo "Skipping repo init, already configured"
	fi
}

lmpNGGW(){
	if [[ ! -e ~/.configuredNGGW ]]; then
		protect_dirs "$PROTECT"
		repo init -u https://github.com/PelionIoT/manifest-lmp-pelion-edge.git -b $BRANCH -m pelion.xml || true
		git clone -b pelion-edge-24-lmp-82 git@github.com:PelionIoT/manifest-lmp-pelion-edge-nggw.git .repo/local_manifests
		sed -i 's,^BBLAYERS += " \\,BBLAYERS += "${OEROOT}/layers/meta-user \\,g' .repo/manifests/conf/bblayers.conf
		repo sync -j"$(nproc)" --force-sync || true
		restore_dirs "$PROTECT"
		cat ${HOME}/.profile | grep pe-interactive.sh
		if [[ $? -ne 0 ]]; then
			echo "source /vagrant/pe-interactive.sh" >> ${HOME}/.profile
		fi
		touch ~/.configuredNGGW
	else
		echo "Skipping repo init, already configured"
	fi
}



#This script will write the necessary devmode settings on every boot.  This is necessary when rebuilding from a rsync-auto mapped meta-mbed-edge.
devmodeHost(){
	MODE="dev"
	if [[ -e /home/ubuntu/CERTS/mbed_cloud_dev_credentials.c && ! -e $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/mbed_cloud_dev_credentials.c ]]; then
		cp /home/ubuntu/CERTS/mbed_cloud_dev_credentials.c $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/
	fi
	if [[ -e /home/ubuntu/CERTS/update_default_resources.c && ! -e $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/update_default_resources.c ]]; then
		cp /home/ubuntu/CERTS/update_default_resources.c $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/
	fi
	cd $WORK
	if [[ ! -e .repo/manifests/conf/local.conf.og ]]; then
		cp .repo/manifests/conf/local.conf .repo/manifests/conf/local.conf.og
	fi
	cp .repo/manifests/conf/local.conf.og .repo/manifests/conf/local.conf
	echo -e "\n" >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_DEVELOPER_MODE = "ON"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_FIRMWARE_UPDATE = "ON"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_FOTA_ENABLE = "ON"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_CURL_DYNAMIC_LINK = "ON"' >> .repo/manifests/conf/local.conf
	set_metadata "MODE" "$MODE"
}


promodeHost(){
	MODE="production"
	if [[ -e $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/mbed_cloud_dev_credentials.c ]]; then
		rm -rf $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/
	fi
	if [[ -e $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/update_default_resources.c ]]; then
		rm -rf $WORK/layers/meta-mbed-edge/recipes-connectivity/mbed-edge-core/files/
	fi
	cd $WORK
	if [[ ! -e .repo/manifests/conf/local.conf.og ]]; then
		cp .repo/manifests/conf/local.conf .repo/manifests/conf/local.conf.og
	fi
	cp .repo/manifests/conf/local.conf.og .repo/manifests/conf/local.conf
	echo -e "\n" >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_FACTORY_MODE = "ON"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_DEVELOPER_MODE = "OFF"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_BYOC_MODE = "OFF"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_FIRMWARE_UPDATE = "ON"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_FOTA_ENABLE = "ON"' >> .repo/manifests/conf/local.conf
	echo 'MBED_EDGE_CORE_CONFIG_CURL_DYNAMIC_LINK = "ON"' >> .repo/manifests/conf/local.conf
	set_metadata "MODE" "$MODE"
}

enableParsec(){
	echo 'MBED_EDGE_CORE_CONFIG_PARSEC_TPM_SE_SUPPORT = "ON"' >> .repo/manifests/conf/local.conf
	set_metadata "PARSEC" "true"
}
disableParsec(){
	echo "a dummy, we don't do anything real to disable parsec"
	set_metadata "PARSEC" "false"
}
for cmd in $CMDS; do
	$cmd
done





#source setup-environment
#bitbake lmp-gateway-image
# cd $WORK
# MACHINE=uz3eg-iocc source setup-environment
# bitbake lmp-gateway-image