#!/bin/sh


echo "Downloading utilities."

success=`curl -L https://www.dropbox.com/s/ldmmn0dcr058iod/stbdiag_utils.sh?dl=0 -o /mnt/persist/stbdiag_utils.sh `
chmod +x /mnt/persist/stbdiag.sh
source /mnt/persist/stbdiag_utils.sh

if [ -e /mnt/persist/stbdiag_utils.sh ]; then
    echo "Successful"
else
    echo "FAILED!"
fi

echo "Starting tcpdump in the background."
tcpdump -i br0 -vv -s 0 -l host 255.255.255.251 or host 239.255.255.251 or port 2100 or port 19798 -w /mnt/persist/Minerva-$HOSTNAME.pcap > /dev/null 2>&1 &

while true; do
  read -p "Press any key when ready to stop tcpdump and proceed" yn
  case $yn in
       * ) break;;
  esac
done

killall tcpdump

upload_to_dropbox dumps /mnt/persist/Minerva-$HOSTNAME.pcap


