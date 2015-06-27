#!/bin/sh

DATE=$( date +%Y%m%d_%H%M%S )
LOCAL_SCRIPT_DIR="/mnt/hdd"

echo -n "Downloading utilities: "

curl -L https://www.dropbox.com/s/ldmmn0dcr058iod/stbdiag_utils.sh?dl=0 -o $LOCAL_SCRIPT_DIR/stbdiag_utils.sh > /dev/null 2>&1 
UTILS_SUCCESS=0
source $LOCAL_SCRIPT_DIR/stbdiag_utils.sh

if [ -e $LOCAL_SCRIPT_DIR/stbdiag_utils.sh ] && [ $UTILS_SUCCESS == 1 ]; then
    echo "SUCCESS"
else
    echo "FAILED!"
    exit ;
fi

echo "Starting tcpdump in the background."
tcpdump -i br0 -vv -s 0 -l host 255.255.255.251 or host 239.255.255.251 or port 2100 or port 19798 -w $LOCAL_SCRIPT_DIR/Minerva-$HOSTNAME-$DATE.pcap > /dev/null 2>&1 &

while true; do
  read -p "Press any key when ready to stop tcpdump and proceed: " yn
  case $yn in
       * ) break;;
  esac
done

killall tcpdump

upload_to_dropbox dumps $LOCAL_SCRIPT_DIR/Minerva-$HOSTNAME-$DATE.pcap

#
# Cleanup
#
read -p "Do you wish to clean up pcap files? [Y/n]" yn
case $yn in
 [Nn]* ) echo "Cleanup not performed."; break;;
     * ) echo "Cleaning up..."; do_cleanup $LOCAL_SCRIPT_DIR/stbdiag*.sh $LOCAL_SCRIPT_DIR/Minerva-$HOSTNAME-$DATE.pcap ; break;;
esac

