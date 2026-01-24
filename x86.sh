#!/bin/bash
#
# Lets emulate an x86 in bash....
#
declare -a X86_MNEM
declare -a X86_OP1
declare -a X86_OP2
declare -a X86_ENC
declare -a X86_REGS
declare -a X86_MEM

error_handler() {
    echo error....
    exit 0
}

trap 'error_handler' ERR

# CPU Flags
# flags="odiszapc"
SF=0
ZF=0
AF=0
PF=0
CF=0
DF=0
IF=0

# fetch byte from PC
fetch8() {
    local __out=$1
    local pc=${X86_REGS[15]}
    local cs=${X86_REGS[17]}
    local addr=$(((cs * 16 + pc) & 0xfffff))
    local v=${X86_MEM[$addr]}
    X86_REGS[15]=$(((pc+1) & 0xffff))
    printf -v "$__out" "0x%.2x" $v
}

# fetch word from PC
fetch16() {
    local __out=$1
    fetch8 LO
    fetch8 HI
    printf -v "$__out" "0x%.2x%.2x" $HI $LO
}

# fetchv
fetchv() {
    case $osize in
	0xffff)
	    fetch16 IR
	    ;;
	0xffffffff)
	    fetch16 LO
	    fetch16 HI
	    IR=$(printf "0x%.4x%.4x" $HI $LO)
	    ;;
	esac
}

# read8 seg off
read8() {
    local off=$2
    local base=$(($1 * 16))
    local addr=$(((base + (off + 0 & 0xffff)) & 0xfffff))
    local v=${X86_MEM[$addr]}
    printf "0x%x" $v
}

# write8 seg off val
write8() {
    local off=$2
    local base=$(($1 * 16))
    local addr=$(((base + (off + 0 & 0xffff)) & 0xfffff))
    X86_MEM[$addr]=$(($3 & 0xff))
}

# read16 seg off
read16() {
    local off=$2
    local base=$(($1 * 16))
    local a0=$(((base + (off + 0 & 0xFFFF)) & 0xfffff))
    local a1=$(((base + (off + 1 & 0xFFFF)) & 0xfffff))
    local v1=${X86_MEM[$a0]}
    local v2=${X86_MEM[$a1]}
    printf "0x%.2x%.2x" $v2 $v1
}

# write16 seg off val
write16() {
    local off=$2
    local base=$(($1 * 16))
    local a0=$(((base + (off + 0 & 0xFFFF)) & 0xfffff))
    local a1=$(((base + (off + 1 & 0xFFFF)) & 0xfffff))
    X86_MEM[$a0]=$(($3 & 0xff))
    X86_MEM[$a1]=$((($3 >> 8) & 0xff))
}

loadptr() {
    local cs=$1
    local co=$2
    local oparg=($3)
    local pseg=${oparg[1]}
    local pofs=${oparg[2]}
    printf -v "$co" $(read16 $pseg $pofs)
    printf -v "$cs" $(read16 $pseg $((pofs + 2)))
}

# push value to stack (dec->write)
pushv() {
    local val=$1
    local mask=$2
    local sp=${X86_REGS[4]}
    local ss=${X86_REGS[18]}
    case $mask in
	0xffff)
	    sp=$(((sp - 2) & 0xffff))
	    setreg 4 $sp 0xffff
	    write16 $ss $sp $val
	    ;;
	0xffffffff)
	    sp=$(((sp - 2) & 0xffffffff))
	    write16 $ss $sp $((val >> 16))
	    sp=$(((sp - 2) & 0xffffffff))
	    write16 $ss $sp $val
	    setreg 4 $sp 0xffffffff
	    ;;
    esac
}

# pop value from stack (read -> inc)
popv() {
    local __out=$1
    local sp=${X86_REGS[4]}
    local ss=${X86_REGS[18]}
    case $osize in
	0xffff)
	    setreg 4 $((sp + 2)) 0xffff
	    N=$(read16 $ss $sp)
	    printf -v "$__out" "0x%x" $N
	    ;;
	0xffffffff)
	    L=$(read16 $ss $sp)
	    sp=$(((sp + 2) & 0xffffffff))
	    H=$(read16 $ss $sp)
	    sp=$(((sp + 2) & 0xffffffff))
	    setreg 4 $sp
	    printf -v "$__out" "0x%.4x%.4x" $H $L
	    ;;
    esac
}

