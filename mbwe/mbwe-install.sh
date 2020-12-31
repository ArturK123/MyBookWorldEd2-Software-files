#!/bin/bash
ID="##### MBWE ##### (install.sh):"
# ****************************************
# MBWE FIRMWARE INSTALL
# ****************************************
# By Krzysztof Przygoda
# http://www.iknowsomething.com
# with help of http:/mybookworld.wikidot.com
# 2011-11-16 tested with firmware:
  FW_SCRIPT_VER="01.02.12"
# ****************************************

# To start this script:
# 1) Copy folder mbwe to Desktop
# 2) Open Terminal (Ctrl+Alt+t)
# 3) Type folowing: 
# cd Desktop/mbwe
# sudo bash ./mbwe-install.sh

# ****************************************
# (1) LOOK FOR FIRMWARE & PREPARE
# ****************************************

LOG_FILE=`pwd`/mbwe-status.log
MAIN_SCRIPT="mbwe-install.sh"
CONFIG_SCRIPT="mbwe-config.sh"
FW_SCRIPT="mbwe-getfw.sh"
ERROR=1
MESSAGE=""

echo "$ID [START] `date`">${LOG_FILE}

source ./${CONFIG_SCRIPT}

# Check if MBWE disk exists
ls /dev/${DISK_LABEL} >/dev/null 2>&1
RETVAL=$?

if [ ! -n "$DISK_LABEL" ] || [ "$RETVAL" -eq "2" ] #2 for cannot access
then
	echo	
	MESSAGE="$ID [EXITING] Disk not present or misspecified DISK_LABEL=$DISK_LABEL in $CONFIG_SCRIPT file."; echo $MESSAGE>>${LOG_FILE}; echo $MESSAGE
	echo "Resolve that problem (look into Disk Utility and/or edit $CONFIG_SCRIPT) and try again $MAIN_SCRIPT"
	echo "To start Disk Utility and edit config [hit any key]"
	read
	gedit ${CONFIG_SCRIPT} &
	palimpsest
	exit ${ERROR}
fi

# Check MAC address
if [ -z ${MAC_ADDRS} ];then
	MESSAGE="$ID_MAC [EXITING] No MAC address input in ${CONFIG_SCRIPT}"
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	exit 10
elif [ $(echo ${MAC_ADDRS} | awk 'BEGIN {FS=":"} {print NF}') != 6 ];then 
	MESSAGE="$ID_MAC [EXITING] MAC address input is wrong in ${CONFIG_SCRIPT} (MAC_ADDRS=${MAC_ADDRS})"
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	exit 20
fi

# Start
echo
echo 
echo "################################################################################"
echo "# WARNING!!! READ CAREFULLY!!! DATA LOSS POSSIBILITY!!!"
echo "################################################################################"
echo "# This script will ### ERASE ALL DATA ### on disk ### $DISK_LABEL ###"
echo "# specified by you in $CONFIG_SCRIPT file and install FRESH MBWE firmware !!!"
echo "# Your current disk config is:"
echo "#"
echo "# DISK_LABEL=${DISK_LABEL}"
echo "# MBWE_MODEL=${MBWE_MODEL}"
echo "# MBWE_SERIAL=${MBWE_SERIAL}"
echo "# MAC_ADDRS=${MAC_ADDRS}"
echo "#"
echo "# To be shure it is your disk go to System > Administration > Disk Utility"
echo "# identify it and edit DISK_LABEL=${DISK_LABEL} in $CONFIG_SCRIPT."
echo "# !!! ALWAYS REMEMBER 2 IMPORTANT POINTS !!!"
echo "# 1) If you misidentify your disk, you will destroy some other connected to this PC!"
echo "# 2) Disk label may change each disk connect/disconnect operation!!!"
echo "################################################################################"
echo "# Is it CORRECT? Do you UNDERSTAND and ACCEPT IT? [type 'yes'+ENTER to proceed]"
echo "# Operation will take about 1 minute and 30 seconds (excluding fw download)"
echo "#"
echo "# To CANCEL and start 'Disk Utility' and edit $CONFIG_SCRIPT [hit any key]"
echo "################################################################################"
read -p "Your answer is: " DECISION

case $DECISION in
	yes) ;;
	*) gedit ${CONFIG_SCRIPT} &
	palimpsest >/dev/null
	exit
esac

