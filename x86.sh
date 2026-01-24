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
    local pc=${X86_REGS[15]}
    local cs=${X86_REGS[17]}
    local addr=$(((cs * 16 + pc) & 0xfffff))
    local v=${X86_MEM[$addr]}
    X86_REGS[15]=$(((pc+1) & 0xffff))
    IR=$(printf "0x%.2x" $v)
}

# fetch word from PC
fetch16() {
    fetch8
    local v1=$IR
    fetch8
    local v2=$IR
    IR=$(printf "0x%.2x%.2x" $v2 $v1)
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

# push value to stack
push16() {
    local val=$1
    local sp=${X86_REGS[4]}
    local ss=${X86_REGS[18]}
    sp=$(((sp - 2) & 0xffff))
    setreg 4 $sp 0xffff
    write16 $ss $sp $val
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
setop 0x9a CALL Ap
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
setop 0xea JMP Ap
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
setop 0xf7 GRP3 Ev __ MRR # TEST needs Iv
setop 0xf8 CLC
setop 0xf9 STC
setop 0xfa CLI
setop 0xfb STI
setop 0xfc CLD
setop 0xfd STD
setop 0xfe GRP4 Eb __ MRR # INC Eb/DEC Eb
setop 0xff GRP5 Ev __ MRR

# Create register object with current value
mkreg() {
    local num=$1 mask=$2
    reg=$(getreg $num $mask)
    printf "reg $num $mask $reg"
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

# Create effective address
mkea() {
    local mrr=$1 mask=$2
    local mm=$(((mrr >> 6) & 3))
    local rrr=$((mrr & 7))
    if [[ $mm -eq 3 ]]; then
	mkreg $rrr $mask
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
	       fetch16
	       off=$IR
	   fi
	   ;;
	7) off=$bx ;;
    esac
    if [ $mm -eq 1 ] ; then
	fetch8
	off=$(add8 $off $IR)
    elif [ $mm -eq 2 ] ; then
	fetch16
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
    printf "mem $val 0x%x $mask $mm $rrr\n" $off
    exit 0
}

# decode opcode args
# opmrr is original opcode << 8 + MRR byte (or 00)
decarg() {
    local opmrr=$1 oparg=$2 mask=$3
    local ggg=$(((opmrr >> 3) & 7))
    local opg=$(((opmrr >> 8) & 7))

    # set mask on Gb/Eb etc to 0xff
    [[ $oparg == ?b* ]] && mask=0xff
    case $oparg in
	rES) echo "seg 0" ;;
	rCS) echo "seg 1" ;;
	rSS) echo "seg 2" ;;
	rDS) echo "seg 3" ;;
	Sw)  echo "seg ${ggg}" ;;
	Xb | Xv) echo "mem rDS rvDI $mask" ;;
	Yb | Yv) echo "mem rES rvSI $mask" ;;
	Gb | Gv)  mkreg ${ggg} $mask ;;
	gb | gv)  mkreg $opg $mask ;;
	Eb | Ew | Ev | Mp)  mkea $opmrr $mask ;;
	rCL) mkreg 1 0xff ;;
	rAL) mkreg 0 0xff ;;
	rvAX) mkreg 0 $mask ;;
	rDX) mkreg 2 0xffff ;;
	i1) echo "imm 1 $mask" ;;
	i3) echo "imm 3 $mask" ;;
	Ib) fetch8 ; echo "imm $IR 0xffff" ;;
	Iv) fetch16 ; echo "imm $IR 0xffff" ;;
	Ob | Ov) mkea 0x6 $mask ;;
	*) echo "$oparg" ;;
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
	    local n=$((oparg[1] + 16))
	    getreg $n 0xffff
	    ;;
	*)
	    echo 0x1234
	    ;;
    esac
}

# set result value
execset() {
    local oparg=($1)
    local val=$2

    printf "set:[${op[*]}] $val\n"
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
    esac
}

