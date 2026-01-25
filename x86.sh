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

lock=0
verbose=0
cpu_type=8088
addr_mask=0xfffff

showregs() {
    for i in `seq 0 20`; do
	printf "%.2d %.8x\n" $i ${X86_REGS[i]}
    done
}

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
TF=0

getflags() {
    N=${X86_REGS[14]}
    CF=$(((N >> 0) & 1))   # 001
    PF=$(((N >> 2) & 1))   # 004
    AF=$(((N >> 4) & 1))   # 010
    ZF=$(((N >> 6) & 1))   # 040
    SF=$(((N >> 7) & 1))   # 080
    TF=$(((N >> 8) & 1))   # 100
    IF=$(((N >> 9) & 1))   # 200
    DF=$(((N >> 10) & 1))  # 400
    OF=$(((N >> 11) & 1))  # 800
}

setflags() {
    N=0x0FD5
    nf=$((
	    0xf000 |
	    (OF<<11) |
		(DF<<10) |
		(IF<<9)  |
		(TF<<8)  |
		(SF<<7)  |
		(ZF<<6)  |
		(AF<<4)  |
		(PF<<2)  |
	   (1<<1) |
	   CF
	))
    X86_REGS[14]=$(((X86_REGS[14] & ~N) | nf))
}

# fetch byte from PC
fetch8() {
    local __out=$1
    local pc=${X86_REGS[15]}
    local cs=${X86_REGS[17]}
    local addr=$(((cs * 16 + pc) & $addr_mask))
    printf "fetch %d %x\n" $addr $addr
    local v=${X86_MEM[$addr]}
    X86_REGS[15]=$(((pc+1) & 0xffff))
    printf -v "$__out" "0x%.2x" $v
}

# fetch word from PC
fetch16() {
    local __out=$1
    fetch8 FLO
    fetch8 FHI
    printf -v "$__out" "0x%.2x%.2x" $FHI $FLO
}

# fetchv
fetchv() {
    local LO=0 HI=0
    case $osize in
	0xffff)
	    fetch16 IR
	    ;;
	0xffffffff)
	    fetch16 D0
	    fetch16 D1
	    printf -v IR "0x%.4x%.4x" $D1 $D0
	    ;;
	0xffffffffffffffff)
	    fetch16 D0
	    fetch16 D1
	    fetch16 D2
	    fetch16 D3
	    printf -v IR "0x%.4x%.4x%.4x%.4x" $D3 $D2 $D1 $D0
	    ;;
	esac
}

# read8 seg off
read8() {
    local off=$2
    local base=$(($1 * 16))
    local addr=$(((base + (off + 0 & 0xffff)) & $addr_mask))
    local v=${X86_MEM[$addr]}
    printf "0x%x" $v
}

# write8 seg off val
write8() {
    local off=$2
    local base=$(($1 * 16))
    local addr=$(((base + (off + 0 & 0xffff)) & $addr_mask))
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
    printf -v "$co" "0x%x" $(read16 $pseg $pofs)
    printf -v "$cs" "0x%x" $(read16 $pseg $((pofs + 2)))
}

# push value to stack (dec->write)
pushv() {
    local val=$1
    local mask=$2
    local issp=$3
    local sp=${X86_REGS[4]}
    local ss=${X86_REGS[18]}
    case $mask in
	0xffff)
	    sp=$(((sp - 2) & 0xffff))
	    setreg 4 $sp 0xffff
	    if [ -n "$issp" ]; then
		write16 $ss $sp $sp
	    else
		write16 $ss $sp $val
	    fi
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
    printf "setreg $num %x $mask\n" $val
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

vector() {
    local vector=$1
    local ncs=$(read16 0x0 $((vector * 4 + 2)))
    local npc=$(read16 0x0 $((vector * 4 + 0)))

    setflags
    printf "int 0x%x 0x%x\n" $ncs $npc
    pushv $(getreg 14 0xffff) 0xffff # flags
    pushv $(getreg 17 0xffff) 0xffff # cs
    pushv $(getreg 15 0xffff) 0xffff # ip

    setreg 17 $ncs 0xffff
    setreg 15 $npc $osize
}

