#!/bin/sh

DATE=$( date +%Y%m%d_%H%M%S )

do_cleanup() {
    pcap_filename=$1
    rm -rf /mnt/persist/stbdiag_*.sh
    rm -rf $pcap_filename
}

echo "Downloading utilities."

success=`curl -L https://www.dropbox.com/s/ldmmn0dcr058iod/stbdiag_utils.sh?dl=0 -o /mnt/persist/stbdiag_utils.sh `
source /mnt/persist/stbdiag_utils.sh

if [ -e /mnt/persist/stbdiag_utils.sh ]; then
    echo "Successful"
else
    echo "FAILED!"
fi

echo "Starting tcpdump in the background."
tcpdump -i br0 -vv -s 0 -l host 255.255.255.251 or host 239.255.255.251 or port 2100 or port 19798 -w /mnt/persist/Minerva-$HOSTNAME-$DATE.pcap > /dev/null 2>&1 &

while true; do
  read -p "Press any key when ready to stop tcpdump and proceed: " yn
  case $yn in
       * ) break;;
  esac
done

killall tcpdump

upload_to_dropbox dumps /mnt/persist/Minerva-$HOSTNAME-$DATE.pcap

#
# Cleanup
#
read -p "Do you wish to clean up pcap files? [Y/n]" yn
case $yn in
 [Nn]* ) echo "Cleanup not performed."; break;;
     * ) echo "Cleaning up..."; do_cleanup /mnt/persist/Minerva-$HOSTNAME-$DATE.pcap ; break;;
esac

