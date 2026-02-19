#!/bin/bash
#
# Lets emulate an x86 in bash....
#
# used this as a guide for undocumented instructions:
# https://www.righto.com/2023/07/undocumented-8086-instructions.html
# https://gchq.github.io/CyberChef/#recipe=Disassemble_x86('16','Full%20x86%20architecture',8,0,true,true)&input=NjcgRjcgODQgQzIgNzcgMDIgMDAgMDAg&oeol=CRLF
# 
# 00 0x0000     | 0x00      | Divide by 0
# 16 0x0010     | 0x04      | Overflow (INTO)
# 20 0x0014     | 0x05      | Bounds range exceeded (BOUND)
# 24 0x0018     | 0x06      | Invalid opcode (UD2)
# 48 0x0030     | 0x0C      | Stack-segment fault
# 52 0x0034     | 0x0D      | General protection fault
declare -a X86_MNEM
declare -a X86_OP1
declare -a X86_OP2
declare -a X86_OP3
declare -a X86_ENC
declare -a X86_REGS
declare -a X86_MEM

tsv_seg=0
tsv_off=0
tsv_lin=0

fault=99
lock=0
verbose=0
cpu_type=8088
addr_mask=0xfffff

MRR=0x1
LCK=0x2
SPC=0x4

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
    if [[ $cpu_type == 8088 ]]; then
	nf=$((nf | 0xf000))
    fi
    X86_REGS[14]=$(((X86_REGS[14] & ~N) | nf))
}

# Set register value
setreg() {
    local num=$1 val="$2" mask="$3" lbl=$4
    if [[ -z $mask ]] ; then
	mask=0xffffffff
	exit 1
    fi
    local xnum=$num
    case $num in
	AX) num=0 ;;
	CX) num=1 ;;
	DX) num=2 ;;
	BX) num=3 ;;
	SP) num=4 ;;
	BP) num=5 ;;
	SI) num=6 ;;
	DI) num=7 ;;
	FLAGS) num=14 ;;
	IP) num=15 ;;
	ES) num=16 ;;
	CS) num=17 ;;
	SS) num=18 ;;
	DS) num=19 ;;
	FS) num=20 ;;
	GS) num=21 ;;
    esac
    val=$((val & mask))
    if [[ mask -eq 0xff && $num -ge 4 ]]; then
	# special case for AH/BH/CH/DH
	mask=0xff00
	val=$((val << 8))
	num=$((num - 4))
    fi
    printf " setreg $num %.4x $mask [$lbl]\n" $val
    X86_REGS[$num]=$(((X86_REGS[num] & ~mask) | val))
}

setszp() {
    local res=$1 mask=$2
    case $mask in
	0xff) sgn=0x80 ;;
	0xffff) sgn=0x8000 ;;
	0xffffffff) sgn=0x80000000 ;;
	0xffffffffffffffff) sgn=
    esac
    ZF=$(((res & mask) == 0))
    SF=$(((res & sgn) != 0))
    PF=$(parity $res)
}

# Get register value
getreg() {
    local num=$1 mask=$2
    local xnum=$num
    case $num in
	AX) num=0 ;;
	CX) num=1 ;;
	DX) num=2 ;;
	BX) num=3 ;;
	SP) num=4 ;;
	BP) num=5 ;;
	SI) num=6 ;;
	DI) num=7 ;;
	FLAGS) num=14 ;;
	IP) num=15 ;;
	ES) num=16 ;;
	CS) num=17 ;;
	SS) num=18 ;;
	DS) num=19 ;;
	FS) num=20 ;;
	GS) num=21 ;;
    esac
    if [[ mask -eq 0xff && $num -ge 4 ]]; then
	# special case for AH/BH/CH/DH
	printf "0x%x" $(((X86_REGS[num - 4] >> 8) & mask))
	return
    fi
    printf "0x%x" $((X86_REGS[num] & mask))
}

# Check if access out of segment bounds
checkmem() {
    local co=$1
    local vect=$2

    if [[ -z "$vect" ]]; then
	vect=0xd
    fi

    # GP or SS
    if [[ $cpu_type == 80386 && $co -gt 0xffff && $co -lt 0xfffff ]]; then
	printf "fault checkmem 0x%x $vect\n" $co
	fault=$vect
    fi
}

checkpg() {
    local tt=$1

    if (( "$tt"!="mem" )); then
	return
    fi
    local f=$2 seg=$3 off=$4 mask=$5
    case $mask in
	0xff) size=1 ;;
	0xffff) size=2 ;;
	0xffffffff) size=4 ;;
	*) size=8;;
    esac
    if (( $cpu_type == 80386 && $off+$size > 0x10000 )) ; then
	echo "checkpg [$f] [$seg] [$off] [$mask]"
	fault=$f
    fi
}

# fetch byte from PC
fetch8() {
    local out=$1
    local pc=${X86_REGS[15]}
    local cs=${X86_REGS[17]}
    local addr=$(((cs * 16 + pc) & $addr_mask))
    local v=${X86_MEM[$addr]}
    printf "@fetch  [%d] [%.8x] off=%.8x [%.2x]\n" $addr $addr $pc $v
    printf -v "$out" "0x%.2x" $v
    if [[ $lastfetch -eq 0xffff ]] ; then
	printf "==================== lastpc=0xffff fetch\n"
	fault=0xd
	lastfetch=0
    else
	lastfetch=$pc
    fi
    setreg IP $((pc+1)) 0xfffff "fetch8"
}

# fetch word from PC
fetch16() {
    local out=$1
    fetch8 FLO
    fetch8 FHI
    printf -v "$out" "0x%.2x%.2x" $FHI $FLO
}

# fetch 16/32/64
fetchv() {
    local out=$1
    case $osize in
	0xffff)
	    fetch16 $out
	    ;;
	0xffffffff)
	    fetch16 D0
	    fetch16 D1
	    printf -v $out "0x%.4x%.4x" $D1 $D0
	    ;;
	0xffffffffffffffff)
	    fetch16 D0
	    fetch16 D1
	    fetch16 D2
	    fetch16 D3
	    printf -v $out "0x%.4x%.4x%.4x%.4x" $D3 $D2 $D1 $D0
	    ;;
	esac
}

# read8 seg off
read8() {
    local out=$1
    local off=$3
    checkmem $((off + 0))
    local base=$(($2 * 16))
    local addr=$(((base + (off + 0)) & $addr_mask))
    local v=${X86_MEM[$addr]}
    printf "read8 [%x] %d %.8x off=%.8x [%.2x]\n" $base $addr $addr $off $v
    printf -v "$out" "0x%x" $v
}

# write8 seg off val
write8() {
    local off=$2
    checkmem $((off + 0))
    local base=$(($1 * 16))
    local addr=$(((base + (off + 0 & 0xffff)) & $addr_mask))
    printf "write8 [%x] %d %.8x off=%.8x [%.2x]\n" $base $addr $addr $off $3
    X86_MEM[$addr]=$(($3 & 0xff))
}

# read16 seg off
read16() {
    local out=$1
    local off=$3
    local vect=$4
    checkmem $((off + 0)) $vect
    checkmem $((off + 1)) $vect
    local base=$(($2 * 16))
    local a0=$(((base + (off + 0 & 0xFFFF)) & $addr_mask))
    local a1=$(((base + (off + 1 & 0xFFFF)) & $addr_mask))
    local v1=${X86_MEM[$a0]}
    local v2=${X86_MEM[$a1]}
    printf -v "$out" "0x%.2x%.2x" $v2 $v1
}

# write16 seg off val
write16() {
    local off=$2
    local base=$(($1 * 16))
    local a0=$(((base + (off + 0 & 0xFFFF)) & $addr_mask))
    local a1=$(((base + (off + 1 & 0xFFFF)) & $addr_mask))
    printf "write16 [%x] %d %.8x off=%.8x [%.2x]\n" $base $addr $addr $off $3
    X86_MEM[$a0]=$(($3 & 0xff))
    X86_MEM[$a1]=$((($3 >> 8) & 0xff))
}

