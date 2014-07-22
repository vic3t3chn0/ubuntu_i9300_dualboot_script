#!/bin/bash

SCRIPT_NAME=$0
ASSETS_FOLDER="recoveries"
MAKO="mako"
HAMMERHEAD="hammerhead"
GROUPER="grouper"
MAGURO="maguro"
MANTA="manta"
FLO="flo"
EXYNOS="exynos"

# Used version of CWM recovery
URL_TWRP_PATH_BASE="http://techerrata.com/browse/twrp2/i9300"
TWRP_VERSION_2310="2.3.1.0"
TWRP_SIZE=
URL_SUPERU="http://download.chainfire.eu/382/SuperSU/UPDATE-SuperSU-v1.93.zip?retrieve_file=1"
URL_U_INSTALLER_PACKAGE="http://humpolec.ubuntu.com/UPDATE-UbuntuInstaller.zip"
RECOVERY_IMAGE=openrecovery-twrp-2.3.1.0-i9300.img
SU_PACKAGE=UPDATE-SuperSU-v1.93.zip
UBUNTU_INSTALLER_PACKAGE=UPDATE-UbuntuInstaller.zip
FORCE_DOWNLOAD=0
DEVICE_INSTALL_SLEEP=7

#DEVICE= "m0"
RECOVERY="recovery"
RELEASE_FOLDER="releases"
COMMAND_FILE="update_command"
TARGET_RELEASE_FOLDER="/extSdCard/ubuntu_release"
CACHE_RECOVERY="/cache/recovery"
UPDATE_PACKAGES=

# get device model
detect_device() {
    echo "Waiting for device $DEVICE_ID to install Ubuntu installer to."
    DEVICE=$(adb -s $DEVICE_ID shell getprop ro.product.device)
    CM_DEVICE=$(adb -s $DEVICE_ID shell getprop ro.cm.device)
    TWRP_VERSION=$TWRP_VERSION_2310
    if [[ "$DEVICE" == mako* ]]; then
        echo "Detected connected Nexus 4"
        DEVICE=$MAKO
        CWM_SIZE=8600000
    elif [[ "$DEVICE" == maguro* ]]; then
        echo "Detected connected Galaxy Nexus"
        DEVICE=$MAGURO
        DEVICE_INSTALL_SLEEP=25
        CWM_SIZE=6900000
    elif [[ "$DEVICE" == grouper* ]]; then
        echo "Detected connected Nexus 7"
        DEVICE=$GROUPER
        DEVICE_INSTALL_SLEEP=25
        TWRP_SIZE=7490000
    elif [[ "$DEVICE" == manta* ]]; then
        echo "Detected connected Nexus 10"
        DEVICE=$MANTA
        TWRP_SIZE=7000000
    elif [[ "$DEVICE" == hammerhead* ]]; then
        echo "Detected connected Nexus 5"
        DEVICE=$HAMMERHEAD
        CWM_VERSION=$CWM_VERSION_6044
        TWRP_SIZE=11400000
    elif [[ "$DEVICE" == flo* ]]; then
        echo "Detected connected Nexus 7-2013"
        DEVICE=$FLO
        TWRP_SIZE=9300000
    elif [[ "$DEVICE" == deb* ]]; then
        echo "Detected connected Nexus 7-2013"
        DEVICE=$FLO
        CWM_VERSION=$CWM_VERSION_6044
        TWRP_SIZE=9300000
    elif [[ "$DEVICE" == tilapia* ]]; then
        echo "Detected connected Nexus 7 - 2013 GSM"
        DEVICE=$FLO
        TWRP_SIZE=9300000
    elif [[ "$DEVICE" == m0* ]]; then
        echo "Detected connected I9300"
        DEVICE=$EXYNOS
    	TWRP_SIZE=6000000
	else
        echo "Connected device is not supported"
        exit 0
    fi
    RECOVERY_URL=$URL_TWRP_PATH_BASE-$TWRP_VERSION-$DEVICE.img
    RECOVERY_IMAGE=$RECOVERY-$DEVICE-$TWRP_VERSION.img
}