# Set register value
setreg() {
    local num=$1 val=$2 mask=$3
    if [[ -z $mask ]] ; then
	mask=0xffffffff
    fi
    val=$((val & mask))
    if [[ mask -eq 0xff && $num -ge 4 ]]; then
	mask=0xFF00
	val=$((val << 8))
	num=$((num - 4))
    fi
#    printf "setreg $num %x $mask\n" $val
    X86_REGS[$num]=$(((X86_REGS[num] & ~mask) | val))
}

# Get register value
getreg() {
    local num=$1 mask=$2
    if [[ mask -eq 0xff && $num -ge 4 ]]; then
	printf "0x%x" $(((X86_REGS[num - 4] >> 8) & mask))
	return
    fi
    printf "0x%x" $((X86_REGS[num] & mask))
}

# Test JCC conditions
ccond=(ccO ccNO ccB ccNB ccZ ccNZ ccBE ccA ccS ccNS ccPE ccPO ccL ccGE ccLE ccG) 
testcond() {
    local opcode=$1
    local cc=$((opcode & 0xF))

    printf " %x OF=$OF SF=$SF ZF=$ZF AF=$AF PF=$PF CF=$CF DF=$DF IF=$IF seg=$seg\n" ${X86_REGS[14]}
    case ${ccond[$cc]} in
	ccO)   (( OF == 1 )) ;;
	ccNO)  (( OF == 0 )) ;;
	ccB)   (( CF == 1 )) ;;
	ccNB)  (( CF == 0 )) ;;
	ccZ)   (( ZF == 1 )) ;;
	ccNZ)  (( ZF == 0 )) ;;
	ccBE)  (( CF == 1 || ZF == 1 )) ;;
        ccA)   (( CF == 0 && ZF == 0 )) ;;
        ccS)   (( SF == 1 )) ;;
        ccNS)  (( SF == 0 )) ;;
        ccPE)  (( PF == 1 )) ;;
        ccPO)  (( PF == 0 )) ;;
        ccL)   (( SF != OF )) ;;
        ccGE)  (( SF == OF )) ;;
        ccLE)  (( ZF == 1 || SF != OF )) ;;
        ccG)   (( ZF == 0 && SF == OF )) ;;
    esac
}

setop() {
    local op=$1 mnem=$2 o1=$3 o2=$4 enc=$5
#    printf "seto %.2X $mnem $o1 $o2\n" $op
    X86_MNEM[$op]="$mnem"
    X86_OP1[$op]="$o1"
    X86_OP2[$op]="$o2"
    X86_ENC[$op]="$enc"
}

# special case sub opcode (opcode << 8) + subop
grpop() {
    local op=$1 sub=$2 o1=$3 o2=$4
    local m2=$((op * 256 + (sub << 3)))
    printf "new grp %.4x %x %x $o1 $o2\n" $m2 $op $sub
    X86_OP1[$m2]="$o1"
    X86_OP2[$m2]="$o2"
}

grp1=(ADD OR ADC SBB AND SUB XOR CMP)
grp2=(ROL ROR RCL RCR SHL SHR SAL SAR)
grp3=(TEST TEST NOT NEG MUL IMUL DIV IDIV)
grp4=(INC DEC)
grp5=(INC DEC CALL CALLF JMP JMPF PUSH)
for i in {0..7}; do
  base=$(( i << 3 ))
  op=${grp1[$i]}

  setop $((base+0)) $op Eb Gb MRR
  setop $((base+1)) $op Ev Gv MRR
  setop $((base+2)) $op Gb Eb MRR
  setop $((base+3)) $op Gv Ev MRR
  setop $((base+4)) $op rAL Ib
  setop $((base+5)) $op rvAX Iv

  setop $((0x40+i)) INC gv
  setop $((0x48+i)) DEC gv
  setop $((0x50+i)) PUSH gv
  setop $((0x58+i)) POP gv
  setop $((0xb0+i)) MOV gb Ib
  setop $((0xb8+i)) MOV gv Iv
  setop $((0x90+i)) XCHG gv rvAX

  setop $((0x70+i)) JCC Jb
  setop $((0x78+i)) JCC Jb
done

setop 0x06 PUSH rES
setop 0x07 POP rES
setop 0x0e PUSH rCS
setop 0x0f ----
setop 0x16 PUSH rSS
setop 0x17 POP rSS
setop 0x1E PUSH rDS
setop 0x1F POP rDS

setop 0x26 SEG rES
setop 0x27 DAA
setop 0x2e SEG rCS
setop 0x2f DAS

