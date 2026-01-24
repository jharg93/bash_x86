#!/bin/bash

# Run single-step json tests for x86 core

# Load x86 core
. x86.sh load

verbose=0

# return register index
regindex() {
    case $1 in
	ax) echo 0 ;;
	cx) echo 1 ;;
	dx) echo 2 ;;
	bx) echo 3 ;;
	sp) echo 4 ;;
	bp) echo 5 ;;
	si) echo 6 ;;
	di) echo 7 ;;
	es) echo 16 ;;
	cs) echo 17 ;;
	ss) echo 18 ;;
	ds) echo 19 ;;
	ip) echo 15 ;;
	flags) echo 14 ;;
	*) echo -1 ;;
    esac
}

fstr() {
    local f=$1
    local out=""
    (( f & (1<<11) )) && out+="o" || out+="."
    (( f & (1<<10) )) && out+="d" || out+="."
    (( f & (1<<9)  )) && out+="i" || out+="."
    (( f & (1<<7)  )) && out+="s" || out+="."
    (( f & (1<<6)  )) && out+="z" || out+="."
    (( f & (1<<4)  )) && out+="a" || out+="."
    (( f & (1<<2)  )) && out+="p" || out+="."
    (( f & 1       )) && out+="c" || out+="."
    echo $out
}

# Initial: Load register values
# Final: Verify registers are expected
check() {
    local key=$1 value=$2 ini=$3

    index=$(regindex "$key")
    if [ $verbose != 0 ]; then
	printf "set: $key $index %x\n" $value
    fi
    if [ "$index" -lt 0 ]; then
	return
    fi
    local rv=${X86_REGS[$index]}
    if [ $ini -eq 1 ]; then
	X86_REGS[$index]=$value
    elif [[ "$rv" -ne "$value" ]] ; then
	case $key in
	    # hack. ignore jumps/calls/flags
	    flags)
		value=$((value & ~0x10))
		rv=$((rv & ~0x10))
		if [[ "$rv" -ne "$value" ]] ; then
		    printf "flags mismatch %x %s %x %s\n" $value $(fstr $value) $rv $(fstr $rv)
		fi
		;;
	    *)
		printf "mismatch: $key $index %x [got: $rv %x]\n" $value $rv
		;;
	esac
    fi
}

# Parse registers from json file
parseregs() {
    local json=$1
    local ini=$2
    local section=$3

    # read json key/value pairs
    jq -c "$section" <<< "$json" > .input.$$
    jq -r "$section | to_entries[] | [.key, .value] | @tsv" > .input.$$ <<< "$json"
    while IFS=$'\t' read -r key value ; do
	check "$key" "$value" "$ini"
    done < .input.$$
}

# Parse memory from json file
parsemem() {
    local json=$1
    local ini=$2
    local section=$3

    jq -r "$section | .[] | @tsv" > .input.$$ <<< "$json"
#    echo "readmem $section"
    while IFS=$'\t' read -r addr val ; do
	mv=${X86_MEM[$addr]}
	if [ -z "$mv" ]; then
	    mv=0
	fi
	if [ $verbose != 0 ] ; then
	    printf "$addr <- %x [${X86_MEM[$addr]}]\n" $val
	fi
	if [ $ini -eq 1 ]; then
	    X86_MEM[$addr]=$val
	elif [ "$mv" -ne "$val" ]; then
	    printf "mismatch: mem $addr %x [got: %x]\n" $val $mv
	fi
    done < .input.$$
}

# Scan json for initial
loadfile() {
    local file=$1
    while read j; do
	printf "\n\n=====\n"
	parseregs "$j" 1 ".initial.regs"
	parsemem "$j" 1 ".initial.ram"

	# Load Flags
	getflags
	printf " %x OF=$OF SF=$SF ZF=$ZF AF=$AF PF=$PF CF=$CF DF=$DF IF=$IF seg=$seg\n" ${X86_REGS[14]}

	# Loop while prefix set
	pfx=1
	seg=""
	rep=0
	osize=0xffff
	mask=0xffff
	while [ $pfx -eq 1 ]; do
	    pfx=0
	    fetch8 opcode
	    printf "opcode is ${opcode} %x\n" ${X86_REGS[15]}
	    decode $opcode
	done
	setflags

	# Read final regso
	parseregs "$j" 0 ".final.regs"
	parsemem "$j" 0 ".final.ram"
    done < <(jq -c ".[]" $file)
}

while getopts "v" opt; do
    case "$opt" in
	v) verbose=1 ;;
    esac
done
shift $((OPTIND - 1))

loadfile $1