# Load pointer for CALLF/JUMPF
loadptr() {
    local cs=$1
    local co=$2

    #mem0 vect1 seg2 base3 mask4
    local oparg=($3)
    case ${oparg[0]} in
	"mem")
	    local pseg=${oparg[2]}
	    local pofs=${oparg[3]}
	    read16 coff $pseg $pofs
	    read16 cseg $pseg $((pofs + 2))
	    ;;
	"ptr")
	    printf -v cseg "0x%x" ${oparg[1]}
	    printf -v coff "0x%x" ${oparg[2]}
	    ;;
    esac
}

# push value to stack (dec->write)
pushv() {
    local val=$1
    local mask=$2
    local lbl=$3
    
    local sp=${X86_REGS[4]}
    local ss=${X86_REGS[18]}
    printf "pushv 0x%x 0x%x %x [%s]\n" $sp $val $mask $lbl
    case $mask in
	0xffff)
	    # decrement then write
	    sp=$(((sp - 2) & 0xffff))
	    setreg SP $sp 0xffff "pushw.sp"
	    write16 $ss $sp $val
	    ;;
	0xffffffff)
	    sp=$(((sp - 2) & 0xffffffff))
	    write16 $ss $sp $((val >> 16))
	    sp=$(((sp - 2) & 0xffffffff))
	    write16 $ss $sp $val
	    setreg SP $sp 0xffffffff "pushd.sp"
	    ;;
    esac
}

# pop value from stack (read -> inc)
popv() {
    local out=$1
    local sp=${X86_REGS[4]}
    local ss=${X86_REGS[18]}
    case $osize in
	0xffff)
	    read16 N $ss $sp
	    printf "pop16 $N $fault\n"
	    printf -v "$out" "0x%x" $N
	    if [[ $fault -ne 99 ]] ; then
		echo "========== fault in popv $fault"
		return
	    fi
	    setreg SP $((sp + 2)) 0xffff "popw.sp"
	    ;;
	0xffffffff)
	    read16 PL $ss $sp 0x0c
	    sp=$(((sp + 2) & 0xffffffff))
	    read16 PH $ss $sp 0x0c
	    sp=$(((sp + 2) & 0xffffffff))
	    if [[ $fault -ne 99 ]] ; then
		echo "========== fault in popv $fault"
		return
	    fi
	    setreg SP $sp $osize "popd.sp"
	    printf "pop32\n"
	    printf -v "$out" "0x%.4x%.4x" $PH $PL
	    ;;
    esac
}

# 0x6 = UD2
# 0xc = SS
# 0xd = GPF
vector() {
    local vec=$1
    local vpc=$2
    read16 ncs 0x0 $((vec * 4 + 2))
    read16 npc 0x0 $((vec * 4 + 0))

    if [[ -z "$vpc" ]] ; then
	vpc=$spc
    fi
    if (( $ncs == 0 && $npc == 0 )) ; then
	echo "ZERO VECTOR"
	return
    fi
    printf "vector: $vec 0x%x 0x%x\n" $ncs $npc
    setflags
    pushv $(getreg FLAGS 0xffff) 0xffff "flags"
    pushv $(getreg CS 0xffff) 0xffff "cs"
    pushv $vpc 0xffff "ip"

    setreg CS $ncs 0xffff "vector.cs"
    setreg IP $npc $osize "vector.pc"
    pfx=0
}

# Undefined opcode fault
UD2() {
    printf "ud2 0x%x 0x%x 0x%x\n" $ncs $npc $spc
    vector 0x6 $spc
}