# Undefined opcode fault
UD2() {
    local ncs=$(read16 0x0 0x1a)
    local npc=$(read16 0x0 0x18)

    setflags
    printf "ud2 0x%x 0x%x 0x%x\n" $ncs $npc $lock
    pushv $(getreg 14 0xffff) 0xffff # flags
    pushv $(getreg 17 0xffff) 0xffff # cs
    pushv $lock 0xffff # ip

    setreg 17 $ncs 0xffff
    setreg 15 $npc $osize
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
    if [ $verbose ] ; then
	printf "seto %.2X $mnem $o1 $o2\n" $op
    fi
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
setop 0xf2 REP repnz # repnz
setop 0xf3 REP repz  # repz
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

add386() {
    addr_mask=0xffffff
    setop 0x64 SEG rFS
    setop 0x65 SEG rGS
    setop 0x66 OSZ
    setop 0x67 ASZ
    setop 0xC8 ENTER Iw Ib
    setop 0xC9 LEAVE
    setop 0xFA0 PUSH rFS
    setop 0xFA1 POP rFS
    setop 0xFA8 PUSH rGS
    setop 0xFA9 POP rGS
    setop 0xFB3 LSS Gv Mp
    setop 0xFB5 LFS Gv Mp
    setop 0xFB6 LGE Gv Mp
    for i in {0..7} ; do
	setop $((0xF80+i)) JCC Jv
	setop $((0xF88+i)) JCC Jv
	setop $((0xF98+i)) SETCC Eb __ MRR
    done
}

# Get segment base
getseg() {
    local __out=$1
    local vseg=$2
    local oseg=$3
    local lbl=$4
    if [ -n "$oseg" ] ; then
	vseg=$oseg
    fi
    case $vseg in
	"seg 0") val=$(getreg 16 0xffff) ;;
	"seg 1") val=$(getreg 17 0xffff) ;;
	"seg 2") val=$(getreg 18 0xffff) ;;
	"seg 3") val=$(getreg 19 0xffff) ;;
	"seg 4") val=$(getreg 20 0xffff) ;;
	"seg 5") val=$(getreg 21 0xffff) ;;
	*) echo "no seg $vseg $lbl" ; exit 0 ;;
    esac
    printf -v "$__out" "0x%x" $val
}

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
    getseg val "$easeg" "$seg" "ea"
    printf -v "$__out" "mem $val 0x%x $mask $mm $rrr" $off
}