setop 0x36 SEG rSS
setop 0x37 AAA
setop 0x3e SEG rDS
setop 0x3f AAS

setop 0x80 GRP1 Eb Ib MRR
setop 0x81 GRP1 Ev Iv MRR
setop 0x82 GRP1 Eb Ib MRR
setop 0x83 GRP1 Ev Sb MRR
setop 0x84 TEST Gb Eb MRR
setop 0x85 TEST Gv Ev MRR
setop 0x86 XCHG Gb Eb MRR
setop 0x87 XCHG Gv Ev MRR
setop 0x88 MOV Eb Gb MRR
setop 0x89 MOV Ev Gv MRR
setop 0x8a MOV Gb Eb MRR
setop 0x8b MOV Gv Ev MRR
setop 0x8c MOV Ew Sw MRR
setop 0x8d LEA Gv Mp MRR
setop 0x8e MOV Sw Ew MRR
setop 0x8f POP Ev __ MRR

setop 0x90 NOP
setop 0x98 CBW
setop 0x99 CWD
setop 0x9a CALLF Ap
setop 0x9b WAIT
setop 0x9c PUSHF
setop 0x9d POPF
setop 0x9e SAHF
setop 0x9f LAHF

setop 0xa0 MOV rAL Ob
setop 0xa1 MOV rvAX Ov
setop 0xa2 MOV Ob rAL
setop 0xa3 MOV Ov rvAX
setop 0xa4 MOVS Yb Xb
setop 0xa5 MOVS Yv Xv
setop 0xa6 CMPS Xb Yb
setop 0xa7 CMPS Xv Yv
setop 0xa8 TEST rAL Ib
setop 0xa9 TEST rvAX Iv
setop 0xaa STOS Yb rAL
setop 0xab STOS Yv rvAX
setop 0xac LODS rAL Xb
setop 0xad LODS rvAX Xv
setop 0xae SCAS rAL Yb
setop 0xaf SCAS rvAX Yv

setop 0xc0 GRP2 Eb Ib MRR
setop 0xc1 GRP2 Ev Ib MRR
setop 0xc2 RET Iw
setop 0xc3 RET
setop 0xc4 LES Gv Mp MRR
setop 0xc5 LDS Gv Mp MRR
setop 0xc6 MOV Eb Ib MRR
setop 0xc7 MOV Ev Iv MRR
setop 0xca RETF Iw
setop 0xcb RETF
setop 0xcc INT i3
setop 0xcd INT Ib
setop 0xce INTO
setop 0xcf IRET

setop 0xd0 GRP2 Eb i1 MRR
setop 0xd1 GRP2 Ev i1 MRR
setop 0xd2 GRP2 Eb rCL MRR
setop 0xd3 GRP2 Ev rCL MRR
setop 0xd4 AAM Ib
setop 0xd5 AAD Ib
setop 0xd6 SALC
setop 0xd7 XLAT

setop 0xe0 LOOPNZ Jb
setop 0xe1 LOOPZ Jb
setop 0xe2 LOOP Jb
setop 0xe3 JCXZ Jb
setop 0xe4 IN rAL Ib
setop 0xe5 IN rvAX Ib
setop 0xe6 OUT Ib rAL
setop 0xe7 OUT Iv rvAX
setop 0xe8 CALL Jv
setop 0xe9 JMP Jv
setop 0xea JMPF Ap
setop 0xeb JMP Jb
setop 0xec IN rAL rDX
setop 0xed IN rvAX rDX
setop 0xee OUT rDX rAL
setop 0xef OUT rDX rvAX

setop 0xf0 LOCK
setop 0xf2 REP 0x1 PFX
setop 0xf3 REP 0x2 PFX
setop 0xf4 HLT
setop 0xf5 CMC
setop 0xf6 GRP3 Eb __ MRR # TEST needs Ib
grpop 0xf6 0 Eb Ib
grpop 0xf6 1 Eb Ib
setop 0xf7 GRP3 Ev __ MRR # TEST needs Iv
grpop 0xf7 0 Ev Iv
grpop 0xf7 1 Ev Iv
setop 0xf8 CLC
setop 0xf9 STC
setop 0xfa CLI
setop 0xfb STI
setop 0xfc CLD
setop 0xfd STD
setop 0xfe GRP4 Eb __ MRR # INC Eb/DEC Eb
setop 0xff GRP5 Ev __ MRR # INC Ev/DEC Ev
grpop 0xfe 3 Mp __
grpop 0xff 5 Mp __

