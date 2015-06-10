#!/bin/sh
#0.4
#This script assumes it is run on a device with /mnt/hdd as a persistent directory (Amulet DVR for example)
#This script will gather things, and upload the output to Dropbox. (Tom Simpson)
#This script will look for THINK client and cause a coredump.
#This file is known as "diagupload.sh" on Dropbox share, I download and rename in instructions to prevent from over writing this in some dumb fashion.
clear
echo "Hello ${h1}, we are going to run a few things. You will most likely need to reboot afterwards" 

h1=$(hostname)
date=$( date +%Y%m%d_%H%M%S )

echo "Dumping dmesg to file"
dmesg > /mnt/hdd/${h1}/corefiles/dmesg-${date}.out
echo "Dumping top to file"
top -b -n1 > /mnt/hdd/${h1}/corefiles/top-${date}.out

echo "Gathering diagnostic info"
hwblk_field() { echo "$status" | sed -ne "/$1/ s|.*: ||p" ; }

model_name() {
	case "$(hwblk_field 'HW Model')" in
		18) echo "Kamai 400";;
		19) echo "Kamai 400";;
		20) echo "Amulet 400";;
		21) echo "Amulet 400";;
		22) echo "Amulet 400";;
		23) echo "Amulet 400";;
		24) echo "Magi 450";;
		25) echo "Kamai 400v2";;
		26) echo "Kamai 500";;
		27) echo "Amulet 500";;
		28) echo "Magi 450a";;
		29) echo "Magi 400";;
		30) echo "Magi 410";;
		31) echo "Kamai 450";;
		32) echo "Amulet 450m";;
		33) echo "Kamai X";;
		34) echo "Aria 500c";;
		35) echo "Aria 500i";;
		36) echo "Aria 500t";;
		37) echo "XTV125H-C";;
		38) echo "XTV125H-2C";;
		39) echo "Magi 550";;
		40) echo "Aria 500i";;
		41) echo "Amulet 600";;
		42) echo "Kamai 600";;
		*)  echo "Entone STB";;
	esac
}

toKilo() { local n; read n; expr $n \/ 1024; }
toMega() { local n; read n; expr $n \/ 1048576; }
roundoff() { local x ; read x ; local n="`expr $1 / 2`" ; expr \( "$x" + "$n" \) \/ "$1" \* "$1"; }

sw_version() { sed -ne "/$1/ s|.*: ||p" /tmp/diag/general/status; }

get_uptime() { uptime | sed -e 's|.*up[ \t]*\([^,]\+\),.*|\1|'; }

_df() { df -m | grep $1 | tail -n1 | awk "{print \$$2}"; }
_df_unit() { local size="$(_df $*)"; if [ "$size" -gt 1024 ]; then echo "$(echo ${size} | toKilo)GB"; elif [ -n "$size" ]; then echo "${size}MB"; else echo "--"; fi ; }
disk_size() { _df_unit $1 2; }
disk_used() { _df_unit $1 3; }

nand_size() { grep "nand0." /proc/mtd | awk '{printf "0x"$2 "\n"}' | xargs printf "%d\n" | awk '{s+=$1} END {print s / 1048576}' | roundoff 64; }
nand_used() { expr $(nand_size) - $(_df `partition_info approotfs` 4) - $(_df /mnt/persist 4); }

ram_system_total() { grep "MemTotal:" /proc/meminfo | awk '{printf $2 }'; }
ram_system_free() { grep "MemFree:" /proc/meminfo | awk '{printf $2 }'; }
ram_nexus_total() { heapDump 2>&1 | sed 's,.*size \([0-9]*\).*,\1,g' | awk '{s+=$1} END {print s}' | toKilo; }
ram_nexus_free() { heapDump 2>&1 | sed 's,.*free \([0-9]*\).*,\1,g' | awk '{s+=$1} END {print s}' | toKilo; }
ram_size() { grep "System RAM" /proc/iomem | sed 's,\([0-9a-fA-F]\{8\}\)-\([0-9a-fA-F]\{8\}\).*,-0x\1 0x\2 1,g' | xargs printf "%d\n" | awk '{s+=$1} END {print s / 1024}'; }
ram_used() { expr $(ram_size) - $(ram_system_free) - $(ram_nexus_free); }

