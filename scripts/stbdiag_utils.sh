#!/bin/sh
CORE_DIR=`cat /proc/sys/kernel/core_pattern | awk 'BEGIN{FS="%"}{print $1}'`
UTILS_SUCCESS=1

upload_to_dropbox() {
    upload_path=$1
    local_fully_qualified_filename=$2
    curl -H "Authorization: Bearer zf_DdnPHb5AAAAAAAAAADT9lSd93RJy3HeBShWgENMgso_IYW9Cu48XN6E4PCg15" https://api-content.dropbox.com/1/files_put/auto/$upload_path/ -T $local_fully_qualified_filename >> /dev/null 2>&1
    echo "File $fully_qualified_filename uploaded to QA Dropbox Account."
}

do_cleanup() {
    local num_args=$#
    ind=$((num_args))
    echo $ind
    while [ 0 -lt $ind ]; do  
        rm -rf ${@:$ind}
        ind=$(( ind - 1 ))
    done
}

do_timed_logread() {
    time=$1
    outfile=$2
    if [ $# -ne 2 ]; then 
        echo "illegal number of parameters"
        return;
    fi

    if [ -z "$time" ]; then 
        local time_sec=60; 
    else
        local time_sec=$(( time*60 ))
    fi

    outfile=$2
    
    echo -ne "Performing logread: "
    logread -f > $outfile 2>&1 &
    # Count down while logread is active
    local loop_count=0
    while [ $time_sec -ne 0 ]; do 
        sleep 1;
        echo -ne "#"
        time_sec=$(( time_sec - 1 )) 
        mod=$(( loop_count % 10 ))
        if [ $mod -eq 0 ] && [ $loop_count -ne 0 ]; then
           echo -ne "\033[2K"
           echo -ne "\rPerforming logread: "
        fi
        loop_count=$(( loop_count + 1 ))
    done
    
    echo

    killall logread 
}

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
	_print_value 'persist Size (Used)' "$(disk_size /mnt/hdd) ($(disk_used /mnt/hdd))"
	_print_value 'IP Address' "$(hwblk_field 'IP')"

	# TODO: implement error code field
	#_print_value 'Error Code' '--'
	printf "}"
}