GPF() {
    printf "gpf 0x%x 0x%x 0x%x\n" $ncs $npc $spc
    vector 0xd $spc
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

# Setup opcode table mnemonic+opcode args
setop() {
    local op=$1 mnem=$2 o1=$3 o2=$4 enc=$5
    if [ $verbose ] ; then
        printf "seto %.2X $mnem $o1 $o2 $enc\n" $op
    fi
    X86_MNEM[$op]="$mnem"
    X86_OP1[$op]="$o1"
    X86_OP2[$op]="$o2"
    X86_ENC[$op]="$enc" 
}

# special case for 3-op IMUL
setop3() {
    local op=$1 o3=$2
    X86_OP3[$op]="$o3"
    if [ $verbose ] ; then
        printf "seto3 %.2X $o3\n" $op
    fi
}

# special case GRP opargs (opcode << 8) + subop
grpop() {
    local op=$1 sub=$2 o1=$3 o2=$4
    local m2=$((op * 256 + (sub << 3)))
    printf "new grp %.4x %x %x $o1 $o2\n" $m2 $op $sub
    X86_OP1[$m2]="$o1"
    X86_OP2[$m2]="$o2"
}

# Setup opcodes
# undocumented:
#  D6 = salc
#  0F = pop cs
#  6x = jcc
#  C0 = ret
#  C1 = ret
#  C8 = retf Ib
#  C9 = ret
#  F1 = lock
#  82.x = Ib
#  83.x = Sb
#  D0.6 = setmo
#  D1.6 = setmo
#  D2.6 = setmo
#  D3.6 = setmo
#  F6.1 = test
#  F7.1 = test
#  FE.2 = call
#  FE.3 = call
#  FE.4 = jmp
#  FE.5 = jmp
#  FE.6 = push
#  FE.7 = push
#  FF.7 = push
eregs=(EAX ECX EDX EBX ESP EBP ESI EDI)
grp1=(ADD OR ADC SBB AND SUB XOR CMP)
grp2=(ROL ROR RCL RCR SHL SHR SETMO SAR)
grp3=(TEST TEST NOT NEG MUL IMUL DIV IDIV)
grp4=(INC DEC)
grp5=(INC DEC CALL CALLF JMP JMPF PUSH PUSH)
grp6=(SLDT STR LLDT LTR VERR VERW)
grp7=(SGDT SIDT LGDT LIDT SMSW __ LMSW __)
grp8=(__ __ __ __ BT BTS BTR BTC)
for i in {0..7}; do
  base=$(( i << 3 ))

  op=${grp1[$i]}
  setop $((base+0)) $op Eb Gb MRR LCK # grp1
  setop $((base+1)) $op Ev Gv MRR LCK # grp1
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

  # 8088 60-6F are same as 70-7F
  setop $((0x60+i)) JCC Jb
  setop $((0x68+i)) JCC Jb
  setop $((0x70+i)) JCC Jb
  setop $((0x78+i)) JCC Jb

  setop $((0xD8+i)) NOP Gb Eb MRR
done

setop 0x06 PUSH rES
setop 0x07 POP rES
setop 0x0e PUSH rCS
setop 0x0f ----
setop 0x16 PUSH rSS
setop 0x17 POP rSS
setop 0x1E PUSH rDS
setop 0x1F POP rDS

setop 0x26 SEG rES __ __ LCK
setop 0x27 DAA __ __ __ NO64
setop 0x2e SEG rCS __ __ LCK
setop 0x2f DAS __ __ __ NO64

setop 0x36 SEG rSS
setop 0x37 AAA      # AX+=0x106
setop 0x3e SEG rDS
setop 0x3f AAS      # AX-=0x106

setop 0x80 GRP1 Eb Ib MRR LCK
setop 0x81 GRP1 Ev Iv MRR LCK
setop 0x82 GRP1 Eb Ib MRR LCK
setop 0x83 GRP1 Ev Sb MRR LCK
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

setop 0xc1 RET         # undocumented
setop 0xc2 RET Iw
setop 0xc3 RET
setop 0xc4 LES Gv Mp MRR
setop 0xc5 LDS Gv Mp MRR
setop 0xc6 MOV Eb Ib MRR
setop 0xc7 MOV Ev Iv MRR
setop 0xc8 RET          # undocumented
setop 0xc9 RETF         # undocumented
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
setop 0xe7 OUT Ib rvAX
setop 0xe8 CALL Jv
setop 0xe9 JMP Jv
setop 0xea JMPF Ap
setop 0xeb JMP Jb
setop 0xec IN rAL rDX
setop 0xed IN rvAX rDX
setop 0xee OUT rDX rAL
setop 0xef OUT rDX rvAX

setop 0xf0 LOCK
setop 0xf1 LOCK      #undocumented
setop 0xf2 REP repnz
setop 0xf3 REP repz
setop 0xf4 HLT
setop 0xf5 CMC
setop 0xf6 GRP3 Eb __ MRR
grpop 0xf6 0 Eb Ib
grpop 0xf6 1 Eb Ib
setop 0xf7 GRP3 Ev __ MRR
grpop 0xf7 0 Ev Iv
grpop 0xf7 1 Ev Iv
setop 0xf8 CLC
setop 0xf9 STC
setop 0xfa CLI
setop 0xfb STI
setop 0xfc CLD
setop 0xfd STD
setop 0xfe GRP4 Eb __ MRR # INC Eb/DEC Eb
setop 0xff GRP5 Ev __ MRR # INC Ev/DEC Ev/CALL Ev/CALL Mp/JMP Ev/JMP Mp/PUSH Ev
grpop 0xff 3 Mp __
grpop 0xff 5 Mp __

# 386-specific opcodes
add386() {
    addr_mask=0xffffff
    setop 0x60 PUSHA
    setop 0x61 POPA
    setop 0x62 BOUND Gv Mp MRR
    setop 0x63 ARPL Ew Rw MRR
    setop 0x64 SEG rFS
    setop 0x65 SEG rGS
    setop 0x66 OSZ
    setop 0x67 ASZ
    setop 0x68 PUSH Iv
    setop 0x69 IMUL Gv Ev MRR # Gv Ev Ib
    setop3 0x69 Iv
    setop 0x6A PUSH Ib
    setop 0x6B IMUL Gv Ev MRR # Gv Ev Iv
    setop3 0x6B Ib
    setop 0x6C INS Yb rDX
    setop 0x6D INS Yv rDX
    setop 0x6E OUTS rDX Xb
    setop 0x6F OUTS rDX Xv
    setop 0xc0 GRP2 Eb Ib MRR
    setop 0xc1 GRP2 Ev Ib MRR
    setop 0xC8 ENTER Iw Ib
    setop 0xC9 LEAVE
    setop 0xFA0 PUSH rFS
    setop 0xFA1 POP rFS
    setop 0xFA3 BT Ev Gv MRR LCK
    setop 0xFA4 SHLD Ev Gv MRR # Ev Gv Ib
    setop3 0xFA4 Ib
    setop 0xFA5 SHLD Ev Gv MRR # Ev Gv rCL
    setop3 0xFA5 rCL
    setop 0xFA8 PUSH rGS
    setop 0xFA9 POP rGS
    setop 0xFAB BTS Ev Gv MRR LCK
    setop 0xFAC SHRD Ev Gv MRR # Ev Gv Ib
    setop3 0xFAC Ib
    setop 0xFAD SHRD Ev Gv MRR # Ev Gv rCL
    setop3 0xFAD rCL
    setop 0xFAF IMUL Gv Ev MRR
    setop 0xFB2 LSS Gv Mp MRR
    setop 0xFB3 BTR Ev Gv MRR LCK
    setop 0xFB4 LFS Gv Mp MRR
    setop 0xFB5 LGS Gv Mp MRR
    setop 0xFB6 MOVZX Gv Eb MRR
    setop 0xFB7 MOVZX Gv Ew MRR
    setop 0xFBA GRP8 Ev Ib MRR
    setop 0xFBB BTC Ev Gv MRR LCK
    setop 0xFBC BSF Ev Gv MRR
    setop 0xFBD BSR Gv Ev MRR
    setop 0xFBE MOVSX Gv Eb MRR
    setop 0xFBF MOVSX Gv Ew MRR
    for i in {0..7} ; do
	setop $((0xF80+i)) JCC Jv
	setop $((0xF88+i)) JCC Jv
	setop $((0xF90+i)) SETCC Eb __ MRR
	setop $((0xF98+i)) SETCC Eb __ MRR
    done
}

showtbl() {
    for X in {0..256}; do
	printf "%-5.5s " "${X86_MNEM[$X]}"
	if [[ $((X & 0xF)) -eq 0x0f ]] ; then
	    printf "\n"
	fi
    done
    for X in {3840..4095}; do
	printf "%-5.5s " "${X86_MNEM[$X]}"
	if [[ $((X & 0xF)) -eq 0x0f ]] ; then
	    printf "\n"
	fi
    done
}

# Get segment base
getseg() {
    local out=$1
    local vseg=$2
    local oseg=$3
    local lbl=$4
    if [ -n "$oseg" ] ; then
	vseg=$oseg
    fi
    local svect=0xd
    case $vseg in
	"seg 0") val=$(getreg ES 0xffff) ;;
	"seg 1") val=$(getreg CS 0xffff) ;;
	"seg 2") val=$(getreg SS 0xffff) ; svect=0x0c ;;
	"seg 3") val=$(getreg DS 0xffff) ;;
	"seg 4") val=$(getreg FS 0xffff) ;;
	"seg 5") val=$(getreg GS 0xffff) ;;
	*) echo "no seg $vseg $lbl" ; exit 0 ;;
    esac
    printf -v "$out" "$svect 0x%x" $val
    echo "getseg [$vseg] [$oseg] -> [$val]"
}

# Create register object with current value
mkreg() {
    local out=$1
    local num=$2 mask=$3
    reg=$(getreg $num $mask)
    printf -v "$out" "reg $num $mask $reg"
}

# Parity calc
parity() {
    local v=$(($1 & 0xFF))
    ((v ^= v >> 4))
    ((v ^= v >> 2))
    ((v ^= v >> 1))
    (((v & 1)))
    echo $?
}

add8() {
    local v1=$1
    local v2=$2
    # convert signed
    if [ $((v2 & 0x80)) -ne 0 ]; then
	v2=$(((v2 - 256) & 0xffff))
    fi
    echo $(((v1 + v2) & 0xffff))
}

add16() {
    local v1=$1
    local v2=$2
    echo $(((v1 + v2) & 0xFFFF))
}

# Create immediate
mkimm() {
    local out=$1
    local v=$2
    local mask=$3

    printf -v "$out" "imm 0x%x $mask" $v
}