# String operations. ES:DI, DS:SI
# strop var seg index mask
strop() {
    local __out=$1 vs=$2 vo=$3 mask=$4

    # if no overriding seg, default to DS
    if [[ -z $vs ]] ; then
	vs="seg 3"
    fi
    getseg val "$vs" "" "strop"

    # Get Index
    local voff=$(getreg $vo 0xffff)

    # Calculate delta
    delta=1
    [ $mask == 0xffff ] && delta=2
    [ $mask == 0xffffffff ] && delta=4

    # Check DF flag
    [ $DF != 0 ] && delta=$((-delta))

    # inc/dec index
    setreg $vo $((voff + delta)) $opsize

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
	rFS) printf -v "$__out" "seg 4" ;;
	rGS) printf -v "$__out" "seg 5" ;;
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
	    fetchv
	    printf -v "$__out" "imm 0x%x 0xffff" $((X86_REGS[15] + $IR))
	    ;;
	rCL) mkreg $__out 1 0xff ;;
	rAL) mkreg $__out 0 0xff ;;
	rvAX) mkreg $__out 0 $mask ;;
	rDX) mkreg $__out 2 0xffff ;;
	i1) mkimm $__out 1 $mask ;;
	i3) mkimm $__out 3 $mask ;;
	Ib) fetch8 IR ; mkimm $__out $IR $mask ;;
	Iw) fetch16 IR; mkimm $__out $IR $mask ;;
	Iv) fetchv ; mkimm $__out $IR $mask ;;
	Sb)
	    # signed byte
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
	    if [[ $am -eq 0xff ]] ; then
		read8 $base $off
	    elif [[ $am -eq 0xffff ]] ; then
		read16 $base $off
	    elif [[ $am -eq 0xffffffff ]] ; then
		ED0=$(read16 $base $((off + 0)))
		ED1=$(read16 $base $((off + 2)))
		printf "0x%.4x%.4x" $ED1 $ED0
	    elif [[ $am -eq 0xffffffffffffffff ]] ; then
		ED0=$(read16 $base $((off + 0)))
		ED1=$(read16 $base $((off + 2)))
		ED2=$(read16 $base $((off + 4)))
		ED3=$(read16 $base $((off + 6)))
		printf "0x%.4x%.4x%.4x%.4x" $ED3 $ED2 $ED1 $ED0
	    fi
	    ;;
	seg)
	    # seg n (0=es, 1=cs, 2=ss, 3=ds)
	    case $cpu_type in
		80386)
		    local n=$((oparg[1] + 16))
		    getreg $n 0xffff
		    ;;
		*)
		    local n=$(((oparg[1] & 0x3) + 16))
		    getreg $n 0xffff
		    ;;
	    esac
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
	    if [[ $am -eq 0xff ]] ; then
		write8 $base $off $val
	    elif [[ $am -eq 0xffff ]] ; then
		write16 $base $off $val
	    elif [[ $am -eq 0xffffffff ]] ; then
		write16 $base $((off + 0)) $((val & 0xFFFF))
		write16 $base $((off + 2)) $(((val >> 16) & 0xFFFF))
	    elif [[ $am -eq 0xffffffffffffffff ]] ; then
		write16 $base $((off + 0)) $((val & 0xFFFF))
		write16 $base $((off + 2)) $(((val >> 16) & 0xFFFF))
		write16 $base $((off + 4)) $(((val >> 32) & 0xFFFF))
		write16 $base $((off + 6)) $(((val >> 48) & 0xFFFF))
	    fi
	    ;;
	seg)
	    case cpu_type in
		80386)
		    local n=$((oparg[1] + 16))
		    setreg $n $val 0xffff
		    ;;
		*)
		    local n=$(((oparg[1] & 3) + 16))
		    setreg $n $val 0xffff
		    ;;
	    esac
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
    smask=$(execsz "$s1")
    case $opfn in
	SUB) res=$((v1 - v2)) ; ncf=2 ;;
	ADD) res=$((v1 + v2)) ; ncf=1 ;;
	ADC) res=$((v1 + v2 + CF)) ; ncf=1 ;;
	SBB) res=$((v1 - v2 - CF)) ; ncf=2 ;;
	INC) res=$((v1 + 1)) ; v2=1 ; ncf=3 ;;
	DEC) res=$((v1 - 1)) ; v2=1 ; ncf=4 ;;
	NEG) res=$((0 - v1)) v2=$v1 ; v1=0; ncf=2 ;;
	NOT) res=$((~v1)) ;;
	AND) res=$((v1 & v2)) ;;
	XOR) res=$((v1 ^ v2)) ;;
	OR)  res=$((v1 | v2)) ;;
	TEST) dest="" ; res=$((v1 & v2)) ;;
	CMP)  dest="" ; res=$((v1 - v2)) ; ncf=2 ;;
	SHL|SAL) res=$((v1 << v2)) ;;
	SHR) res=$((v1 >> v2)) ;;
    esac

    if [[ $smask -eq 0xffffffffffffffff ]] ; then
	sgn=0x8000000000000000
    else
	sgn=$(printf "0x%x" $((smask - (smask >> 1))))
    fi
    res=$((res & smask))

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