echo "$ID (1) Starting with params: DISK_LABEL=${DISK_LABEL}, MBWE_MODEL=${MBWE_MODEL}, MBWE_SERIAL=${MBWE_SERIAL}.">>${LOG_FILE}

echo "$ID Looking for $MBWE_MODEL firmware..."
source ./${FW_SCRIPT}

# Install mdadm from the Internet
#echo "Y" | apt-get install mdadm
# wihout postfix
echo "Y" | apt-get install --no-install-recommends mdadm


# Stop all active RAID arrays
mdadm --stop --scan
RETVAL=$?

if [ "$RETVAL" -eq "127" ] || [ "$RETVAL" -eq "126" ]
#127 for command not found, 126 permission problem
then
	MESSAGE="$ID [EXITING] Cannot proceed without mdadm command installed. You don't have Internet connection or permission to install/use it. Connect computer to the Internet and/or login to root then try again $MAIN_SCRIPT [ENTER TO EXIT]"
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	read; exit ${ERROR}
fi

# ****************************************
# (2) BUILD OS BOOT PARTITION
# ****************************************
# This part will take about 10 seconds
# For infos about the constants see ./fw/upgrade1.sh
# Useful constants
STAGE1=${FW_DIR}/stage1.wrapped
INITRD=${FW_DIR}/uUpgradeRootfs
INITK=${FW_DIR}/uImage.1
UBOOT=${FW_DIR}/u-boot.wrapped
KERNEL=${FW_DIR}/uImage
ROOTFS=${FW_DIR}/rootfs.ext2
BS=512
MBR1st=${FW_DIR}/1stMBR
MBR2nd=${FW_DIR}/2ndMBR
MAC=${FW_DIR}/default_env

# DISK SECTOR OFFSETS.
STAGE1_START=36
UBOOT_START=38
UPGRADE_FLAG_OFFSET=290
KERNEL_START=336
INITRD_START=16674
INITK_START=8482
MAC_START=274
MBR1st_START=432
MBR2nd_START=416
STAGE1_BACKUP_START=32178
UBOOT_BACKUP_START=32180
KERNEL_BACKUP_START=32478
MAC_BACKUP_START=32416

mkdir ./rootfs 2>/dev/null
echo "$ID Writing partition table and building OS boot partition..."
mount -o loop,ro,noatime ${FW_DIR}/rootfs.arm.ext2 ./rootfs

if [ ! -f ./rootfs/etc/DSKPART ]
then
	MESSAGE="$ID_FW [EXITING] No DISKPART in your firmware (/rootfs/etc/DSKPART)??? Probably things have changed and we won't make the deal this way (further proceeding doesn't make any sense). Your disk is untouched so far if it makes you happy somehow. All what's left to you is to check what's going on with your firmware version and if really something has changed since version 01.02.06 (2011-04-16) then make manually appropriate changes in scripts if possible [ENTER TO EXIT]"
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	read; exit ${ERROR}
fi

echo "$ID Clearing boot partition. Please be patient and do not disturb - it will take about 30 seconds..."
dd if=/dev/zero of=/dev/${DISK_LABEL} bs=${BS} count=64320
sync

# MBRs Restauration - no more needed since version 01.02.06
#dd if=mbr_${DISK_SIZE} of=/dev/${DISK_LABEL} bs=446 count=1 seek=0
#dd if=mbr_${DISK_SIZE} of=/dev/${DISK_LABEL} bs=${BS} count=1 seek=0
#sync

# Create partition table from firmware (DSKPART included in FW from version 01.02.06)
#sfdisk --force /dev/${DISK_LABEL} < ./rootfs/etc/DSKPART 2>/dev/null

# We use parted/GPT instead of sfdisk/MBR due to partitions bigger than 2TB
device=${DISK_LABEL}
fstype=gpt