print_usage() {
    echo "Welcome to Humpolec. This is Ubuntu-Android dualboot enabler"
    echo "Please connect supported phone with adb enabled"
    echo " "
    echo "$SCRIPT_NAME [device ID [action [ custom install packages ]"
    echo " "
    echo "  device ID is optional, if not provided first connected device will be picked "
    echo "  actions:"
    echo "    No parameter: script will try to detect if 'full' or 'delta' installation should be performed"
    echo "    help: Prints this help"
    echo "    full: Full installation: this will install SuperUser package as well Ubuntu dualboot installer."
    echo "         Use this if you don't have SuperUser package installed on your device."
    echo "         Typical first time choice for unmodified factory images clean AOSP builds"
    echo "         Installation will reboot twice into the recovery, if prompterd **** when exiting recovery, answer NO"
    echo "         Optionally provide if device ID is switch if to install customisation"
    echo "    update: Updates application: this will install Ubuntu dualboot installer. It assumes there is alresdy Super User installed"
    echo "         Typical option for for CyanogenMod or other similar builds."
    echo "         Use this option if you already have Ubuntu dualboot installer installed and are only upgrading"
    echo "         Installation will reboot twice into the recovery, if prompterd when existing recovery, answer NO"
    echo "         Optionally provide if device ID is switch if to install customisation"
    echo "    push: Push custom install packages to the phone and start dualboot application"
    echo "         Provide packages to push to device ubuntu,device,version,..."
    echo "    channel: Download files form given channel and push them to the phone"
    echo "         Latest version is downloaded"
    echo ""
    echo "    options:"
    echo "        device ID: id of the device to install to"
}

download_su_package() {
    echo "Downloading SU package"
    # check downloaded file size, this often fails, so retry. Expected size is 1184318
    download_file $URL_SUPERU $SU_PACKAGE 1184000
}

download_app_update() {
    echo "Downloading Ubuntu Installer application package"
    # check downloaded file size, this often fails, so retry. Expected size is 2309120
    download_file $URL_U_INSTALLER_PACKAGE $UBUNTU_INSTALLER_PACKAGE 2309000
}

download_recovery() {
    echo "Downloading recovery for $DEVICE"
    # check downloaded file size, this often fails, so retry. any recovery should be more than 5M
    download_file $RECOVERY_URL $RECOVERY_IMAGE $TWRP_SIZE
}

download_file() {
    DOWNLOAD_URL=$1
    FILENAME=$2
    TARGET_SIZE=$3
    SIZE=1
    # check if file should be downloaded at all
    FILE_SIZE=$(ls -al $2 | awk '{ print $5}')
    if [[ $FORCE_DOWNLOAD == 0 ]] && [[ $FILE_SIZE -ge $TARGET_SIZE ]]; then
        echo "Skipping download, file already downloaded"
        return
    fi
    # check downloaded file size, this often fails, so retry. Expected size is TARGET_SIZE
    while [[ $TARGET_SIZE -gt $SIZE ]]
    do
        curl $DOWNLOAD_URL > $FILENAME
        SIZE=$(ls -la $FILENAME | awk '{ print $5}')
        echo "Downloaded file has size: $SIZE"
    done
}

wait_for_adb() {
    MODE=$1
    echo "Dev:$DEVICE_ID: Waiting for adb $MODE to be ready"
    ADB_STATE=$(adb devices | grep $DEVICE_ID)
    while ! [[ "$ADB_STATE" == *$MODE ]]
    do
        sleep 1
        ADB_STATE=$(adb devices | grep $DEVICE_ID)
    done
}

# Wait for adb device in normal or recovery mode
wait_for_any_adb() {
    echo "Waiting for device to be connected in normal or recovery mode"
  #  ADB_STATE=$(adb devices | grep $DEVICE_ID | grep -P -w '(device)|(recovery)')
    ADB_STATE=$(adb devices | grep $DEVICE_ID |grep 'device\|recovery')
    while [[ -z "$ADB_STATE" ]]
    do
        sleep 1
        ADB_STATE=$(adb devices | grep $DEVICE_ID |grep 'device\|recovery')
    done
}


wait_for_adb_disconnect() {
    echo "Dev:$DEVICE_ID: Waiting for device to be disconnected"
    STATE=$(adb devices | grep $DEVICE_ID)
    while [[ "$STATE" == *$DEVICE_ID* ]]
    do
        sleep 1
        STATE=$(adb devices | grep $DEVICE_ID)
    done
}

