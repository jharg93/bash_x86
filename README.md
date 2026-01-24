# bash_x86

This is a toy emulator for x86 written in Bash.  It's about as slow as you can imagine....

The script works well enough to pass many of the tests from:
https://github.com/SingleStepTests/8088/tree/main/v2

eg run ./86json.sh 00.json

✅ Pass

| Opcode | Status | Mnemonic |
| ------ | ------ | -------- |
| 00 | ✅ Pass | ADD Eb Gb |
| 01 | ✅ Pass | ADD Ev Gv |
| 02 | ✅ Pass | ADD Gb Eb |
| 03 | ✅ Pass | ADD Gv Ev |
| 04 | ✅ Pass | ADD rAL Ib |
| 05 | ✅ Pass | ADD rvAX Iv |
| 06 | ✅ Pass | PUSH rES  |
| 07 | ❌ Fail | POP rES  |
| 08 | ✅ Pass | OR Eb Gb |
| 09 | ✅ Pass | OR Ev Gv |
| 0A | ✅ Pass | OR Gb Eb |
| 0B | ✅ Pass | OR Gv Ev |
| 0C | ✅ Pass | OR rAL Ib |
| 0D | ✅ Pass | OR rvAX Iv |
| 0E | ✅ Pass | PUSH rCS  |
| 0F | ❌ Fail | ----   |
| 10 | ✅ Pass | ADC Eb Gb |
| 11 | ✅ Pass | ADC Ev Gv |
| 12 | ✅ Pass | ADC Gb Eb |
| 13 | ✅ Pass | ADC Gv Ev |
| 14 | ✅ Pass | ADC rAL Ib |
| 15 | ✅ Pass | ADC rvAX Iv |
| 16 | ✅ Pass | PUSH rSS  |
| 17 | ❌ Fail | POP rSS  |
| 18 | ✅ Pass | SBB Eb Gb |
| 19 | ✅ Pass | SBB Ev Gv |
| 1A | ✅ Pass | SBB Gb Eb |
| 1B | ✅ Pass | SBB Gv Ev |
| 1C | ✅ Pass | SBB rAL Ib |
| 1D | ✅ Pass | SBB rvAX Iv |
| 1E | ✅ Pass | PUSH rDS  |
| 1F | ❌ Fail | POP rDS  |
| 20 | ✅ Pass | AND Eb Gb |
| 21 | ✅ Pass | AND Ev Gv |
| 22 | ✅ Pass | AND Gb Eb |
| 23 | ✅ Pass | AND Gv Ev |
| 24 | ✅ Pass | AND rAL Ib |
| 25 | ✅ Pass | AND rvAX Iv |
| 27 | ❌ Fail | DAA   |
| 28 | ✅ Pass | SUB Eb Gb |
| 29 | ✅ Pass | SUB Ev Gv |
| 2A | ✅ Pass | SUB Gb Eb |
| 2B | ✅ Pass | SUB Gv Ev |
| 2C | ✅ Pass | SUB rAL Ib |
| 2D | ✅ Pass | SUB rvAX Iv |
| 2F | ❌ Fail | DAS   |
| 30 | ✅ Pass | XOR Eb Gb |
| 31 | ✅ Pass | XOR Ev Gv |
| 32 | ✅ Pass | XOR Gb Eb |
| 33 | ✅ Pass | XOR Gv Ev |
| 34 | ✅ Pass | XOR rAL Ib |
| 35 | ✅ Pass | XOR rvAX Iv |
| 37 | ✅ Pass | AAA   |
| 38 | ✅ Pass | CMP Eb Gb |
| 39 | ✅ Pass | CMP Ev Gv |
| 3A | ✅ Pass | CMP Gb Eb |
| 3B | ✅ Pass | CMP Gv Ev |
| 3C | ✅ Pass | CMP rAL Ib |
| 3D | ✅ Pass | CMP rvAX Iv |
| 3F | ✅ Pass | AAS   |
| 40 | ✅ Pass | INC gv  |
| 41 | ✅ Pass | INC gv  |
| 42 | ✅ Pass | INC gv  |
| 43 | ✅ Pass | INC gv  |
| 44 | ✅ Pass | INC gv  |
| 45 | ✅ Pass | INC gv  |
| 46 | ✅ Pass | INC gv  |
| 47 | ✅ Pass | INC gv  |
| 48 | ✅ Pass | DEC gv  |
| 49 | ✅ Pass | DEC gv  |
| 4A | ✅ Pass | DEC gv  |
| 4B | ✅ Pass | DEC gv  |
| 4C | ✅ Pass | DEC gv  |
| 4D | ✅ Pass | DEC gv  |
| 4E | ✅ Pass | DEC gv  |
| 4F | ✅ Pass | DEC gv  |
| 50 | ✅ Pass | PUSH gv  |
| 51 | ✅ Pass | PUSH gv  |
| 52 | ✅ Pass | PUSH gv  |
| 53 | ✅ Pass | PUSH gv  |
| 54 | ❌ Fail | PUSH gv  |
| 55 | ✅ Pass | PUSH gv  |
| 56 | ✅ Pass | PUSH gv  |
| 57 | ✅ Pass | PUSH gv  |
| 58 | ❌ Fail | POP gv  |
| 59 | ❌ Fail | POP gv  |
| 5A | ❌ Fail | POP gv  |
| 5B | ❌ Fail | POP gv  |
| 5C | ❌ Fail | POP gv  |
| 5D | ❌ Fail | POP gv  |
| 5E | ❌ Fail | POP gv  |
| 5F | ❌ Fail | POP gv  |
| 60 | ❌ Fail ||
| 61 | ❌ Fail ||
| 62 | ❌ Fail ||
| 63 | ❌ Fail ||
| 64 | ❌ Fail ||
| 65 | ❌ Fail ||
| 66 | ❌ Fail ||
| 67 | ❌ Fail ||
| 68 | ❌ Fail ||
| 69 | ❌ Fail ||
| 6A | ❌ Fail ||
| 6B | ❌ Fail ||
| 6C | ❌ Fail ||
| 6D | ❌ Fail ||
| 6E | ❌ Fail ||
| 6F | ❌ Fail ||
| 70 | ✅ Pass | JCC Jb  |
| 71 | ✅ Pass | JCC Jb  |
| 72 | ✅ Pass | JCC Jb  |
| 73 | ✅ Pass | JCC Jb  |
| 74 | ✅ Pass | JCC Jb  |
| 75 | ✅ Pass | JCC Jb  |
| 76 | ✅ Pass | JCC Jb  |
| 77 | ✅ Pass | JCC Jb  |
| 78 | ✅ Pass | JCC Jb  |
| 79 | ✅ Pass | JCC Jb  |
| 7A | ✅ Pass | JCC Jb  |
| 7B | ✅ Pass | JCC Jb  |
| 7C | ✅ Pass | JCC Jb  |
| 7D | ✅ Pass | JCC Jb  |
| 7E | ✅ Pass | JCC Jb  |
| 7F | ✅ Pass | JCC Jb  |
| 80.0 | ❌ Fail ||
| 80.1 | ❌ Fail ||
| 80.2 | ❌ Fail ||
| 80.3 | ❌ Fail ||
| 80.4 | ❌ Fail ||
| 80.5 | ❌ Fail ||
| 80.6 | ❌ Fail ||
| 80.7 | ✅ Pass ||
| 81.0 | ❌ Fail ||
| 81.1 | ❌ Fail ||
| 81.2 | ❌ Fail ||
| 81.3 | ❌ Fail ||
| 81.4 | ❌ Fail ||
| 81.5 | ❌ Fail ||
| 81.6 | ❌ Fail ||
| 81.7 | ✅ Pass ||
| 82.0 | ❌ Fail ||
| 82.1 | ❌ Fail ||
| 82.2 | ❌ Fail ||
| 82.3 | ❌ Fail ||
| 82.4 | ❌ Fail ||
| 82.5 | ❌ Fail ||
| 82.6 | ❌ Fail ||
| 82.7 | ✅ Pass ||
| 83.0 | ❌ Fail ||
| 83.1 | ❌ Fail ||
| 83.2 | ❌ Fail ||
| 83.3 | ❌ Fail ||
| 83.4 | ❌ Fail ||
| 83.5 | ❌ Fail ||
| 83.6 | ❌ Fail ||
| 83.7 | ✅ Pass ||
| 84 | ✅ Pass | TEST Gb Eb |
| 85 | ✅ Pass | TEST Gv Ev |
| 86 | ✅ Pass | XCHG Gb Eb |
| 87 | ✅ Pass | XCHG Gv Ev |
| 88 | ✅ Pass | MOV Eb Gb |
| 89 | ✅ Pass | MOV Ev Gv |
| 8A | ✅ Pass | MOV Gb Eb |
| 8B | ✅ Pass | MOV Gv Ev |
| 8C | ❌ Fail | MOV Ew Sw |
| 8D | ✅ Pass | LEA Gv Mp |
| 8E | ❌ Fail | MOV Sw Ew |
| 8F | ❌ Fail | POP Ev __ |
| 90 | ✅ Pass | NOP  |
| 91 | ✅ Pass | XCHG gv rvAX |
| 92 | ✅ Pass | XCHG gv rvAX |
| 93 | ✅ Pass | XCHG gv rvAX |
| 94 | ✅ Pass | XCHG gv rvAX |
| 95 | ✅ Pass | XCHG gv rvAX |
| 96 | ✅ Pass | XCHG gv rvAX |
| 97 | ✅ Pass | XCHG gv rvAX |
| 98 | ❌ Fail | CBW   |
| 99 | ❌ Fail | CWD   |
| 9A | ❌ Fail | CALL Ap  |
| 9C | ❌ Fail | PUSHF   |
| 9D | ❌ Fail | POPF   |
| 9E | ✅ Pass | SAHF   |
| 9F | ❌ Fail | LAHF   |
| A0 | ✅ Pass | MOV rAL Ob |
| A1 | ✅ Pass | MOV rvAX Ov |
| A2 | ✅ Pass | MOV Ob rAL |
| A3 | ✅ Pass | MOV Ov rvAX |
| A4 | ❌ Fail | MOVS Yb Xb |
| A5 | ❌ Fail | MOVS Yv Xv |
| A6 | ❌ Fail | CMPS Xb Yb |
| A7 | ❌ Fail | CMPS Xv Yv |
| A8 | ✅ Pass | TEST rAL Ib |
| A9 | ✅ Pass | TEST rvAX Iv |
| AA | ❌ Fail | STOS Yb rAL |
| AB | ❌ Fail | STOS Yv rvAX |
| AC | ❌ Fail | LODS rAL Xb |
| AD | ❌ Fail | LODS rvAX Xv |
| AE | ❌ Fail | SCAS rAL Yb |
| AF | ❌ Fail | SCAS rvAX Yv |
| B0 | ✅ Pass | MOV gb Ib |
| B1 | ✅ Pass | MOV gb Ib |
| B2 | ✅ Pass | MOV gb Ib |
| B3 | ✅ Pass | MOV gb Ib |
| B4 | ✅ Pass | MOV gb Ib |
| B5 | ✅ Pass | MOV gb Ib |
| B6 | ✅ Pass | MOV gb Ib |
| B7 | ✅ Pass | MOV gb Ib |
| B8 | ✅ Pass | MOV gv Iv |
| B9 | ✅ Pass | MOV gv Iv |
| BA | ✅ Pass | MOV gv Iv |
| BB | ✅ Pass | MOV gv Iv |
| BC | ✅ Pass | MOV gv Iv |
| BD | ✅ Pass | MOV gv Iv |
| BE | ✅ Pass | MOV gv Iv |
| BF | ✅ Pass | MOV gv Iv |
| C0 | ❌ Fail | GRP2 Eb Ib |
| C1 | ❌ Fail | GRP2 Ev Ib |
| C2 | ❌ Fail | RET Iw  |
| C3 | ❌ Fail | RET   |
| C4 | ❌ Fail | LES Gv Mp |
| C5 | ❌ Fail | LDS Gv Mp |
| C6 | ❌ Fail | MOV Eb Ib |
| C7 | ❌ Fail | MOV Ev Iv |
| C8 | ❌ Fail ||
| C9 | ❌ Fail ||
| CA | ❌ Fail | RETF Iw  |
| CB | ❌ Fail | RETF   |
| CC | ❌ Fail | INT i3  |
| CD | ❌ Fail | INT Ib  |
| CE | ❌ Fail | INTO   |
| CF | ❌ Fail | IRET   |
| D0.0 | ❌ Fail ||
| D0.1 | ❌ Fail ||
| D0.2 | ❌ Fail ||
| D0.3 | ❌ Fail ||
| D0.4 | ✅ Pass ||
| D0.5 | ✅ Pass ||
| D0.6 | ❌ Fail ||
| D0.7 | ❌ Fail ||
| D1.0 | ❌ Fail ||
| D1.1 | ❌ Fail ||
| D1.2 | ❌ Fail ||
| D1.3 | ❌ Fail ||
| D1.4 | ✅ Pass ||
| D1.5 | ✅ Pass ||
| D1.6 | ❌ Fail ||
| D1.7 | ❌ Fail ||
| D2.0 | ❌ Fail ||
| D2.1 | ❌ Fail ||
| D2.2 | ❌ Fail ||
| D2.3 | ❌ Fail ||
| D2.4 | ✅ Pass ||
| D2.5 | ✅ Pass ||
| D2.6 | ❌ Fail ||
| D2.7 | ❌ Fail ||
| D3.0 | ❌ Fail ||
| D3.1 | ❌ Fail ||
| D3.2 | ❌ Fail ||
| D3.3 | ❌ Fail ||
| D3.4 | ✅ Pass ||
| D3.5 | ✅ Pass ||
| D3.6 | ❌ Fail ||
| D3.7 | ❌ Fail ||
| D4 | ❌ Fail | AAM Ib  |
| D5 | ❌ Fail | AAD Ib  |
| D6 | ❌ Fail | SALC   |
| D7 | ❌ Fail | XLAT   |
| D8 | ❌ Fail ||
| D9 | ❌ Fail ||
| DA | ❌ Fail ||
| DB | ❌ Fail ||
| DC | ❌ Fail ||
| DD | ❌ Fail ||
| DE | ❌ Fail ||
| DF | ❌ Fail ||
| E0 | ❌ Fail | LOOPNZ Jb  |
| E1 | ❌ Fail | LOOPZ Jb  |
| E2 | ❌ Fail | LOOP Jb  |
| E3 | ✅ Pass | JCXZ Jb  |
| E4 | ❌ Fail | IN rAL Ib |
| E5 | ❌ Fail | IN rvAX Ib |
| E6 | ✅ Pass | OUT Ib rAL |
| E7 | ✅ Pass | OUT Iv rvAX |
| E8 | ❌ Fail | CALL Jv  |
| E9 | ✅ Pass | JMP Jv  |
| EA | ❌ Fail | JMP Ap  |
| EB | ✅ Pass | JMP Jb  |
| EC | ❌ Fail | IN rAL rDX |
| ED | ❌ Fail | IN rvAX rDX |
| EE | ✅ Pass | OUT rDX rAL |
| EF | ✅ Pass | OUT rDX rvAX |
| F5 | ✅ Pass | CMC   |
| F6.0 | ✅ Pass ||
| F6.1 | ✅ Pass ||
| F6.2 | ❌ Fail ||
| F6.3 | ✅ Pass ||
| F6.4 | ❌ Fail ||
| F6.5 | ❌ Fail ||
| F6.6 | ❌ Fail ||
| F6.7 | ❌ Fail ||
| F7.0 | ✅ Pass ||
| F7.1 | ✅ Pass ||
| F7.2 | ❌ Fail ||
| F7.3 | ✅ Pass ||
| F7.4 | ❌ Fail ||
| F7.5 | ❌ Fail ||
| F7.6 | ❌ Fail ||
| F7.7 | ❌ Fail ||
| F8 | ✅ Pass | CLC   |
| F9 | ✅ Pass | STC   |
| FA | ✅ Pass | CLI   |
| FB | ✅ Pass | STI   |
| FC | ✅ Pass | CLD   |
| FD | ✅ Pass | STD   |
| FE.0 | ✅ Pass ||
| FE.1 | ✅ Pass ||
| FF.0 | ✅ Pass ||
| FF.1 | ✅ Pass ||
| FF.2 | ❌ Fail ||
| FF.3 | ❌ Fail ||
| FF.4 | ✅ Pass ||
| FF.5 | ❌ Fail ||
| FF.6 | ✅ Pass ||
| FF.7 | ❌ Fail ||