parted --script /dev/$device mklabel $fstype
DSKPART_START=`sed -n -e '3s/\([0-9]*\),\([0-9]*\),fd/\1/p' < ./rootfs/etc/DSKPART`
DSKPART_SIZE=`sed -n -e '3s/\([0-9]*\),\([0-9]*\),fd/\2/p' < ./rootfs/etc/DSKPART`
DSKPART_END=`expr $DSKPART_START + $DSKPART_SIZE - 1`
parted --script /dev/$device unit s mkpart primary $DSKPART_START $DSKPART_END
parted --script /dev/$device set 1 raid on
DSKPART_START=`sed -n -e '4s/\([0-9]*\),\([0-9]*\),fd/\1/p' < ./rootfs/etc/DSKPART`
DSKPART_SIZE=`sed -n -e '4s/\([0-9]*\),\([0-9]*\),fd/\2/p' < ./rootfs/etc/DSKPART`
DSKPART_END=`expr $DSKPART_START + $DSKPART_SIZE - 1`
parted --script /dev/$device unit s mkpart primary $DSKPART_START $DSKPART_END
parted --script /dev/$device set 2 raid on
DSKPART_START=`sed -n -e '5s/\([0-9]*\),\([0-9]*\),fd/\1/p' < ./rootfs/etc/DSKPART`
DSKPART_SIZE=`sed -n -e '5s/\([0-9]*\),\([0-9]*\),fd/\2/p' < ./rootfs/etc/DSKPART`
DSKPART_END=`expr $DSKPART_START + $DSKPART_SIZE - 1`
parted --script /dev/$device unit s mkpart primary $DSKPART_START $DSKPART_END
parted --script /dev/$device set 3 raid on
DSKPART_START=`sed -n -e '6s/\([0-9]*\),\([0-9]*\),fd/\1/p' < ./rootfs/etc/DSKPART`
parted --script /dev/$device unit s mkpart primary $DSKPART_START 100%
parted --script /dev/$device set 4 raid on
partprobe >/dev/null 2>&1

sync

# Update the backup images.
# Backup stage-1 image
dd "if=${STAGE1}" of=/dev/${DISK_LABEL} bs=${BS} seek=${STAGE1_BACKUP_START}
# Update 2nd boot info in MBR if version is before 01.01.18.
dd "if=${MBR2nd}" of=/dev/${DISK_LABEL} bs=1 seek=${MBR2nd_START}
sync
sync

# Update the u-boot image.
dd "if=${UBOOT}" of=/dev/${DISK_LABEL} bs=${BS} seek=${UBOOT_BACKUP_START}
sync

# Write 2nd uboot environment to new location if version is before 01.01.18
dd "if=${MAC}" of=/dev/${DISK_LABEL} bs=512 seek=${MAC_START}
dd "if=${MAC}" of=/dev/${DISK_LABEL} bs=512 seek=${MAC_BACKUP_START}
sync
sync

# Write 2nd kernel to new location if version is before 01.01.18
dd "if=${KERNEL}" of=/dev/${DISK_LABEL} bs=${BS} seek=${KERNEL_BACKUP_START}
sync

# Main stage-1 image
dd "if=${STAGE1}" of=/dev/${DISK_LABEL} bs=${BS} seek=${STAGE1_START}
# Update 1st boot info in MBR if version is before 01.01.18
dd "if=${MBR1st}" of=/dev/${DISK_LABEL} bs=1 seek=${MBR1st_START}
# Upgraded stage-1 loader MBR
sync
sync

# Update the u-boot image.
dd "if=${UBOOT}" of=/dev/${DISK_LABEL} bs=${BS} seek=${UBOOT_START}
sync

# Write 1st kernel to new location if version is before 01.01.18
dd "if=${KERNEL}" of=/dev/${DISK_LABEL} bs=${BS} seek=${KERNEL_START}
sync

# Prepare to switch to upgrade mode in u-boot
# Copy initial ramdisk

# Main upgrade rootfs
dd "if=${INITRD}" of=/dev/${DISK_LABEL} bs=${BS} seek=${INITRD_START}
# Installed upgrade initrd
sync

# Copy upgrade kernel
dd "if=${INITK}" of=/dev/${DISK_LABEL} bs=${BS} seek=${INITK_START}
sync

# Now enable update flag
# echo -n "1" | dd of=/dev/${DISK_LABEL} seek=${UPGRADE_FLAG_OFFSET} bs=${BS}
# Now disable update flag
dd if=/dev/zero of=/dev/${DISK_LABEL} seek=${UPGRADE_FLAG_OFFSET} count=1 bs=${BS}
sync

echo "$ID (2) OS BOOT partition built on ${DISK_LABEL}">>$LOG_FILE

# ****************************************
# (3) BUILD FILESYSTEM
# ****************************************
echo "$ID Building disk filesystem..."

