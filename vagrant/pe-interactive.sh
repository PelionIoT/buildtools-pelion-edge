#!/bin/bash
#---------------------------------------------------------------------------------------------------------------------------
# Functions needed for Global Varribles
#---------------------------------------------------------------------------------------------------------------------------


set_sourcedirs() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")";
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR_THISSCRIPT="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}



set_sourcedirs

cd ~/lmpbuild/
source .metadata
MACHINE=$MACHINE source setup-environment
#----------------------------------------------------------------------
BUILDPATH="$WORK/build*"
LAYERDIR="$WORK/layers"
COMPILEPATH=$BUILDPATH"/tmp*/work/cortexa*"
DEPLOYPATH=$BUILDPATH"/deploy"
IMAGEPATH=$DEPLOYPATH"/images/$MACHINE"
IPKPATH=$DEPLOYPATH"/ipk"
#console-image-raspberrypi3.wic.gz
alias cd-config="cd $BUILDPATH/conf"
alias cd-mpe="cd $LAYERDIR/meta-pelion-edge"
alias cd-build="cd $BUILDPATH"
alias cd-ipk="cd $IPKPATH"
alias cd-compilearea="cd $COMPILEPATH"
alias cd-images="cd $IMAGEPATH"
alias sp="source /vagrant/pe-interactive.sh"
alias scp-pull=""


info(){
    echo "this is called pe-interactive.sh"
}

bake(){
    cd-build
    bitbake "$@"
}

pe-clean-simple(){
    local r="$1"
    bitbake $r -c clean 1x 1x
}

pe-clean-cache() {
    local r="$1"
    bitbake $r -c cleansstate x1 x1
}

pe-clean-deepest(){
    local r="$1"
    pushd . >> /dev/null
    cd-compilearea
    sudo rm -rf $r
    cd-build
    bitbake $r -c cleanall
    popd >> /dev/null
}

pe-bitbake-new(){
    local r="$1"
    pe-clean-deepest "$r"
    cd-build
    bitbake "$r"
}


# pe-bitbake-new(){
#     #delete the old compile area
#     sudo rm -rf /home/ubuntu/lmpbuild/build*/tmp*/work/cortexa*/mbed-edge-core-*
#     #switch back to the bitbake rootdir
#     cd /home/ubuntu/lmpbuild/build-*/
#     #call the standard cleanall (this does a deep clean)
#     bitbake virtual/mbed-edge-core -c cleanall
#     #start a new build of edge core
#     bitbake virtual/mbed-edge-core
# }

pe-devshell(){
    local r="$1"
    pe-clean-deepest "$r"
    cd-build
    bitbake -c devshell "$r"
}

pe-clean-deepest-wwimage(){
    pe-clean-deepest $yyimage
}

pe-clean-tempall(){
    echo "this will erase everything in $yybuildpath/tmp"
    echo "Continue (${YELLOW}y${NORM}/${YELLOW}n${NORM}):"
    read x
    if [[ $x = "y" || $x = "yes" ]]; then
        yysource
        pushd . >> /dev/null
        cd-buildarea
        rm -rf tmp 1x 1x
        popd >> /dev/null
    fi
}

pe-inspect-ipk(){
    local ipk="$1"
    echo "inspecting $ipk"
    pushd . >> /dev/null
    temp=$(mktemp -d /tmp/XXXXX);
    cp $ipk $temp/
    cd $temp
    DIRNAME=$(dirname "$ipk")
    FILENAME=$(basename -- "$ipk")
    EXTENSION="${FILENAME##*.}"
    FILEHEAD="${FILENAME%.*}"
    sudo ar -x $FILENAME
    sudo tar -xvzf control.tar.gz
    sudo tar -xvJf data.tar.xz


    echo -en "#!/bin/bash\nmmu=\$(cat /tmp/mmunow)\n    text=\"([\$mmu]: exit when done) \"\n    export PS1=\"\\\[\\\e[31;43m\\\]\\\W\\\\$text[\\\e[m\\\] \"\n    export PS1=\"\\\[\\\e[36m\\\]\$text\\\[\\\e[33m\\\]\\\W >\\\[\\\e[m\\\] \"\n" >/tmp/s.sh
    bash --rcfile <(echo '. /tmp/s.sh')
    popd >> /dev/null
    echo "Do you wish to destroy $temp"
    select yn in "Yes" "No"; do
        case $yn in
            Yes )
            #
            rm -rf $temp
            break;;
            #
            No ) exit;;
            #
        esac
    done
}