# Create register object with current value
mkreg() {
    local __out=$1
    local num=$2 mask=$3
    reg=$(getreg $num $mask)
    printf -v "$__out" "reg $num $mask $reg"
}

parity() {
    local v1=$(($1 & 0xFF))
    v=$v1
    ((v ^= v >> 4))
    ((v ^= v >> 2))
    ((v ^= v >> 1))
    (((v & 1)))
    rc=$?
    echo "parity $v1 $rc" >> .parity
    echo $rc
}

add8() {
    local v1=$1
    local v2=$2
    # convert signed
    if [ $((v2 & 0x80)) -ne 0 ]; then
	v2=$((v2 - 256))
    fi
    echo $((v1 + v2))
}

add16() {
    local v1=$1
    local v2=$2
    echo $(((v1 + v2) & 0xFFFF))
}

# Create immediate
mkimm() {
    local __out=$1
    local v=$2
    local mask=$3

    printf -v "$__out" "imm 0x%x $mask" $v
}

# Create effective address
mkea() {
    local __out=$1
    local mrr=$2 mask=$3
    local mm=$(((mrr >> 6) & 3))
    local rrr=$((mrr & 7))
    if [[ $mm -eq 3 ]]; then
	mkreg $__out $rrr $mask
	return
    fi
    off=""
    easeg="seg 3"
    local bx=$(getreg 3 0xffff)
    local bp=$(getreg 5 0xffff)
    local si=$(getreg 6 0xffff)
    local di=$(getreg 7 0xffff)
    case $rrr in
	0) off=$(((bx+si) & 0xffff)) ;;
	1) off=$(((bx+di) & 0xffff)) ;;
	2) off=$(((bp+si) & 0xffff)) ; easeg="seg 2" ;;
	3) off=$(((bp+di) & 0xffff)) ; easeg="seg 2" ;;
	4) off=$si ;;
	5) off=$di ;;
	6) if [[ $mm -ne 0 ]] ; then
	       off=$bp
	       easeg="seg 2"
	   else
	       fetch16 off
	   fi
	   ;;
	7) off=$bx ;;
    esac
    if [ $mm -eq 1 ] ; then
	fetch8 IR
	off=$(add8 $off $IR)
    elif [ $mm -eq 2 ] ; then
	fetch16 IR
	off=$(add16 $off $IR)
    fi
    
    # Segment override
    if [ ! -z "$seg" ]; then
	easeg="$seg"
    fi
    case $easeg in
	"seg 0") val=$(getreg 16 0xffff) ;;
	"seg 1") val=$(getreg 17 0xffff) ;;
	"seg 2") val=$(getreg 18 0xffff) ;;
	"seg 3") val=$(getreg 19 0xffff) ;;
	*) echo "no seg" ; exit 0 ;;
    esac
    printf -v "$__out" "mem $val 0x%x $mask $mm $rrr" $off
}

strop() {
    local __out=$1
    local vs=$2 vo=$3 mask=$4

    # if no overriding seg, default to DS
    if [[ -z $vs ]] ; then
	vs="seg 3"
    fi
    case $vs in
	"seg 0") val=$(getreg 16 0xffff) ;;
	"seg 1") val=$(getreg 17 0xffff) ;;
	"seg 2") val=$(getreg 18 0xffff) ;;
	"seg 3") val=$(getreg 19 0xffff) ;;
	*) echo "no seg" ; exit 0 ;;
    esac

    # Get Index
    local voff=$(getreg $vo 0xffff)

    # Calculate delta
    delta=1
    [ $mask == 0xffff ] && delta=2
    [ $DF != 0 ] && delta=$((-delta))

    # inc/dec index
    setreg $vo $((voff + delta)) 0xffff

    # Memory address
    printf -v "$__out" "mem 0x%.4x 0x%.4x 0x%.4x" $val $voff $mask
}    