# Run alu op
aluop() {
    local opfn=$1
    local s1="$2" s2="$3"
    local v1="$(execval "$s1")"
    local v2="$(execval "$s2")"
    local dest=$s1

    res="0xdeadbeef"
    printf "alu: $opfn %x %x\n" $v1 $v2
    case $opfn in
	SUB) res=$((v1 - v2)) ;;
	ADD) res=$((v1 + v2)) ;;
	ADC) res=$((v1 + v2 + CF)) ;;
	SUB) res=$((v1 - v2)) ;;
	SBB) res=$((v1 - v2 - CF)) ;;
	INC) res=$((v1 + 1)) ;;
	DEC) res=$((v1 - 1)) ;;
	NEG) res=$((0 - v1)) ;;
	NOT) res=$((~v2)) ;;
	AND) res=$((v1 & v2)) ; CF=0 ; OF=0 ;;
	XOR) res=$((v1 ^ v2)) ; CF=0 ; OF=0 ;;
	OR)  res=$((v1 | v2)) ; CF=0 ; OF=0 ;;
	TEST) dest="" ; res=$((v1 & v2)) CF=0 ; OF=0 ;;
	CMP)  dest="" ; res=$((v1 - v2)) ;;
	SHL|SAL) res=$((v1 << v2)) ;;
	SHR) res=$((v1 >> v2)) ;;
    esac
    printf "result is:[$dest] [%x]\n" $res
    execset "$dest" "$res"
}

# Execute an opcode
execop() {
    local opcode=$1 opfn=$2 s1="$3" eval s2="$4"
    flags=""
    
    # get ggg from MRR for decoding op group
    if [[ $opfn == GRP* ]]; then
	subop=$(((opcode >> 3) & 7))
	case $opfn in
	    GRP1) opfn=${grp1[$subop]} ;;
	    GRP2) opfn=${grp2[$subop]} ;;
	    GRP3) opfn=${grp3[$subop]} ;;
	    GRP4) opfn=${grp4[$subop]} ;;
	    GRP5) opfn=${grp5[$subop]} ;;
	esac
    fi
    printf "opfn: $opfn\n"
    case $opfn in
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
	JCC)
	    SF=0 ZF=1 CF=0 PF=0 OF=0
	    testcond $((opcode >> 8))
	    rc=$?
	    echo $rc
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
	CWD)
	    # convert signed AX/EAX/RAX to DX/EDX/RDX
	    ax=$(getreg 0 $osize)
	    sgn=$(printf "0x%x" $((osize - (osize >> 1))))
	    if [ $(($ax & $sgn)) != 0 ]; then
		# if AX is signed, then set DX=-1
		setreg 2 0xffffffff $osize
	    fi
	    ;;
	PUSH)
	    local v1="$(execval "$s1")"
	    push16 $v1
	    ;;
	POP)
	    printf "popping....\n"
	    execset "$s1" 0xbeefcafe
	    ;;
	LEA)
	    # s1 = Gv
	    # s2 = Mp [mem seg off mask mm rrr]
	    local lea=($s2)
	    execset "$s1" ${lea[2]}
	    ;;
	AAA)
	    local AX=$(getreg 0 0xffff)
	    printf "AX=%x %x\n", $AX ${X86_REGS[0]}
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
	    printf "AX=%x\n", $AX
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
	NOP | WAIT | LOCK | REP) ;;
	*) printf " noval\n" ; return ;;
    esac
    printf " %x SF=$SF ZF=$ZF AF=$AF PF=$PF CF=$CF DF=$DF IF=$IF seg=$seg\n" ${X86_REGS[14]}

}

# decode and exec opcode
decode() {
    opcode=$1
    mnem=${X86_MNEM[$opcode]}
    printf "==== %.2x $mnem ${X86_OP1[$opcode]} ${X86_OP2[$opcode]}\n" $opcode 
    opfn=$((opcode * 256))
    if [[ ${X86_ENC[$opcode]} == MRR ]] ; then
	fetch8
	opfn=$((opfn + $IR))
    fi
    m1=$(decarg $opfn "${X86_OP1[$opcode]}" $osize)
    m2=$(decarg $opfn "${X86_OP2[$opcode]}" $osize)
    printf "[$m1] [$m2]\n"
    execop $opfn $mnem "$m1" "$m2"
    if [ -z $mnem ]; then
	echo "--- missing"
    fi
}