# 386 EA
mkea32() {
    local out=$1
    local mrr=$2 mask=$3
    local mm=$(((mrr >> 6) & 3))
    local rrr=$((mrr & 7))
    local off=0
    local sib=0
    
    # default to DS
    easeg="seg 3"
    rrscale=1
    printf " mm:$mm rrr:$rrr %x\n" $opmrr
    if (( $rrr == 4 )) ; then
	# SIB byte
	fetch8 SIB

	local ss=$((1 << ((SIB >> 6) & 3)))
	local ii=$(((SIB >> 3) & 7))
	local bb=$((SIB & 7))
	
	rrr=$bb
	if (( $ii != 4 )) ; then
	    sib=$(getreg $ii $osize)
	    printf " iii: ${eregs[$ii]} 0x%.8x x $ss\n" $sib
	    sib=$((sib * ss))
	else
	    # undocumented scale base
	    rrscale=$ss
	fi
	# new base register
    fi

    # Now get base address
    if (( $mm == 0 && $rrr == 5 )) ; then
	# disp32, no base
	fetch16 SI0
	fetch16 SI1
	off=$(((SI1 << 16) + SI0))
	easeg="seg 3" # DS
	printf " bbb: [d16] 0x%.8x\n" $off 
    else
	off=$(getreg $rrr $osize)
	off=$((off * rrscale))
	# SS follows EBP
	if (( rrr == 5 || rrr == 4 )) ; then
	    easeg="seg 2" # SS
	fi
	printf " bbb: ${eregs[$rrr]} 0x%.8x\n" $off 
    fi

    # Get displacement
    SI0=0
    if (( mm == 1 )) ; then
	fetch8 SI0
	signex SI0 $SI0 0xff 0x80
    elif (( mm == 2 )) ; then
	fetch16 SI0
	fetch16 SI1
	SI0=$((SI0 + (SI1 << 16)))
	signex SI0 $SI0 0xffffffff 0x80000000
    fi
    printf " base offset: sib:%.8x off:%.8x disp:%.8x [$easeg] [$seg]\n" $sib $off $SI0

    # Segment override
    off=$(((sib + off + SI0) & addr_mask))
    getseg val "$easeg" "$seg" "ea"
    printf "ea32: [$val] %.8x\n" $off

    sv=($val)
    case $mask in
	0xff)
	    if (( $((off)) > 0xffff && $cpu_type == 80386 )) ; then
		echo "prefaultb $sv"
		fault=${sv[0]}
	    fi
	    ;;
	0xffff)
	    if (( $((off+1)) > 0xffff && $cpu_type == 80386 )) ; then
		echo "prefaultw $sv"
		fault=${sv[0]}
	    fi
	    ;;
	0xffffffff)
	    if (( $((off+3)) > 0xffff && $cpu_type == 80386 )) ; then
		echo "prefaultd $sv"
		fault=${sv[0]}
	    fi
	    ;;
    esac

    printf "tsv: 0x%x 0x%x 0x%x\n" $tsv_seg $tsv_off $tsv_lin
    printf -v "$out" "mem $val 0x%x 0x%x $mm $rrr" $off $mask
}    

# Create effective address
mkea() {
    local out=$1
    local mrr=$2 mask=$3
    local mm=$(((mrr >> 6) & 3))
    local rrr=$((mrr & 7))
    if [[ $mm -eq 3 ]]; then
	mkreg $out $rrr $mask
	return
    fi
    if (( $asize == 0xffffffff )) ; then
	mkea32 $out $mrr $mask
	return
    fi
    off=""
    easeg="seg 3"
    local bx=$(getreg BX 0xffff)
    local bp=$(getreg BP 0xffff)
    local si=$(getreg SI 0xffff)
    local di=$(getreg DI 0xffff)
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
    echo "base offset: $off"
    if [ $mm -eq 1 ] ; then
	fetch8 IR
	off=$(add8 $off $IR)
    elif [ $mm -eq 2 ] ; then
	fetch16 IR
	off=$(add16 $off $IR)
    fi
    
    # Segment override
    getseg val "$easeg" "$seg" "ea"
    sv=($val)
    case $mask in
	0xff)
	    if (( $off > 0xffff && $cpu_type == 80386 )) ; then
		echo "prefault $val"
		fault=${sv[0]}
	    fi
	    ;;
	0xffff)
	    if (( $((off+1)) > 0xffff && $cpu_type == 80386 )) ; then
		echo "prefault $val"
		fault=${sv[0]}
	    fi
	    ;;
	0xffffffff)
	    if (( $((off+3)) > 0xffff && $cpu_type == 80386 )) ; then
		echo "prefault $val"
		fault=${sv[0]}
	    fi
	    ;;
    esac

    printf "2tsv: 0x%x 0x%x\n" $tsv_seg $tsv_off
    printf "pc ${X86_REGS[15]}\n"
    printf -v "$out" "mem $val 0x%x 0x%x $mm $rrr" $off $mask
}

# String operations. ES:DI, DS:SI
# strop var seg index mask
strop() {
    local out=$1 vs=$2 vo=$3 mask=$4

    # if no overriding seg, default to DS
    if [[ -z $vs ]] ; then
	vs="seg 3"
    fi

    # Get Index
    local voff=$(getreg $vo 0xffff)

    # Calculate delta
    delta=1
    [ $mask == 0xffff ] && delta=2
    [ $mask == 0xffffffff ] && delta=4
    [ $mask == 0xffffffffffffffff ] && delta=8
    
    # Check DF flag
    [ $DF != 0 ] && delta=$((-delta))
    printf "strop vo is $vo $voff $delta %x\n"  $((voff + delta))

    # Memory address
    getseg val "$vs" "" "strop"
    printf -v "$out" "mem $val 0x%x 0x%x" $voff $mask
    if (( $cpu_type == 80386 && voff + delta > 0xffff )) ; then
	sv=($val)
	fault=${sv[0]}
	echo "ACK"
	return
    fi

    # inc/dec index
    setreg "$vo" "$((voff + delta))" $asize "strop"
}    

# decode opcode args
# opmrr is original opcode << 8 + MRR byte (or 00)
decarg() {
    local out=$1
    local opmrr=$2 oparg=$3 mask=$4
    local ggg=$(((opmrr >> 3) & 7))
    local opg=$(((opmrr >> 8) & 7))

    if [[ $fault -ne 99 ]] ; then
	echo "=========== fault in decarg [$fault] [$oparg]"
	return
    fi
    
    # set mask on Gb/Eb etc to 0xff
    [[ $oparg == ?b* ]] && mask=0xff
    [[ $oparg == ?w* ]] && mask=0xffff
    case $oparg in
	rES) printf -v "$out" "seg 0" ;;
	rCS) printf -v "$out" "seg 1" ;;
	rSS) printf -v "$out" "seg 2" ;;
	rDS) printf -v "$out" "seg 3" ;;
	rFS) printf -v "$out" "seg 4" ;;
	rGS) printf -v "$out" "seg 5" ;;
	Sw)
	    printf "sw.... $ggg\n"
	    if (( $cpu_type == 80386 && $ggg > 5 )) ; then
		echo "faultseg big"
		fault=0x6
	    fi
	    printf -v "$out" "seg ${ggg}" ;;
	Xb | Xv) strop $out "$seg" 6 $mask ;;  # <DS>:SI
	Yb | Yv) strop $out "seg 0" 7 $mask ;; # ES:DI
	Gb | Gv) mkreg $out ${ggg} $mask ;;
	gb | gv) mkreg $out $opg $mask ;;
	Eb | Ev | Ew) mkea $out $opmrr $mask ;;
	Mp)
	    if (( $(((opmrr >> 6) & 3)) == 3 )) ; then
		echo "REG for Mp!"
		fault=0x6
		return
	    fi
	    mkea $out $opmrr $mask ;;
	Ob)
	    if [[ $asize -eq 0xffffffff ]]; then
		mkea $out 0x5 $mask
	    else
		mkea $out 0x6 $mask
	    fi
	    ;;
	Ov) if [[ $asize -eq 0xffffffff ]]; then
		mkea $out 0x5 $asize
	    else
		mkea $out 0x6 $asize
	    fi
	    ;;
	Jb)
	    fetch8 IR
	    local addr=$(add8 ${X86_REGS[15]} $IR)
	    printf -v "$out" "imm $addr 0xff"
	    ;;
	Jv)
	    fetchv IR
	    printf -v "$out" "imm 0x%x 0xffff" $((X86_REGS[15] + $IR))
	    ;;
	rCL) mkreg $out 1 0xff ;;
	rAL) mkreg $out 0 0xff ;;
	rvAX) mkreg $out 0 $mask ;;
	rDX) mkreg $out 2 0xffff ;;
	i1) mkimm $out 1 $mask ;;
	i3) mkimm $out 3 $mask ;;
	Ib) fetch8 IR ; mkimm $out $IR $mask ;;
	Iw) fetch16 IR; mkimm $out $IR $mask ;;
	Iv) fetchv IR ; mkimm $out $IR $mask ;;
	Sb)
	    # signed byte
	    fetch8 IR
	    if [ $((IR & 0x80)) != 0 ]; then
		IR=$((IR | 0xFF00))
	    fi
	    mkimm $out $IR 0xffff
	    ;;
	Ap)
	    fetchv AR
	    fetch16 IR
	    printf -v "$out" "ptr 0x%x 0x%.4x" $IR $AR
	    ;;
	*) printf -v "$out" "$oparg" ;;
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
	    # mem0 vect1 seg2 off3 mask4
	    echo "${oparg[4]}"
	    ;;
	*)
	    echo 0
    esac
}