# Stop automounted RAID arrays on your disk
mdadm --stop --scan

# Delete old superblocks
# To make sure that there are no remains from previous RAID installations
# If there are no remains from previous RAID installations, each of the commands will throw an error mdadm: Unrecognised md component device (which is nothing to worry about)
mdadm --zero-superblock /dev/${DISK_LABEL}1
mdadm --zero-superblock /dev/${DISK_LABEL}2
mdadm --zero-superblock /dev/${DISK_LABEL}3
mdadm --zero-superblock /dev/${DISK_LABEL}4

# Delete all boot sectors
dd if=/dev/zero of=/dev/${DISK_LABEL}1 bs=512 count=1
sync
dd if=/dev/zero of=/dev/${DISK_LABEL}2 bs=512 count=1
sync
dd if=/dev/zero of=/dev/${DISK_LABEL}3 bs=512 count=1
sync
dd if=/dev/zero of=/dev/${DISK_LABEL}4 bs=512 count=1
sync

# Make the raid partitions
# This RAID array scheme comes from FW - do not change it until FW is diffrent
# It's not realted to partition scheme | sda1/md0 | sda2/md1 | sda3/md3 | sda4/md2 |
PART_OS_BOOT=md0
PART_SWAP=md1
PART_OS_VAR=md3
PART_DATA=md2

# echo y for "yes" !
echo "y" | mdadm --create --metadata=0.9 /dev/${PART_OS_BOOT} -l 1 -n 2  /dev/${DISK_LABEL}1 missing
echo "y" | mdadm --create --metadata=0.9 /dev/${PART_SWAP} -l 1 -n 2  /dev/${DISK_LABEL}2 missing 
echo "y" | mdadm --create --metadata=0.9 /dev/${PART_OS_VAR} -l 1 -n 2  /dev/${DISK_LABEL}3 missing
echo "y" | mdadm --create --metadata=0.9 /dev/${PART_DATA} -l 1 -n 2  /dev/${DISK_LABEL}4 missing

# Format the raid partitions 12 seconds
mkfs.ext3 /dev/${PART_OS_BOOT}
mkfs.ext3 /dev/${PART_OS_VAR}

# We don't care about DataVolume here - it will be MBWE problem later :)
# 40 minutes for 2TB, 20 minutes for 1TB, so lots of time to spare here
# mkfs.ext3 /dev/${PART_DATA}

# Format swap partition
mkswap /dev/${PART_SWAP}

echo "$ID (3) Filesystem built on ${DISK_LABEL}">>$LOG_FILE

# ****************************************
# (4) INSTALL NAS OS
# ****************************************

# Mount OS partitions to copy NAS OS
mkdir ./${DISK_LABEL}1 2>/dev/null
mkdir ./${DISK_LABEL}3 2>/dev/null
#mkdir ./${DISK_LABEL}4 2>/dev/null
mkdir ./rootfs 2>/dev/null

echo "$ID Installing NAS OS..."
mount -o loop,ro,noatime ${FW_DIR}/rootfs.arm.ext2 ./rootfs >>$LOG_FILE
mount -o rw,noatime /dev/${PART_OS_BOOT} ./${DISK_LABEL}1 >>$LOG_FILE
mount -o rw,noatime /dev/${PART_OS_VAR} ./${DISK_LABEL}3 >>$LOG_FILE
#mount -o rw,noatime /dev/${PART_DATA} ./${DISK_LABEL}4 >>$LOG_FILE