pe-inspect-build(){
    wicfile="$1"
    echo "inspecting" > /tmp/mmunow
    pushd . >> /dev/null
    which kpartx >> /dev/null
    if [[ $? -ne 0 ]]; then
        sudo apt-get update -y
        sudo apt-get install kpartx -y
    fi
    sudo losetup --detach-all
    local devmark=$(sudo kpartx -v -l "$wicfile" | xargs | awk -F 'loop' '{print $2}' | awk -F 'p' '{print $1}');
    sudo kpartx -v -a "$wicfile"
    if [[ ! -e /mnt/factory ]]; then
        sudo mkdir /mnt/boot
        sudo mkdir /mnt/upgrade
        sudo mkdir /mnt/user
        sudo mkdir /mnt/factory
        sudo mkdir /mnt/userdata
    fi
    sudo mount /dev/mapper/loop${devmark}p1 /mnt/boot
    sudo mount /dev/mapper/loop${devmark}p2 /mnt/factory
    sudo mount /dev/mapper/loop${devmark}p3 /mnt/upgrade
    sudo mount /dev/mapper/loop${devmark}p5 /mnt/user
    sudo mount /dev/mapper/loop${devmark}p6 /mnt/userdata
    cd /mnt/
    ls
    echo -en "#!/bin/bash\nmmu=\$(cat /tmp/mmunow)\n    text=\"([\$mmu]: exit when done) \"\n    export PS1=\"\\\[\\\e[31;43m\\\]\\\W\\\\$text[\\\e[m\\\] \"\n    export PS1=\"\\\[\\\e[36m\\\]\$text\\\[\\\e[33m\\\]\\\W >\\\[\\\e[m\\\] \"\n" >/tmp/s.sh
    bash --rcfile <(echo '. /tmp/s.sh')
    popd >> /dev/null
    echo "Do you wish to unmap the mounts"
    select yn in "Yes" "No"; do
        case $yn in
            Yes )
                #
                sudo umount /mnt/boot;
                sudo umount /mnt/factory;
                sudo umount /mnt/userdata;
                sudo umount /mnt/user;
                sudo umount /mnt/upgrade;
                sudo kpartx -d "$wicfile"
                sudo losetup --detach-all
                break;;
                #
                No ) exit;;
                #
            esac
        done
    }

    pe-search-version-used(){
        bitbake -s | grep $1
    }

    pe-search-version-installed(){
        looking=$(_prompt "What are you looking for (enter for everthing)")
        out=$(bitbake -g console-image && cat pn-depends.dot | grep -v -e '-native' | grep -v digraph | grep -v -e '-image' | awk '{print $1}' | sort | uniq)
        if [[ "$looking" = "" ]]; then
            echo "$out" | tr " " "\n"
        else
            echo $out | tr " " "\n" | grep "$looking"
        fi
    }

    pe-search-layerinfo(){
        bitbake-layers show-recipes | grep --after-context=2 --before-context=2 $1
    }

    pe-search-find-path(){
        oe-pkgdata-util find-path $1
    }

    setPrompt(){
        CLEANCOLOR=$(tput setaf 8)
        if [[ $DIRTY = 1 ]]; then
            CLEANCOLOR="$(tput setaf 8)"
            CL="\[$CLEANCOLOR\](dirty)\[$(tput setaf 2)"
        else
            CL="\[$CLEANCOLOR\](clean)\[$(tput setaf 2)"
        fi

        PM="\[$(tput setaf 2)\]pe-tool \[$(tput setaf 1)\]"
        MM="$PM$CL"
        TAG="$NAME"
    #export PS1="$MM\[$(tput sgr0)\]\[$(tput setaf 2)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 2)\]\h\[$(tput setaf 3)\]\n\w\n\W\[$(tput sgr0)\] $"
    export PS1="\[$(tput sgr0)\]\[$(tput setaf 6)\]$TAG\[$(tput setaf 6)\] \h\[$(tput setaf 3)\]\n\w\n$MM\[$(tput sgr0)\]$"
}

setPrompt

_prompt(){
    echo -en "${YELLOW}$1: ${NORM}${CYAN}" > $(tty)
    read xxx
    echo -en "${NORM}" > $(tty)
    echo "$xxx"
}