# get arg value
execval() {
    local out=$1
    local oparg=($2)
    case ${oparg[0]} in
	reg)
	    # reg num mask val
	    printf -v "$out" "${oparg[3]}"
	    ;;
	imm)
	    printf -v "$out" "${oparg[1]}"
	    ;;
	mem)
	    # mem0 vect1 seg2 off3 mask4
	    local base=${oparg[2]}
	    local off=${oparg[3]}
	    local am=${oparg[4]}
	    local vect=${oparg[1]}
	    if [[ $am -eq 0xff ]] ; then
		read8 ED0 $base $off
		printf -v $out "0x%.4x" $ED0
	    elif [[ $am -eq 0xffff ]] ; then
		read16 ED0 $base $off $vect
		printf -v $out "0x%.4x" $ED0
	    elif [[ $am -eq 0xffffffff ]] ; then
		read16 ED0 $base $((off + 0)) $vect
		read16 ED1 $base $((off + 2)) $vect
		printf -v $out "0x%.4x%.4x" $ED1 $ED0
	    elif [[ $am -eq 0xffffffffffffffff ]] ; then
		read16 ED0 $base $((off + 0)) $vect
		read16 ED1 $base $((off + 2)) $vect
		read16 ED2 $base $((off + 4)) $vect
		read16 ED3 $base $((off + 6)) $vect
		printf -v $out "0x%.4x%.4x%.4x%.4x" $ED3 $ED2 $ED1 $ED0
	    fi
	    ;;
	seg)
	    # seg n (0=es, 1=cs, 2=ss, 3=ds)
	    case $cpu_type in
		80386)
		    local n=$((oparg[1] + 16))
		    printf -v $out $(getreg $n 0xffff)
		    ;;
		*)
		    local n=$(((oparg[1] & 0x3) + 16))
		    printf -v $out $(getreg $n 0xffff)
		    ;;
	    esac
	    ;;
	*)
	    printf -v $out 0x0
	    ;;
    esac
}

# set result value
execset() {
    local oparg=($1)
    local val=$2

    if [[ $fault -ne 99 ]] ; then
	echo "========= fault in execset [$fault]"
	return
    fi
#    printf "set:[${oparg[*]}] $val\n"
    case ${oparg[0]} in
	reg)
	    setreg ${oparg[1]} $val ${oparg[2]}
	    ;;
	mem)
	    # mem0 vect1 seg2 off3 mask4	
	    local base=${oparg[2]}
	    local off=${oparg[3]}
	    local am=${oparg[4]}
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
	    case $cpu_type in
		80386)
		    local n=$((oparg[1] + 16))
		    setreg $n $val 0xffff "seg"
		    ;;
		*)
		    local n=$(((oparg[1] & 3) + 16))
		    setreg $n $val 0xffff "seg"
		    ;;
	    esac
	    ;;
    esac
}

# Does a shift left, CF=msb, shift in lsb
shlop() {
    local out=$1 v=$2 msb=$3 lsb=$4
    CF=$(((v & msb) != 0))
    printf -v "$out" "0x%x" $(((v << 1) | lsb))
}

# Does a shift right, CF=lsb, shift in msb
shrop() {
    local out=$1 v=$2 msb=$3 lsb=$4
    CF=$(((v & lsb) != 0))
    printf -v "$out" "0x%x" $(((v >> 1) | msb))
}

shiftop() {
    local opfn=$1
    local s1="$2" s2="$3"
    execval v1 "$s1"
    execval count "$s2"
    local dest=$s1

    if [[ $fault -ne 99 ]] ; then
	echo "======== fault in shiftop [$fault]"
	return
    fi
    local cmask=0xfffffffff
    smask=$(execsz "$s1")
    if [[ $smask -eq 0xffffffffffffffff ]] ; then
	msb=0x8000000000000000
    else
	msb=$(printf "0x%x" $((smask - (smask >> 1))))
    fi
    printf "shift: $opfn %.4x %.4x %x %x\n" $v1 $count $smask $msb
    # no mask on 8088?
    (( count == 0 )) && return

    # run one loop per bit
    res=$v1
    for ((i=1; i<=count; i++)) ; do
	case $opfn in
	    ROL)
		shlop res $res $msb $(((res & msb) != 0))
		(( OF = CF ^ ((res & msb) != 0) ))
		;;
	    ROR)
		shrop res $res $(((res & 1) * msb)) 0x1
		(( OF = ((res ^ (res << 1)) & msb) != 0 ))
		;;
	    RCL)
		shlop res $res $msb $CF
		(( OF = CF ^ ((res & msb) != 0) ))
		;;
	    RCR)
		(( OF = CF ^ ((res & msb) != 0) ))
		shrop res $res $((CF * msb)) 0x1 
		;;
	    SHL)
		# shl ok
		shlop res $res $msb 0
		(( AF = ((res & 0x10) != 0 )))
		(( OF = CF ^ ((res & msb) != 0) ))
		;;
	    SHR)
		# shr ok
		AF=0
		OF=$(((res & msb) != 0))
		shrop res $res 0 1
		;;
	    SAL)
		# undocumented?? 
		res=0xffffffff
		OF=0
		CF=0
		;;
	    SAR)
		# SAR 1 ok
		AF=0
		OF=0
		shrop res $res $((res & msb)) 1
		;;
	esac
	res=$((res & smask))
	printf "shift... %x $CF $OF\n" $res
    done
    printf "result is:[$dest] [%d:%.4x] [%.4x] %.4x\n" $res $res $mask $msb
    case $opfn in
    SHL|SAL|SHR|SAR)
	ZF=$(((res & smask) == 0))
	SF=$(((res & msb) != 0))
	PF=$(parity $res)
	;;
    esac
    execset "$dest" $res
    return
}

# Run alu op
aluop() {
    local opfn=$1
    local s1="$2" s2="$3"
    execval v1 "$s1"
    execval v2 "$s2"
    local dest=$s1

    if [[ $fault -ne 99 ]] ; then
	echo "======== fault in aluop [$fault]"
	return
    fi
    local ncf=0
    res="0xdeadbeef"
    printf "alu: $opfn %.4x %.4x\n" $v1 $v2
    smask=$(execsz "$s1")
    if [[ $smask -eq 0xffffffffffffffff ]] ; then
	sgn=0x8000000000000000
    else
	sgn=$(printf "0x%x" $((smask - (smask >> 1))))
    fi
    case $opfn in
	ADD) res=$((v1 + v2)) ; ncf=1 ;;
	ADC) res=$((v1 + v2 + CF)) ; ncf=1 ;;
	SUB) res=$((v1 - v2)) ; ncf=2 ;;
	SBB) res=$((v1 - v2 - CF)) ; ncf=2 ;;
	INC) res=$((v1 + 1)) ; v2=1 ; ncf=3 ;;
	DEC) res=$((v1 - 1)) ; v2=1 ; ncf=4 ;;
	NEG) res=$((0 - v1)) v2=$v1 ; v1=0; ncf=2 ;;
	NOT) res=$((~v1)) ; ncf=6 ;; 
	AND) res=$((v1 & v2)) ;;
	XOR) res=$((v1 ^ v2)) ;;
	OR)  res=$((v1 | v2)) ;;
	TEST) dest="" ; res=$((v1 & v2)) ;;
	CMP)  dest="" ; res=$((v1 - v2)) ; ncf=2 ;;
    esac
    res=$((res & smask))
    execset "$dest" "$res"

    printf "result is:[$dest] [%d:%.4x] [%.4x] %.4x\n" $res $res $mask $sgn
    case $ncf in
	1)
	    # add/adc
	    AF=$(((v1 & 0xF) + (v2 & 0xF) > 0xF))
	    OF=$((((v1 ^ res) & (v2 ^ res) & sgn) != 0))
	    CF=$(((((v1 & v2) | (v1 & ~res) | (v2 & ~res)) & sgn) != 0))
	    ;;
	2)
	    # sub/sbb/neg
	    AF=$(((v1 & 0xF) < (v2 & 0xF)))
	    OF=$((((v1 ^ v2) & (v1 ^ res) & sgn) != 0))
	    CF=$(((((~v1 & v2) | ((~v1 | v2) & res)) & sgn) != 0))
	    ;;
	3)
	    # inc only sets OF
	    OF=$((((v1 ^ res) & (v2 ^ res) & sgn) != 0))
	    AF=$(((v1 & 0xF) == 0xF))
	    ;;
	4)
	    # dec only sets OF
	    OF=$((((v1 ^ v2) & (v1 ^ res) & sgn) != 0))
	    AF=$(((v1 & 0xF) == 0x0))
	    ;;
	6)
	    # not doesn't set flags
	    return
	    ;;
	0)
	    OF=0
	    CF=0
	    AF=0
	    ;;
    esac
    ZF=$((res == 0))
    SF=$(((res & sgn) != 0))
    PF=$(parity $res)
}

