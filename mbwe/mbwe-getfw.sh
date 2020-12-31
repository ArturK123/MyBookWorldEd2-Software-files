#!/bin/bash
ID_FW="##### MBWE ##### (getfw.sh):"
# ****************************************
# MBWE FIRMWARE DOWNLOAD
# ****************************************
# By Krzysztof Przygoda
# http://www.iknowsomething.com
# with help of http:/mybookworld.wikidot.com
# 2014-02-07 tested with firmware:
  FW_SCRIPT_VER="01.02.14"
# ****************************************

# This script takes local or download and unpack MBWE firmware
# The same firmware is for WDH2NC, WDH1NC, so you get WDHxNC img
URL_FW=http://download.wdc.com/nas/wdhxnc-01.02.14.img

# If URL_FW is no longer avaible you can change it or download the latest firmware manually in the browser with this link:
URL_FW_HTML="http://websupport.wdc.com/firmware/list.asp?type=WDH2NC&fw=01.01.18"

# This link placed in the browser always gives in return link to the latest firmware img, regarding the MBWE type and your current FW version you provide
# Link construction is as follows:
# http://websupport.wdc.com/firmware/list.asp?type=MODEL&fw=VERSION
# where:
# MODEL=WDH2NC or WDH1NC - but it doesn't matter until it's the same fw for both models
# VERSION=01.01.18 - this must be always previous/older FW wersion than the latest, otherwise you will get no upgrade available message
# (for link contruction see /proto/SxM_webui/admin/fw_chk.php)

FW_DIR=./fw
FW_TMP_DIR=./fw_tmp

if [ ! -f ./fw.img ]
then
	MESSAGE="$ID_FW No fw.img file found in current folder. Downloading firmware from the Internet..."
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	
	# Get html page with actual FW link and extract img link
	wget ${URL_FW_HTML} -O ./fw.html
	URL_FW=`sed 's/http/\^http/g' ./fw.html | tr -s "^" "\n" | grep http | sed 's/\".*//g'`

	# Finally get FW img
	wget ${URL_FW} -O ./fw.img
	RETVAL=$?

	if [ "$RETVAL" -eq "8" ]
	then
		echo "$ID_FW [EXITING] Firmware file not found in current folder nor on $URL_FW" >>${LOG_FILE}
		echo "$ID_FW Go to $URL_FW_HTML and download image manually saving file as fw.img then try again $MAIN_SCRIPT [ENTER TO EXIT]"
		read; exit ${ERROR}
	fi
else
	MESSAGE="$ID_FW Processing firmware fw.img file found in current folder."
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE	
fi

mkdir ${FW_TMP_DIR} 2> /dev/null
echo "$ID_FW Decoding firmware..."
# See /proto/SxM_webui/admin/inc/wixHooks.class
dd skip=0 count=1 bs=5120 if=./fw.img of=${FW_TMP_DIR}/tmp_img1
dd skip=15 count=1 bs=5120 if=./fw.img of=${FW_TMP_DIR}/tmp_img2

cp ./fw.img ${FW_TMP_DIR}/fw.img
dd seek=0 count=1 bs=5120 if=${FW_TMP_DIR}/tmp_img2 of=${FW_TMP_DIR}/fw.img 
dd skip=1 seek=1 bs=5120 if=./fw.img of=${FW_TMP_DIR}/fw.img 

cp ${FW_TMP_DIR}/fw.img ${FW_TMP_DIR}/tmp_img2
dd seek=15 count=1 bs=5120 if=${FW_TMP_DIR}/tmp_img1 of=${FW_TMP_DIR}/fw.img 
dd skip=16 seek=16 bs=5120 if=${FW_TMP_DIR}/tmp_img2 of=${FW_TMP_DIR}/fw.img 

rm ${FW_TMP_DIR}/tmp_img1
rm ${FW_TMP_DIR}/tmp_img2

echo "$ID_FW Extracting firmware... pass 1/2"
# Extract gzipped image .tar.gz
cd ${FW_TMP_DIR}
tar zxf ./fw.img
RETVAL=$?
rm ./fw.img

if [ "$RETVAL" -eq "2" ] #2 for error - broken tar
then
	MESSAGE="$ID_FW [EXITING] Firmware archive file is broken (tar result: $RETVAL) and I cannot proceed. Go to $URL_FW2 and download image manually saving file as fw.img then try again $MAIN_SCRIPT [ENTER TO EXIT]"
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	read; exit ${ERROR}
fi