wait_for_fastboot() {
    echo "Dev:$DEVICE_ID: Waiting for fastboot to be ready"
    FASTBOOT_STATE=$(fastboot devices | grep $DEVICE_ID | awk '{ print $1}' )
    while ! [[ "$FASTBOOT_STATE" == *$DEVICE_ID* ]]
    do
        sleep 1
        FASTBOOT_STATE=$(fastboot devices | grep $DEVICE_ID | awk '{ print $1}' )
    done
}

wait_for_heimdall(){
 	echo "Dev:$DEVICE_ID: Waiting for heimdall to be ready"
	HEIMDALL_STATE=$(adb devices | grep $DEVICE_ID | awk '{print $1}' )
	while ! [["$HEIMDALL_STATE" == *$DEVICE_ID* ]]
	do
		sleep 1
		HEIMDALL_STATE=$(adb devices | grep $DEVICE_ID | awk '{print $1}' )
	done
}

print_ask_help() {
    echo "For more information refer to $ $SCRIPT_NAME HELP"
}

auto_mode() {
    CM_DEVICE=$(adb -s $DEVICE_ID shell getprop ro.cm.device)
    SU_BIN="/system/bin/su"
    SU_XBIN="/system/xbin/su"
    RES_BIN=$(adb -s $DEVICE_ID shell ls $SU_BIN | awk '{ print $2}' )
    RES_XBIN=$(adb -s $DEVICE_ID shell ls $SU_XBIN | awk '{ print $2}' )
    echo "Device $DEVICE_ID bin: $RES_BIN, xbin: $RES_XBIN, CM_DEVICE: $CM_DEVICE" 
    if [[ $RES_BIN == "No" ]] &&  [[ $RES_XBIN == "No" ]] && [[ "$CM_DEVICE" != "$DEVICE*" ]]; then
        echo "selecting FULL mode"
        download_su_package
        download_app_update
        install_ubuntu_installer $SU_PACKAGE $UBUNTU_INSTALLER_PACKAGE
    else
        echo "selecting UPDATE mode"
        download_app_update
        install_ubuntu_installer $UBUNTU_INSTALLER_PACKAGE
    fi
}

install_ubuntu_installer() {
    echo "install_ubuntu_installer<<"
    SIDELOAD_PACKAGE=$1
    echo "Dev:$DEVICE_ID: Rebooting to bootloader"
    wait_for_any_adb
    adb -s $DEVICE_ID reboot bootloader
    wait_for_heimdall
    fastboot -s $DEVICE_ID boot $RECOVERY_IMAGE
    wait_for_adb recovery
    echo "Dev:$DEVICE_ID: Creating update command"
    adb -s $DEVICE_ID shell rm -rf $CACHE_RECOVERY
    adb -s $DEVICE_ID shell mkdir $CACHE_RECOVERY
    adb -s $DEVICE_ID shell "echo -e '--sideload' > $CACHE_RECOVERY/command"
    echo "Dev:$DEVICE_ID: Booting back to bootloader"
    adb -s $DEVICE_ID reboot bootloader
    wait_for_heimdall
    fastboot -s $DEVICE_ID boot $RECOVERY_IMAGE
    wait_for_adb sideload
    adb -s $DEVICE_ID sideload $SIDELOAD_PACKAGE
    # wait for device to come back to recovery mode and extra 5 seconds, then reboot
    wait_for_adb recovery
    if [[ -e $2 ]]; then
        shift
        echo "Let's run once more for $1"
        echo "Dev:$DEVICE_ID: Rebooting in '$DEVICE_INSTALL_SLEEP' seconds"
        sleep $DEVICE_INSTALL_SLEEP
        # if there are more packages, install them, otherwise reboot
        install_ubuntu_installer $*
    else
        echo "Wait for installation of package to complete"
        echo "If you are asked to preserve possibly lost root access"
        echo "Or if device should be rooted"
        echo "This is false warning and you can answer either yes or no"
        echo "Finished!!!!"
        echo "Complete reboot from phone menu"
    fi
}