signex() {
    local out=$1 v=$2 mask=$3 sgn=$4
    v=$((v & mask))
    if [[ $(((v & sgn))) != 0 ]]; then
	v=$((v | ~mask))
    fi
    printf -v "$out" "0x%x" $v
}

mulfn() {
    local out=$1 TMPA=$2 TMPB=$3 opgrp
    local PROD=0

    CF=0
    PF=0
    SF=0
    ZF=0
    while [[ $TMPB -ne 0 ]]; do
	printf "loop %x %x %x\n" $PROD $TMPA $TMPB
	if [[ $((TMPB & 1)) != 0 ]] ; then
	    local R=$((PROD + TMPA))
	    CF=$((R > 0xffff))
	    
	    PROD=$((R & 0xffff))
	    setszp $PROD 0xffff
	    echo "parity $PF"
	fi
	TMPA=$(((TMPA << 1) & 0xffff))
	TMPB=$((TMPB >> 1))
    done
    printf "mul %x %x -> %x\n" $2 $3 $PROD
    CF=$(((PROD & 0xFF00) != 0))
    OF=$CF
    printf -v "$out" "0x%x" $PROD
}

# Execute an opcode
execop() {
    local opmrr=$1 opfn=$2 s1="$3" s2="$4" s3="$5"
    flags=""
    
    if [[ $opfn == JCC ]] ; then
	subop=$(((opmrr >> 8) & 0xF))
	cc=${ccond[$subop]:2}
	printf "jcc: $cc\n"
    else
	printf "opfn: $opfn\n"
    fi

    # get sign bit
    sgn=$(printf "0x%x" $((osize - (osize >> 1))))
    case $opfn in
	MOVS | LODS | STOS)
	    checkpg $s1
	    checkpg $s2
	    execval v1 "$s2"
	    printf "osize=$osize $v1\n"
	    execset "$s1" "$v1"
	    if [[ -n "$rep" ]] ; then
		local cx=$(getreg CX $osize)
		local pc=$(getreg IP $osize)
		if [[ $cx -ne 0 ]]; then
		    cx=$(((cx - 1) & $osize))
		    setreg CX $cx $osize "movs.cx"
		    if [[ $cx -ne 0 ]] ; then
		    	# decrease CX,PC and set prefix
			setreg IP $((pc - 1)) $osize "movs.pc"
			pfx=1
		    fi
		fi
	    fi
	    ;;
	CMPS | SCAS)
	    aluop CMP "$s1" "$s2"
	    echo "strop:CMPS $rep $ZF"
	    if [[ -n "$rep" ]]; then
		local cx=$(getreg CX $osize)
		local pc=$(getreg IP $osize)
		echo "inrep $rep"
		if [[ $cx -ne 0 ]]; then
		    cx=$(((cx - 1) & $osize))
		    setreg CX $cx $osize "cmps.cx"

		    # default to loop then turn off
		    pfx=1
		    [[ $cx -eq 0 ]] && pfx=0
		    [[ "$rep" == "repz" && $ZF == 0 ]] && pfx=0
		    [[ "$rep" == "repnz" && $ZF == 1 ]] && pfx=0
		    if [[ $pfx -ne 0 ]] ; then
			# if pfx set then decrease PC
			setreg IP $((pc - 1)) $osize "cmps.pc"
		    fi
		fi
	    fi
	    ;;
	MOV | MOVZX)
	    # easy. A=B
	    execval v1 "$s2"
	    execset "$s1" "$v1"
	    ;;
	MOVSX)
	    execval v1 "$s2"
	    opgrp=$((opmrr & 0xFFFF00))
	    if [[ $opgrp -eq 0xfbe00 ]] ; then
		signex v1 $v1 0xff 0x80
	    fi
	    if [[ $opgrp -eq 0x0fbf00 ]] ; then
		signex v1 $v1 0xffff 0x8000
	    fi
	    printf "moo 0x%x 0x%x\n" $opgrp $v1
	    execset "$s1" "$v1"
	    ;;
	ADD|OR|ADC|SBB|AND|SUB|XOR|CMP|\
	    TEST|INC|DEC|NEG|NOT)
	    aluop $opfn "$s1" "$s2"
	    ;;
	ROL|ROR|RCL|RCR|SHL|SHR|SAL|SAR)
	    shiftop $opfn "$s1" "$s2"
	    ;;
	SETMO)
	    execval v1 "$s1"
	    execval v2 "$s2"
	    printf "setmo $v1 $v2"
	    CF=0
	    AF=0
	    OF=0
	    setszp 0xff 0xff
	    execset "$s1" -1
	    ;;
	IMUL)
	    opgrp=$((opmrr & 0xFFF00))
	    printf "opgrp %x\n" $opgrp
	    if (( $opgrp == 0xfaf00 )) ; then
		# imul Gv = Gv * Ev
		execval v1 "$s1"
		execval v2 "$s2"
		signex v1 "$v1" $osize $sgn
		signex v2 "$v2" $osize $sgn
		printf "imul3 %x %x %x %x\n" $v1 $v2 $osize $sgn
		res=$((v1 * v2))
		execset "$s1" "$res"
	    fi
	    if (( $opgrp == 0x6900 )) ; then
		# imul Gv =  Ev * Iv
		execval v1 "$s2"
		execval v2 "$s3"
		signex v1 "$v1" $osize $sgn
		signex v2 "$v2" $osize $sgn
		printf "imul69 %x %x %x %x\n" $v1 $v2 $osize $sgn
		res=$((v1 * v2))
		execset "$s1" "$res"
	    fi
	    if (( $opgrp == 0x6B00 )) ; then
		# imul Gv =  Ev * Ib
		execval v1 "$s2"
		execval v2 "$s3"
		signex v1 "$v1" $osize $sgn
		signex v2 "$v2" 0xff 0x80
		printf "imul6B %x %x %x %x\n" $v1 $v2 $osize $sgn
		res=$((v1 * v2))
		execset "$s1" "$res"
	    fi
	    if (( $opgrp == 0xf600 )) ; then
		# mul/imul ax = al * Eb
		v1=$(getreg 0 0xff)
		execval v2 "$s1"
		signex v1 "$v1" 0xff 0x80
		signex v2 "$v2" 0xff 0x80
		res=$((v1 * v2))
		printf "@@F6 $opfn %x %x -> %x\n" $v1 $v2 $res
		setreg 0 $res 0xffff
		ZF=$(((res & 0xFFFF) == 0))
		SF=$(((res & 0x8000) != 0))
		CF=$(( $res > 0xFF ))
		OF=CF
	    fi
	    if (( $opgrp == 0xf700 )) ; then
		# mul/imul vdx:vax = vax * Ev
		v1=$(getreg 0 $osize)
		execval v2 "$s1"
		signex v1 "$v1" 0xffff 0x8000
		signex v2 "$v2" 0xffff 0x8000
		res=$((v1 * v2))
		printf "@@F7 $opfn %x %x -> %x\n" $v1 $v2 $res
		setreg 0 $res $osize
		ZF=$(((res & osize) == 0))
		case $osize in
		    0xffff)
			setreg 2 $((res >> 16)) 0xffff
			SF=$(((res & 0x80000000) != 0))
			CF=$(( $res > 0xFFFF ))
			OF=CF
			;;
		    0xffffffff)
			setreg 2 $((res >> 32)) $osize
			SF=$(((res & 0x8000000000000000) != 0))
			CF=$(( $res > 0xFFFFFFFF ))
			OF=CF
			;;
		esac
	    fi
	    ;;
	MUL)
	    opgrp=$((opmrr & 0xFFF00))
	    printf "opgrp %x\n" $opgrp
	    if (( $opgrp == 0xf600 )) ; then
		# mul/imul ax = al * Eb
		v1=$(getreg 0 0xff)
		execval v2 "$s1"
		mulfn res $v1 $v2 0xff
		setreg 0 $res 0xffff
	    fi
	    if (( $opgrp == 0xf700 )) ; then
		# mul/imul vdx:vax = vax * Ev
		v1=$(getreg 0 $osize)
		execval v2 "$s1"
		mulfn res $v1 $v2 $osize
	    fi
	    printf "mul [%x] [%x] -> %x\n" $v1 $v2 $res
	    ;;
	DIV)
	    opgrp=$((opmrr & 0xFF00))
	    execval v2 "$s1"
	    if [[ $opgrp -eq 0xF600 ]]; then
		# AH = AX % Eb
		# AL = AX / Eb
		local ax=$(getreg AX 0xffff)
		local res=$((ax / v2))
		setreg SP $((ax % v2)) 0xff
		setreg 0 $res 0xff
		echo "div"
	    fi
	    if [[ $opgrp -eq 0xF700 ]]; then
		# DX = DX:AX % Ev
		# AX = DX:AX / Ev
		local ax=$(getreg AX 0xffff)
		local dx=$(getreg DX 0xffff)
		local dax=$(((dx << 16) + ax))
		local res=$((dax / v2))
		setreg 2 $((dax % v2)) 0xffff
		setreg 0 $res 0xffff
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
	    setreg IP $v1 $osize "ret.pc"
	    # ret Iw
	    execval v1 "$s1"
	    if [[ $v1 -ne 0 ]]; then
		local sp=$(getreg SP $osize)
		setreg SP $((sp + v1)) $osize
	    fi
	    ;;
	RETF)
	    popv co
	    popv cs
	    setreg IP co $osize "retf.pc"
	    setreg CS cs 0xffff "retf.cs"
	    # retf Iw
	    execval v1 "$s1"
	    if [[ $v1 -ne 0 ]]; then
		local sp=$(getreg SP $osize)
		setreg SP $((sp + v1)) $osize
	    fi
	    ;;
	CALL)
	    execval arg "$s1"
	    pushv $(getreg IP $osize) $osize
	    setreg IP $arg $osize "call.pc"
	    ;;
	CALLF)
	    loadptr cseg coff "$s1"
	    pushv $(getreg CS 0xffff) 0xffff # push cs
	    pushv $(getreg IP 0xffff) 0xffff # push ip
	    setreg CS $cseg 0xffff "callf.cs"
	    setreg IP $coff $osize "callf.pc"
	    ;;
	JMP)
	    execval arg "$s1"
	    setreg IP $arg 0xffff "jmp.pc"
	    ;;
	JMPF)
	    loadptr cseg coff "$s1"
	    if [[ $fault -ne 99 ]]; then
		echo "========= fault in jmpf [$fault]"
		return
	    fi
	    setreg CS $cseg 0xffff "jmpf.cs"
	    setreg IP $coff $osize "jmpf.pc"
	    ;;
	JCC)
	    testcond $((opmrr >> 8))
	    if [ $? = 0 ]; then
		execval arg "$s1"
		setreg IP $arg $osize "jcc.pc"
	    fi
	    ;;
	SETCC)
	    testcond $((opmrr >> 8))
	    rc=$?
	    execset "$s1" $((1-rc))
	    ;;
	LDS | LES | LSS | LFS | LGS)
	    local oparg=($s2)
	    local pseg=${oparg[2]}
	    local pofs=${oparg[3]}
	    if [[ $osize -eq 0xffff ]]; then
		echo "o16"
		read16 coff $pseg $pofs
		read16 cseg $pseg $((pofs + 2))
	    fi
	    if [[ $osize -eq 0xffffffff ]]; then
		read16 cofL $pseg $pofs
		read16 cofH $pseg $((pofs + 2))
		read16 cseg $pseg $((pofs + 4))
		coff=$(((cofH << 16) + cofL))
	    fi
	    echo "read pointer $pseg $pofs $cseg $coff $fault"
	    if [[ $fault -ne 99 ]]; then
		echo "===== fault in lds/les [$fault]"
		return
	    fi
	    case $opfn in
		LES | LSS | LDS | LFS | LGS)
		    # hack use subst for segname
		    setreg ${opfn:1:2} $cseg 0xffff
		    ;;
	    esac
	    execset "$s1" $coff
	    ;;
	LOOP | LOOPZ | LOOPNZ)
	    execval lz "$s1"
	    local cx=$(getreg CX $asize)
	    local pc=$(getreg IP $osize)
	    cx=$(((cx - 1) & $asize))
	    setreg CX $cx $asize
	    if (( $cx == 0 )) ; then
		return
	    fi
	    case $opfn in
		LOOP)
		    setreg IP $lz $osize "loop"
		    ;;
		LOOPZ)
		    (( ZF == 1 )) && setreg IP $lz $osize "loopz"
		    ;;
		LOOPNZ)
		    (( ZF == 0 )) && setreg IP $lz $osize "loopnz"
		    ;;
	    esac
	    ;;
	JCXZ)
	    execval lz "$s1"
	    local cx=$(getreg CX $asize)
	    local pc=$(getreg IP $osize)
	    if (( $cx == 0 )); then
		setreg IP $lz $osize "jcxz"
	    fi
	    ;;
	XCHG)
	    execval v1 "$s1"
	    execval v2 "$s2"
	    execset "$s1" "$v2"
	    execset "$s2" "$v1"
	    ;;
	OSZ)
	    # operand size prefix
	    pfx=1
	    osize=0xffffffff
	    ;;
	ASZ)
	    # address size prefix
	    pfx=1
	    asize=0xffffffff
	    ;;
	SEG)
	    # segment override prefix
	    pfx=1
	    seg="$s1"
	    ;;
	REP)
	    pfx=1
	    rep="$s1"
	    ;;
	LOCK)
	    printf "lock pc: %x\n" $(getreg IP 0xffff)
	    pfx=1
	    lock=1
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
	    if [ $(($ax & $sgn)) != 0 ]; then
		# if AX is signed, then set DX=-1
		setreg 2 0xffffffff $osize
	    else
		setreg 2 0 $osize
	    fi
	    ;;
	PUSH)
	    execval v1 "$s1"
	    if [[ "$s1" == "reg 4 "* && $cpu_type == 8088 ]] ; then
		# SP decrements then pushes itself
		printf "special sp\n"
		v1=$((v1 - 2))
	    fi
	    pushv $v1 $osize
	    ;;
	POP)
	    popv v1 
	    printf "popping.... $v1\n"
	    execset "$s1" $v1
	    ;;
	LAHF)
	    local ah=$(((SF << 7) | (ZF << 6) | (AF << 4) | (PF << 2) | 0x2 | CF))
	    setreg SP $ah 0xff
	    ;;
	PUSHF)
	    setflags
	    pushv ${X86_REGS[14]} $osize
	    ;;
	POPF)
	    popv v1
	    printf "set flags %x\n" $v1
	    setreg FLAGS $v1 0xfd5
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
	    execval v1 "$s1"
	    vector $v1 ${X86_REGS[15]}
	    ;;
	INTO)
	    (( OF == 1 )) && vector 0x4 ${X86_REGS[15]}
	    ;;
	IRET)
	    popv npc
	    popv ncs
	    popv nflag
	    setreg IP $npc $osize "iret"
	    setreg CS $ncs 0xffff
	    setreg FLAGS $nflag 0xfd5
	    getflags
	    ;;
	XLAT)
	    # al=seg:[bx+al]
	    local v1=$(getreg BX 0xffff)
	    local v2=$(getreg 0 0xff)
	    local xoff=$(((v1 + v2) & 0xffff))
	    getseg xseg "seg 3" "$seg" "xlat"
	    xs=($xseg)
	    printf "xlat: vbx:%x al:%x |bx+al%d |$xseg\n" $v1 $v2 $xoff
	    read8 XL ${xs[1]} $xoff
	    setreg 0 $XL 0xff
	    ;;
	SALC)
	    # AL=00 or FF depending on Carry
	    setreg 0 $((CF*255)) 0xff
	    ;;
	IN)
	    # hack return set bits
	    execset "$s1" 0xffffffff
	    ;;
	LEA)
	    # s1 = Gv
	    # s2 = Mp [mem vect seg off mask mm rrr]
	    local lea=($s2)
	    execset "$s1" ${lea[3]}
	    ;;
	AAA) # 37
	    al=$(getreg 0 0xff)
	    ah=$(getreg 4 0xff)
	    printf "aaa: %.2x %.2x\n" $ah $al
	    if (( ((al & 0xF) > 9 || AF == 1 ) )); then
		setreg 4 $((ah + 1)) 0xff
		res=$(((al + 6) & 0xff))
		OF=$(( (~(al ^ 6) & (al ^ res) & 0x80) != 0 ))
		AF=1
		CF=1
	    else
		res=$al
		OF=0
		AF=0
		CF=0
	    fi
	    setszp $res 0xff
	    setreg 0 $((res & 0xF)) 0xff
	    ;;
	AAS) # 3F
	    al=$(getreg 0 0xff)
	    ah=$(getreg 4 0xff)
	    printf "aas: %.2x %.2x\n" $ah $al
	    if (( ((al & 0xF) > 9 || AF == 1 ) )) ; then
		setreg 4 $((ah - 1)) 0xff
		res=$(((al - 6) & 0xff))
		OF=$(( ((al ^ 6) & (al ^ res) & 0x80) != 0 ))
		AF=1
		CF=1
	    else
		res=$al
		OF=0
		AF=0
		CF=0
	    fi
	    setszp $res 0xff
	    setreg 0 $((res & 0xF)) 0xff
	    ;;
	AAM)
	    al=$(getreg 0 0xff)
	    fl=$(getreg FLAGS 0xffff)
	    execval v1 "$s1"
	    echo "AAM $al $v1 $fl"
	    AF=0
	    OF=0
	    CF=0
	    if (( v1 == 0 )); then
		setszp 0x0 0xff
		pc=$(getreg IP $osize)
		vector 0 $pc
	    else 
		res=$((al % v1))
		setszp $res 0xff
		setreg 0 $res 0xff
		setreg 4 $((al / v1)) 0xff
	    fi
	    ;;
	AAD)
	    al=$(getreg 0 0xff)
	    ah=$(getreg 4 0xff)
	    execval v1 "$s1"
	    ores=$(((ah * v1) & 0xff))
	    res=$((ores + al))
	    CF=$((res > 0xff))
	    AF=$(((ores & 0xF) + (al & 0xF) > 9))
	    OF=$(((~(ores ^ al) & (ores ^ res) & 0x80) != 0 )) 
	    printf "aad %x %x %x [ %x -> %x]\n" $ah $al $v1 $ores $res

	    setszp $res 0xff
	    setreg 0 $((res & 0xff)) 0xffff
	    ;;
	DAA) # 27
	    ;;
	DAS) # 2F
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
    local op3="${X86_OP3[$opcode]}"
    
    # create opcode << 8 + mrr byte
    if [[ ${X86_ENC[$opcode]} == MRR ]] ; then
	fetch8 IR
	opmrr=$((opmrr + $IR))
    fi
    pc=$(getreg IP $osize)
    printf "==== %.8x %.4x $opfn $op1 $op2 asz:$asize osz:$osize seg:$seg lock:$lock\n" $pc $opmrr
    # get ggg from MRR for decoding op group
    if [[ $opfn == GRP* ]]; then
	subop=$(((opmrr >> 3) & 7))
	case $opfn in
	    GRP1) opfn=${grp1[$subop]} ;;
	    GRP2) opfn=${grp2[$subop]} ;;
	    GRP3) opfn=${grp3[$subop]} ;;
	    GRP4) opfn=${grp4[$subop]} ;;
	    GRP5) opfn=${grp5[$subop]} ;;
	    GRP7) opfn=${grp7[$subop]} ;;
	    GRP8) opfn=${grp8[$subop]} ;;
	esac
	# Handle group difference oparg
	local submrr=$((opmrr & 0xFF38))
	printf "new sub: <${X86_OP1[$submrr]}> <${X86_OP2[$submrr]}> %x\n" $submrr
	if [ -n "${X86_OP1[$submrr]}" ] ; then
	    op1="${X86_OP1[$submrr]}"
	fi
	if [ -n "${X86_OP2[$submrr]}" ] ; then
	    op2="${X86_OP2[$submrr]}"
	fi
    fi
    m3=""

    # Check fault reg lock
    if [[ $lock -ne 0 && $op1 == G* ]] ; then
	printf "fault reg lock"
	fault=0x6
	return
    fi
    # Check LOCK
    if [[ $lock -ne 0 ]] ; then
	echo "===== lockme $opfn"
	case $opfn in
	    SEG | ASZ | OSZ)
		;;
	    BT | BTS | BTR | BTC | ADD | OR | ADC | SBB | AND | SUB | XOR | NOT | NEG | INC | DEC | XCHG)
		if [[ ${X86_ENC[$opcode]} == MRR ]] ; then
		    printf "opmrr: %x\n" $opmrr
		    if [[ $(((opmrr >> 6) & 3)) == 3 ]] ; then 
			echo "NOT MEM [$s1] [$op1]"
			fault=0x6
			return
		    fi
		else
		    echo "NOT MEM [$s1] [$op1]"
		    fault=0x6
		    return
		fi
		;;
	    *)
		printf "=== lock fault\n"
		fault=0x6
		return
		;;
	esac
    fi
    decarg m1 $opmrr $op1 $osize
    decarg m2 $opmrr $op2 $osize
    decarg m3 $opmrr $op3 $osize
    printf "[$m1] [$m2] [$m3]\n"
    if [[ $fault -ne 99 ]] ; then
	printf "=============== fault in args: $fault\n"
	return
    fi
    execop $opmrr $opfn "$m1" "$m2" "$m3"
    if [[ $fault -ne 99 ]] ; then
	printf "=============== fault in exec: $fault\n"
	return
    fi
    pc=$(getreg IP 0xffff)
    setreg IP $pc 0xfffff "post-exec"
    if [ -z $opfn ]; then
	echo "--- missing"
    fi
}