# decode opcode args
# opmrr is original opcode << 8 + MRR byte (or 00)
decarg() {
    local __out=$1
    local opmrr=$2 oparg=$3 mask=$4
    local ggg=$(((opmrr >> 3) & 7))
    local opg=$(((opmrr >> 8) & 7))

    # set mask on Gb/Eb etc to 0xff
    [[ $oparg == ?b* ]] && mask=0xff
    case $oparg in
	rES) printf -v "$__out" "seg 0" ;;
	rCS) printf -v "$__out" "seg 1" ;;
	rSS) printf -v "$__out" "seg 2" ;;
	rDS) printf -v "$__out" "seg 3" ;;
	Sw)  printf -v "$__out" "seg ${ggg}" ;;
	Xb | Xv) strop $__out "$seg" 6 $mask ;;  # <DS>:SI
	Yb | Yv) strop $__out "seg 0" 7 $mask ;; # ES:DI
	Gb | Gv) mkreg $__out ${ggg} $mask ;;
	gb | gv) mkreg $__out $opg $mask ;;
	Eb | Ew | Ev | Mp)  mkea $__out $opmrr $mask ;;
	Ob | Ov) mkea $__out 0x6 $mask ;;
	Jb)
	    fetch8 IR
	    local addr=$(add8 ${X86_REGS[15]} $IR)
	    printf -v "$__out" "imm $addr 0xff"
	    ;;
	Jv)
	    fetchv IR
	    printf -v "$__out" "imm 0x%x 0xffff" $((X86_REGS[15] + $IR))
	    ;;
	rCL) mkreg $__out 1 0xff ;;
	rAL) mkreg $__out 0 0xff ;;
	rvAX) mkreg $__out 0 $mask ;;
	rDX) mkreg $__out 2 0xffff ;;
	i1) mkimm $__out 1 $mask ;;
	i3) mkimm $__out 3 $mask ;;
	Ib) fetch8 IR ; mkimm $__out $IR $mask ;;
	Iv) fetchv ; mkimm $__out $IR $mask ;;
	Sb)
	    fetch8 IR
	    if [ $((IR & 0x80)) != 0 ]; then
		IR=$((IR | 0xFF00))
	    fi
	    mkimm $__out $IR 0xffff
	    ;;
	Ap)
	    fetch16 IS
	    fetch16 IR
	    printf -v "$__out" "imm 0x%.4x%.4x 0xffff" $IR $IS
	    ;;
	*) printf -v "$__out" "$oparg" ;;
    esac
}

# get exec size
execsz() {
    local oparg=($1)
    case ${oparg[0]} in
	reg)
	    echo "${oparg[2]}"
	    ;;
	mem)
	    echo "${oparg[3]}"
	    ;;
	*)
	    echo 0
    esac
}

# get arg value
execval() {
    local oparg=($1)
    case ${oparg[0]} in
	reg)
	    # reg num mask val
	    echo "${oparg[3]}"
	    ;;
	imm)
	    echo "${oparg[1]}"
	    ;;
	mem)
	    # mem seg off mask mm rrr
	    local off=${oparg[2]}
	    local base=${oparg[1]}
	    local am=${oparg[3]}
	    if [[ $am -eq 0xffff ]] ; then
		read16 $base $off
	    else
		read8 $base $off
	    fi
	    ;;
	seg)
	    # seg n (0=es, 1=cs, 2=ss, 3=ds)
	    local n=$(((oparg[1] & 0x3) + 16))
	    getreg $n 0xffff
	    ;;
	*)
	    echo 0x0
	    ;;
    esac
}

# set result value
execset() {
    local oparg=($1)
    local val=$2

    printf "set:[${oparg[*]}] $val\n"
    case ${oparg[0]} in
	reg)
	    setreg ${oparg[1]} $val ${oparg[2]}
	    ;;
	mem)
	    local off=${oparg[2]}
	    local base=${oparg[1]}
	    local am=${oparg[3]}
	    if [[ $am -eq 0xffff ]] ; then
		write16 $base $off $val
	    else
		write8 $base $off $val
	    fi
	    ;;
	seg)
	    local n=$(((oparg[1] & 3) + 16))
	    setreg $n $val 0xffff
	    ;;
    esac
}