push_install_packages() {
    adb -s $DEVICE_ID shell rm -rf $TARGET_RELEASE_FOLDER
    adb -s $DEVICE_ID shell mkdir -p $TARGET_RELEASE_FOLDER
    
    UPDATE_COMMAND+="format system\n"
    UPDATE_COMMAND+="mount system\n"
    for PACKAGE in $UPDATE_PACKAGES
    do
        if [[ -f $PACKAGE ]]; then
            echo "adb -s $DEVICE_ID push $PACKAGE $TARGET_RELEASE_FOLDER"
            adb -s $DEVICE_ID push $PACKAGE $TARGET_RELEASE_FOLDER/
            FILENAME=$(basename $PACKAGE)
            UPDATE_COMMAND+="update $FILENAME\n"
        fi
    done
    UPDATE_COMMAND+="unmount system\n"
    rm $COMMAND_FILE
    echo -e $UPDATE_COMMAND > $COMMAND_FILE
    
    adb -s $DEVICE_ID push $COMMAND_FILE    $TARGET_RELEASE_FOLDER
    
    adb -s $DEVICE_ID shell am start -n com.canonical.ubuntu.installer/.InstallActivity \
                    --es updateCommand "'"$TARGET_RELEASE_FOLDER/$COMMAND_FILE"'"
}

push_custom_install_packages() {
    UPDATE_PACKAGES=""
    while [[ ! -z $1 && -f $1 ]]
    do
        echo "Dev:$DEVICE_ID: Using custom package: $1"
        UPDATE_PACKAGES+=" $1"
        shift
    done
    push_install_packages
}

download_channel_install_packages() {
    CHANNEL=$1
    BASE_SERVER_URL="http://system-image.ubuntu.com"
    CHANNEL_URL="$BASE_SERVER_URL/ubuntu-touch/$CHANNEL/$DEVICE/index.json"
    echo "Selected channel: $CHANNEL_URL"
    CHANNEL_PACKAGES=$(curl $CHANNEL_URL | python -c "import json
import sys
data =  json.load(sys.stdin)
count = len(data['images'])
for i in range(count -1,0,-1):
    if data['images'][i]['type'] == 'full':
        pCount = len(data['images'][i]['files'])
        for ii in range(0, pCount):
            print data['images'][i]['files'][ii]['size'], data['images'][i]['files'][ii]['path']
        break")
    while read -r line; do
        SIZE=$( echo $line | awk '{ print $1}')
        PACKAGE=$(echo $line | awk '{ print $2}')
        download_file $BASE_SERVER_URL$PACKAGE $(basename $PACKAGE) $SIZE
        UPDATE_PACKAGES+=" $(basename $PACKAGE)"
    done <<< "$CHANNEL_PACKAGES"
    push_install_packages
}


if [[ "$1" == help ]]; then
    echo "help" 
    print_usage
    exit 0
fi

#get device id, check if parameter is device ID, if not, just pick first one connected
if [[ ! -z $1 ]] && [[ "$1" != full ]] && [[ "$1" != update ]] && [[ "$1" != push ]] && [[ "$1" != channel ]]; then
    echo "Using passed device id: $1"
    DEVICE_ID=$1
    shift
else
    echo "No device ID specified, picking first available device"
    DEVICE_ID=$(adb devices | grep -w 'device' | awk '{ print $1}')
fi

# if we still don't have any device exit
if [[ -z $DEVICE_ID ]]; then 
    echo "There is no connected device"
    exit 0
fi

# choose action
ACTION=$1
shift
# unlikely, but check again for help
if [[ "$ACTION" == help ]]; then
    echo "help" 
    print_usage
fi

detect_device $*
# get recovery unless this is push action
if [[ "$ACTION" != push ]]; then
    download_recovery
fi
if [[ "$ACTION" == full ]]; then
    echo "Dev:$DEVICE_ID: selected full install"
    download_su_package
    download_app_update
    install_ubuntu_installer $SU_PACKAGE $UBUNTU_INSTALLER_PACKAGE
elif [[ "$ACTION" == update ]]; then
    echo "Dev:$DEVICE_ID: selected update install"
    download_app_update
    install_ubuntu_installer $UBUNTU_INSTALLER_PACKAGE
elif [[ "$ACTION" == push ]]; then
    echo "Dev:$DEVICE_ID: selected push custom files"
    push_custom_install_packages $*
elif [[ "$ACTION" == channel ]]; then
    echo "Dev:$DEVICE_ID: selected download files for given channel and push to device"
    download_channel_install_packages $*
else
    echo "Dafaulting to auto action"
    auto_mode
fi
