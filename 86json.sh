#!/bin/bash

# Load x86 core
. x86.sh load

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

# Initial: Load register values
# Final: Verify registers are expected
check() {
    local key=$1 value=$2 ini=$3

    index=$(regindex "$key")
#    printf "set: $key $index %x\n" $value
    if [ "$index" -lt 0 ]; then
	return
    fi
    local rv=${X86_REGS[$index]}
    if [ $ini -eq 1 ]; then
	X86_REGS[$index]=$value
    elif [[ "$rv" -ne "$value" ]] ; then
	case $key in
	    ip|flags) ;;
	    *) printf "mismatch: $key $index $value [got: $rv %x]\n" $rv ;;
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
#    echo -n "$section: "
#    cat .input
    
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
#	printf "$addr <- %x [${X86_MEM[$addr]}]\n" $val
	if [ $ini -eq 1 ]; then
	    X86_MEM[$addr]=$val
	elif [ "$mv" -ne "$val" ]; then
	    echo "mismatch: mem $addr $val [got: $mv]"
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
	CF=$(((X86_REGS[14] >> 0) & 1))
	PF=$(((X86_REGS[14] >> 2) & 1))
	AF=$(((X86_REGS[14] >> 4) & 1))
	ZF=$(((X86_REGS[14] >> 6) & 1))
	SF=$(((X86_REGS[14] >> 7) & 1))
	IF=$(((X86_REGS[14] >> 9) & 1))
	DF=$(((X86_REGS[14] >> 10) & 1))
	OF=$(((X86_REGS[14] >> 11) & 1))
	printf " %x SF=$SF ZF=$ZF AF=$AF PF=$PF CF=$CF DF=$DF IF=$IF seg=$seg\n" ${X86_REGS[14]}

	pfx=1
	seg=""
	osize=0xffff
	mask=0xffff
	while [ $pfx -eq 1 ]; do
	    pfx=0
	    fetch8
	    opcode=$IR
	    printf "opcode is ${opcode} %x\n" ${X86_REGS[15]}
	    decode $opcode
	done
	N=$((0x1|0x4|0x10|0x40|0x80|0x200|0x400|0x800))
	nf=$(((OF << 11) | (DF << 10) | (IF << 9) |
		  (SF << 7) | (ZF << 6) | (AF << 4) |
		  (PF << 2) | 0x2 | CF))
	X86_REGS[14]=$((X86_REGS[14] & ~N))
	X86_REGS[14]=$((X86_REGS[14] | nf))

	# Read final regso
	parseregs "$j" 0 ".final.regs"
	parsemem "$j" 0 ".final.ram"
    done < <(jq -c ".[]" $file)
}

loadfile $1