# Run alu op
aluop() {
    local opfn=$1
    local s1="$2" s2="$3"
    local v1="$(execval "$s1")"
    local v2="$(execval "$s2")"
    local dest=$s1

    local ncf=0
    res="0xdeadbeef"
    printf "alu: $opfn %.4x %.4x\n" $v1 $v2
    case $opfn in
	SUB) res=$((v1 - v2)) ; ncf=2 ;;
	ADD) res=$((v1 + v2)) ; ncf=1 ;;
	ADC) res=$((v1 + v2 + CF)) ; ncf=1 ;;
	SBB) res=$((v1 - v2 - CF)) ; ncf=2 ;;
	INC) res=$((v1 + 1)) ; v2=1 ; ncf=3 ;;
	DEC) res=$((v1 - 1)) ; v1=1 ; ncf=4 ;;
	NEG) res=$((0 - v1)) ;;
	NOT) res=$((~v2)) ;;
	AND) res=$((v1 & v2)) ;;
	XOR) res=$((v1 ^ v2)) ;;
	OR)  res=$((v1 | v2)) ;;
	TEST) dest="" ; res=$((v1 & v2)) ;;
	CMP)  dest="" ; res=$((v1 - v2)) ; ncf=2 ;;
	SHL|SAL) res=$((v1 << v2)) ;;
	SHR) res=$((v1 >> v2)) ;;
    esac

    smask=$(execsz "$s1")
    res=$((res & smask))
    sgn=$(printf "0x%x" $((smask - (smask >> 1))))
    printf "result is:[$dest] [%d:%.4x] [%.4x] %.4x\n" $res $res $mask $sgn
    ZF=$((res == 0))
    SF=$(((res & sgn) != 0))
    PF=$(parity $res)
    case $ncf in
	1)
	    OF=$((((v1 ^ res) & (v2 ^ res) & sgn) != 0))
	    CF=$(((((v1 & v2) | (v1 & ~res) | (v2 & ~res)) & sgn) != 0))
	    ;;
	2)
	    OF=$((((v1 ^ v2) & (v1 ^ res) & sgn) != 0))
	    CF=$(((((~v1 & v2) | ((~v1 | v2) & res)) & sgn) != 0))
	    ;;
	3)
	    # inc only sets OF
	    OF=$((((v1 ^ res) & (v2 ^ res) & sgn) != 0))
	    ;;
	4)
	    # dec only sets OF
	    OF=$((((v1 ^ v2) & (v1 ^ res) & sgn) != 0))
	    ;;
	0)
	    OF=0
	    CF=0
	    ;;
    esac
    execset "$dest" "$res"
}