JSON_SEPARATOR=""
_print_value() { printf "$JSON_SEPARATOR\"$1\": \"%s\"" "$2"; JSON_SEPARATOR=", "; }

#netflix_esn() { netflixESN > /dev/null; NETFLIX_ESN=$(cat /tmp/netflix-esn); }

print_json() {
	printf "{"
	_print_value 'Model Name' "$(model_name)"
	_print_value 'Board Version' "$(hwblk_field 'Board Version')"
	_print_value 'Serial Number' "$(hwblk_field 'HW Model')-$(hwblk_field 'ESN')"
	_print_value 'PBL Version' "$(sw_version pbl)"
	_print_value 'BBL Version' "$(sw_version bbl)"
	_print_value 'APP Version' "$(sw_version app)"
#	netflix_esn
#	if [ ! -z ${NETFLIX_ESN} ]; then
#	    _print_value 'Netflix ESN' "${NETFLIX_ESN}"
#	fi
	_print_value 'System Uptime' "$(get_uptime)"
	_print_value 'Flash Size (Used)' "$(nand_size)MB ($(nand_used)MB)"
	_print_value 'Ram Size (Used)' "$(ram_size | toKilo)MB ($(ram_used | toKilo)MB)"
	_print_value 'System Memory' "$(ram_system_free | toKilo) / $(ram_system_total | toKilo)"
	_print_value 'Nexus Memory' "$(ram_nexus_free | toKilo) / $(ram_nexus_total | toKilo)"
	_print_value 'HDD Size (Used)' "$(disk_size /mnt/hdd) ($(disk_used /mnt/hdd))"
	_print_value 'IP Address' "$(hwblk_field 'IP')"

	# TODO: implement error code field
	#_print_value 'Error Code' '--'
	printf "}"
}

print_json >/mnt/hdd/${h1}/corefiles/generalstbinfo.out

#Looking for Think client, if it's not running dump a log message. If it is running, kill it for core file.
#case "$(pidof think | wc -w)" in

#0)  echo "Think Client NOT running.  $(date)" >> /mnt/hdd/${h1}/corefiles/generalstbinfo.out
#	;;
#*)  echo "Think Client IS running, killing for core file: $(date)" >> /mnt/hdd/${h1}/corefiles/generalstbinfo.out
    killall -11 think
#    echo "Killing think client core file since it's running."
#    ;;
#esac

printf "Creating core file archive /mnt/hdd/${h1}-${date}-core.tar.gz, this will take a moment."
cd /mnt/hdd/${h1}/corefiles
tar -czvf /mnt/hdd/${h1}-${date}-core.tar.gz ./*
ls -l /mnt/hdd/*.gz 
printf "Creating log file archive if available /mnt/hdd/${h1}-${date}-logs.tar.gz"
cd /mnt/hdd/
tar -czvf /mnt/hdd/${h1}-${date}-logs.tar.gz -C /mnt/hdd/ logf*
ls -l /mnt/hdd/*.gz
curl -H "Authorization: Bearer ZwB0XhhU_yoAAAAAAANEpkjYNQxNua5rQtFAGV2DHYeaQ-sQeDyugH8JLp4-7Y1o" https://api-content.dropbox.com/1/files_put/auto/ -T /mnt/hdd/${h1}-${date}-core.tar.gz
curl -H "Authorization: Bearer ZwB0XhhU_yoAAAAAAANEpkjYNQxNua5rQtFAGV2DHYeaQ-sQeDyugH8JLp4-7Y1o" https://api-content.dropbox.com/1/files_put/auto/ -T /mnt/hdd/${h1}-${date}-logs.tar.gz
printf "\nCleaning up after ourselves.\n"
#find /mnt/hdd/${h1}/corefiles -type f -mtime +3 -delete
#find /mnt/hdd/ -name log -type f -mtime +3 -delete
#rm /mnt/hdd/*.gz
#rm /mnt/hdd/log*
#rm /mnt/hdd/${h1}/corefiles/*
echo  "Done, you can reboot now."
