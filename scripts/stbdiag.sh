#!/bin/sh
#set -x
###############################################################################################################
#                                                                                                             #
# This script assumes it is run on a device with $LOCAL_SCRIPT_DIR as a persistent directory (should work for      #
# all Entone versions). It will gather STB diag info and cause a core dump for the THINK client. Following    #
# this it will upload the tar/gz output to Dropbox. (Tom Simpson)                                             #
# This script will look for THINK client and cause a coredump.                                                #
# This file is known as "diagupload.sh" on Dropbox share, I download and rename in instructions to prevent    #
# from over writing this in some dumb fashion.                                                                #
#                                                                                                             #
###############################################################################################################
HOST=$(hostname)
DATE=$( date +%Y%m%d_%H%M%S )
LOCAL_SCRIPT_DIR="/mnt/hdd"
UTILS_SUCCESS=0
THINK_KILL=0

clear
mkdir -p $LOCAL_SCRIPT_DIR/${HOST}/logfiles
echo "Hello ${HOST}, we are going to run a few things. You will most likely need to reboot afterwards" 

echo -n "Downloading utilities: "
curl -L https://www.dropbox.com/s/ldmmn0dcr058iod/stbdiag_utils.sh?dl=0 -o $LOCAL_SCRIPT_DIR/stbdiag_utils.sh > /dev/null 2>&1 
source $LOCAL_SCRIPT_DIR/stbdiag_utils.sh

if [ -e $LOCAL_SCRIPT_DIR/stbdiag_utils.sh ] && [ $UTILS_SUCCESS == 1 ]; then
    echo "SUCCESS"
else
    echo "FAILED!"
    exit ;
fi

#
# Do timed logread command (Entone)
#
read -p "Do you want to accumulate 1 minute of logread data? [Yn]" yn
case $yn in
 [Nn]* ) break;;
     * ) echo "Doing timed logread.  This will take 1 minute.";
         do_timed_logread 1 $LOCAL_SCRIPT_DIR/${HOST}/logfiles/logread.out;
         break;;
esac

read -p "Do you want to check Think status and force kill if running? [Yn]" yn
case $yn in
 [Nn]* ) echo "Skipping Think kill"; THINK_KILL=0; break;;
     * ) break;;
esac

#
# Looking for Think client, if it's not running and no core files were left around, EXIT. If it is running, kill it for core file.
#
if [ $THINK_KILL -eq 1 ]; then
   echo -n "Think status at script start: " | tee $LOCAL_SCRIPT_DIR/${HOST}/logfiles/think_status.out
   case "$(pidof think | wc -w)" in

   0)  echo -n "Think Client NOT running. " | tee -a $LOCAL_SCRIPT_DIR/${HOST}/logfiles/think_status.out ;
       if [ "$(ls -A $CORE_DIR)" ]; then
           echo "Core files exist, continuing!" | tee -a $LOCAL_SCRIPT_DIR/${HOST}/logfiles/think_status.out ;
       else
           echo "No core files exist. EXITING!" | tee -a $LOCAL_SCRIPT_DIR/${HOST}/logfiles/think_status.out ;
           exit ;
       fi
       ;;
   *)  echo "Think Client IS running, killing for core file: $DATE" | tee -a $LOCAL_SCRIPT_DIR/${HOST}/logfiles/think_status.out;
       killall -11 think ;
       ;;
   esac
fi

echo "Dumping dmesg to file"
dmesg > $LOCAL_SCRIPT_DIR/${HOST}/logfiles/dmesg-${DATE}.out
echo "Dumping top to file"
top -b -n1 > $LOCAL_SCRIPT_DIR/${HOST}/logfiles/top-${DATE}.out

echo "Gathering general STB info"

print_json > $LOCAL_SCRIPT_DIR/${HOST}/logfiles/generalstbinfo.out

echo "Creating core file archive $LOCAL_SCRIPT_DIR/${HOST}-${DATE}-core.tar.gz, this will take a moment."

found=0
x=1

echo -n "Waiting for core file: #" 

for x in 1 2 3 4 5 6 7 8 9 10
do
  if [ "$(ls -A $CORE_DIR)" ]; then
    found=1
    break
  else
    #echo "$CORE_DIR is Empty"
    echo -n "#"
    sleep 1
  fi
done
echo ""

if [ $found -eq 0 ]; then
  echo "Could not create core file... exiting!"
  exit 255
fi
    
ls -la $CORE_DIR
tar -czvf $LOCAL_SCRIPT_DIR/${HOST}-${DATE}-core.tar.gz $CORE_DIR/*
ls -l $LOCAL_SCRIPT_DIR/*.gz 

printf "Creating log file archive if available $LOCAL_SCRIPT_DIR/${HOST}-${DATE}-logs.tar.gz"
tar -czvf $LOCAL_SCRIPT_DIR/${HOST}-${DATE}-logs.tar.gz $LOCAL_SCRIPT_DIR/${HOST}/logfiles/*
ls -l $LOCAL_SCRIPT_DIR/*.gz

# 
# Check whether upload is desired.
#
read -p "Do you want to upload tar files to Dropbox? [Y/n]" yn
case $yn in
  [Nn]* ) echo "Upload not performed."; break;;
      * ) echo "Uploading..."; 
          upload_to_dropbox uploads $LOCAL_SCRIPT_DIR/${HOST}-${DATE}-core.tar.gz;
          upload_to_dropbox uploads $LOCAL_SCRIPT_DIR/${HOST}-${DATE}-logs.tar.gz;
          break;;
esac

#
# Check whether cleanup is desired.
#
read -p "Do you want to clean up core/log files? [Y/n]" yn
case $yn in
 [Nn]* ) echo "Cleanup not performed."; break;;
     * ) echo "Cleaning up..."; do_cleanup $LOCAL_SCRIPT_DIR/${HOST}*  $LOCAL_SCRIPT_DIR/stbdiag*.sh ; break;;
esac

#
# Check whether reboot is desired.
#
read -p "Do you want to reboot the box? [Y/n]" yn
case $yn in
 [Nn]* ) echo "Bye!"; exit;;
     * ) echo "Rebooting!"; reboot; break;;
esac