# Execute an opcode
execop() {
    local opcode=$1 opfn=$2 s1="$3" eval s2="$4"
    flags=""
    
    if [[ $opfn == JCC ]] ; then
	subop=$(((opcode >> 8) & 0xF))
	cc=${ccond[$subop]:2}
	printf "jcc: $cc\n"
    else
	printf "opfn: $opfn\n"
    fi
    case $opfn in
	MOVS | LODS | STOS)
	    local v1="$(execval "$s2")"
	    execset "$s1" "$v1"
	    if [[ $rep != 0 ]] ; then
		local cx=$(getreg 1 $osize)
		local pc=$(getreg 15 $osize)
		if [[ $cx -ne 0 ]]; then
		    cx=$(((cx - 1) & $osize))
		    setreg 1 $cx $osize
		    if [[ $cx -ne 0 ]] ; then
		    	# decrease CX,PC and set prefix
			setreg 15 $((pc - 1)) $osize
			pfx=1
		    fi
		fi
	    fi
	    ;;
	MOV)
	    execset "$s1" "$(execval "$s2")"
	    ;;
	ADD|OR|ADC|SBB|AND|SUB|XOR|CMP|\
	    ROL|ROR|RCL|RCR|SHL|SHR|SAL|SAR|\
	    TEST|INC|DEC|NEG|NOT)
	    aluop $opfn "$s1" "$s2"
	    ;;
	CLI) IF=0 ;;
	STI) IF=1 ;;
	CLD) DF=0 ;;
	STD) DF=1 ;;
	CLC) CF=0 ;;
	STC) CF=1 ;;
	CMC) CF=$((1-CF)) ;;
	RET)
	    arg="$(execval "$s1")"
	    local sp=$(getreg 4 $osize)
	    setreg 4 $((sp + arg)) $osize
	    popv v1
	    setreg 15 $v1 $osize
	    ;;
	RETF)
	    arg="$(execval "$s1")"
	    local sp=$(getreg 4 $osize)
	    setreg 4 $((sp + arg)) $osize
	    popv co
	    popv cs
	    setreg 15 co $osize
	    setreg 17 cs 0xffff
	    ;;
	CALL)
	    arg="$(execval "$s1")"
	    pushv $(getreg 15 0xffff) 0xffff
	    setreg 15 $arg 0xffff
	    ;;
	CALLF)
	    local arg="$(execval "$s1")"
	    local cseg=$((arg >> 16))
	    local coff=$((arg & 0xFFFF))
	    if [[ "$s1" == "mem"* ]] ; then
		local oparg=($s1)
		local pseg=${oparg[1]}
		local pofs=${oparg[2]}
		coff=$(read16 $pseg $pofs)
		cseg=$(read16 $pseg $((pofs + 2)))
	    fi
	    pushv $(getreg 17 0xffff) 0xffff # push cs
	    pushv $(getreg 15 0xffff) 0xffff # push ip
	    setreg 17 $cseg 0xffff
	    setreg 15 $coff 0xffff
	    ;;
	JMP)
	    arg="$(execval "$s1")"
	    setreg 15 $arg 0xffff
	    ;;
	JMPF)
	    arg="$(execval "$s1")"
	    local cseg=$((arg >> 16))
	    local coff=$((arg & 0xFFFF))
	    if [[ "$s1" == "mem"* ]] ; then
		local oparg=($s1)
		local pseg=${oparg[1]}
		local pofs=${oparg[2]}
		coff=$(read16 $pseg $pofs)
		cseg=$(read16 $pseg $((pofs + 2)))
	    fi
	    setreg 17 $cseg 0xffff
	    setreg 15 $coff 0xffff
	    ;;
	JCC)
	    testcond $((opcode >> 8))
	    rc=$?
	    if [ $rc = 0 ]; then
		local arg="$(execval "$s1")"
		echo "dojump $arg $s1"
		setreg 15 $arg 0xffff
	    fi
	    ;;
	LDS | LES)
	    local oparg=($s2)
	    local pseg=${oparg[1]}
	    local pofs=${oparg[2]}
	    coff=$(read16 $pseg $pofs)
	    cseg=$(read16 $pseg $((pofs + 2)))
	    echo "read pointer $cseg $coff"
	    case $opfn in
		LDS)
		    setreg 19 $cseg 0xffff
		    ;;
		LES)
		    setreg 16 $cseg 0xffff
		    ;;
	    esac
	    execset "$s1" $coff
	    ;;
	LOOP | LOOPZ | LOOPNZ | JCXZ)
	    local v1=$(execval "$s1")
	    local cx=$(getreg 1 $osize)
	    local pc=$(getreg 15 $osize)
	    case $opfn in
		LOOP)
		    cx=$(((cx - 1) & $osize))
		    setreg 1 $cx $osize
		    if [[ $cx -ne 0 ]] ; then
			# do jump
			echo loop
			pc=$v1
		    fi
		    ;;
		LOOPZ)
		    cx=$(((cx - 1) & $osize))
		    setreg 1 $cx $osize
		    if [[ $cx -ne 0 && ZF -eq 1 ]] ; then
			echo loop
			pc=$v1
		    fi
		    ;;
		LOOPNZ)
		    cx=$(((cx - 1) & $osize))
		    setreg 1 $cx $osize
		    if [[ $cx -ne 0 && ZF -eq 0 ]] ; then
			echo loop
			pc=$v1
		    fi
		    ;;
		JCXZ)
		    if [[ $cx -eq 0 ]]; then
			pc=$v1
		    fi
		    ;;
	    esac
	    setreg 15 $pc 0xffff
	    ;;
	XCHG)
	    local v1=$(execval "$s1")
	    local v2=$(execval "$s2")
	    execset "$s1" "$v2"
	    execset "$s2" "$v1"
	    ;;
	SEG)
	    # segment override prefix
	    pfx=1
	    echo "seg pfx $s1"
	    seg="$s1"
	    ;;
	REP)
	    pfx=1
	    echo "rep pfx $1"
	    rep="$s1"
	    ;;
	CBW)
	    ax=${X86_REGS[0]}
	    case $osize in
		0xffff)
		    # cbw
		    ax=$((ax & 0xFF))
		    if [[ $((ax & 0x80)) != 0 ]]; then
			ax=$((ax | 0xFF00))
		    fi
		    ;;
		0xffffffff)
		    # cwde
		    ax=$((ax & 0xFFFF))
		    if [[ $((ax & 0x8000)) != 0 ]]; then
			ax=$((ax | 0xFFFF0000))
		    fi
		    ;;
	    esac
	    setreg 0 $ax $osize
	    ;;
	CWD)
	    # convert signed AX/EAX/RAX to DX/EDX/RDX
	    ax=$(getreg 0 $osize)
	    sgn=$(printf "0x%x" $((osize - (osize >> 1))))
	    if [ $(($ax & $sgn)) != 0 ]; then
		# if AX is signed, then set DX=-1
		setreg 2 0xffffffff $osize
	    else
		setreg 2 0 $osize
	    fi
	    ;;
	PUSH)
	    local v1="$(execval "$s1")"
	    pushv $v1 $osize
	    ;;
	POP)
	    popv v1 
	    printf "popping.... $v1\n"
	    execset "$s1" $v1
	    ;;
	IN)
	    # hack return set bits
	    execset "$s1" 0xffffffff
	    ;;
	LEA)
	    # s1 = Gv
	    # s2 = Mp [mem seg off mask mm rrr]
	    local lea=($s2)
	    execset "$s1" ${lea[2]}
	    ;;
	AAA)
	    local AX=$(getreg 0 0xffff)
	    if (( $((AX & 0xF)) > 9 || AF==1 )); then
		AX=$((AX + 0x106))
		AF=1
		CF=1
	    else
		AF=0
		CF=0
	    fi
	    setreg 0 $((AX & 0xFF0F)) 0xffff
	    ;;
	AAS)
	    local AX=$(getreg 0 0xffff)
	    if (( $((AX & 0xF)) > 9 || AF==1 )); then
		AX=$((AX - 0x106))
		AF=1
		CF=1
	    else
		AF=0
		CF=0
	    fi
	    setreg 0 $((AX & 0xFF0F)) 0xffff
	    ;;
	AAM)
	    local v1=$(getreg 0 0xff)
	    local v2="$(execval "$s1")"
	    local res=$((v1 % v2))
	    setreg 4 $((v1 / v2)) 0xff
	    setreg 0 $res 0xff

	    local sgn=0x80
	    ZF=$((res == 0))
	    SF=$(((res & sgn) != 0))
	    PF=$(parity $res)