signex() {
    local out=$1 v=$2 mask=$3 sgn=$4
    if [[ $(((v & sgn))) != 0 ]]; then
	v=$((v | ~mask))
    fi
    printf -v "$out" "0x%x" $v
}

# Execute an opcode
execop() {
    local opmrr=$1 opfn=$2 s1="$3" eval s2="$4"
    flags=""
    
    if [[ $opfn == JCC ]] ; then
	subop=$(((opmrr >> 8) & 0xF))
	cc=${ccond[$subop]:2}
	printf "jcc: $cc\n"
    else
	printf "opfn: $opfn\n"
    fi
    # Check LOCK
    if [[ -n "$lock" ]] ; then
	case $opfn in
	    SEG)
		;;
	    BT | BTS | BTR | BTC | ADD | OR | ADC | SBB | AND | SUB | XOR | NOT | NEG | INC | DEC)
		if [[ $s1 == "mem "* ]]; then
		    echo "IS MEM"
		else
		    echo "NOT MEM"
		    UD2
		fi
		;;
	    *)
		UD2
		return
		;;
	esac
    fi
    
    case $opfn in
	MOVS | LODS | STOS)
	    local v1="$(execval "$s2")"
	    printf "osize=$osize $v1\n"
	    execset "$s1" "$v1"
	    if [[ -n "$rep" ]] ; then
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
	CMPS | SCAS)
	    aluop CMP "$s1" "$s2"
	    echo "strop:CMPS $rep $ZF"
	    if [[ -n "$rep" ]]; then
		local cx=$(getreg 1 $osize)
		local pc=$(getreg 15 $osize)
		echo "inrep $rep"
		if [[ $cx -ne 0 ]]; then
		    cx=$(((cx - 1) & $osize))
		    setreg 1 $cx $osize
		    pfx=1
		    [[ $cx -eq 0 ]] && pfx=0
		    [[ "$rep" == "repz" && ZF -eq 0 ]] && pfx=0
		    [[ "$rep" == "repnz" && ZF -eq 1 ]] && pfx=0
		    if [[ $pfx -ne 0 ]] ; then
			setreg 15 $((pc - 1)) $osize
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
	MUL | IMUL)
	    opgrp=$((opmrr & 0xFF00))
	    local v2="$(execval "$s1")"
	    if [[ $opgrp -eq 0xF600 ]]; then
		# AX = AL * eb
		v1=$(getreg 0 0xff)
		if [[ $opfn == IMUL ]]; then
		    signex v1 $v1 0xff 0x80
		    signex v2 $v2 0xff 0x80
		fi
		res=$((v1 * v2))
		printf "mul %x %x %x\n" $v1 $v2 $res
		setreg 0 $res 0xffff
		SF=$(((res & 0x8000) != 0))
		CF=$(((res & 0xFF00) != 0))
		OF=$CF
	    fi
	    if [[ $opgrp -eq 0xF700 ]]; then
		# DX:AX = AX * Ev
		v1=$(getreg 0 $osize)
		if [[ $opfn == IMUL ]]; then
		    signex v1 $v1 0xffff 0x8000
		    signex v2 $v2 0xffff 0x8000
		fi
		res=$((v1 * v2))
		printf "mul %x %x %x\n" $v1 $v2 $res
		setreg 0 $res 0xffff
		setreg 2 $((res >> 16)) 0xffff
		SF=$(((res & 0x80000000) != 0))
		CF=$(((res & 0xFFFF0000) != 0))
		OF=$CF
	    fi
	    ZF=$((res == 0))
	    PF=$(parity $res)
	    ;;
	DIV)
	    opgrp=$((opmrr & 0xFF00))
	    local v2="$(execval "$s1")"
	    if [[ $opgrp -eq 0xF600 ]]; then
		# AH = AX % Eb
		# AL = AX / Eb
		local ax=$(getreg 0 0xffff)
		local res=$((ax / v2))
		setreg 4 $((ax % v2)) 0xff
		setreg 0 $res 0xff
		echo "div"
	    fi
	    if [[ $opgrp -eq 0xF700 ]]; then
		# DX = DX:AX % Ev
		# AX = DX:AX / Ev
		local ax=$(getreg 0 0xffff)
		local dx=$(getreg 2 0xffff)
		local dax=$(((dx << 16) + ax))
		local res=$((dax / v2))
		setreg 2 $((dax % v2)) 0xffff
		setreg 0 $res 0xffff
	    fi
	    if [[ $opfn == AAM ]] ; then
		# AH = AL / Ib
		# AL = AL % Ib
		local ax=$(getreg 0 0xff)
		local res=$((ax / v2))
		setreg 0 $((ax % v2)) 0xff
		setreg 4 $res 0xff
	    fi
	    ;;
	    
	CLI) IF=0 ;;
	STI) IF=1 ;;
	CLD) DF=0 ;;
	STD) DF=1 ;;
	CLC) CF=0 ;;
	STC) CF=1 ;;
	CMC) CF=$((1-CF)) ;;
	RET)
	    popv v1
	    setreg 15 $v1 $osize
	    v1="$(execval "$s1")"
	    if [[ $v1 -ne 0 ]]; then
		local sp=$(getreg 4 $osize)
		setreg 4 $((sp + v1)) $osize
	    fi
	    ;;
	RETF)
	    popv co
	    popv cs
	    setreg 15 co $osize
	    setreg 17 cs 0xffff
	    v1="$(execval "$s1")"
	    if [[ $v1 -ne 0 ]]; then
		local sp=$(getreg 4 $osize)
		setreg 4 $((sp + v1)) $osize
	    fi
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
	    if [[ "$s1" == "mem "* ]] ; then
		loadptr cseg coff "$s1"
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
	    if [[ "$s1" == "mem "* ]] ; then
		loadptr cseg coff "$s1"
	    fi
	    setreg 17 $cseg 0xffff
	    setreg 15 $coff 0xffff
	    ;;
	JCC)
	    testcond $((opmrr >> 8))
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
	OSZ)
	    # operand size prefix
	    pfx=1
	    osize=0xffffffff
	    echo "osize $osize"
	    ;;
	ASZ)
	    # address size prefix
	    pfx=1
	    asize=0xffffffff
	    echo "asize $asize"
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
	LOCK)
	    printf "lock pc: %x\n" $(getreg 15 0xffff)
	    pfx=1
	    lock=$((X86_REGS[15]-1))
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
	    if [[ $s1 == "reg 4 "* ]];then
		# push SP special case
		pushv $v1 $osize "1"
	    else
		pushv $v1 $osize
	    fi
	    ;;
	POP)
	    popv v1 
	    printf "popping.... $v1\n"
	    execset "$s1" $v1
	    ;;
	LAHF)
	    local ah=$(((SF << 7) | (ZF << 6) | (AF << 4) | (PF << 2) | 0x2 | CF))
	    setreg 4 $ah 0xff
	    ;;
	PUSHF)
	    setflags
	    pushv ${X86_REGS[14]} $osize
	    ;;
	POPF)
	    popv v1
	    printf "set flags %x\n" $v1
	    setreg 14 $v1 0xfd5
	    getflags
	    ;;
	SAHF)
	    local ah=$(getreg 4 0xff)
	    CF=$(((ah & 0x1) != 0))
	    PF=$(((ah & 0x4) != 0))
	    AF=$(((ah & 0x10) != 0))
	    ZF=$(((ah & 0x40) != 0))
	    SF=$(((ah & 0x80) != 0))
	    ;;
	INT)
	    local v1="$(execval "$s1")"
	    vector $v1
	    ;;
	INTO)
	    [[ OF ]] && vector 0x4
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
	    ;;
	AAS)
	    ;;
	AAM)
	    ;;
	AAD)
	    ;;
	DAA)
	    ;;
	DAS)
	    ;;
	NOP | WAIT) ;;
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