# Copy NAS OS rootfs files to the 1st 2GB NAS OS boot partition
cp -a ./rootfs/* ./${DISK_LABEL}1 >>$LOG_FILE

# Copy NAS OS rootfs/var files to the 3rd 1GB partition (mounted under MBWE as /var)
cp -a ./rootfs/var/* ./${DISK_LABEL}3 >>$LOG_FILE

# Add MAC address init at first boot 
echo "#!/bin/sh
/usr/local/wdc/uboot_env/mac_set.sh ${MAC_ADDRS}
rm -f /etc/init.d/S02mac_set" > ./${DISK_LABEL}1/etc/init.d/S02mac_set
chmod +x ./${DISK_LABEL}1/etc/init.d/S02mac_set

# It's necessary for success to set flags and MBWE ids
echo final_tested_ok > ./${DISK_LABEL}1/etc/mfgtest_state
echo ${MBWE_SERIAL} > ./${DISK_LABEL}1/etc/serialNumber
echo ${MBWE_MODEL} > ./${DISK_LABEL}1/etc/modelNumber

# Prepare for non-WD disk
FACTORY_DEFAULT="./${DISK_LABEL}1/proto/SxM_webui/admin/tools/factoryDefault.sh"

if [ -f ${FACTORY_DEFAULT} ]
then
    FACTORY_FIND="grep WDC"
    FACTORY_REPLACE="grep ."
    sed -i.bak "s|${FACTORY_FIND}|${FACTORY_REPLACE}|g" ${FACTORY_DEFAULT}
fi

# Set the factory_restore flag -> thats rebuild a clean (=deleted!!!) md2/sda4 after reboot
touch ./${DISK_LABEL}1/etc/.factory_restore
sync

clear
MESSAGE="$ID (4) NAS OS installed on ${DISK_LABEL}1 and ${DISK_LABEL}3"
echo $MESSAGE >>$LOG_FILE
echo $MESSAGE
echo ""
echo "$ID OPTIONAL STEP: For curious people now it's time to fiddle around with your new system (look in nautils for volumes ${DISK_LABEL}1 and ${DISK_LABEL}3). Don't spoil anything :)"
echo ""
read -p "Anyway, sooner or later you must [Hit ENTER to FINISH]"
echo ""
echo "$ID Finishing..."

# ****************************************
# (5) FINISH
# ****************************************

# We must manually close every process using disk to successfully unmount partitions
# In Ubuntu 10.10 that are autoopened Nautilus windows with new partitions
#echo "$ID Now go to the Desktop and right click on every disk icon and choose from menu 'Stop Multi-disk drive' then come back and press [ENTER]"; read
#echo "$ID Now close every automatically opened window with new disk partitions (${DISK_LABEL}1 and ${DISK_LABEL}3) then come back and press [ENTER]"; read

# The file system is ready -> stop Raid
umount ./${DISK_LABEL}1
umount ./${DISK_LABEL}3
#umount ./${DISK_LABEL}4
umount ./rootfs
mdadm --stop --scan

rm ./${DISK_LABEL}1 2>/dev/null
rm ./${DISK_LABEL}3 2>/dev/null
rm ./rootfs 2>/dev/null

# You can backup your new MBR here
#dd if=/dev/${DISK_LABEL} of=mbr bs=${BS} count=1 seek=0

# Remember that cfdisk will now throw partition error - that's normal since 01.02.16
# FATAL ERROR: Bad primary partition 1: Partition ends in the final partial cylinder
#cfdisk /dev/${DISK_LABEL}

# That's all
sync
echo "$ID [DONE] `date`">>${LOG_FILE}

echo "################################################################################"
echo "# THAT'S ALL. YOUR DISK IS READY TO REMOVE"
echo "################################################################################"
echo "# Now remove your disk if it is connected by USB or just shutdown your computer"
echo "# and then remove it."
echo "# Then place it in MBWE case. Boot up should take about 3 minutes."
echo "# If your version is WDH2NC (2 disks RAID) then after boot up, shutdown MBWE,"
echo "# unplug MBWE from electricity, place your second disk in an empty bay,"
echo "# boot up again and MBWE will synch it automatically"
echo "# Good luck!"
echo "# Support on http://iknowsomething.com/tag/my-book-world-edition/"
echo "################################################################################"
echo
echo "$ID Now go to Disk Utility app and click 'Safe Removal' by your disk ${DISK_LABEL} and close Disk Utility [hit ENTER to launch Disk Utility]"; read
# Under diffrent distros palimpsest may throw warnings/errors
palimpsest >/dev/null

ls /dev/${DISK_LABEL} 2>/dev/null
RETVAL=$?

echo "$ID Attempt to disk removal result (ls /dev/${DISK_LABEL}): $RETVAL ('0' for disk present, '2' for disk removed)">>${LOG_FILE}

if [ "$RETVAL" -eq "0" ] #0 for success - disk present, 2 for disk removed (cannot access)
then
	echo "$ID [WARNING] It looks like you didn't removed disk ${DISK_LABEL} - it is still present. You must do 'Safe Removal' or just shutdown computer and then remove disk. Otherwise, you can break it!"
fi
read -p "[Hit ENTER to EXIT]"
exit