#	    OF=$((((v1 ^ res) & (v2 ^ res) & sgn) != 0))
#	    CF=$(((((v1 & v2) | (v1 & ~res) | (v2 & ~res)) & sgn) != 0))
	    ;;
	AAD)
	    local v1=$(getreg 0 0xff)
	    local v2=$(getreg 4 0xff)
	    local v3="$(execval "$s1")"
	    setreg 4 0 0xff
	    setreg 0 $((v1 + (v2 * v3))) 0xff
	    ;;
	DAA)
	    local AL=$(getreg 0 0xff)
	    echo "AL:$AL CF:$CF AF:$AF"
	    ;;
	DAS)
	    local AL=$(getreg 0 0xff)
	    echo "AL:$AL CF:$CF AF:$AF"
	    ;;
	NOP | WAIT | LOCK | REP) ;;
	*) printf " noval\n" ; return ;;
    esac
    printf " %x OF=$OF SF=$SF ZF=$ZF AF=$AF PF=$PF CF=$CF DF=$DF IF=$IF seg=$seg\n" ${X86_REGS[14]}

}

# decode and exec opcode
decode() {
    opcode=$1
    local opfn=${X86_MNEM[$opcode]}
    local opmrr=$((opcode * 256))
    local op1="${X86_OP1[$opcode]}"
    local op2="${X86_OP2[$opcode]}"

    printf "==== %.2x $opfn $op1 $op2 %x\n" $opcode $opmrr
    # create opcode << 8 + mrr byte
    if [[ ${X86_ENC[$opcode]} == MRR ]] ; then
	fetch8 IR
	opmrr=$((opmrr + $IR))
    fi
    # get ggg from MRR for decoding op group
    if [[ $opfn == GRP* ]]; then
	subop=$(((opmrr >> 3) & 7))
	case $opfn in
	    GRP1) opfn=${grp1[$subop]} ;;
	    GRP2) opfn=${grp2[$subop]} ;;
	    GRP3) opfn=${grp3[$subop]} ;;
	    GRP4) opfn=${grp4[$subop]} ;;
	    GRP5) opfn=${grp5[$subop]} ;;
	esac
	# Handle group difference oparg
	local submrr=$((opmrr & 0xFF38))
	printf "new sub: <${X86_OP1[$submrr]}> <${X86_OP2[$submrr]}> %x\n" $submrr
	if [ -n "${X86_OP1[$submrr]}" ] ; then
	    op1="${X86_OP1[$submrr]}"
	    echo "new op1" $op1
	fi
	if [ -n "${X86_OP2[$submrr]}" ] ; then
	    op2="${X86_OP2[$submrr]}"
	    echo "new op1" $op2
	fi
    fi
    decarg m1 $opmrr $op1 $osize
    decarg m2 $opmrr $op2 $osize
    printf "[$m1] [$m2]\n"
    execop $opmrr $opfn "$m1" "$m2"
    if [ -z $opfn ]; then
	echo "--- missing"
    fi
}