echo "$ID_FW Checking..."
# Look at firmware image checksum
FW_IMG2=upgrd-pkg-1nc.wdg
md5sum -c ${FW_IMG2}.md5 
RETVAL=$?

if [ "$RETVAL" -eq "1" ] #1 for error - checksum did NOT match
then
	MESSAGE="$ID_FW [EXITING] Firmware image checksum does NOT match ${FW_IMG2} (md5sum result: $RETVAL) and I cannot proceed. Go to $URL_FW2 and download image manually saving file as fw.img then try again $MAIN_SCRIPT [ENTER TO EXIT]" >>${LOG_FILE}
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	read; exit ${ERROR}
fi

cd ..

# Unpack firmware
mkdir ${FW_DIR} 2> /dev/null
echo "$ID_FW Extracting firmware... pass 2/2"
SKIP=`awk '/^__ARCHIVE_FOLLOWS__/ {print NR +1; exit 0 }' ${FW_TMP_DIR}/${FW_IMG2}`
tail -n+${SKIP} ${FW_TMP_DIR}/${FW_IMG2} | gunzip  | /bin/tar xm -C ${FW_DIR}

echo "$ID_FW Checking..."
# Check firmware package files md5sums
cd ${FW_DIR}
md5sum -c md5sum.lst
RETVAL=$?

if [ "$RETVAL" -eq "1" ] #1 for error - checksum did NOT match
then
	MESSAGE="$ID_FW [EXITING] Extracted firmware package files checksum does NOT match md5sum.lst (md5sum result: $RETVAL) and I cannot proceed. Go to $URL_FW2 and download image manually saving file as fw.img then try again $MAIN_SCRIPT [ENTER TO EXIT]"
	echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
	read; exit ${ERROR}
fi

cd ..

# Check the current version 
FW_CURRENT_VER=`awk '{print $1}' ${FW_TMP_DIR}/fw.ver`

CV1=`echo $FW_CURRENT_VER | awk -F. '{print $1}'`
CV2=`echo $FW_CURRENT_VER | awk -F. '{print $2}'`
CV3=`echo $FW_CURRENT_VER | awk -F. '{print $3}'`

SV1=`echo $FW_SCRIPT_VER | awk -F. '{print $1}'`
SV2=`echo $FW_SCRIPT_VER | awk -F. '{print $2}'`
SV3=`echo $FW_SCRIPT_VER | awk -F. '{print $3}'`

# If FW version is lower than script was tested then exit
if [ "$FW_CURRENT_VER" != "01.02.06" ]
then
	if [ "$CV1" -lt "$SV1" ] || \
	   ([ "$CV1" -eq "$SV1" ] && [ "$CV2" -lt "$SV2" ]) || \
	   ([ "$CV1" -eq "$SV1" ] && [ "$CV2" -eq "$SV2" ] && [ "$CV3" -lt "$SV3" ])
	then
		MESSAGE="$ID_FW [EXITING] You have acuired obsolete firmware ver $FW_CURRENT_VER (not supported here). Delete it from disk to download the latest automatically next time or just go to $URL_FW2 and download image manually, saving file as fw.img, then try again $MAIN_SCRIPT [ENTER TO EXIT]"
		echo $MESSAGE>>$LOG_FILE; echo $MESSAGE
		read; exit ${ERROR}
	fi
fi

MESSAGE="$ID_FW Firmware ver $FW_CURRENT_VER seems to be OK and is placed in ${FW_DIR} folder."
echo $MESSAGE>>$LOG_FILE; echo $MESSAGE

# If FW version is greater than script tested then warn
if [ "$CV1" -gt "$SV1" ] || \
   ([ "$CV1" -eq "$SV1" ] && [ "$CV2" -gt "$SV2" ]) || \
   ([ "$CV1" -eq "$SV1" ] && [ "$CV2" -eq "$SV2" ] && [ "$CV3" -gt "$SV3" ])
then
	MESSAGE="This script was tested with firmware ver $FW_SCRIPT_VER but you acuired greater ver $FW_CURRENT_VER. Further proceeding can only be considered as an experiment with no guarantee of success. If something will go wrong you'll end up at last with ### ERASED DISK ### If you are brave and it doesn't scare you [type 'yes' to proceed]"
	echo	
	echo "################################################################################"
	echo "# WARNING!!!"
	echo "################################################################################"
	echo "$ID_FW [WARNING] $MESSAGE">>$LOG_FILE; echo $MESSAGE
	echo "################################################################################"
	read -p "Your answer: " DECISION
	case $DECISION in
		yes) ;;
		*) exit
	esac
fi

