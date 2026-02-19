# bash_x86

This is a toy emulator for x86 written in Bash.  It's about as slow as you can imagine....

The script works well enough to pass many of the tests from:
https://github.com/SingleStepTests/8088/tree/main/v2

eg run ./86json.sh 00.json

| Opcode | Status | Mnemonic |
| ------ | ------ | -------- |
| 00 | ✅ Pass | 00 ADD Eb Gb |
| 01 | ✅ Pass | 01 ADD Ev Gv |
| 02 | ✅ Pass | 02 ADD Gb Eb |
| 03 | ✅ Pass | 03 ADD Gv Ev |
| 04 | ✅ Pass | 04 ADD rAL Ib |
| 05 | ✅ Pass | 05 ADD rvAX Iv |
| 06 | ✅ Pass | 06 PUSH rES  |
| 07 | ✅ Pass | 07 POP rES  |
| 08 | ✅ Pass | 08 OR Eb Gb |
| 09 | ✅ Pass | 09 OR Ev Gv |
| 0A | ✅ Pass | 0A OR Gb Eb |
| 0B | ✅ Pass | 0B OR Gv Ev |
| 0C | ✅ Pass | 0C OR rAL Ib |
| 0D | ✅ Pass | 0D OR rvAX Iv |
| 0E | ✅ Pass | 0E PUSH rCS  |
| 10 | ✅ Pass | 10 ADC Eb Gb |
| 11 | ✅ Pass | 11 ADC Ev Gv |
| 12 | ✅ Pass | 12 ADC Gb Eb |
| 13 | ✅ Pass | 13 ADC Gv Ev |
| 14 | ✅ Pass | 14 ADC rAL Ib |
| 15 | ✅ Pass | 15 ADC rvAX Iv |
| 16 | ✅ Pass | 16 PUSH rSS  |
| 17 | ✅ Pass | 17 POP rSS  |
| 18 | ✅ Pass | 18 SBB Eb Gb |
| 19 | ✅ Pass | 19 SBB Ev Gv |
| 1A | ✅ Pass | 1A SBB Gb Eb |
| 1B | ✅ Pass | 1B SBB Gv Ev |
| 1C | ✅ Pass | 1C SBB rAL Ib |
| 1D | ✅ Pass | 1D SBB rvAX Iv |
| 1E | ✅ Pass | 1E PUSH rDS  |
| 1F | ✅ Pass | 1F POP rDS  |
| 20 | ✅ Pass | 20 AND Eb Gb |
| 21 | ✅ Pass | 21 AND Ev Gv |
| 22 | ✅ Pass | 22 AND Gb Eb |
| 23 | ✅ Pass | 23 AND Gv Ev |
| 24 | ✅ Pass | 24 AND rAL Ib |
| 25 | ✅ Pass | 25 AND rvAX Iv |
| 27 | ❌ Fail | 27 DAA   |
| 28 | ✅ Pass | 28 SUB Eb Gb |
| 29 | ✅ Pass | 29 SUB Ev Gv |
| 2A | ✅ Pass | 2A SUB Gb Eb |
| 2B | ✅ Pass | 2B SUB Gv Ev |
| 2C | ✅ Pass | 2C SUB rAL Ib |
| 2D | ✅ Pass | 2D SUB rvAX Iv |
| 2F | ❌ Fail | 2F DAS   |
| 30 | ✅ Pass | 30 XOR Eb Gb |
| 31 | ✅ Pass | 31 XOR Ev Gv |
| 32 | ✅ Pass | 32 XOR Gb Eb |
| 33 | ✅ Pass | 33 XOR Gv Ev |
| 34 | ✅ Pass | 34 XOR rAL Ib |
| 35 | ✅ Pass | 35 XOR rvAX Iv |
| 37 | ✅ Pass | 37 AAA   |
| 38 | ✅ Pass | 38 CMP Eb Gb |
| 39 | ✅ Pass | 39 CMP Ev Gv |
| 3A | ✅ Pass | 3A CMP Gb Eb |
| 3B | ✅ Pass | 3B CMP Gv Ev |
| 3C | ✅ Pass | 3C CMP rAL Ib |
| 3D | ✅ Pass | 3D CMP rvAX Iv |
| 3F | ✅ Pass | 3F AAS   |
| 40 | ✅ Pass | 40 INC gv  |
| 41 | ✅ Pass | 41 INC gv  |
| 42 | ✅ Pass | 42 INC gv  |
| 43 | ✅ Pass | 43 INC gv  |
| 44 | ✅ Pass | 44 INC gv  |
| 45 | ✅ Pass | 45 INC gv  |
| 46 | ✅ Pass | 46 INC gv  |
| 47 | ✅ Pass | 47 INC gv  |
| 48 | ✅ Pass | 48 DEC gv  |
| 49 | ✅ Pass | 49 DEC gv  |
| 4A | ✅ Pass | 4A DEC gv  |
| 4B | ✅ Pass | 4B DEC gv  |
| 4C | ✅ Pass | 4C DEC gv  |
| 4D | ✅ Pass | 4D DEC gv  |
| 4E | ✅ Pass | 4E DEC gv  |
| 4F | ✅ Pass | 4F DEC gv  |
| 50 | ✅ Pass | 50 PUSH gv  |
| 51 | ✅ Pass | 51 PUSH gv  |
| 52 | ✅ Pass | 52 PUSH gv  |
| 53 | ✅ Pass | 53 PUSH gv  |
| 54 | ✅ Pass | 54 PUSH gv  |
| 55 | ✅ Pass | 55 PUSH gv  |
| 56 | ✅ Pass | 56 PUSH gv  |
| 57 | ✅ Pass | 57 PUSH gv  |
| 58 | ✅ Pass | 58 POP gv  |
| 59 | ✅ Pass | 59 POP gv  |
| 5A | ✅ Pass | 5A POP gv  |
| 5B | ✅ Pass | 5B POP gv  |
| 5C | ✅ Pass | 5C POP gv  |
| 5D | ✅ Pass | 5D POP gv  |
| 5E | ✅ Pass | 5E POP gv  |
| 5F | ✅ Pass | 5F POP gv |
| 60 | ✅ Pass | 60 PUSHA |
| 61 | ✅ Pass | 61 POPA |
| 62 | ✅ Pass | 62 BOUND |
| 63 | ✅ Pass | 63 ARPL |
| 64 | ✅ Pass | 64 SEG FS |
| 65 | ✅ Pass | 65 SEG GS |
| 66 | ✅ Pass | none |
| 67 | ✅ Pass | none |
| 68 | ✅ Pass | none |
| 69 | ✅ Pass | none |
| 6A | ✅ Pass | none |
| 6B | ✅ Pass | none |
| 6C | ✅ Pass | 6C INS Yb rDX |
| 6D | ✅ Pass | 6D INS Yv rDX |
| 6E | ✅ Pass | 6E OUTS rDX Xb |
| 6F | ✅ Pass | 6F OUTS rDX Xv |
| 70 | ✅ Pass | 70 JCC Jb  |
| 71 | ✅ Pass | 71 JCC Jb  |
| 72 | ✅ Pass | 72 JCC Jb  |
| 73 | ✅ Pass | 73 JCC Jb  |
| 74 | ✅ Pass | 74 JCC Jb  |
| 75 | ✅ Pass | 75 JCC Jb  |
| 76 | ✅ Pass | 76 JCC Jb  |
| 77 | ✅ Pass | 77 JCC Jb  |
| 78 | ✅ Pass | 78 JCC Jb  |
| 79 | ✅ Pass | 79 JCC Jb  |
| 7A | ✅ Pass | 7A JCC Jb  |
| 7B | ✅ Pass | 7B JCC Jb  |
| 7C | ✅ Pass | 7C JCC Jb  |
| 7D | ✅ Pass | 7D JCC Jb  |
| 7E | ✅ Pass | 7E JCC Jb  |
| 7F | ✅ Pass | 7F JCC Jb  |
| 80.0 | ✅ Pass | 80.0 ADD Eb Ib |
| 80.1 | ✅ Pass | 80.1 OR Eb Ib |
| 80.2 | ✅ Pass | 80.2 ADC Eb Ib |
| 80.3 | ✅ Pass | 80.3 SBB Eb Ib |
| 80.4 | ✅ Pass | 80.4 AND Eb Ib |
| 80.5 | ✅ Pass | 80.5 SUB Eb IB |
| 80.6 | ✅ Pass | 80.6 XOR Eb Ib |
| 80.7 | ✅ Pass | 80.7 CMP Eb Ib |
| 81.0 | ✅ Pass | 81.0 ADD Ev Iv |
| 81.1 | ✅ Pass | 81.1 OR Ev Iv |
| 81.2 | ✅ Pass | 81.2 ADC Ev Iv |
| 81.3 | ✅ Pass | 81.3 SBB Ev Iv |
| 81.4 | ✅ Pass | 81.4 AND Ev Iv |
| 81.5 | ✅ Pass | 81.5 SUB Eb IB |
| 81.6 | ✅ Pass | 81.6 XOR Ev Iv |
| 81.7 | ✅ Pass | 81.7 CMP Ev Iv |
| 82.0 | ✅ Pass | 82.0 ADD Eb Ib |
| 82.1 | ✅ Pass | 82.1 OR Eb Ib |
| 82.2 | ✅ Pass | 82.2 ADC Eb Ib |
| 82.3 | ✅ Pass | 82.3 SBB Eb Ib |
| 82.4 | ✅ Pass | 82.4 AND Eb Ib |
| 82.5 | ✅ Pass | 82.5 SUB Eb IB |
| 82.6 | ✅ Pass | 82.6 XOR Eb Ib |
| 82.7 | ✅ Pass | 82.7 CMP Eb Ib |
| 83.0 | ✅ Pass | 83.0 ADD Ev Sb |
| 83.1 | ✅ Pass | 83.1 OR Ev Sb |
| 83.2 | ✅ Pass | 83.2 ADC Ev Sb |
| 83.3 | ✅ Pass | 83.3 SBB Ev Sb |
| 83.4 | ✅ Pass | 83.4 AND Ev Sb |
| 83.5 | ✅ Pass | 83.5 SUB Eb IB |
| 83.6 | ✅ Pass | 83.6 XOR Ev Sb |
| 83.7 | ✅ Pass | 83.7 CMP Ev Sb |
| 84 | ✅ Pass | 84 TEST Gb Eb |
| 85 | ✅ Pass | 85 TEST Gv Ev |
| 86 | ✅ Pass | 86 XCHG Gb Eb |
| 87 | ✅ Pass | 87 XCHG Gv Ev |
| 88 | ✅ Pass | 88 MOV Eb Gb |
| 89 | ✅ Pass | 89 MOV Ev Gv |
| 8A | ✅ Pass | 8A MOV Gb Eb |
| 8B | ✅ Pass | 8B MOV Gv Ev |
| 8C | ✅ Pass | 8C MOV Ew Sw |
| 8D | ✅ Pass | 8D LEA Gv Mp |
| 8E | ✅ Pass | 8E MOV Sw Ew |
| 8F | ✅ Pass | 8F POP Ev __ |
| 90 | ✅ Pass | 90 NOP   |
| 91 | ✅ Pass | 91 XCHG gv rvAX |
| 92 | ✅ Pass | 92 XCHG gv rvAX |
| 93 | ✅ Pass | 93 XCHG gv rvAX |
| 94 | ✅ Pass | 94 XCHG gv rvAX |
| 95 | ✅ Pass | 95 XCHG gv rvAX |
| 96 | ✅ Pass | 96 XCHG gv rvAX |
| 97 | ✅ Pass | 97 XCHG gv rvAX |
| 98 | ✅ Pass | 98 CBW   |
| 99 | ✅ Pass | 99 CWD   |
| 9A | ✅ Pass | 9A CALL Ap  |
| 9C | ✅ Pass | 9C PUSHF   |
| 9D | ✅ Pass | 9D POPF   |
| 9E | ✅ Pass | 9E SAHF   |
| 9F | ✅ Pass | 9F LAHF   |
| A0 | ✅ Pass | A0 MOV rAL Ob |
| A1 | ✅ Pass | A1 MOV rvAX Ov |
| A2 | ✅ Pass | A2 MOV Ob rAL |
| A3 | ✅ Pass | A3 MOV Ov rvAX |
| A4 | ✅ Pass | A4 MOVS Yb Xb |
| A5 | ✅ Pass | A5 MOVS Yv Xv |
| A6 | ✅ Pass | A6 CMPS Xb Yb |
| A7 | ✅ Pass | A7 CMPS Xv Yv |
| A8 | ✅ Pass | A8 TEST rAL Ib |
| A9 | ✅ Pass | A9 TEST rvAX Iv |
| AA | ✅ Pass | AA STOS Yb rAL |
| AB | ✅ Pass | AB STOS Yv rvAX |
| AC | ✅ Pass | AC LODS rAL Xb |
| AD | ✅ Pass | AD LODS rvAX Xv |
| AE | ✅ Pass | AE SCAS rAL Yb |
| AF | ✅ Pass | AF SCAS rvAX Yv |
| B0 | ✅ Pass | B0 MOV gb Ib |
| B1 | ✅ Pass | B1 MOV gb Ib |
| B2 | ✅ Pass | B2 MOV gb Ib |
| B3 | ✅ Pass | B3 MOV gb Ib |
| B4 | ✅ Pass | B4 MOV gb Ib |
| B5 | ✅ Pass | B5 MOV gb Ib |
| B6 | ✅ Pass | B6 MOV gb Ib |
| B7 | ✅ Pass | B7 MOV gb Ib |
| B8 | ✅ Pass | B8 MOV gv Iv |
| B9 | ✅ Pass | B9 MOV gv Iv |
| BA | ✅ Pass | BA MOV gv Iv |
| BB | ✅ Pass | BB MOV gv Iv |
| BC | ✅ Pass | BC MOV gv Iv |
| BD | ✅ Pass | BD MOV gv Iv |
| BE | ✅ Pass | BE MOV gv Iv |
| BF | ✅ Pass | BF MOV gv Iv |
| D0.0 | ✅ Pass | D0.0 ROL Eb i1 |
| D0.1 | ✅ Pass | D0.1 ROR Eb i1 |
| D0.2 | ✅ Pass | D0.2 RCL Eb i1 |
| D0.3 | ✅ Pass | D0.3 RCR Eb i1 |
| D0.4 | ✅ Pass | D0.4 SHL Eb i1 |
| D0.5 | ✅ Pass | D0.5 SHR Eb i1 |
| D0.6 | ✅ Pass | D0.6 SAL Eb i1 |
| D0.7 | ✅ Pass | D0.7 SAR Eb i1 |
| D1.0 | ✅ Pass | D1.0 ROL Ev i1 |
| D1.1 | ✅ Pass | D1.1 ROR Ev i1 |
| D1.2 | ✅ Pass | D1.2 RCL Ev i1 |
| D1.3 | ✅ Pass | D1.3 RCR Ev i1 |
| D1.4 | ✅ Pass | D1.4 SHL Ev i1 |
| D1.5 | ✅ Pass | D1.5 SHR Ev i1 |
| D1.6 | ✅ Pass | D1.6 SAL Ev i1 |
| D1.7 | ✅ Pass | D1.7 SAR Ev i1 |
| D2.0 | ✅ Pass | D2.0 ROL Eb rCL |
| D2.1 | ✅ Pass | D2.1 ROR Eb rCL |
| D2.2 | ✅ Pass | D2.2 RCL Eb rCL |
| D2.3 | ✅ Pass | D2.3 RCR Eb rCL |
| D2.4 | ✅ Pass | D2.4 SHL Eb rCL |
| D2.5 | ✅ Pass | D2.5 SHR Eb rCL |
| D2.6 | ✅ Pass | D2.6 SAL Eb rCL |
| D2.7 | ✅ Pass | D2.7 SAR Eb rCL |
| D3.0 | ✅ Pass | D3.0 ROL Ev rCL |
| D3.1 | ✅ Pass | D3.1 ROR Ev rCL |
| D3.2 | ✅ Pass | D3.2 RCL Ev rCL |
| D3.3 | ✅ Pass | D3.3 RCR Ev rCL |
| D3.4 | ✅ Pass | D3.4 SHL Ev rCL |
| D3.5 | ✅ Pass | D3.5 SHR Ev rCL |
| D3.6 | ✅ Pass | D3.6 SAL Ev rCL |
| D3.7 | ✅ Pass | D3.7 SAR Ev rCL |
| D4 | ✅ Pass | D4 AAM Ib  |
| D5 | ❌ Fail | D5 AAD Ib  |
| D6 | ✅ Pass | D6 SALC   |
| D7 | ✅ Pass | D7 XLAT   |
| D8 | ✅ Pass | none |
| D9 | ✅ Pass | none |
| DA | ✅ Pass | none |
| DB | ✅ Pass | none |
| DC | ✅ Pass | none |
| DD | ✅ Pass | none |
| DE | ✅ Pass | none |
| DF | ✅ Pass | none |
| E0 | ✅ Pass | E0 LOOPNZ Jb  |
| E1 | ✅ Pass | E1 LOOPZ Jb  |
| E2 | ✅ Pass | E2 LOOP Jb  |
| E3 | ✅ Pass | E3 JCXZ Jb  |
| E4 | ✅ Pass | E4 IN rAL Ib |
| E5 | ✅ Pass | E5 IN rvAX Ib |
| E6 | ✅ Pass | E6 OUT Ib rAL |
| E7 | ✅ Pass | E7 OUT Iv rvAX |
| E8 | ✅ Pass | E8 CALL Jv  |
| E9 | ✅ Pass | E9 JMP Jv  |
| EA | ✅ Pass | EA JMP Ap  |
| EB | ✅ Pass | EB JMP Jb  |
| EC | ✅ Pass | EC IN rAL rDX |
| ED | ✅ Pass | ED IN rvAX rDX |
| EE | ✅ Pass | EE OUT rDX rAL |
| EF | ✅ Pass | EF OUT rDX rvAX |
| F5 | ✅ Pass | F5 CMC   |
| F6.0 | ✅ Pass | F6.0 TEST Eb Ib |
| F6.1 | ✅ Pass | F6.1 TEST Eb Ib |
| F6.2 | ✅ Pass | F6.2 NOT Eb |
| F6.3 | ✅ Pass | F6.3 NEG Eb |
| F6.4 | ❌ Fail | F6.4 MUL Eb |
| F6.5 | ❌ Fail | F6.5 IMUL Eb |
| F6.6 | ❌ Fail | F6.6 DIV Eb |
| F6.7 | ❌ Fail | F6.7 IDIV Eb |
| F7.0 | ✅ Pass | F7.0 TEST Ev Iv |
| F7.1 | ✅ Pass | F7.1 TEST Ev Iv |
| F7.2 | ✅ Pass | F7.2 NOT Ev |
| F7.3 | ✅ Pass | F7.3 NEG Ev |
| F7.4 | ❌ Fail | F7.4 MUL Ev |
| F7.5 | ❌ Fail | F7.5 IMUL Ev |
| F7.6 | ❌ Fail | F7.6 DIV Ev |
| F7.7 | ❌ Fail | F7.7 IDIV Ev |
| F8 | ✅ Pass | F8 CLC   |
| F9 | ✅ Pass | F9 STC   |
| FA | ✅ Pass | FA CLI   |
| FB | ✅ Pass | FB STI   |
| FC | ✅ Pass | FC CLD   |
| FD | ✅ Pass | FD STD   |
| FE.0 | ✅ Pass | FE.0 INC Eb |
| FE.1 | ✅ Pass | FE.1 DEC Eb |
| FF.0 | ✅ Pass | FF.0 INC Ev |
| FF.1 | ✅ Pass | FF.1 DEC Ev |
| FF.2 | ✅ Pass | FF.2 CALL Ev |
| FF.3 | ✅ Pass | FF.3 CALL Mp |
| FF.4 | ✅ Pass | FF.4 JMP Ev |
| FF.5 | ✅ Pass | FF.5 JMP Mp |
| FF.6 | ✅ Pass | FF.6 PUSH Ev |
| FF.7 | ❌ Fail | none |
