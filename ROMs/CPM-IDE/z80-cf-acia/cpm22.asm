;
;
;**************************************************************
;*
;*             C P / M   version   2 . 2
;*
;*   Reconstructed from memory image on February 27, 1981
;*
;*                by Clark A. Calkins
;*
;**************************************************************
;
; Let this paragraph represent a right to use, distribute, modify,
; enhance, and otherwise make available in a nonexclusive manner
; CP/M and its derivatives. This right comes from the company,
; DRDOS, Inc.'s purchase of Digital Research, the company and
; all assets, dating back to the mid-1990's. DRDOS, Inc. and I,
; Bryan Sparks, President of DRDOS, Inc. as its representative,
; is the owner of CP/M and the successor in interest of
; Digital Research assets."
;
;**************************************************************
;
; Converted to z88dk z80asm for RC2014 by
; Phillip Stevens @feilipu https://feilipu.me
; March 2018
;

SECTION rodata_lib           ;read only library (code)

;------------------------------------------------------------------------------
; location setting
;------------------------------------------------------------------------------

PUBLIC  __COMMON_AREA_PHASE_CCP_BDOS    ;base of ccp
defc    __COMMON_AREA_PHASE_CCP_BDOS    = 0xDC00

;------------------------------------------------------------------------------
; start of definitions
;------------------------------------------------------------------------------

EXTERN  _cpm_iobyte
EXTERN  _cpm_cdisk
EXTERN  _cpm_ccp_tfcb
EXTERN  _cpm_ccp_tbuff
EXTERN  _cpm_ccp_tbase

DEFC    IOBYTE      =       _cpm_iobyte     ;i/o definition byte
DEFC    TDRIVE      =       _cpm_cdisk      ;current drive name and user number
DEFC    ENTRY       =       _cpm_bdos_head  ;entry point for the cp/m bdos
DEFC    TFCB        =       _cpm_ccp_tfcb   ;default file control block
DEFC    TBUFF       =       _cpm_ccp_tbuff  ;i/o buffer and command line storage
DEFC    TBASE       =       _cpm_ccp_tbase  ;transient program storage area

;
;   Set control character equates.
;
DEFC    CNTRLC      =   03H     ;control-c
DEFC    CNTRLE      =   05H     ;control-e
DEFC    BS          =   08H     ;backspace
DEFC    TAB         =   09H     ;tab
DEFC    LF          =   0AH     ;line feed
DEFC    FF          =   0CH     ;form feed
DEFC    CR          =   0DH     ;carriage return
DEFC    CNTRLP      =   10H     ;control-p
DEFC    CNTRLR      =   12H     ;control-r
DEFC    CNTRLS      =   13H     ;control-s
DEFC    CNTRLU      =   15H     ;control-u
DEFC    CNTRLX      =   18H     ;control-x
DEFC    CNTRLZ      =   1AH     ;control-z (end-of-file mark)
DEFC    DEL         =   7FH     ;rubout

;
;   Set origin for CP/M
;
PUBLIC  _rodata_cpm_ccp_head
_rodata_cpm_ccp_head:           ;origin of the cpm ccp in rodata

PHASE   __COMMON_AREA_PHASE_CCP_BDOS

PUBLIC  _cpm_ccp_head
_cpm_ccp_head:                  ;origin of the cpm ccp

CBASE:
    JP    COMMAND       ;execute command processor (ccp).
    JP    CLEARBUF      ;entry to empty input buffer before starting ccp.

;
;   Standard cp/m ccp input buffer. Format is (max length),
;   (actual length), (char #1), (char #2), (char #3), etc.
;
INBUFF:
    DEFB    127         ;length of input buffer.
    DEFB    0           ;current length of contents.
    DEFM    "Copyright 1979 (c) by Digital Research"
    DEFS    89,0
INPOINT:
    DEFW    INBUFF+2    ;input line pointer
NAMEPNT:
    DEFW    0           ;input line pointer used for error message. Points to
                        ;start of name in error.
;
;   Routine to print (A) on the console. All registers used.
;
PRINT:
    LD    E,A        ;setup bdos call.
    LD    C,2
    JP    ENTRY
;
;   Routine to print (A) on the console and to save (BC).
;
PRINTB:
    PUSH    BC
    CALL    PRINT
    POP     BC
    RET
;
;   Routine to send a carriage return, line feed combination
;   to the console.
;
CRLF:   
    LD      A,CR
    CALL    PRINTB
    LD      A,LF
    JP      PRINTB
;
;   Routine to send one space to the console and save (BC).
;
SPACE:
    LD      A,' '
    JP      PRINTB
;
;   Routine to print character string pointed to be (BC) on the
;   console. It must terminate with a null byte.
;
PLINE:
    PUSH    BC
    CALL    CRLF
    POP    HL
PLINE2:
    LD    A,(HL)
    OR    A
    RET    Z
    INC    HL
    PUSH    HL
    CALL    PRINT
    POP    HL
    JP    PLINE2
;
;   Routine to reset the disk system.
;
RESDSK:
    LD    C,13
    JP    ENTRY
;
;   Routine to select disk (A).
;
DSKSEL:
    LD    E,A
    LD    C,14
    JP    ENTRY
;
;   Routine to call bdos and save the return code. The zero
;   flag is set on a return of 0ffh.
;
ENTRY1:
    CALL    ENTRY
    LD    (RTNCODE),A    ;save return code.
    INC    A        ;set zero if 0ffh returned.
    RET
;
;   Routine to open a file. (DE) must point to the FCB.
;
OPEN:
    LD    C,15
    JP    ENTRY1
;
;   Routine to open file at (FCB).
;
OPENFCB:
    XOR    A        ;clear the record number byte at fcb+32
    LD    (FCB+32),A
    LD    DE,FCB
    JP    OPEN
;
;   Routine to close a file. (DE) points to FCB.
;
CLOSE:
    LD    C,16
    JP    ENTRY1
;
;   Routine to search for the first file with ambiguous name
;   (DE).
;
SRCHFST:
    LD    C,17
    JP    ENTRY1
;
;   Search for the next ambiguous file name.
;
SRCHNXT:
    LD    C,18
    JP    ENTRY1
;
;   Search for file at (FCB).
;
SRCHFCB:
    LD    DE,FCB
    JP    SRCHFST
;
;   Routine to delete a file pointed to by (DE).
;
DELETE:
    LD    C,19
    JP    ENTRY
;
;   Routine to call the bdos and set the zero flag if a zero
;   status is returned.
;
ENTRY2:
    CALL    ENTRY
    OR    A        ;set zero flag if appropriate.
    RET
;
;   Routine to read the next record from a sequential file.
;   (DE) points to the FCB.
;
RDREC:
    LD    C,20
    JP    ENTRY2
;
;   Routine to read file at (FCB).
;
READFCB:
    LD    DE,FCB
    JP    RDREC
;
;   Routine to write the next record of a sequential file.
;   (DE) points to the FCB.
;
WRTREC:
    LD    C,21
    JP    ENTRY2
;
;   Routine to create the file pointed to by (DE).
;
CREATE:
    LD    C,22
    JP    ENTRY1
;
;   Routine to rename the file pointed to by (DE). Note that
;   the new name starts at (DE+16).
;
RENAM:
    LD    C,23
    JP    ENTRY
;
;   Get the current user code.
;
GETUSR:
    LD    E,0FFH
;
;   Routine to get or set the current user code.
;   If (E) is FF then this is a GET, else it is a SET.
;
GETSETUC:
    LD    C,32
    JP    ENTRY
;
;   Routine to set the current drive byte at (TDRIVE).
;
SETCDRV:
    CALL    GETUSR        ;get user number
    ADD    A,A        ;and shift into the upper 4 bits.
    ADD    A,A
    ADD    A,A
    ADD    A,A
    LD    HL,CDRIVE    ;now add in the current drive number.
    OR    (HL)
    LD    (TDRIVE),A    ;and save.
    RET
;
;   Move currently active drive down to (TDRIVE).
;
MOVECD:
    LD    A,(CDRIVE)
    LD    (TDRIVE),A
    RET
;
;   Routine to convert (A) into upper case ascii. Only letters
;   are affected.
;
UPPER:
    CP    'a'        ;check for letters in the range of 'a' to 'z'.
    RET    C
    CP    '{'
    RET    NC
    AND    5FH        ;convert it if found.
    RET
;
;   Routine to get a line of input. We must check to see if the
;   user is in (BATCH) mode. If so, then read the input from file
;   ($$$.SUB). At the end, reset to console input.
;
GETINP:
    LD    A,(BATCH)    ;if =0, then use console input.
    OR    A
    JP    Z,GETINP1
;
;   Use the submit file ($$$.sub) which is prepared by a
;   SUBMIT run. It must be on drive (A) and it will be deleted
;   if and error occures (like eof).
;
    LD    A,(CDRIVE)    ;select drive 0 if need be.
    OR    A
    LD    A,0        ;always use drive A for submit.
    CALL    NZ,DSKSEL    ;select it if required.
    LD    DE,BATCHFCB
    CALL    OPEN        ;look for it.
    JP    Z,GETINP1    ;if not there, use normal input.
    LD    A,(BATCHFCB+15)    ;get last record number+1.
    DEC    A
    LD    (BATCHFCB+32),A
    LD    DE,BATCHFCB
    CALL    RDREC        ;read last record.
    JP    NZ,GETINP1    ;quit on end of file.
;
;   Move this record into input buffer.
;
    LD    DE,INBUFF+1
    LD    HL,TBUFF      ;data was read into buffer here.
                        ;all 128 characters may be used.
    CALL    LDI_128     ;(HL++)->(DE++), 128 times.
    LD    HL,BATCHFCB+14
    LD    (HL),0        ;zero out the 's2' byte.
    INC    HL           ;and decrement the record count.
    DEC    (HL)
    LD    DE,BATCHFCB    ;close the batch file now.
    CALL    CLOSE
    JP    Z,GETINP1    ;quit on an error.
    LD    A,(CDRIVE)    ;re-select previous drive if need be.
    OR    A
    CALL    NZ,DSKSEL    ;don't do needless selects.
;
;   Print line just read on console.
;
    LD    HL,INBUFF+2
    CALL    PLINE2
    CALL    CHKCON        ;check console, quit on a key.
    JP    Z,GETINP2    ;jump if no key is pressed.
;
;   Terminate the submit job on any keyboard input. Delete this
;   file such that it is not re-started and jump to normal keyboard
;   input section.
;
    CALL    DELBATCH    ;delete the batch file.
    JP    CMMND1        ;and restart command input.
;
;   Get here for normal keyboard input. Delete the submit file
;   in case there was one.
;
GETINP1:
    CALL    DELBATCH    ;delete file ($$$.sub).
    CALL    SETCDRV        ;reset active disk.
    LD    C,10        ;get line from console device.
    LD    DE,INBUFF
    CALL    ENTRY
    CALL    MOVECD        ;reset current drive (again).
;
;   Convert input line to upper case.
;
GETINP2:
    LD    HL,INBUFF+1
    LD    B,(HL)        ;(B)=character counter.
GETINP3:
    INC    HL
    LD    A,B        ;end of the line?
    OR    A
    JP    Z,GETINP4
    LD    A,(HL)        ;convert to upper case.
    CALL    UPPER
    LD    (HL),A
    DEC    B        ;adjust character count.
    JP    GETINP3
GETINP4:
    LD    (HL),A        ;add trailing null.
    LD    HL,INBUFF+2
    LD    (INPOINT),HL    ;reset input line pointer.
    RET
;
;   Routine to check the console for a key pressed. The zero
;   flag is set is none, else the character is returned in (A).
;
CHKCON:
    LD    C,11        ;check console.
    CALL    ENTRY
    OR    A
    RET    Z        ;return if nothing.
    LD    C,1        ;else get character.
    CALL    ENTRY
    OR    A        ;clear zero flag and return.
    RET
;
;   Routine to get the currently active drive number.
;
GETDSK:
    LD    C,25
    JP    ENTRY
;
;   Set the standard dma address.
;
STDDMA:
    LD    DE,TBUFF
;
;   Routine to set the dma address to (DE).
;
DMASET:
    LD    C,26
    JP    ENTRY
;
;  Delete the batch file created by SUBMIT.
;
DELBATCH:
    LD    HL,BATCH    ;is batch active?
    LD    A,(HL)
    OR    A
    RET    Z
    LD    (HL),0        ;yes, de-activate it.
    XOR    A
    CALL    DSKSEL        ;select drive 0 for sure.
    LD    DE,BATCHFCB    ;and delete this file.
    CALL    DELETE
    LD    A,(CDRIVE)    ;reset current drive.
    JP    DSKSEL
;
;   Check to two strings at (PATTRN1) and (PATTRN2). They must be
;   the same or we halt....
;
;VERIFY:
;   LD    DE,PATTRN1    ;these are the serial number bytes.
;   LD    HL,PATTRN2    ;ditto, but how could they be different?
;   LD    B,6        ;6 bytes each.
;VERIFY1:
;   LD    A,(DE)
;   CP    (HL)
;   JP    NZ,HALT        ;jump to halt routine.
;   INC    DE
;   INC    HL
;   DEC    B
;   JP    NZ,VERIFY1
;   RET
;
;   Print back file name with a '?' to indicate a syntax error.
;
SYNERR:
    CALL    CRLF        ;end current line.
    LD    HL,(NAMEPNT)    ;this points to name in error.
SYNERR1:
    LD    A,(HL)        ;print it until a space or null is found.
    CP    ' '
    JP    Z,SYNERR2
    OR    A
    JP    Z,SYNERR2
    PUSH    HL
    CALL    PRINT
    POP    HL
    INC    HL
    JP    SYNERR1
SYNERR2:
    LD    A,'?'        ;add trailing '?'.
    CALL    PRINT
    CALL    CRLF
    CALL    DELBATCH    ;delete any batch file.
    JP    CMMND1        ;and restart from console input.
;
;   Check character at (DE) for legal command input. Note that the
;   zero flag is set if the character is a delimiter.
;
CHECK:
    LD    A,(DE)
    OR    A
    RET    Z
    CP    ' '        ;control characters are not legal here.
    JP    C,SYNERR
    RET    Z        ;check for valid delimiter.
    CP    '='
    RET    Z
    CP    '_'
    RET    Z
    CP    '.'
    RET    Z
    CP    ':'
    RET    Z
    CP    ';'
    RET    Z
    CP    '<'
    RET    Z
    CP    '>'
    RET    Z
    RET
;
;   Get the next non-blank character from (DE).
;
NONBLANK:
    LD    A,(DE)
    OR    A        ;string ends with a null.
    RET    Z
    CP    ' '
    RET    NZ
    INC    DE
    JP    NONBLANK
;
;   Add (HL)=(HL)+(A)
;
ADDHL:
    ADD    A,L
    LD    L,A
    RET    NC        ;take care of any carry.
    INC    H
    RET
;
;   Convert the first name in (FCB).
;
CONVFST:
    LD    A,0
;
;   Format a file name (convert * to '?', etc.). On return,
;   (A)=0 is an unambiguous name was specified. Enter with (A) equal to
;   the position within the fcb for the name (either 0 or 16).
;
CONVERT:
    LD    HL,FCB
    CALL    ADDHL
    PUSH    HL
    PUSH    HL
    XOR    A
    LD    (CHGDRV),A    ;initialize drive change flag.
    LD    HL,(INPOINT)    ;set (HL) as pointer into input line.
    EX    DE,HL
    CALL    NONBLANK    ;get next non-blank character.
    EX    DE,HL
    LD    (NAMEPNT),HL    ;save pointer here for any error message.
    EX    DE,HL
    POP    HL
    LD    A,(DE)        ;get first character.
    OR    A
    JP    Z,CONVRT1
    SBC    A,'A'-1        ;might be a drive name, convert to binary.
    LD    B,A        ;and save.
    INC    DE        ;check next character for a ':'.
    LD    A,(DE)
    CP    ':'
    JP    Z,CONVRT2
    DEC    DE        ;nope, move pointer back to the start of the line.
CONVRT1:
    LD    A,(CDRIVE)
    LD    (HL),A
    JP    CONVRT3
CONVRT2:
    LD    A,B
    LD    (CHGDRV),A    ;set change in drives flag.
    LD    (HL),B
    INC    DE
;
;   Convert the basic file name.
;
CONVRT3:
    LD    B,08H
CONVRT4:
    CALL    CHECK
    JP    Z,CONVRT8
    INC    HL
    CP    '*'        ;note that an '*' will fill the remaining
    JP    NZ,CONVRT5    ;field with '?'.
    LD    (HL),'?'
    JP    CONVRT6
CONVRT5:
    LD    (HL),A
    INC    DE
CONVRT6:
    DEC    B
    JP    NZ,CONVRT4
CONVRT7:
    CALL    CHECK        ;get next delimiter.
    JP    Z,GETEXT
    INC    DE
    JP    CONVRT7
CONVRT8:
    INC    HL        ;blank fill the file name.
    LD    (HL),' '
    DEC    B
    JP    NZ,CONVRT8
;
;   Get the extension and convert it.
;
GETEXT:
    LD    B,03H
    CP    '.'
    JP    NZ,GETEXT5
    INC    DE
GETEXT1:
    CALL    CHECK
    JP    Z,GETEXT5
    INC    HL
    CP    '*'
    JP    NZ,GETEXT2
    LD    (HL),'?'
    JP    GETEXT3
GETEXT2:
    LD    (HL),A
    INC    DE
GETEXT3:
    DEC    B
    JP    NZ,GETEXT1
GETEXT4:
    CALL    CHECK
    JP    Z,GETEXT6
    INC    DE
    JP    GETEXT4
GETEXT5:
    INC    HL
    LD    (HL),' '
    DEC    B
    JP    NZ,GETEXT5
GETEXT6:
    LD    B,3
GETEXT7:
    INC    HL
    LD    (HL),0
    DEC    B
    JP    NZ,GETEXT7
    EX    DE,HL
    LD    (INPOINT),HL    ;save input line pointer.
    POP    HL
;
;   Check to see if this is an ambiguous file name specification.
;   Set the (A) register to non zero if it is.
;
    LD    BC,11        ;set name length.
GETEXT8:
    INC    HL
    LD    A,(HL)
    CP    '?'        ;any question marks?
    JP    NZ,GETEXT9
    INC    B        ;count them.
GETEXT9:
    DEC    C
    JP    NZ,GETEXT8
    LD    A,B
    OR    A
    RET
;
;   CP/M command table. Note commands can be either 3 or 4 characters long.
;
DEFC    NUMCMDS =   7        ;number of commands
CMDTBL:
    DEFM    "DIR "
    DEFM    "ERA "
    DEFM    "TYPE"
    DEFM    "SAVE"
    DEFM    "REN "
    DEFM    "USER"
    DEFM    "EXIT"
;
;   The following six bytes must agree with those at (PATTRN2)
;   or cp/m will HALT. Why?
;
;PATTRN1:
;    DEFM    0,22,0,0,0,0    ;(* serial number bytes *).
;
;   Search the command table for a match with what has just
;   been entered. If a match is found, then we jump to the
;   proper section. Else jump to (UNKNOWN).
;   On return, the (C) register is set to the command number
;   that matched (or NUMCMDS+1 if no match).
;
SEARCH:
    LD    HL,CMDTBL
    LD    C,0
SEARCH1:
    LD    A,C
    CP    NUMCMDS        ;this command exists.
    RET    NC
    LD    DE,FCB+1    ;check this one.
    LD    B,4        ;max command length.
SEARCH2:
    LD    A,(DE)
    CP    (HL)
    JP    NZ,SEARCH3    ;not a match.
    INC    DE
    INC    HL
    DEC    B
    JP    NZ,SEARCH2
    LD    A,(DE)        ;allow a 3 character command to match.
    CP    ' '
    JP    NZ,SEARCH4
    LD    A,C        ;set return register for this command.
    RET
SEARCH3:
    INC    HL
    DEC    B
    JP    NZ,SEARCH3
SEARCH4:
    INC    C
    JP    SEARCH1
;
;   Set the input buffer to empty and then start the command
;   processor (ccp).
;
CLEARBUF:
    XOR    A
    LD    (INBUFF+1),A      ;second byte is actual length.
;
;**************************************************************
;*
;*
;* C C P  -   C o n s o l e   C o m m a n d   P r o c e s s o r
;*
;**************************************************************
;*
COMMAND:
    LD      SP,CCPSTACK     ;setup stack area.
    PUSH    BC              ;note that (C) should be equal to:
    LD      A,C             ;(uuuudddd) where 'uuuu' is the user number
    RRA                     ;and 'dddd' is the drive number.
    RRA
    RRA
    RRA
    AND     0FH             ;isolate the user number.
    LD      E,A
    CALL    GETSETUC        ;and set it.
    CALL    RESDSK          ;reset the disk system.
    LD      (BATCH),A       ;clear batch mode flag.
    POP     BC
    LD      A,C
    AND     0FH             ;isolate the drive number.
    LD      (CDRIVE),A      ;and save.
    CALL    DSKSEL          ;...and select. 
    LD      A,(INBUFF+1)
    OR      A               ;anything in input buffer already?
    JP      NZ,CMMND2       ;yes, we just process it.
;
;   Entry point to get a command line from the console.
;
CMMND1:
    LD      SP,CCPSTACK     ;set stack straight.
    CALL    CRLF            ;start a new line on the screen.
    CALL    GETDSK          ;get current drive.
    ADD     A,'A'
    CALL    PRINT           ;print current drive.
    LD      A,'>'
    CALL    PRINT           ;and add prompt.
    CALL    GETINP          ;get line from user.
;
;   Process command line here.
;
CMMND2:
    LD    DE,TBUFF
    CALL    DMASET        ;set standard dma address.
    CALL    GETDSK
    LD    (CDRIVE),A    ;set current drive.
    CALL    CONVFST        ;convert name typed in.
    CALL    NZ,SYNERR    ;wild cards are not allowed.
    LD    A,(CHGDRV)    ;if a change in drives was indicated,
    OR    A                 ;then treat this as an unknown command
    JP    NZ,UNKNOWN    ;which gets executed.
    CALL    SEARCH        ;else search command table for a match.
;
;   Note that an unknown command returns
;   with (A) pointing to the last address
;   in our table which is (UNKNOWN).
;
    LD    HL,CMDADR    ;now, look thru our address table for command (A).
    LD    E,A        ;set (DE) to command number.
    LD    D,0
    ADD    HL,DE
    ADD    HL,DE        ;(HL)=(CMDADR)+2*(command number).
    LD    A,(HL)        ;now pick out this address.
    INC    HL
    LD    H,(HL)
    LD    L,A
    JP    (HL)        ;now execute it.
;
;   CP/M command address table.
;
CMDADR:
    DEFW    DIRECT,ERASE,TYPE,SAVE
    DEFW    RENAME,USER,EXIT,UNKNOWN
;
;   Halt the system. Reason for this is unknown at present.
;
HALT:
    LD    HL,76F3H    ;'DI HLT' instructions.
    LD    (CBASE),HL
    LD    HL,CBASE
    JP    (HL)
;
;   Read error while TYPEing a file.
;
RDERROR:
    LD    BC,RDERR
    JP    PLINE

RDERR:
    DEFM    "Read error",0
;
;   Required file was not located.
;
NONE:
    LD    BC,NOFILE
    JP    PLINE

NOFILE:
    DEFM    "No file",0
;
;   Decode a command of the form 'A>filename number{ filename}.
;   Note that a drive specifier is not allowed on the first file
;   name. On return, the number is in register (A). Any error
;   causes 'filename?' to be printed and the command is aborted.
;
DECODE:
    CALL    CONVFST        ;convert filename.
    LD    A,(CHGDRV)    ;do not allow a drive to be specified.
    OR    A
    JP    NZ,SYNERR
    LD    HL,FCB+1    ;convert number now.
    LD    BC,11        ;(B)=sum register, (C)=max digit count.
DECODE1:
    LD    A,(HL)
    CP    ' '        ;a space terminates the numeral.
    JP    Z,DECODE3
    INC    HL
    SUB    '0'        ;make binary from ascii.
    CP    10        ;legal digit?
    JP    NC,SYNERR
    LD    D,A        ;yes, save it in (D).
    LD    A,B        ;compute (B)=(B)*10 and check for overflow.
    AND    0E0H
    JP    NZ,SYNERR
    LD    A,B
    RLCA
    RLCA
    RLCA            ;(A)=(B)*8
    ADD    A,B        ;.......*9
    JP    C,SYNERR
    ADD    A,B        ;.......*10
    JP    C,SYNERR
    ADD    A,D        ;add in new digit now.
DECODE2:
    JP    C,SYNERR
    LD    B,A        ;and save result.
    DEC    C        ;only look at 11 digits.
    JP    NZ,DECODE1
    RET
DECODE3:
    LD    A,(HL)        ;spaces must follow (why?).
    CP    ' '
    JP    NZ,SYNERR
    INC    HL
DECODE4:
    DEC    C
    JP    NZ,DECODE3
    LD    A,B        ;set (A)=the numeric value entered.
    RET  
;
;   Compute (HL)=(TBUFF)+(A)+(C) and get the byte that's here.
;
EXTRACT:
    LD    HL,TBUFF
    ADD    A,C
    CALL    ADDHL
    LD    A,(HL)
    RET
;
;   Check drive specified. If it means a change, then the new
;   drive will be selected. In any case, the drive byte of the
;   fcb will be set to null (means use current drive).
;
DSELECT:
    XOR    A        ;null out first byte of fcb.
    LD    (FCB),A
    LD    A,(CHGDRV)    ;a drive change indicated?
    OR    A
    RET    Z
    DEC    A        ;yes, is it the same as the current drive?
    LD    HL,CDRIVE
    CP    (HL)
    RET    Z
    JP    DSKSEL        ;no. Select it then.
;
;   Check the drive selection and reset it to the previous
;   drive if it was changed for the preceeding command.
;
RESETDR:
    LD    A,(CHGDRV)    ;drive change indicated?
    OR    A
    RET    Z
    DEC    A        ;yes, was it a different drive?
    LD    HL,CDRIVE
    CP    (HL)
    RET    Z
    LD    A,(CDRIVE)    ;yes, re-select our old drive.
    JP    DSKSEL
;
;**************************************************************
;*
;*           D I R E C T O R Y   C O M M A N D
;*
;**************************************************************
;
DIRECT:
    CALL    CONVFST        ;convert file name.
    CALL    DSELECT        ;select indicated drive.
    LD    HL,FCB+1    ;was any file indicated?
    LD    A,(HL)
    CP    ' '
    JP    NZ,DIRECT2
    LD    B,11        ;no. Fill field with '?' - same as *.*.
DIRECT1:
    LD    (HL),'?'
    INC    HL
    DEC    B
    JP    NZ,DIRECT1
DIRECT2:
    LD    E,0        ;set initial cursor position.
    PUSH    DE
    CALL    SRCHFCB        ;get first file name.
    CALL    Z,NONE        ;none found at all?
DIRECT3:
    JP    Z,DIRECT9    ;terminate if no more names.
    LD    A,(RTNCODE)    ;get file's position in segment (0-3).
    RRCA
    RRCA
    RRCA
    AND    60H        ;(A)=position*32
    LD    C,A
    LD    A,10
    CALL    EXTRACT        ;extract the tenth entry in fcb.
    RLA            ;check system file status bit.
    JP    C,DIRECT8    ;we don't list them.
    POP    DE
    LD    A,E        ;bump name count.
    INC    E
    PUSH    DE
    AND    03H        ;at end of line?
    PUSH    AF
    JP    NZ,DIRECT4
    CALL    CRLF        ;yes, end this line and start another.
    PUSH    BC
    CALL    GETDSK        ;start line with ('A:').
    POP    BC
    ADD    A,'A'
    CALL    PRINTB
    LD    A,':'
    CALL    PRINTB
    JP    DIRECT5
DIRECT4:
    CALL    SPACE        ;add seperator between file names.
    LD    A,':'
    CALL    PRINTB
DIRECT5:
    CALL    SPACE
    LD    B,1        ;'extract' each file name character at a time.
DIRECT6:
    LD    A,B
    CALL    EXTRACT
    AND    7FH        ;strip bit 7 (status bit).
    CP    ' '        ;are we at the end of the name?
    JP    NZ,DRECT65
    POP    AF        ;yes, don't print spaces at the end of a line.
    PUSH    AF
    CP    3
    JP    NZ,DRECT63
    LD    A,9        ;first check for no extension.
    CALL    EXTRACT
    AND    7FH
    CP    ' '
    JP    Z,DIRECT7    ;don't print spaces.
DRECT63:
    LD    A,' '        ;else print them.
DRECT65:
    CALL    PRINTB
    INC    B        ;bump to next character psoition.
    LD    A,B
    CP    12        ;end of the name?
    JP    NC,DIRECT7
    CP    9        ;nope, starting extension?
    JP    NZ,DIRECT6
    CALL    SPACE        ;yes, add seperating space.
    JP    DIRECT6
DIRECT7:
    POP    AF        ;get the next file name.
DIRECT8:
    CALL    CHKCON        ;first check console, quit on anything.
    JP    NZ,DIRECT9
    CALL    SRCHNXT        ;get next name.
    JP    DIRECT3        ;and continue with our list.
DIRECT9:
    POP    DE        ;restore the stack and return to command level.
    JP    GETBACK
;
;**************************************************************
;*
;*                E R A S E   C O M M A N D
;*
;**************************************************************
;
ERASE:
    CALL    CONVFST        ;convert file name.
    CP    11        ;was '*.*' entered?
    JP    NZ,ERASE1
    LD    BC,YESNO    ;yes, ask for confirmation.
    CALL    PLINE
    CALL    GETINP
    LD    HL,INBUFF+1
    DEC    (HL)        ;must be exactly 'y'.
    JP    NZ,CMMND1
    INC    HL
    LD    A,(HL)
    CP    'Y'
    JP    NZ,CMMND1
    INC    HL
    LD    (INPOINT),HL    ;save input line pointer.
ERASE1:
    CALL    DSELECT        ;select desired disk.
    LD    DE,FCB
    CALL    DELETE        ;delete the file.
    INC    A
    CALL    Z,NONE        ;not there?
    JP    GETBACK        ;return to command level now.

YESNO:
    DEFM    "All (y/n)?",0
;
;**************************************************************
;*
;*            T Y P E   C O M M A N D
;*
;**************************************************************
;
TYPE:
    CALL    CONVFST        ;convert file name.
    JP    NZ,SYNERR    ;wild cards not allowed.
    CALL    DSELECT        ;select indicated drive.
    CALL    OPENFCB        ;open the file.
    JP    Z,TYPE5        ;not there?
    CALL    CRLF        ;ok, start a new line on the screen.
    LD    HL,NBYTES    ;initialize byte counter.
    LD    (HL),0FFH    ;set to read first sector.
TYPE1:
    LD    HL,NBYTES
TYPE2:
    LD    A,(HL)        ;have we written the entire sector?
    CP    128
    JP    C,TYPE3
    PUSH    HL        ;yes, read in the next one.
    CALL    READFCB
    POP    HL
    JP    NZ,TYPE4    ;end or error?
    XOR    A        ;ok, clear byte counter.
    LD    (HL),A
TYPE3:
    INC    (HL)        ;count this byte.
    LD    HL,TBUFF    ;and get the (A)th one from the buffer (TBUFF).
    CALL    ADDHL
    LD    A,(HL)
    CP    CNTRLZ        ;end of file mark?
    JP    Z,GETBACK
    CALL    PRINT        ;no, print it.
    CALL    CHKCON        ;check console, quit if anything ready.
    JP    NZ,GETBACK
    JP    TYPE1
;
;   Get here on an end of file or read error.
;
TYPE4:
    DEC    A        ;read error?
    JP    Z,GETBACK
    CALL    RDERROR        ;yes, print message.
TYPE5:
    CALL    RESETDR        ;and reset proper drive
    JP    SYNERR        ;now print file name with problem.
;
;**************************************************************
;*
;*            S A V E   C O M M A N D
;*
;**************************************************************
;
SAVE:
    CALL    DECODE        ;get numeric number that follows SAVE.
    PUSH    AF        ;save number of pages to write.
    CALL    CONVFST        ;convert file name.
    JP    NZ,SYNERR    ;wild cards not allowed.
    CALL    DSELECT        ;select specified drive.
    LD    DE,FCB        ;now delete this file.
    PUSH    DE
    CALL    DELETE
    POP    DE
    CALL    CREATE        ;and create it again.
    JP    Z,SAVE3        ;can't create?
    XOR    A        ;clear record number byte.
    LD    (FCB+32),A
    POP    AF        ;convert pages to sectors.
    LD    L,A
    LD    H,0
    ADD    HL,HL        ;(HL)=number of sectors to write.
    LD    DE,TBASE    ;and we start from here.
SAVE1:
    LD    A,H        ;done yet?
    OR    L
    JP    Z,SAVE2
    DEC    HL        ;nope, count this and compute the start
    PUSH    HL        ;of the next 128 byte sector.
    LD    HL,128
    ADD    HL,DE
    PUSH    HL        ;save it and set the transfer address.
    CALL    DMASET
    LD    DE,FCB        ;write out this sector now.
    CALL    WRTREC
    POP    DE        ;reset (DE) to the start of the last sector.
    POP    HL        ;restore sector count.
    JP    NZ,SAVE3    ;write error?
    JP    SAVE1
;
;   Get here after writing all of the file.
;
SAVE2:
    LD    DE,FCB        ;now close the file.
    CALL    CLOSE
    INC    A        ;did it close ok?
    JP    NZ,SAVE4
;
;   Print out error message (no space).
;
SAVE3:
    LD    BC,NOSPACE
    CALL    PLINE
SAVE4:
    CALL    STDDMA        ;reset the standard dma address.
    JP    GETBACK

NOSPACE:
    DEFM    "No space",0
;
;**************************************************************
;*
;*           R E N A M E   C O M M A N D
;*
;**************************************************************
;
RENAME:
    CALL    CONVFST         ;convert first file name.
    JP      NZ,SYNERR       ;wild cards not allowed.
    LD      A,(CHGDRV)      ;remember any change in drives specified.
    PUSH    AF
    CALL    DSELECT         ;and select this drive.
    CALL    SRCHFCB         ;is this file present?
    JP      NZ,RENAME6      ;yes, print error message.
    LD      HL,FCB          ;yes, move this name into second slot.
    LD      DE,FCB+16
    CALL    LDI_16          ;copy 16 bytes
    LD      HL,(INPOINT)    ;get input pointer.
    EX      DE,HL
    CALL    NONBLANK        ;get next non blank character.
    CP      '='             ;only allow an '=' or '_' seperator.
    JP      Z,RENAME1
    CP      '_'
    JP      NZ,RENAME5
RENAME1:
    EX      DE,HL
    INC     HL              ;ok, skip seperator.
    LD      (INPOINT),HL    ;save input line pointer.
    CALL    CONVFST         ;convert this second file name now.
    JP      NZ,RENAME5      ;again, no wild cards.
    POP     AF              ;if a drive was specified, then it
    LD      B,A             ;must be the same as before.
    LD      HL,CHGDRV
    LD      A,(HL)
    OR      A
    JP      Z,RENAME2
    CP      B
    LD      (HL),B
    JP      NZ,RENAME5      ;they were different, error.
RENAME2:
    LD      (HL),B          ;reset as per the first file specification.
    XOR     A
    LD      (FCB),A         ;clear the drive byte of the fcb.
RENAME3:
    CALL    SRCHFCB         ;and go look for second file.
    JP      Z,RENAME4       ;doesn't exist?
    LD      DE,FCB
    CALL    RENAM           ;ok, rename the file.
    JP      GETBACK
;
;   Process rename errors here.
;
RENAME4:
    CALL    NONE            ;file not there.
    JP      GETBACK

RENAME5:
    CALL    RESETDR        ;bad command format.
    JP      SYNERR

RENAME6:
    LD      BC,EXISTS       ;destination file already exists.
    CALL    PLINE
    JP      GETBACK

EXISTS:
    DEFM    "File exists",0
;
;**************************************************************
;*
;*             U S E R   C O M M A N D
;*
;**************************************************************
;
USER:
    CALL    DECODE      ;get numeric value following command.
    CP      16          ;legal user number?
    JP      NC,SYNERR
    LD      E,A         ;yes but is there anything else?
    LD      A,(FCB+1)
    CP      ' '
    JP      Z,SYNERR    ;yes, that is not allowed.
    CALL    GETSETUC    ;ok, set user code.
    JP      GETBACK1
;
;**************************************************************
;*
;*             E X I T   C O M M A N D
;*
;**************************************************************
;
EXTERN _cpm_bios_canary
EXTERN __Exit
;
EXIT:
    LD      BC,EXIT_MSG ;notify exit to bios monitor
    CALL    PLINE
    XOR     A
    LD      (_cpm_bios_canary),A    ;kill the bios canary
    OUT     ($38),A                 ;toggle ROM
    JP      __Exit                  ;reset back to ROM monitor
                                    ;initialise from beginning
                                    ;in case large CP/M apps
                                    ;overwrite the heap, etc
;
EXIT_MSG:
    DEFM    "Exiting CP/M\n",0
;
;**************************************************************
;*
;*        T R A N S I E N T   P R O G R A M   C O M M A N D
;*
;**************************************************************
;
UNKNOWN:
;   CALL    VERIFY        ;check for valid system (why?).
    LD    A,(FCB+1)    ;anything to execute?
    CP    ' '
    JP    NZ,UNKWN1
    LD    A,(CHGDRV)    ;nope, only a drive change?
    OR    A
    JP    Z,GETBACK1    ;neither???
    DEC    A
    LD    (CDRIVE),A    ;ok, store new drive.
    CALL    MOVECD        ;set (TDRIVE) also.
    CALL    DSKSEL        ;and select this drive.
    JP    GETBACK1    ;then return.
;
;   Here a file name was typed. Prepare to execute it.
;
UNKWN1:
    LD    DE,FCB+9    ;an extension specified?
    LD    A,(DE)
    CP    ' '
    JP    NZ,SYNERR    ;yes, not allowed.
UNKWN2:
    PUSH    DE
    CALL    DSELECT        ;select specified drive.
    POP    DE
    LD    HL,COMFILE    ;set the extension to 'COM'.
    LDI
    LDI
    LDI
    CALL    OPENFCB        ;and open this file.
    JP    Z,UNKWN9    ;not present?
;
;   Load in the program.
;
    LD    HL,TBASE    ;store the program starting here.
UNKWN3:
    PUSH    HL
    EX    DE,HL
    CALL    DMASET        ;set transfer address.
    LD    DE,FCB        ;and read the next record.
    CALL    RDREC
    JP    NZ,UNKWN4    ;end of file or read error?
    POP    HL        ;nope, bump pointer for next sector.
    LD    DE,128
    ADD    HL,DE
    LD    DE,CBASE    ;enough room for the whole file?
    LD    A,L
    SUB    E
    LD    A,H
    SBC    A,D
    JP    NC,UNKWN0    ;no, it can't fit.
    JP    UNKWN3
;
;   Get here after finished reading.
;
UNKWN4:
    POP    HL
    DEC    A        ;normal end of file?
    JP    NZ,UNKWN0
    CALL    RESETDR        ;yes, reset previous drive.
    CALL    CONVFST        ;convert the first file name that follows
    LD    HL,CHGDRV    ;command name.
    PUSH    HL
    LD    A,(HL)        ;set drive code in default fcb.
    LD    (FCB),A
    LD    A,16        ;put second name 16 bytes later.
    CALL    CONVERT        ;convert second file name.
    POP    HL
    LD    A,(HL)        ;and set the drive for this second file.
    LD    (FCB+16),A
    XOR    A        ;clear record byte in fcb.
    LD    (FCB+32),A
    LD    DE,TFCB        ;move it into place at(005Ch).
    LD    HL,FCB
    CALL    LDI_32      ;move 33 bytes in total
    LD      A,(HL)
    LD      (DE),A
    LD    HL,INBUFF+2    ;now move the remainder of the input
UNKWN5:
    LD    A,(HL)        ;line down to (0080h). Look for a non blank.
    OR    A         ;or a null.
    JP    Z,UNKWN6
    CP    ' '
    JP    Z,UNKWN6
    INC     HL
    JP    UNKWN5
;
;   Do the line move now. It ends in a null byte.
;
UNKWN6:
    LD    B,0        ;keep a character count.
    LD    DE,TBUFF+1    ;data gets put here.
UNKWN7:
    LD    A,(HL)        ;move it now.
    LD    (DE),A
    OR    A
    JP    Z,UNKWN8
    INC    B
    INC    HL
    INC    DE
    JP    UNKWN7
UNKWN8:
    LD    A,B        ;now store the character count.
    LD    (TBUFF),A
    CALL    CRLF        ;clean up the screen.
    CALL    STDDMA        ;set standard transfer address.
    CALL    SETCDRV        ;reset current drive.
    CALL    TBASE        ;and execute the program.
;
;   Transient programs return here (or reboot).
;
    LD    SP,BATCH    ;set stack first off.
    CALL    MOVECD        ;move current drive into place (TDRIVE).
    CALL    DSKSEL        ;and reselect it.
    JP    CMMND1        ;back to comand mode.
;
;   Get here if some error occured.
;
UNKWN9:
    CALL    RESETDR        ;inproper format.
    JP    SYNERR

UNKWN0:
    LD    BC,BADLOAD    ;read error or won't fit.
    CALL    PLINE
    JP    GETBACK

BADLOAD:
    DEFM    "Bad load",0
COMFILE:
    DEFM    "COM"        ;command file extension.
;
;   Get here to return to command level. We will reset the
;   previous active drive and then either return to command
;   level directly or print error message and then return.
;
GETBACK:
    CALL    RESETDR        ;reset previous drive.
GETBACK1:
    CALL    CONVFST        ;convert first name in (FCB).
    LD    A,(FCB+1)    ;if this was just a drive change request,
    SUB    ' '        ;make sure it was valid.
    LD    HL,CHGDRV
    OR    (HL)
    JP    NZ,SYNERR
    JP    CMMND1        ;ok, return to command level.

PUBLIC  _cpm_ccp_tail

_cpm_ccp_tail:                 ;tail of the cpm ccp

PUBLIC  _cpm_ccp_data_head

_cpm_ccp_data_head:            ;origin of the cpm ccp data

;
;   Batch (or SUBMIT) processing information storage.
;
BATCH:      DEFB    0        ;batch mode flag (0=not active).
BATCHFCB:   DEFM    0,"$$$     SUB",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;
;   File control block setup by the CCP.
;
FCB:        DEFM    0,"           ",0,0,0,0,0,"           ",0,0,0,0,0
RTNCODE:    DEFB    0        ;status returned from bdos call.
CDRIVE:     DEFB    0        ;currently active drive.
CHGDRV:     DEFB    0        ;change in drives flag (0=no change).
NBYTES:     DEFW    0        ;byte counter used by TYPE.

;
;   Room for expansion, and prevent potential stack overflow.
;
ALIGN       0x20

;
;   ccp stack area.
;
            DEFS    32,0
CCPSTACK:                   ;top of ccp stack area.

;
;   Note that the following six bytes must match those at
;   (PATTRN1) or cp/m will HALT. Why?
;
;PATTRN2:    DEFM    0,22,0,0,0,0    ;(* serial number bytes *).

PUBLIC  _cpm_ccp_data_tail
_cpm_ccp_data_tail:         ;tail of the cpm ccp

;
;**************************************************************
;*
;*                    B D O S   E N T R Y
;*
;**************************************************************
;

ALIGN       0x100           ;ALIGN the FBASE to a page

PUBLIC      _cpm_bdos_head
_cpm_bdos_head:             ;origin of the cpm bdos

;   Entry into bdos. (DE) or (E) are the parameters passed. The
;   function number desired is in register (C).
;
FBASE:
    EX      DE,HL           ;save the (DE) parameters.
    LD      (PARAMS),HL
    EX      DE,HL
    LD      A,E             ;and save register (E) in particular.
    LD      (EPARAM),A
    LD      HL,0
    LD      (STATUS),HL     ;clear return status.
    LD      (USRSTACK),SP   ;save users stack pointer.
    LD      SP,STKAREA      ;and set our own.
    XOR     A               ;clear auto select storage space.
    LD      (AUTOFLAG),A
    LD      (AUTO),A
    LD      HL,GOBACK       ;set return address.
    PUSH    HL
    LD      A,C             ;get function number.
    CP      NFUNCTS         ;valid function number?
    RET     NC
    LD      C,E             ;keep single register function here.   
    LD      HL,FUNCTNS      ;now look thru the function table.
    LD      E,A
    LD      D,0             ;(DE)=function number.
    ADD     HL,DE
    ADD     HL,DE           ;(HL)=(start of table)+2*(function number).
    LD      E,(HL)
    INC     HL
    LD      D,(HL)          ;now (DE)=address for this function.
    LD      HL,(PARAMS)     ;retrieve parameters.
    EX      DE,HL           ;now (DE) has the original parameters.
    JP      (HL)            ;execute desired function.
;
;   BDOS function jump table.
;
    DEFC    NFUNCTS = 41    ;number of functions in following table.

FUNCTNS:
    DEFW    WBOOT,GETCON,OUTCON,GETRDR,PUNCH,LIST,DIRCIO,GETIOB
    DEFW    SETIOB,PRTSTR,RDBUFF,GETCSTS,GETVER,RSTDSK,SETDSK,OPENFIL
    DEFW    CLOSEFIL,GETFST,GETNXT,DELFILE,READSEQ,WRTSEQ,FCREATE
    DEFW    RENFILE,GETLOG,GETCRNT,PUTDMA,GETALOC,WRTPRTD,GETROV,SETATTR
    DEFW    GETPARM,GETUSER,RDRANDOM,WTRANDOM,FILESIZE,SETRAN,LOGOFF,RTN
    DEFW    RTN,WTSPECL
;
;   Bdos error message section.
;
BADSCTR:
    LD      HL,BADSEC       ;bad sector message.
    CALL    PRTERR          ;print it and get a 1 char response.
    CP      CNTRLC          ;re-boot request (control-c)?
    JP      Z,0             ;yes.
    RET                     ;no, return to retry i/o function.

BADSLCT:
    LD      HL,BADSEL       ;bad drive selected.
    JP      ERRORBDOS

RODISK:
    LD      HL,DISKRO       ;disk is read only.
    JP      ERRORBDOS

ROFILE:
    LD      HL,FILERO       ;file is read only.

ERRORBDOS:
    CALL    PRTERR
    JP      0               ;always reboot on these errors.

BDOSERR:    DEFM    "Bdos Err On "
BDOSDRV:    DEFM    " : $"
BADSEC:     DEFM    "Bad Sector$"
BADSEL:     DEFM    "Select$"
FILERO:     DEFM    "File "
DISKRO:     DEFM    "R/O$"
;
;   Print bdos error message.
;
PRTERR:
    PUSH    HL              ;save second message pointer.
    CALL    OUTCRLF         ;send (cr)(lf).
    LD      A,(ACTIVE)      ;get active drive.
    ADD     A,'A'           ;make ascii.
    LD      (BDOSDRV),A     ;and put in message.
    LD      BC,BDOSERR      ;and print it.
    CALL    PRTMESG
    POP     BC              ;print second message line now.
    CALL    PRTMESG
;
;   Get an input character. We will check our 1 character
;   buffer first. This may be set by the console status routine.
;
GETCHAR:
    LD      HL,CHARBUF      ;check character buffer.
    LD      A,(HL)          ;anything present already?
    LD      (HL),0          ;...either case clear it.
    OR      A
    RET     NZ              ;yes, use it.
    JP      CONIN           ;nope, go get a character responce.
;
;   Input and echo a character.
;
GETECHO:
    CALL    GETCHAR         ;input a character.
    CALL    CHKCHAR         ;carriage control?
    RET     C               ;no, a regular control char so don't echo.
    PUSH    AF              ;ok, save character now.
    LD      C,A
    CALL    OUTCON          ;and echo it.
    POP     AF              ;get character and return.
    RET
;
;   Check character in (A). Set the zero flag on a carriage
;   control character and the carry flag on any other control
;   character.
;
CHKCHAR:
    CP      CR              ;check for carriage return, line feed, backspace,
    RET     Z               ;or a tab.
    CP      LF
    RET     Z
    CP      TAB
    RET     Z
    CP      BS
    RET     Z
    CP      ' '             ;other control char? Set carry flag.
    RET
;
;   Check the console during output. Halt on a control-s, then
;   reboot on a control-c. If anything else is ready, clear the
;   zero flag and return (the calling routine may want to do
;   something).
;
CKCONSOL:
    LD      A,(CHARBUF)     ;check buffer.
    OR      A               ;if anything, just return without checking.
    JP      NZ,CKCON2
    CALL    CONST           ;nothing in buffer. Check console.
    AND     01H             ;look at bit 0.
    RET     Z               ;return if nothing.
    CALL    CONIN           ;ok, get it.
    CP      CNTRLS          ;if not control-s, return with zero cleared.
    JP      NZ,CKCON1
    CALL    CONIN           ;halt processing until another char
    CP      CNTRLC          ;is typed. Control-c?
    JP      Z,0             ;yes, reboot now.
    XOR     A               ;no, just pretend nothing was ever ready.
    RET
CKCON1:
    LD      (CHARBUF),A     ;save character in buffer for later processing.
CKCON2:
    LD      A,1             ;set (A) to non zero to mean something is ready.
    RET
;
;   Output (C) to the screen. If the printer flip-flop flag
;   is set, we will send character to printer also. The console
;   will be checked in the process.
;
OUTCHAR:
    LD      A,(OUTFLAG)     ;check output flag.
    OR      A               ;anything and we won't generate output.
    JP      NZ,OUTCHR1
    PUSH    BC
    CALL    CKCONSOL        ;check console (we don't care what's there).
    POP     BC
    PUSH    BC
    CALL    CONOUT          ;output (C) to the screen.
    POP     BC
    PUSH    BC
    LD      A,(PRTFLAG)     ;check printer flip-flop flag.
    OR      A
    CALL    NZ,LIST         ;print it also if non-zero.
    POP     BC
OUTCHR1:
    LD      A,C             ;update cursors position.
    LD      HL,CURPOS
    CP      DEL             ;rubouts don't do anything here.
    RET     Z
    INC     (HL)            ;bump line pointer.
    CP      ' '             ;and return if a normal character.
    RET     NC
    DEC     (HL)            ;restore and check for the start of the line.
    LD      A,(HL)
    OR      A
    RET     Z               ;ignore control characters at the start of the line.
    LD      A,C
    CP      BS              ;is it a backspace?
    JP      NZ,OUTCHR2
    DEC     (HL)            ;yes, backup pointer.
    RET
OUTCHR2:
    CP      LF              ;is it a line feed?
    RET     NZ              ;ignore anything else.
    LD      (HL),0          ;reset pointer to start of line.
    RET
;
;   Output (A) to the screen. If it is a control character
;   (other than carriage control), use ^x format.
;
SHOWIT:
    LD      A,C
    CALL    CHKCHAR         ;check character.
    JP      NC,OUTCON       ;not a control, use normal output.
    PUSH    AF
    LD      C,'^'           ;for a control character, preceed it with '^'.
    CALL    OUTCHAR
    POP     AF
    OR      '@'             ;and then use the letter equivalent.
    LD      C,A
;
;   Function to output (C) to the console device and expand tabs
;   if necessary.
;
OUTCON:
    LD      A,C
    CP      TAB             ;is it a tab?
    JP      NZ,OUTCHAR      ;use regular output.
OUTCON1:
    LD      C,' '           ;yes it is, use spaces instead.
    CALL    OUTCHAR
    LD      A,(CURPOS)      ;go until the cursor is at a multiple of 8

    AND     07H             ;position.
    JP      NZ,OUTCON1
    RET
;
;   Echo a backspace character. Erase the prevoius character
;   on the screen.
;
BACKUP:
    CALL    BACKUP1         ;backup the screen 1 place.
    LD      C,' '           ;then blank that character.
    CALL    CONOUT
BACKUP1:
    LD      C,BS            ;then back space once more.
    JP      CONOUT
;
;   Signal a deleted line. Print a '#' at the end and start
;   over.
;
NEWLINE:
    LD      C,'#'
    CALL    OUTCHAR         ;print this.
    CALL    OUTCRLF         ;start new line.
NEWLN1:
    LD      A,(CURPOS)      ;move the cursor to the starting position.
    LD      HL,STARTING
    CP      (HL)
    RET     NC              ;there yet?
    LD      C,' '
    CALL    OUTCHAR         ;nope, keep going.
    JP      NEWLN1
;
;   Output a (cr) (lf) to the console device (screen).
;
OUTCRLF:   
    LD      C,CR
    CALL    OUTCHAR
    LD      C,LF
    JP      OUTCHAR
;
;   Print message pointed to by (BC). It will end with a '$'.
;
PRTMESG:
    LD      A,(BC)          ;check for terminating character.
    CP      '$'
    RET     Z
    INC     BC
    PUSH    BC              ;otherwise, bump pointer and print it.
    LD      C,A
    CALL    OUTCON
    POP     BC
    JP      PRTMESG
;
;   Function to execute a buffered read.
;
RDBUFF:
    LD      A,(CURPOS)      ;use present location as starting one.
    LD      (STARTING),A
    LD      HL,(PARAMS)     ;get the maximum buffer space.
    LD      C,(HL)
    INC     HL              ;point to first available space.
    PUSH    HL              ;and save.
    LD      B,0             ;keep a character count.
RDBUF1:
    PUSH    BC
    PUSH    HL
RDBUF2:
    CALL    GETCHAR         ;get the next input character.
    AND     7FH             ;strip bit 7.
    POP     HL              ;reset registers.
    POP     BC
    CP      CR              ;end of the line?
    JP      Z,RDBUF17
    CP      LF
    JP      Z,RDBUF17
    CP      BS              ;how about a backspace?
    JP      NZ,RDBUF3
    LD      A,B             ;yes, but ignore at the beginning of the line.
    OR      A
    JP      Z,RDBUF1
    DEC     B               ;ok, update counter.
    LD      A,(CURPOS)      ;if we backspace to the start of the line,
    LD      (OUTFLAG),A     ;treat as a cancel (control-x).
    JP      RDBUF10
RDBUF3:
    CP      DEL             ;user typed a rubout?
    JP      NZ,RDBUF4
    LD      A,B             ;ignore at the start of the line.
    OR      A
    JP      Z,RDBUF1
    LD      A,(HL)          ;ok, echo the prevoius character.
    DEC     B               ;and reset pointers (counters).
    DEC     HL
    JP      RDBUF15
RDBUF4:
    CP      CNTRLE          ;physical end of line?
    JP      NZ,RDBUF5
    PUSH    BC              ;yes, do it.
    PUSH    HL
    CALL    OUTCRLF
    XOR     A               ;and update starting position.
    LD      (STARTING),A
    JP      RDBUF2
RDBUF5:
    CP      CNTRLP          ;control-p?
    JP      NZ,RDBUF6
    PUSH    HL              ;yes, flip the print flag filp-flop byte.
    LD      HL,PRTFLAG
    LD      A,1             ;PRTFLAG=1-PRTFLAG
    SUB     (HL)
    LD      (HL),A
    POP     HL
    JP      RDBUF1
RDBUF6:
    CP      CNTRLX          ;control-x (cancel)?
    JP      NZ,RDBUF8
    POP     HL
RDBUF7:
    LD      A,(STARTING)    ;yes, backup the cursor to here.
    LD      HL,CURPOS
    CP      (HL)
    JP      NC,RDBUFF       ;done yet?
    DEC     (HL)            ;no, decrement pointer and output back up one space.
    CALL    BACKUP
    JP      RDBUF7
RDBUF8:
    CP      CNTRLU          ;control-u (cancel line)?
    JP      NZ,RDBUF9
    CALL    NEWLINE         ;start a new line.
    POP     HL
    JP      RDBUFF
RDBUF9:
    CP      CNTRLR          ;control-r?
    JP      NZ,RDBUF14
RDBUF10:
    PUSH    BC              ;yes, start a new line and retype the old one.
    CALL    NEWLINE
    POP     BC
    POP     HL
    PUSH    HL
    PUSH    BC
RDBUF11:
    LD      A,B             ;done whole line yet?
    OR      A
    JP      Z,RDBUF12
    INC     HL              ;nope, get next character.
    LD      C,(HL)
    DEC     B               ;count it.
    PUSH    BC
    PUSH    HL
    CALL    SHOWIT          ;and display it.
    POP     HL
    POP     BC
    JP      RDBUF11
RDBUF12:
    PUSH    HL              ;done with line. If we were displaying
    LD      A,(OUTFLAG)     ;then update cursor position.
    OR      A
    JP      Z,RDBUF2
    LD      HL,CURPOS       ;because this line is shorter, we must
    SUB     (HL)            ;back up the cursor (not the screen however)
    LD      (OUTFLAG),A     ;some number of positions.
RDBUF13:
    CALL    BACKUP          ;note that as long as (OUTFLAG) is non
    LD      HL,OUTFLAG      ;zero, the screen will not be changed.
    DEC     (HL)
    JP      NZ,RDBUF13
    JP      RDBUF2          ;now just get the next character.
;
;   Just a normal character, put this in our buffer and echo.
;
RDBUF14:
    INC     HL
    LD      (HL),A          ;store character.
    INC     B               ;and count it.
RDBUF15:
    PUSH    BC
    PUSH    HL
    LD      C,A             ;echo it now.
    CALL    SHOWIT
    POP     HL
    POP     BC
    LD      A,(HL)          ;was it an abort request?
    CP      CNTRLC          ;control-c abort?
    LD      A,B
    JP      NZ,RDBUF16
    CP      1               ;only if at start of line.
    JP      Z,0
RDBUF16:
    CP      C               ;nope, have we filled the buffer?
    JP      C,RDBUF1
RDBUF17:
    POP     HL              ;yes end the line and return.
    LD      (HL),B
    LD      C,CR
    JP      OUTCHAR         ;output (cr) and return.
;
;   Function to get a character from the console device.
;
GETCON:
    CALL    GETECHO         ;get and echo.
    JP      SETSTAT         ;save status and return.
;
;   Function to get a character from the tape reader device.
;
GETRDR:
    CALL    READER          ;get a character from reader, set status and return.
    JP      SETSTAT
;
;   Function to perform direct console i/o. If (C) contains (FF)
;   then this is an input request. If (C) contains (FE) then
;   this is a status request. Otherwise we are to output (C).
;
DIRCIO:
    LD      A,C             ;test for (FF).
    INC     A
    JP      Z,DIRC1
    INC     A               ;test for (FE).
    JP      Z,CONST
    JP      CONOUT          ;just output (C).

DIRC1:
    CALL    CONST           ;this is an input request.
    OR      A
    JP      Z,RETMON        ;not ready? Just return (directly).
    CALL    CONIN           ;yes, get character.
    JP      SETSTAT         ;set status and return.
;
;   Function to return the i/o byte.
;
GETIOB:
    LD      A,(IOBYTE)
    JP      SETSTAT
;
;   Function to set the i/o byte.
;
SETIOB:
    LD      HL,IOBYTE
    LD      (HL),C
    RET
;
;   Function to print the character string pointed to by (DE)
;   on the console device. The string ends with a '$'.
;
PRTSTR:
    EX      DE,HL
    LD      BC,HL           ;now (BC) points to it.
    JP      PRTMESG
;
;   Function to interogate the console device.
;
GETCSTS:
    CALL    CKCONSOL
;
;   Get here to set the status and return to the cleanup
;   section. Then back to the user.
;
SETSTAT:
    LD      (STATUS),A
RTN:
    RET
;
;   Set the status to 1 (read or write error code).
;
IOERR1:
    LD      A,1
    JP      SETSTAT
;
;   Select error occured, jump to error routine.
;
SLCTERR:
    JP      BADSLCT
;
;   Select the desired drive.
;
SELECT:
    LD      A,(ACTIVE)      ;get active disk.
    LD      C,A
    CALL    SELDSK          ;select it.
    LD      A,H             ;valid drive?
    OR      L               ;valid drive?
    RET     Z               ;return if not.
;
;   Here, the BIOS returned the address of the parameter block
;   in (HL). We will extract the necessary pointers and save them.
;
    LD      E,(HL)          ;yes, get address of translation table into (DE).
    INC     HL
    LD      D,(HL)
    INC     HL
    LD      (SCRATCH1),HL   ;save pointers to scratch areas.
    INC     HL
    INC     HL
    LD      (SCRATCH2),HL   ;ditto.
    INC     HL
    INC     HL
    LD      (SCRATCH3),HL   ;ditto.
    INC     HL
    INC     HL
    EX      DE,HL           ;now save the translation table address.
    LD      (XLATE),HL
    LD      HL,DIRBUF       ;put the next 8 bytes in DIRBUF.
    EX      DE,HL
    CALL    LDI_8           ;they consist of the directory buffer, pointer, parameter block pointer.
    LD      HL,(DISKPB)     ;check and allocation vectors.
    LD      DE,SECTORS      ;move parameter block into our ram.
    CALL    LDI_15          ;it is 15 bytes long.
    LD      HL,(DSKSIZE)    ;check disk size.
    LD      A,H             ;more than 256 blocks on this?
    LD      HL,BIGDISK
    LD      (HL),0FFH       ;set to small.
    OR      A
    JP      Z,SELECT1
    LD      (HL),0          ;wrong, set to large.
SELECT1:
    LD      A,0FFH          ;clear the zero flag.
    OR      A
    RET
;
;   Routine to home the disk track head and clear pointers.
;
HOMEDRV:
    CALL    HOME            ;home the head.
    XOR     A
    LD      HL,(SCRATCH2)   ;set our track pointer also.
    LD      (HL+),A
    LD      (HL),A
    LD      HL,(SCRATCH3)   ;and our sector pointer.
    LD      (HL+),A
    LD      (HL),A
    RET
;
;   Do the actual disk read and check the error return status.
;
DOREAD:
    CALL    READ
    JP      IORET
;
;   Do the actual disk write and handle any bios error.
;
DOWRITE:
    CALL    WRITE
IORET:
    OR      A
    RET     Z               ;return unless an error occured.
    JP      BADSCTR         ;bad read/write on this sector.
;
;   Routine to select the track and sector that the desired
;   block number falls in.
;
TRKSEC:
    LD      HL,(FILEPOS)    ;get position of last accessed file
                            ;in directory and compute sector #.
    SRL     H               ;sector #=file-position/4.
    RR      L
    SRL     H
    RR      L
    LD      (BLKNMBR),HL    ;save this as the block number of interest.
;
;   If the sector number has already been set (BLKNMBR), enter
;   at this point.
;
TRKSEC1:
    LD      HL,BLKNMBR
    LD      C,(HL)          ;move sector number into (BC).
    INC     HL
    LD      B,(HL)
    LD      HL,(SCRATCH3)   ;get current sector number and
    LD      E,(HL)          ;move this into (DE).
    INC     HL
    LD      D,(HL)
    LD      HL,(SCRATCH2)   ;get current track number.
    LD      A,(HL)          ;and this into (HL).
    INC     HL
    LD      H,(HL)
    LD      L,A
TRKSEC2:
    LD      A,C             ;is desired sector before current one?
    SUB     E
    LD      A,B
    SBC     A,D
    JP      NC,TRKSEC3
    PUSH    HL              ;yes, decrement sectors by one track.
    LD      HL,(SECTORS)    ;get sectors per track.
    LD      A,E
    SUB     L
    LD      E,A
    LD      A,D
    SBC     A,H
    LD      D,A             ;now we have backed up one full track.
    POP     HL
    DEC     HL              ;adjust track counter.
    JP    TRKSEC2
TRKSEC3:
    PUSH    HL              ;desired sector is after current one.
    LD      HL,(SECTORS)    ;get sectors per track.
    ADD     HL,DE           ;bump sector pointer to next track.
    JP      C,TRKSEC4
    LD      A,C             ;is desired sector now before current one?
    SUB     L
    LD      A,B
    SBC     A,H
    JP      C,TRKSEC4
    EX      DE,HL           ;not yes, increment track counter
    POP     HL              ;and continue until it is.
    INC     HL
    JP      TRKSEC3
;
;   Here we have determined the track number that contains the
;   desired sector.
;
TRKSEC4:
    POP     HL              ;get track number (HL).
    PUSH    BC
    PUSH    DE
    PUSH    HL
    EX      DE,HL
    LD      HL,(OFFSET)     ;adjust for first track offset.
    ADD     HL,DE
    LD      BC,HL
    CALL    SETTRK          ;select this track.
    POP     DE              ;reset current track pointer.
    LD      HL,(SCRATCH2)
    LD      (HL+),E
    LD      (HL),D
    POP     DE
    LD      HL,(SCRATCH3)   ;reset the first sector on this track.
    LD      (HL+),E
    LD      (HL),D
    POP     BC
    LD      A,C             ;now subtract the desired one.
    SUB     E               ;to make it relative (1-# sectors/track).
    LD      C,A
    LD      A,B
    SBC     A,D
    LD      B,A
;   LD      HL,(XLATE)      ;translate this sector according to this table.
;   EX      DE,HL
;   CALL    SECTRN          ;let the bios translate it.
;   LD      BC,HL
    JP      SETSEC          ;and select it.
;
;   Compute block number from record number (SAVNREC) and
;   extent number (SAVEXT).
;
GETBLOCK:
    LD      HL,BLKSHFT      ;get logical to physical conversion.
    LD      C,(HL)          ;note that this is base 2 log of ratio.
    LD      A,(SAVNREC)     ;get record number.
GETBLK1:
    OR      A               ;compute (A)=(A)/2^BLKSHFT.
    RRA
    DEC     C
    JP      NZ,GETBLK1
    LD      B,A             ;save result in (B).
    LD      A,8
    SUB     (HL)
    LD      C,A             ;compute (C)=8-BLKSHFT.
    LD      A,(SAVEXT)
GETBLK2:
    DEC     C               ;compute (A)=SAVEXT*2^(8-BLKSHFT).
    JP      Z,GETBLK3
    OR      A
    RLA
    JP      GETBLK2
GETBLK3:
    ADD     A,B
    RET
;
;   Routine to extract the (BC) block byte from the fcb pointed
;   to by (PARAMS). If this is a big-disk, then these are 16 bit
;   block numbers, else they are 8 bit numbers.
;   Number is returned in (HL).
;
EXTBLK:
    LD      HL,(PARAMS)     ;get fcb address.
    LD      DE,16           ;block numbers start 16 bytes into fcb.
    ADD     HL,DE
    ADD     HL,BC
    LD      A,(BIGDISK)     ;are we using a big-disk?
    OR      A
    JP      Z,EXTBLK1
    LD      L,(HL)          ;no, extract an 8 bit number from the fcb.
    LD      H,0
    RET
EXTBLK1:
    ADD     HL,BC           ;yes, extract a 16 bit number.
    LD      E,(HL)
    INC     HL
    LD      D,(HL)
    EX      DE,HL           ;return in (HL).
    RET
;
;   Compute block number.
;
COMBLK:
    CALL    GETBLOCK
    LD      C,A
    LD      B,0
    CALL    EXTBLK
    LD      (BLKNMBR),HL
    RET
;
;   Check for a zero block number (unused).
;
CHKBLK:
    LD      HL,(BLKNMBR)
    LD      A,L             ;is it zero?
    OR      H
    RET
;
;   Adjust physical block (BLKNMBR) and convert to logical
;   sector (LOGSECT). This is the starting sector of this block.
;   The actual sector of interest is then added to this and the
;   resulting sector number is stored back in (BLKNMBR). This
;   will still have to be adjusted for the track number.
;
LOGICAL:
    LD      A,(BLKSHFT)     ;get log2(physical/logical sectors).
    LD      HL,(BLKNMBR)    ;get physical sector desired.
LOGICL1:
    ADD     HL,HL           ;compute logical sector number.
    DEC     A               ;note logical sectors are 128 bytes long.
    JP      NZ,LOGICL1
    LD      (LOGSECT),HL    ;save logical sector.
    LD      A,(BLKMASK)     ;get block mask.
    LD      C,A
    LD      A,(SAVNREC)     ;get next sector to access.
    AND     C               ;extract the relative position within physical block.
    OR      L               ;and add it too logical sector.
    LD      L,A
    LD      (BLKNMBR),HL    ;and store.
    RET
;
;   Set (HL) to point to extent byte in fcb.
;
SETEXT:
    LD      HL,(PARAMS)
    LD      DE,12           ;it is the twelth byte.
    ADD     HL,DE
    RET
;
;   Set (HL) to point to record count byte in fcb and (DE) to
;   next record number byte.
;
SETHLDE:
    LD      HL,(PARAMS)
    LD      DE,15           ;record count byte (#15).
    ADD     HL,DE
    EX      DE,HL
    LD      HL,17           ;next record number (#32).
    ADD     HL,DE
    RET
;
;   Save current file data from fcb.
;
STRDATA:
    CALL    SETHLDE
    LD      A,(HL)          ;get and store record count byte.
    LD      (SAVNREC),A
    EX      DE,HL
    LD      A,(HL)          ;get and store next record number byte.
    LD      (SAVNXT),A
    CALL    SETEXT          ;point to extent byte.
    LD      A,(EXTMASK)     ;get extent mask.
    AND     (HL)
    LD      (SAVEXT),A      ;and save extent here.
    RET
;
;   Set the next record to access. If (MODE) is set to 2, then
;   the last record byte (SAVNREC) has the correct number to access.
;   For sequential access, (MODE) will be equal to 1.
;
SETNREC:
    CALL    SETHLDE
    LD      A,(MODE)        ;get sequential flag (=1).
    CP      2               ;a 2 indicates that no adder is needed.
    JP      NZ,STNREC1
    XOR     A               ;clear adder (random access?).
STNREC1:
    LD      C,A
    LD      A,(SAVNREC)     ;get last record number.
    ADD     A,C             ;increment record count.
    LD      (HL),A          ;and set fcb's next record byte.
    EX      DE,HL
    LD      A,(SAVNXT)      ;get next record byte from storage.
    LD      (HL),A          ;and put this into fcb as number of records used.
    RET
;
;   Shift (HL) right (C) bits.
;
SHIFTR:
    INC     C
SHIFTR1:
    DEC     C
    RET     Z
    SRL     H
    RR      L
    JP      SHIFTR1
;
;   Compute the check-sum for the directory buffer. Return
;   integer sum in (A).
;
CHECKSUM:
    LD      C,128           ;length of buffer.
    LD      HL,(DIRBUF)     ;get its location.
    XOR     A               ;clear summation byte.
CHKSUM1:
    ADD     A,(HL)          ;and compute sum ignoring carries.
    INC     HL
    DEC     C
    JP      NZ,CHKSUM1
    RET
;
;   Shift (HL) left (C) bits.
;
SHIFTL:
    INC     C
SHIFTL1:
    DEC     C
    RET     Z
    ADD     HL,HL           ;shift left 1 bit.
    JP      SHIFTL1
;
;   Routine to set a bit in a 16 bit value contained in (BC).
;   The bit set depends on the current drive selection.
;
SETBIT:
    PUSH    BC              ;save 16 bit word.
    LD      A,(ACTIVE)      ;get active drive.
    LD      C,A
    LD      HL,1
    CALL    SHIFTL          ;shift bit 0 into place.
    POP     BC              ;now 'or' this with the original word.
    LD      A,C
    OR      L
    LD      L,A             ;low byte done, do high byte.
    LD      A,B
    OR      H
    LD      H,A
    RET
;
;   Extract the write protect status bit for the current drive.
;   The result is returned in (A), bit 0.
;
GETWPRT:
    LD      HL,(WRTPRT)     ;get status bytes.
    LD      A,(ACTIVE)      ;which drive is current?
    LD      C,A
    CALL    SHIFTR          ;shift status such that bit 0 is the
    LD      A,L             ;one of interest for this drive.
    AND     01H             ;and isolate it.
    RET
;
;   Function to write protect the current disk.
;
WRTPRTD:
    LD      HL,WRTPRT       ;point to status word.
    LD      C,(HL)          ;set (BC) equal to the status.
    INC     HL
    LD      B,(HL)
    CALL    SETBIT          ;and set this bit according to current drive.
    LD      (WRTPRT),HL     ;then save.
    LD      HL,(DIRSIZE)    ;now save directory size limit.
    INC     HL              ;remember the last one.
    EX      DE,HL
    LD      HL,(SCRATCH1)   ;and store it here.
    LD      (HL+),E         ;put low byte.
    LD      (HL),D          ;then high byte.
    RET
;
;   Check for a read only file.
;
CHKROFL:
    CALL    FCB2HL          ;set (HL) to file entry in directory buffer.
CKROF1:
    LD      DE,9            ;look at bit 7 of the ninth byte.
    ADD     HL,DE
    LD      A,(HL)
    RLA
    RET     NC              ;return if ok.
    JP      ROFILE          ;else, print error message and terminate.
;
;   Check the write protect status of the active disk.
;
CHKWPRT:
    CALL    GETWPRT
    RET     Z               ;return if ok.
    JP      RODISK          ;else print message and terminate.
;
;   Routine to set (HL) pointing to the proper entry in the
;   directory buffer.
;
FCB2HL:
    LD      HL,(DIRBUF)     ;get address of buffer.
    LD      A,(FCBPOS)      ;relative position of file.
    ADD     A,L
    LD      L,A
    RET     NC
    INC     H               ;take care of any carry.
    RET
;
;   Routine to get the 's2' byte from the fcb supplied in
;   the initial parameter specification.
;
GETS2:
    LD      HL,(PARAMS)     ;get address of fcb.
    LD      DE,14           ;relative position of 's2'.
    ADD     HL,DE
    LD      A,(HL)          ;extract this byte.
    RET
;
;   Clear the 's2' byte in the fcb.
;
CLEARS2:
    CALL    GETS2           ;this sets (HL) pointing to it.
    LD      (HL),0          ;now clear it.
    RET
;
;   Set bit 7 in the 's2' byte of the fcb.
;
SETS2B7:
    CALL    GETS2           ;get the byte.
    OR      80H             ;and set bit 7.
    LD      (HL),A          ;then store.
    RET
;
;   Compare (FILEPOS) with (SCRATCH1) and set flags based on
;   the difference. This checks to see if there are more file
;   names in the directory. We are at (FILEPOS) and there are
;   (SCRATCH1) of them to check.
;
MOREFLS:
    LD      HL,(FILEPOS)    ;we are here.
    EX      DE,HL
    LD      HL,(SCRATCH1)   ;and don't go past here.
    LD      A,E             ;compute difference but don't keep.
    SUB     (HL)
    INC     HL
    LD      A,D
    SBC     A,(HL)          ;set carry if no more names.
    RET
;
;   Call this routine to prevent (SCRATCH1) from being greater
;   than (FILEPOS).
;
CHKNMBR:
    CALL    MOREFLS         ;SCRATCH1 too big?
    RET     C
    INC     DE              ;yes, reset it to (FILEPOS).
    LD      (HL-),D
    LD      (HL),E
    RET
;
;   Set the directory checksum byte.
;
SETDIR:
    LD      C,0FFH
;
;   Routine to set or compare the directory checksum byte. If
;   (C)=0ffh, then this will set the checksum byte. Else the byte
;   will be checked. If the check fails (the disk has been changed),
;   then this disk will be write protected.
;
CHECKDIR:
    LD      HL,(CKSUMTBL)
    LD      DE,(ALLOC1)
    OR      A               ;clear carry
    SBC     HL,DE           ;HL=(CKSUMTBL)-(ALLOC1)
    RET     NC              ;ok if (CKSUMTBL) > (ALLOC1), so return.
    PUSH    BC
    CALL    CHECKSUM        ;else compute checksum.
    LD      HL,(CHKVECT)    ;get address of checksum table.
    EX      DE,HL
    LD      HL,(CKSUMTBL)
    ADD     HL,DE           ;set (HL) to point to byte for this drive.
    POP     BC
    INC     C               ;set or check ?
    JP      Z,CHKDIR1
    CP      (HL)            ;check them.
    RET     Z               ;return if they are the same.
    CALL    MOREFLS         ;not the same, do we care?
    RET     NC
    CALL    WRTPRTD         ;yes, mark this as write protected.
    RET
CHKDIR1:
    LD      (HL),A          ;just set the byte.
    RET
;
;   Do a write to the directory of the current disk.
;
DIRWRITE:
    CALL    SETDIR          ;set checksum byte.
    CALL    DIRDMA          ;set directory dma address.
    LD      C,1             ;tell the bios to actually write.
    CALL    DOWRITE         ;then do the write.
    JP      DEFDMA
;
;   Read from the directory.
;
DIRREAD:
    CALL    DIRDMA          ;set the directory dma address.
    CALL    DOREAD          ;and read it.
;
;   Routine to set the dma address to the users choice.
;
DEFDMA:
    LD      HL,USERDMA      ;reset the default dma address and return.
    JP      DIRDMA1
;
;   Routine to set the dma address for directory work.
;
DIRDMA:
    LD      HL,DIRBUF
;
;   Set the dma address. On entry, (HL) points to
;   word containing the desired dma address.
;
DIRDMA1:
    LD      C,(HL+)
    LD      B,(HL)          ;setup (BC) and go to the bios to set it.
    JP      SETDMA
;
;   Move the directory buffer into user's dma space.
;
MOVEDIR:
    LD      HL,(DIRBUF)     ;buffer is located here, and
    LD      DE,(USERDMA)    ;put it here.
;
LDI_128:                    ;(HL++)->(DE++), 128 times.
    LD      BC,LDI_32       ;do the LDI 32 times,
    PUSH    BC              ;a total of 4 times,
    PUSH    BC              ;for a total of 128 bytes.
    PUSH    BC
;
LDI_32:                     ;(HL++)->(DE++), 32 times.
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
LDI_16:                     ;(HL++)->(DE++), 16 times.
    LDI
LDI_15:                     ;(HL++)->(DE++), 15 times.
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
LDI_8:                     ;(HL++)->(DE++), 8 times.
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    RET
;
;   Check (FILEPOS) and set the zero flag if it equals 0ffffh.
;
CKFILPOS:
    LD      HL,FILEPOS
    LD      A,(HL)
    INC     HL
    CP      (HL)            ;are both bytes the same?
    RET     NZ
    INC     A               ;yes, but are they each 0ffh?
    RET
;
;   Set location (FILEPOS) to 0ffffh.
;
STFILPOS:
    LD      HL,0FFFFH
    LD      (FILEPOS),HL
    RET
;
;   Move on to the next file position within the current
;   directory buffer. If no more exist, set pointer to 0ffffh
;   and the calling routine will check for this. Enter with (C)
;   equal to 0ffh to cause the checksum byte to be set, else we
;   will check this disk and set write protect if checksums are
;   not the same (applies only if another directory sector must
;   be read).
;
NXENTRY:
    LD      HL,(FILEPOS)    ;get current count.
    INC     HL              ;go on to the next one.
    LD      (FILEPOS),HL
    EX      DE,HL
    LD      HL,(DIRSIZE)    ;get directory entry size limit.
    OR      A               ;clear carry
    SBC     HL,DE           ;HL=(DIRSIZE)-(FILEPOS)
    JP      NC,NXENT1       ;is there more room left?
    JP      STFILPOS        ;no. Set this flag and return.
NXENT1:
    LD      A,(FILEPOS)     ;get file position within directory.
    AND     03H             ;only look within this sector (only 4 entries fit).
    ADD     A,A             ;convert to relative position (32 bytes each).
    ADD     A,A
    ADD     A,A
    ADD     A,A
    ADD     A,A
    LD      (FCBPOS),A      ;save it as position of fcb.
    OR      A
    RET     NZ              ;return if we are within buffer.
    PUSH    BC
    CALL    TRKSEC          ;we need the next directory sector.
    CALL    DIRREAD
    POP     BC
    JP      CHECKDIR
;
;   Routine to to get a bit from the disk space allocation
;   map. It is returned in (A), bit position 0. On entry to here,
;   set (BC) to the block number on the disk to check.
;   On return, (D) will contain the original bit position for
;   this block number and (HL) will point to the address for it.
;
CKBITMAP:
    LD      A,C             ;determine bit number of interest.
    AND     07H             ;compute (D)=(E)=(C and 7)+1.
    INC     A
    LD      E,A             ;save particular bit number.
    LD      D,A
;
;   Compute (BC)=(BC)/8.
;
    SRL     B
    RR      C
    SRL     B
    RR      C
    SRL     B
    RR      C
;
;   Use this as an offset into the disk space allocation
;   table.
;
    LD      HL,(ALOCVECT)
    ADD     HL,BC
    LD      A,(HL)          ;now get correct byte.
CKBMAP1:
    RLCA                    ;get correct bit into position 0.
    DEC     E
    JP      NZ,CKBMAP1
    RET
;
;   Set or clear the bit map such that block number (BC) will be marked
;   as used. On entry, if (E)=0 then this bit will be cleared, if it equals
;   1 then it will be set (don't use anyother values).
;
STBITMAP:
    PUSH    DE
    CALL    CKBITMAP        ;get the byte of interest.
    AND     0FEH            ;clear the affected bit.
    POP     BC
    OR      C               ;and now set it acording to (C).
;
;   Entry to restore the original bit position and then store
;   in table. (A) contains the value, (D) contains the bit
;   position (1-8), and (HL) points to the address within the
;   space allocation table for this byte.
;
STBMAP1:
    RRCA                    ;restore original bit position.
    DEC     D
    JP      NZ,STBMAP1
    LD      (HL),A          ;and store byte in table.
    RET
;
;   Set/clear space used bits in allocation map for this file.
;   On entry, (C)=1 to set the map and (C)=0 to clear it.
;
SETFILE:
    CALL    FCB2HL          ;get address of fcb
    LD      DE,16
    ADD     HL,DE           ;get to block number bytes.
    PUSH    BC
    LD      C,17            ;check all 17 bytes (max) of table.
SETFL1:
    POP     DE
    DEC     C               ;done all bytes yet?
    RET     Z
    PUSH    DE
    LD      A,(BIGDISK)     ;check disk size for 16 bit block numbers.
    OR      A
    JP      Z,SETFL2
    PUSH    BC              ;only 8 bit numbers. set (BC) to this one.
    PUSH    HL
    LD      C,(HL)          ;get low byte from table, always
    LD      B,0             ;set high byte to zero.
    JP      SETFL3
SETFL2:
    DEC     C               ;for 16 bit block numbers, adjust counter.
    PUSH    BC
    LD      C,(HL)          ;now get both the low and high bytes.
    INC     HL
    LD      B,(HL)
    PUSH    HL
SETFL3:
    LD      A,C             ;block used?
    OR      B
    JP      Z,SETFL4
    LD      HL,(DSKSIZE)    ;is this block number within the
    LD      A,L             ;space on the disk?
    SUB     C
    LD      A,H
    SBC     A,B
    CALL    NC,STBITMAP     ;yes, set the proper bit.
SETFL4:
    POP     HL              ;point to next block number in fcb.
    INC     HL
    POP     BC
    JP      SETFL1
;
;   Construct the space used allocation bit map for the active
;   drive. If a file name starts with '$' and it is under the
;   current user number, then (STATUS) is set to minus 1. Otherwise
;   it is not set at all.
;
BITMAP:
    LD      HL,(DSKSIZE)    ;compute size of allocation table.
    SRL     H               ;(HL)=(HL)/8. 
    RR      L
    SRL     H
    RR      L
    SRL     H
    RR      L
;   INC     HL              ;at least 1 byte.
    LD      BC,HL           ;set (BC) to the allocation table length.
;
;   Initialize the bitmap for this drive. Right now, the first
;   two bytes are specified by the disk parameter block. However
;   a patch could be entered here if it were necessary to setup
;   this table in a special manner. For example, the bios could
;   determine locations of 'bad blocks' and set them as already
;   'used' in the map.
;
    LD      HL,(ALOCVECT)   ;now zero out the table now.
;   DEC     BC              ;loop counters
    INC     B
    INC     C
    XOR     A               ;make zero
BITMAP1:
    LD      (HL+),A         ;zero buffer element
    DEC     C
    JP      NZ,BITMAP1
    DEC     B
    JP      NZ,BITMAP1
    LD      HL,(ALLOC0)     ;get initial space used by directory.
    EX      DE,HL
    LD      HL,(ALOCVECT)   ;and put this into map.
    LD      (HL+),E
    LD      (HL),D
;
;   End of initialization portion.
;
    CALL    HOMEDRV         ;now home the drive.
    LD      HL,(SCRATCH1)
    LD      (HL+),3         ;force next directory request to read in a sector.
    LD      (HL),0
    CALL    STFILPOS        ;clear initial file position also.
BITMAP2:
    LD      C,0FFH          ;read next file name in directory
    CALL    NXENTRY         ;and set checksum byte.
    CALL    CKFILPOS        ;is there another file?
    RET     Z
    CALL    FCB2HL          ;yes, get its address.
    LD      A,0E5H
    CP      (HL)            ;empty file entry?
    JP      Z,BITMAP2
    LD      A,(USERNO)      ;no, correct user number?
    CP      (HL)
    JP      NZ,BITMAP3
    INC     HL
    LD      A,(HL)          ;yes, does name start with a '$'?
    SUB     '$'
    JP      NZ,BITMAP3
    DEC     A               ;yes, set atatus to minus one.
    LD      (STATUS),A
BITMAP3:
    LD      C,1             ;now set this file's space as used in bit map.
    CALL    SETFILE
    CALL    CHKNMBR         ;keep (SCRATCH1) in bounds.
    JP      BITMAP2
;
;   Set the status (STATUS) and return.
;
STSTATUS:
    LD      A,(FNDSTAT)
    JP      SETSTAT
;
;   Check extents in (A) and (C). Set the zero flag if they
;   are the same. The number of 16k chunks of disk space that
;   the directory extent covers is expressad is (EXTMASK+1).
;   No registers are modified.
;
SAMEXT:
    PUSH    BC
    PUSH    AF
    LD      A,(EXTMASK)     ;get extent mask and use it to
    CPL                     ;to compare both extent numbers.
    LD      B,A             ;save resulting mask here.
    LD      A,C             ;mask first extent and save in (C).
    AND     B
    LD      C,A
    POP     AF              ;now mask second extent and compare
    AND     B               ;with the first one.
    SUB     C
    AND     1FH             ;(* only check buts 0-4 *)
    POP     BC              ;the zero flag is set if they are the same.
    RET                     ;restore (BC) and return.
;
;   Search for the first occurence of a file name. On entry,
;   register (C) should contain the number of bytes of the fcb
;   that must match.
;
FINDFST:
    LD      A,0FFH
    LD      (FNDSTAT),A
    LD      HL,COUNTER      ;save character count.
    LD      (HL),C
    LD      HL,(PARAMS)     ;get filename to match.
    LD      (SAVEFCB),HL    ;and save.
    CALL    STFILPOS        ;clear initial file position (set to 0ffffh).
    CALL    HOMEDRV         ;home the drive.
;
;   Entry to locate the next occurence of a filename within the
;   directory. The disk is not expected to have been changed. If
;   it was, then it will be write protected.
;
FINDNXT:
    LD      C,0             ;write protect the disk if changed.
    CALL    NXENTRY         ;get next filename entry in directory.
    CALL    CKFILPOS        ;is file position = 0ffffh?
    JP      Z,FNDNXT6       ;yes, exit now then.
    LD      HL,(SAVEFCB)    ;set (DE) pointing to filename to match.
    EX      DE,HL
    LD      A,(DE)
    CP      0E5H            ;empty directory entry?
    JP      Z,FNDNXT1       ;(* are we trying to reserect erased entries? *)
    PUSH    DE
    CALL    MOREFLS         ;more files in directory?
    POP     DE
    JP      NC,FNDNXT6      ;no more. Exit now.
FNDNXT1:
    CALL    FCB2HL          ;get address of this fcb in directory.
    LD      A,(COUNTER)     ;get number of bytes (characters) to check.
    LD      C,A
    LD      B,0             ;initialize byte position counter.
FNDNXT2:
    LD      A,C             ;are we done with the compare?
    OR      A
    JP      Z,FNDNXT5
    LD      A,(DE)          ;no, check next byte.
    CP      '?'             ;don't care about this character?
    JP      Z,FNDNXT4
    LD      A,B             ;get bytes position in fcb.
    CP      13              ;don't care about the thirteenth byte either.
    JP      Z,FNDNXT4
    CP      12              ;extent byte?
    LD      A,(DE)
    JP      Z,FNDNXT3
    SUB     (HL)            ;otherwise compare characters.
    AND     7FH
    JP      NZ,FINDNXT      ;not the same, check next entry.
    JP      FNDNXT4         ;so far so good, keep checking.
FNDNXT3:
    PUSH    BC              ;check the extent byte here.
    LD      C,(HL)
    CALL    SAMEXT
    POP     BC
    JP      NZ,FINDNXT      ;not the same, look some more.
;
;   So far the names compare. Bump pointers to the next byte
;   and continue until all (C) characters have been checked.
;
FNDNXT4:
    INC     DE              ;bump pointers.
    INC     HL
    INC     B
    DEC     C               ;adjust character counter.
    JP      FNDNXT2
FNDNXT5:
    LD      A,(FILEPOS)     ;return the position of this entry.
    AND     03H
    LD      (STATUS),A
    LD      HL,FNDSTAT
    LD      A,(HL)
    RLA
    RET     NC
    XOR     A
    LD      (HL),A
    RET
;
;   Filename was not found. Set appropriate status.
;
FNDNXT6:
    CALL    STFILPOS        ;set (FILEPOS) to 0ffffh.
    LD      A,0FFH          ;say not located.
    JP      SETSTAT
;
;   Erase files from the directory. Only the first byte of the
;   fcb will be affected. It is set to (E5).
;
ERAFILE:
    CALL    CHKWPRT         ;is disk write protected?
    LD      C,12            ;only compare file names.
    CALL    FINDFST         ;get first file name.
ERAFIL1:
    CALL    CKFILPOS        ;any found?
    RET     Z               ;nope, we must be done.
    CALL    CHKROFL         ;is file read only?
    CALL    FCB2HL          ;nope, get address of fcb and
    LD      (HL),0E5H       ;set first byte to 'empty'.
    LD      C,0             ;clear the space from the bit map.
    CALL    SETFILE
    CALL    DIRWRITE        ;now write the directory sector back out.
    CALL    FINDNXT         ;find the next file name.
    JP      ERAFIL1         ;and repeat process.
;
;   Look through the space allocation map (bit map) for the
;   next available block. Start searching at block number (BC-1).
;   The search procedure is to look for an empty block that is
;   before the starting block. If not empty, look at a later
;   block number. In this way, we return the closest empty block
;   on either side of the 'target' block number. This will speed
;   access on random devices. For serial devices, this should be
;   changed to look in the forward direction first and then start
;   at the front and search some more.
;
;   On return, (DE)= block number that is empty and (HL) =0
;   if no empty block was found.
;
FNDSPACE:
    LD      DE,BC           ;set (DE) as the block that is checked.
;
;   Look before target block. Registers (BC) are used as the lower
;   pointer and (DE) as the upper pointer.
;
FNDSPA1:
    LD      A,C             ;is block 0 specified?
    OR      B
    JP      Z,FNDSPA2
    DEC     BC              ;nope, check previous block.
    PUSH    DE
    PUSH    BC
    CALL    CKBITMAP
    RRA                     ;is this block empty?
    JP      NC,FNDSPA3      ;yes. use this.
;
;   Note that the above logic gets the first block that it finds
;   that is empty. Thus a file could be written 'backward' making
;   it very slow to access. This could be changed to look for the
;   first empty block and then continue until the start of this
;   empty space is located and then used that starting block.
;   This should help speed up access to some files especially on
;   a well used disk with lots of fairly small 'holes'.
;
    POP     BC              ;nope, check some more.
    POP     DE
;
;   Now look after target block.
;
FNDSPA2:
    LD      HL,(DSKSIZE)    ;is block (DE) within disk limits?
    LD      A,E
    SUB     L
    LD      A,D
    SBC     A,H
    JP      NC,FNDSPA4
    INC     DE              ;yes, move on to next one.
    PUSH    BC
    PUSH    DE
    LD      BC,DE
    CALL    CKBITMAP        ;check it.
    RRA                     ;empty?
    JP      NC,FNDSPA3
    POP     DE              ;nope, continue searching.
    POP     BC
    JP      FNDSPA1
;
;   Empty block found. Set it as used and return with (HL)
;   pointing to it (true?).
;
FNDSPA3:
    RLA                     ;reset byte.
    INC     A               ;and set bit 0.
    CALL    STBMAP1         ;update bit map.
    POP     HL              ;set return registers.
    POP     DE
    RET
;
;   Free block was not found. If (BC) is not zero, then we have
;   not checked all of the disk space.
;
FNDSPA4:
    LD      A,C
    OR      B
    JP      NZ,FNDSPA1
    LD      HL,0            ;set 'not found' status.
    RET
;
;   Move a complete fcb entry into the directory and write it.
;
FCBSET:
    LD      BC,0            ;set (BC) to relative byte position.
    LD      DE,32           ;length of each entry.
;
;   Move (E) bytes from the fcb pointed to by (PARAMS) into
;   fcb in directory starting at relative byte (C). This updated
;   directory buffer is then written to the disk.
;
UPDATE:
    LD      HL,(PARAMS)     ;get address of fcb.
    ADD     HL,BC           ;compute starting byte.
    LD      BC,DE           ;set (C) to number of bytes to change.
    EX      DE,HL
    CALL    FCB2HL          ;get address of fcb to update in directory.
    EX      DE,HL
    LDIR                    ;(HL++)->(DE++), BC times.
UPDATE1:
    CALL    TRKSEC          ;determine the track and sector affected.
    JP      DIRWRITE        ;then write this sector out.
;
;   Routine to change the name of all files on the disk with a
;   specified name. The fcb contains the current name as the
;   first 12 characters and the new name 16 bytes into the fcb.
;
CHGNAMES:
    CALL    CHKWPRT         ;check for a write protected disk.
    LD      C,12            ;match first 12 bytes of fcb only.
    CALL    FINDFST         ;get first name.
    LD      HL,(PARAMS)     ;get address of fcb.
    LD      A,(HL)          ;get user number.
    LD      DE,16           ;move over to desired name.
    ADD     HL,DE
    LD      (HL),A          ;keep same user number.
CHGNAM1:
    CALL    CKFILPOS        ;any matching file found?
    RET     Z               ;no, we must be done.
    CALL    CHKROFL         ;check for read only file.
    LD      BC,16           ;start 16 bytes into fcb.
    LD      DE,12           ;and update the first 12 bytes of directory.
    CALL    UPDATE
    CALL    FINDNXT         ;get the next file name.
    JP      CHGNAM1         ;and continue.
;
;   Update a files attributes. The procedure is to search for
;   every file with the same name as shown in fcb (ignoring bit 7)
;   and then to update it (which includes bit 7). No other changes
;   are made.
;
SAVEATTR:
    LD      C,12            ;match first 12 bytes.
    CALL    FINDFST         ;look for first filename.
SAVATR1:
    CALL    CKFILPOS        ;was one found?
    RET     Z               ;nope, we must be done.
    LD      BC,0            ;yes,
    LD      DE,12           ;update the first 12 bytes now.
    CALL    UPDATE          ;update filename and write directory.
    CALL    FINDNXT         ;and get the next file.
    JP      SAVATR1         ;then continue until done.
;
;  Open a file (name specified in fcb).
;
OPENIT:
    LD      C,15            ;compare the first 15 bytes.
    CALL    FINDFST         ;get the first one in directory.
    CALL    CKFILPOS        ;any at all?
    RET     Z
OPENIT1:
    CALL    SETEXT          ;point to extent byte within users fcb.
    LD      A,(HL)          ;and get it.
    PUSH    AF              ;save it and address.
    PUSH    HL
    CALL    FCB2HL          ;point to fcb in directory.
    LD      DE,(PARAMS)     ;this is the users copy.
    PUSH    HL
    CALL    LDI_32          ;move it into users space.
    CALL    SETS2B7         ;set bit 7 in 's2' byte (unmodified).
    POP     DE              ;now get the extent byte from this fcb.
    LD      HL,12
    ADD     HL,DE
    LD      C,(HL)          ;into (C).
    LD      HL,15           ;now get the record count byte into (B).
    ADD     HL,DE
    LD      B,(HL)
    POP     HL              ;keep the same extent as the user had originally.
    POP     AF
    LD      (HL),A
    LD      A,C             ;is it the same as in the directory fcb?
    CP      (HL)
    LD      A,B             ;if yes, then use the same record count.
    JP      Z,OPENIT2
    LD      A,0             ;if the user specified an extent greater than
    JP      C,OPENIT2       ;the one in the directory, then set record count to 0.
    LD      A,128           ;otherwise set to maximum.
OPENIT2:
    LD      HL,(PARAMS)     ;set record count in users fcb to (A).
    LD      DE,15
    ADD     HL,DE           ;compute relative position.
    LD      (HL),A          ;and set the record count.
    RET
;
;   Move two bytes from (DE) to (HL) if (and only if) (HL)
;   point to a zero value (16 bit).
;   Return with zero flag set it (DE) was moved. Registers (DE)
;   and (HL) are not changed. However (A) is.
;
MOVEWORD:
    LD      A,(HL+)         ;check for a zero word.
    OR      (HL-)           ;both bytes zero?
    RET     NZ              ;nope, just return.
    LD      A,(DE+)         ;yes, move two bytes from (DE) into
    LD      (HL+),A         ;this zero space.
    LD      A,(DE-)         ;don't disturb these registers.
    LD      (HL-),A
    RET
;
;   Get here to close a file specified by (fcb).
;
CLOSEIT:
    XOR     A               ;clear status and file position bytes.
    LD      (STATUS),A
    LD      (FILEPOS),A
    LD      (FILEPOS+1),A
    CALL    GETWPRT         ;get write protect bit for this drive.
    RET     NZ              ;just return if it is set.
    CALL    GETS2           ;else get the 's2' byte.
    AND     80H             ;and look at bit 7 (file unmodified?).
    RET     NZ              ;just return if set.
    LD      C,15            ;else look up this file in directory.
    CALL    FINDFST
    CALL    CKFILPOS        ;was it found?
    RET     Z               ;just return if not.
    LD      BC,16           ;set (HL) pointing to records used section.
    CALL    FCB2HL
    ADD     HL,BC
    EX      DE,HL
    LD      HL,(PARAMS)     ;do the same for users specified fcb.
    ADD     HL,BC
    LD      C,16            ;this many bytes are present in this extent.
CLOSEIT1:
    LD      A,(BIGDISK)     ;8 or 16 bit record numbers?
    OR      A
    JP      Z,CLOSEIT4
    LD      A,(HL)          ;just 8 bit. Get one from users fcb.
    OR      A
    LD      A,(DE)          ;now get one from directory fcb.
    JP      NZ,CLOSEIT2
    LD      (HL),A          ;users byte was zero. Update from directory.
CLOSEIT2:
    OR      A
    JP      NZ,CLOSEIT3
    LD      A,(HL)          ;directories byte was zero, update from users fcb.
    LD      (DE),A
CLOSEIT3:
    CP      (HL)            ;if neither one of these bytes were zero,
    JP      NZ,CLOSEIT7     ;then close error if they are not the same.
    JP      CLOSEIT5        ;ok so far, get to next byte in fcbs.
CLOSEIT4:
    CALL    MOVEWORD        ;update users fcb if it is zero.
    EX      DE,HL
    CALL    MOVEWORD        ;update directories fcb if it is zero.
    EX      DE,HL
    LD      A,(DE)          ;if these two values are no different,
    CP      (HL)            ;then a close error occured.
    JP      NZ,CLOSEIT7
    INC     DE              ;check second byte.
    INC     HL
    LD      A,(DE)
    CP      (HL)
    JP      NZ,CLOSEIT7
    DEC     C               ;remember 16 bit values.
CLOSEIT5:
    INC     DE              ;bump to next item in table.
    INC     HL
    DEC     C               ;there are 16 entries only.
    JP      NZ,CLOSEIT1     ;continue if more to do.
    LD      BC,0FFECH       ;backup 20 places (extent byte).
    ADD     HL,BC
    EX      DE,HL
    ADD     HL,BC
    LD      A,(DE)
    CP      (HL)            ;directory's extent already greater than the
    JP      C,CLOSEIT6      ;users extent?
    LD      (HL),A          ;no, update directory extent.
    LD      BC,3            ;and update the record count byte in
    ADD     HL,BC           ;directories fcb.
    EX      DE,HL
    ADD     HL,BC
    LD      A,(HL)          ;get from user.
    LD      (DE),A          ;and put in directory.
CLOSEIT6:
    LD      A,0FFH          ;set 'was open and is now closed' byte.
    LD      (CLOSEFLG),A
    JP      UPDATE1         ;update the directory now.
CLOSEIT7:
    LD      HL,STATUS       ;set return status and then return.
    DEC     (HL)
    RET
;
;   Routine to get the next empty space in the directory. It
;   will then be cleared for use.
;
GETEMPTY:
    CALL    CHKWPRT         ;make sure disk is not write protected.
    LD      HL,(PARAMS)     ;save current parameters (fcb).
    PUSH    HL
    LD      HL,EMPTYFCB     ;use special one for empty space.
    LD      (PARAMS),HL
    LD      C,1             ;search for first empty spot in directory.
    CALL    FINDFST         ;(* only check first byte *)
    CALL    CKFILPOS        ;none?
    POP     HL
    LD      (PARAMS),HL     ;restore original fcb address.
    RET     Z               ;return if no more space.
    EX      DE,HL
    LD      HL,15           ;point to number of records for this file.
    ADD     HL,DE
    LD      C,17            ;and clear all of this space.
    XOR     A
GETMT1:
    LD      (HL+),A
    DEC     C
    JP      NZ,GETMT1
    LD      HL,13           ;clear the 's1' byte also.
    ADD     HL,DE
    LD      (HL),A
    CALL    CHKNMBR         ;keep (SCRATCH1) within bounds.
    CALL    FCBSET          ;write out this fcb entry to directory.
    JP      SETS2B7         ;set 's2' byte bit 7 (unmodified at present).
;
;   Routine to close the current extent and open the next one
;   for reading.
;
GETNEXT:
    XOR     A
    LD      (CLOSEFLG),A    ;clear close flag.
    CALL    CLOSEIT         ;close this extent.
    CALL    CKFILPOS
    RET     Z               ;not there???
    LD      HL,(PARAMS)     ;get extent byte.
    LD      BC,12
    ADD     HL,BC
    LD      A,(HL)          ;and increment it.
    INC     A
    AND     1FH             ;keep within range 0-31.
    LD      (HL),A
    JP      Z,GTNEXT1       ;overflow?
    LD      B,A             ;mask extent byte.
    LD      A,(EXTMASK)
    AND     B
    LD      HL,CLOSEFLG     ;check close flag (0ffh is ok).
    AND     (HL)
    JP      Z,GTNEXT2       ;if zero, we must read in next extent.
    JP      GTNEXT3         ;else, it is already in memory.
GTNEXT1:
    LD      BC,2            ;Point to the 's2' byte.
    ADD     HL,BC
    INC     (HL)            ;and bump it.
    LD      A,(HL)          ;too many extents?
    AND     0FH
    JP      Z,GTNEXT5       ;yes, set error code.
;
;   Get here to open the next extent.
;
GTNEXT2:
    LD      C,15            ;set to check first 15 bytes of fcb.
    CALL    FINDFST         ;find the first one.
    CALL    CKFILPOS        ;none available?
    JP      NZ,GTNEXT3
    LD      A,(RDWRTFLG)    ;no extent present. Can we open an empty one?
    INC     A               ;0ffh means reading (so not possible).
    JP      Z,GTNEXT5       ;or an error.
    CALL    GETEMPTY        ;we are writing, get an empty entry.
    CALL    CKFILPOS        ;none?
    JP      Z,GTNEXT5       ;error if true.
    JP      GTNEXT4         ;else we are almost done.
GTNEXT3:
    CALL    OPENIT1         ;open this extent.
GTNEXT4:
    CALL    STRDATA         ;move in updated data (rec #, extent #, etc.)
    XOR     A               ;clear status and return.
    JP      SETSTAT
;
;   Error in extending the file. Too many extents were needed
;   or not enough space on the disk.
;
GTNEXT5:
    CALL    IOERR1          ;set error code, clear bit 7 of 's2'
    JP      SETS2B7         ;so this is not written on a close.
;
;   Read a sequential file.
;
RDSEQ:
    LD      A,1             ;set sequential access mode.
    LD      (MODE),A
RDSEQ1:
    LD      A,0FFH          ;don't allow reading unwritten space.
    LD      (RDWRTFLG),A
    CALL    STRDATA         ;put rec# and ext# into fcb.
    LD      A,(SAVNREC)     ;get next record to read.
    LD      HL,SAVNXT       ;get number of records in extent.
    CP      (HL)            ;within this extent?
    JP      C,RDSEQ2
    CP      128             ;no. Is this extent fully used?
    JP      NZ,RDSEQ3       ;no. End-of-file.
    CALL    GETNEXT         ;yes, open the next one.
    XOR     A               ;reset next record to read.
    LD      (SAVNREC),A
    LD      A,(STATUS)      ;check on open, successful?
    OR      A
    JP      NZ,RDSEQ3       ;no, error.
RDSEQ2:
    CALL    COMBLK          ;ok. compute block number to read.
    CALL    CHKBLK          ;check it. Within bounds?
    JP      Z,RDSEQ3        ;no, error.
    CALL    LOGICAL         ;convert (BLKNMBR) to logical sector (128 byte).
    CALL    TRKSEC1         ;set the track and sector for this block #.
    CALL    DOREAD          ;and read it.
    JP      SETNREC         ;and set the next record to be accessed.
;
;   Read error occured. Set status and return.
;
RDSEQ3:
    JP      IOERR1
;
;   Write the next sequential record.
;
WTSEQ:
    LD      A,1             ;set sequential access mode.
    LD      (MODE),A
WTSEQ1:
    LD      A,0             ;allow an addition empty extent to be opened.
    LD      (RDWRTFLG),A
    CALL    CHKWPRT         ;check write protect status.
    LD      HL,(PARAMS)
    CALL    CKROF1          ;check for read only file, (HL) already set to fcb.
    CALL    STRDATA         ;put updated data into fcb.
    LD      A,(SAVNREC)     ;get record number to write.
    CP      128             ;within range?
    JP      NC,IOERR1       ;no, error(?).
    CALL    COMBLK          ;compute block number.
    CALL    CHKBLK          ;check number.
    LD      C,0             ;is there one to write to?
    JP      NZ,WTSEQ6       ;yes, go do it.
    CALL    GETBLOCK        ;get next block number within fcb to use.
    LD      (RELBLOCK),A    ;and save.
    LD      BC,0            ;start looking for space from the start
    OR      A               ;if none allocated as yet.
    JP      Z,WTSEQ2
    LD      C,A             ;extract previous block number from fcb
    DEC     BC              ;so we can be closest to it.
    CALL    EXTBLK
    LD      BC,HL
WTSEQ2:
    CALL    FNDSPACE        ;find the next empty block nearest number (BC).
    LD      A,L             ;check for a zero number.
    OR      H
    JP      NZ,WTSEQ3
    LD      A,2             ;no more space?
    JP      SETSTAT
WTSEQ3:
    LD      (BLKNMBR),HL    ;save block number to access.
    EX      DE,HL           ;put block number into (DE).
    LD      HL,(PARAMS)     ;now we must update the fcb for this
    LD      BC,16           ;newly allocated block.
    ADD     HL,BC
    LD      A,(BIGDISK)     ;8 or 16 bit block numbers?
    OR      A
    LD      A,(RELBLOCK)    ;(* update this entry *)
    JP      Z,WTSEQ4        ;zero means 16 bit ones.
    ADD     A,L             ;(HL)=(HL)+(A)
    LD      L,A
    JP      NC,WTSEQADD
    INC     H               ;take care of any carry.
WTSEQADD:
    LD      (HL),E          ;store new block number.
    JP      WTSEQ5
WTSEQ4:
    LD      C,A             ;compute spot in this 16 bit table.
    LD      B,0
    ADD     HL,BC
    ADD     HL,BC
    LD      (HL),E          ;stuff block number (DE) there.
    INC     HL
    LD      (HL),D
WTSEQ5:
    LD      C,2             ;set (C) to indicate writing to un-used disk space.
WTSEQ6:
    LD      A,(STATUS)      ;are we ok so far?
    OR      A
    RET     NZ
    PUSH    BC              ;yes, save write flag for bios (register C).
    CALL    LOGICAL         ;convert (BLKNMBR) over to logical sectors.
    LD      A,(MODE)        ;get access mode flag (1=sequential,
    DEC     A               ;0=random, 2=special?).
    DEC     A
    JP      NZ,WTSEQ9
;
;   Special random i/o from function #40. The current block,
;   if it has not been written to, will be zeroed
;   out and then written.
;
    POP     BC
    PUSH    BC
    LD      A,C             ;get write status flag (2=writing unused space).
    DEC     A
    DEC     A
    JP      NZ,WTSEQ9
    PUSH    HL
    LD      HL,(DIRBUF)     ;zero out the directory buffer.
    LD      D,A             ;note that (A) is zero here.
WTSEQ7:
     LD     (HL),A
    INC     HL
    INC     D               ;do 128 bytes.
    JP      P,WTSEQ7
    CALL    DIRDMA          ;tell the bios the dma address for directory access.
    LD      HL,(LOGSECT)    ;get sector that starts current block.
    LD      C,2             ;set 'writing to unused space' flag.
WTSEQ8:
    LD     (BLKNMBR),HL     ;save sector to write.
    PUSH    BC
    CALL    TRKSEC1         ;determine its track and sector numbers.
    POP     BC
    CALL    DOWRITE         ;now write out 128 bytes of zeros.
    LD      HL,(BLKNMBR)    ;get sector number.
    LD      C,0             ;set normal write flag.
    LD      A,(BLKMASK)     ;determine if we have written the entire
    LD      B,A             ;physical block.
    AND     L
    CP      B
    INC     HL              ;prepare for the next one.
    JP      NZ,WTSEQ8       ;continue until (BLKMASK+1) sectors written.
    POP     HL              ;reset next sector number.
    LD      (BLKNMBR),HL
    CALL    DEFDMA          ;and reset dma address.
;
;   Normal disk write. Set the desired track and sector then
;   do the actual write.
;
WTSEQ9:    
    CALL    TRKSEC1         ;determine track and sector for this write.
    POP     BC              ;get write status flag.
    PUSH    BC
    CALL    DOWRITE         ;and write this out.
    POP     BC
    LD      A,(SAVNREC)     ;get number of records in file.
    LD      HL,SAVNXT       ;get last record written.
    CP      (HL)
    JP      C,WTSEQ10
    LD      (HL),A          ;we have to update record count.
    INC     (HL)
    LD      C,2
;
;*  This area has been patched to correct disk update problem
;*  when using blocking and de-blocking in the BIOS.
;
WTSEQ10:
    PUSH    AF
    CALL    GETS2           ;set 'extent written to' flag.
    AND     7FH             ;(* clear bit 7 *)
    LD      (HL),A
    POP     AF              ;get record count for this extent.
    CP      127             ;is it full?
    JP      NZ,WTSEQ12
    LD      A,(MODE)        ;yes, are we in sequential mode?
    CP      1
    JP      NZ,WTSEQ12
    CALL    SETNREC         ;yes, set next record number.
    CALL    GETNEXT         ;and get next empty space in directory.
    LD      HL,STATUS       ;ok?
    LD      A,(HL)
    OR      A
    JP      NZ,WTSEQ11
    DEC     A               ;yes, set record count to -1.
    LD      (SAVNREC),A
WTSEQ11:
    LD      (HL),0          ;clear status.
WTSEQ12:
    JP      SETNREC         ;set next record to access.
;
;   For random i/o, set the fcb for the desired record number
;   based on the 'r0,r1,r2' bytes. These bytes in the fcb are
;   used as follows:
;
;        fcb+35            fcb+34            fcb+33
;   |     'r-2'      |      'r-1'      |      'r-0'     |
;   |7             0 | 7             0 | 7             0|
;   |0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0|
;   |    overflow   | | extra |  extent   |   record #  |
;   | ______________| |_extent|__number___|_____________|
;                      also 's2'
;
;   On entry, register (C) contains 0ffh if this is a read
;   and thus we can not access unwritten disk space. Otherwise,
;   another extent will be opened (for writing) if required.
;
POSITION:
    XOR     A               ;set random i/o flag.
    LD      (MODE),A
;
;   Special entry (function #40). M/PM ?
;
POSITN1:
    PUSH    BC              ;save read/write flag.
    LD      HL,(PARAMS)     ;get address of fcb.
    EX      DE,HL
    LD      HL,33           ;now get byte 'r0'.
    ADD     HL,DE
    LD      A,(HL)
    AND     7FH             ;keep bits 0-6 for the record number to access.
    PUSH    AF
    LD      A,(HL)          ;now get bit 7 of 'r0' and bits 0-3 of 'r1'.
    RLA
    INC     HL
    LD      A,(HL)
    RLA
    AND     1FH             ;and save this in bits 0-4 of (C).
    LD      C,A             ;this is the extent byte.
    LD      A,(HL)          ;now get the extra extent byte.
    RRA
    RRA
    RRA
    RRA
    AND     0FH
    LD      B,A             ;and save it in (B).
    POP     AF              ;get record number back to (A).
    INC     HL              ;check overflow byte 'r2'.
    LD      L,(HL)
    INC     L
    DEC     L
    LD      L,6             ;prepare for error.
    JP      NZ,POSITN5      ;out of disk space error.
    LD      HL,32           ;store record number into fcb.
    ADD     HL,DE
    LD      (HL),A
    LD      HL,12           ;and now check the extent byte.
    ADD     HL,DE
    LD      A,C
    SUB     (HL)            ;same extent as before?
    JP      NZ,POSITN2
    LD      HL,14           ;yes, check extra extent byte 's2' also.
    ADD     HL,DE
    LD      A,B
    SUB     (HL)
    AND     7FH
    JP      Z,POSITN3       ;same, we are almost done then.
;
;  Get here when another extent is required.
;
POSITN2:
    PUSH    BC
    PUSH    DE
    CALL    CLOSEIT         ;close current extent.
    POP     DE
    POP     BC
    LD      L,3             ;prepare for error.
    LD      A,(STATUS)
    INC     A
    JP      Z,POSITN4       ;close error.
    LD      HL,12           ;put desired extent into fcb now.
    ADD     HL,DE
    LD      (HL),C
    LD      HL,14           ;and store extra extent byte 's2'.
    ADD     HL,DE
    LD      (HL),B
    CALL    OPENIT          ;try and get this extent.
    LD      A,(STATUS)      ;was it there?
    INC     A
    JP      NZ,POSITN3
    POP     BC              ;no. can we create a new one (writing?).
    PUSH    BC
    LD      L,4             ;prepare for error.
    INC     C
    JP      Z,POSITN4       ;nope, reading unwritten space error.
    CALL    GETEMPTY        ;yes we can, try to find space.
    LD      L,5             ;prepare for error.
    LD      A,(STATUS)
    INC     A
    JP      Z,POSITN4       ;out of space?
;
;   Normal return location. Clear error code and return.
;
POSITN3:
    POP     BC              ;restore stack.
    XOR     A               ;and clear error code byte.
    JP      SETSTAT
;
;   Error. Set the 's2' byte to indicate this (why?).
;
POSITN4:
    PUSH    HL
    CALL    GETS2
    LD      (HL),0C0H
    POP     HL
;
;   Return with error code (presently in L).
;
POSITN5:
    POP     BC
    LD      A,L             ;get error code.
    LD      (STATUS),A
    JP      SETS2B7
;
;   Read a random record.
;
READRAN:
    LD      C,0FFH          ;set 'read' status.
    CALL    POSITION        ;position the file to proper record.
    CALL    Z,RDSEQ1        ;and read it as usual (if no errors).
    RET
;
;   Write to a random record.
;
WRITERAN:
    LD      C,0             ;set 'writing' flag.
    CALL    POSITION        ;position the file to proper record.
    CALL    Z,WTSEQ1        ;and write as usual (if no errors).
    RET
;
;   Compute the random record number. Enter with (HL) pointing
;   to a fcb an (DE) contains a relative location of a record
;   number. On exit, (C) contains the 'r0' byte, (B) the 'r1'
;   byte, and (A) the 'r2' byte.
;
;   On return, the zero flag is set if the record is within
;   bounds. Otherwise, an overflow occured.
;
COMPRAND:
    EX      DE,HL           ;save fcb pointer in (DE).
    ADD     HL,DE           ;compute relative position of record #.
    LD      C,(HL)          ;get record number into (BC).
    LD      B,0
    LD      HL,12           ;now get extent.
    ADD     HL,DE
    LD      A,(HL)          ;compute (BC)=(record #)+(extent)*128.
    RRCA                    ;move lower bit into bit 7.
    AND     80H             ;and ignore all other bits.
    ADD     A,C             ;add to our record number.
    LD      C,A
    LD      A,0             ;take care of any carry.
    ADC     A,B
    LD      B,A
    LD      A,(HL)          ;now get the upper bits of extent into
    RRCA                    ;bit positions 0-3.
    AND     0FH             ;and ignore all others.
    ADD     A,B             ;add this in to 'r1' byte.
    LD      B,A
    LD      HL,14           ;get the 's2' byte (extra extent).
    ADD     HL,DE
    LD      A,(HL)
    ADD     A,A             ;and shift it left 4 bits (bits 4-7).
    ADD     A,A
    ADD     A,A
    ADD     A,A
    PUSH    AF              ;save carry flag (bit 0 of flag byte).
    ADD     A,B             ;now add extra extent into 'r1'.
    LD      B,A
    PUSH    AF              ;and save carry (overflow byte 'r2').
    POP     HL              ;bit 0 of (L) is the overflow indicator.
    LD      A,L
    POP     HL              ;and same for first carry flag.
    OR      L               ;either one of these set?
    AND     01H             ;only check the carry flags.
    RET
;
;   Routine to setup the fcb (bytes 'r0', 'r1', 'r2') to
;   reflect the last record used for a random (or other) file.
;   This reads the directory and looks at all extents computing
;   the largerst record number for each and keeping the maximum
;   value only. Then 'r0', 'r1', and 'r2' will reflect this
;   maximum record number. This is used to compute the space used
;   by a random file.
;
RANSIZE:
    LD      C,12            ;look thru directory for first entry with
    CALL    FINDFST         ;this name.
    LD      HL,(PARAMS)     ;zero out the 'r0, r1, r2' bytes.
    LD      DE,33
    ADD     HL,DE
    PUSH    HL
    LD      (HL),D          ;note that (D)=0.
    INC     HL
    LD      (HL),D
    INC     HL
    LD      (HL),D
RANSIZ1:
    CALL    CKFILPOS        ;is there an extent to process?
    JP      Z,RANSIZ3       ;no, we are done.
    CALL    FCB2HL          ;set (HL) pointing to proper fcb in dir.
    LD      DE,15           ;point to last record in extent.
    CALL    COMPRAND        ;and compute random parameters.
    POP     HL
    PUSH    HL              ;now check these values against those
    LD      E,A             ;already in fcb.
    LD      A,C             ;the carry flag will be set if those
    SUB     (HL)            ;in the fcb represent a larger size than
    INC     HL              ;this extent does.
    LD      A,B
    SBC     A,(HL)
    INC     HL
    LD      A,E
    SBC     A,(HL)
    JP      C,RANSIZ2
    LD      (HL),E          ;we found a larger (in size) extent.
    DEC     HL              ;stuff these values into fcb.
    LD      (HL),B
    DEC     HL
    LD      (HL),C
RANSIZ2:
    CALL    FINDNXT         ;now get the next extent.
    JP      RANSIZ1         ;continue til all done.
RANSIZ3:
    POP     HL              ;we are done, restore the stack and
    RET                     ;return.
;
;   Function to return the random record position of a given
;   file which has been read in sequential mode up to now.
;
SETRAN:
    LD      HL,(PARAMS)     ;point to fcb.
    LD      DE,32           ;and to last used record.
    CALL    COMPRAND        ;compute random position.
    LD      HL,33           ;now stuff these values into fcb.
    ADD     HL,DE
    LD      (HL+),C         ;move 'r0'.
    LD      (HL+),B         ;and 'r1'.
    LD      (HL),A          ;and lastly 'r2'.
    RET
;
;   This routine select the drive specified in (ACTIVE) and
;   update the login vector and bitmap table if this drive was
;   not already active.
;
LOGINDRV:
    LD      HL,(LOGIN)      ;get the login vector.
    LD      A,(ACTIVE)      ;get the default drive.
    LD      C,A
    CALL    SHIFTR          ;position active bit for this drive
    PUSH    HL              ;into bit 0.
    EX      DE,HL
    CALL    SELECT          ;select this drive.
    POP     HL
    CALL    Z,SLCTERR       ;valid drive?
    LD      A,L             ;is this a newly activated drive?
    RRA
    RET     C
    LD      HL,(LOGIN)      ;yes, update the login vector.
    LD      BC,HL
    CALL    SETBIT
    LD      (LOGIN),HL      ;and save.
    JP      BITMAP          ;now update the bitmap.
;
;   Function to set the active disk number.
;
SETDSK:
    LD      A,(EPARAM)      ;get parameter passed and see if this
    LD      HL,ACTIVE       ;represents a change in drives.
    CP      (HL)
    RET     Z
    LD      (HL),A          ;yes it does, log it in.
    JP      LOGINDRV
;
;   This is the 'auto disk select' routine. The first byte
;   of the fcb is examined for a drive specification. If non
;   zero then the drive will be selected and logged in.
;
AUTOSEL:
    LD      A,0FFH          ;say 'auto-select activated'.
    LD      (AUTO),A
    LD      HL,(PARAMS)     ;get drive specified.
    LD      A,(HL)
    AND     1FH             ;look at lower 5 bits.
    DEC     A               ;adjust for (1=A, 2=B) etc.
    LD      (EPARAM),A      ;and save for the select routine.
    CP      1EH             ;check for 'no change' condition.
    JP      NC,AUTOSL1      ;yes, don't change.
    LD      A,(ACTIVE)      ;we must change, save currently active
    LD      (OLDDRV),A      ;drive.
    LD      A,(HL)          ;and save first byte of fcb also.
    LD      (AUTOFLAG),A    ;this must be non-zero.
    AND     0E0H            ;whats this for (bits 5,6,7 are used for
    LD      (HL),A          ;something)?
    CALL    SETDSK          ;select and log in this drive.
AUTOSL1:
    LD      A,(USERNO)      ;move user number into fcb.
    LD      HL,(PARAMS)     ;(* upper half of first byte *)
    OR      (HL)
    LD      (HL),A
    RET                     ;and return (all done).
;
;   Function to return the current cp/m version number.
;
GETVER:
    LD      A,022H          ;version 2.2
    JP      SETSTAT
;
;   Function to reset the disk system.
;
RSTDSK:
    LD      HL,0            ;clear write protect status and log
    LD      (WRTPRT),HL     ;in vector.
    LD      (LOGIN),HL
    XOR     A               ;select drive 'A'.
    LD      (ACTIVE),A
    LD      HL,TBUFF        ;setup default dma address.
    LD      (USERDMA),HL
    CALL    DEFDMA
    JP      LOGINDRV        ;now log in drive 'A'.
;
;   Function to open a specified file.
;
OPENFIL:
    CALL    CLEARS2         ;clear 's2' byte.
    CALL    AUTOSEL         ;select proper disk.
    JP      OPENIT          ;and open the file.
;
;   Function to close a specified file.
;
CLOSEFIL:
    CALL    AUTOSEL         ;select proper disk.
    JP      CLOSEIT         ;and close the file.
;
;   Function to return the first occurence of a specified file
;   name. If the first byte of the fcb is '?' then the name will
;   not be checked (get the first entry no matter what).
;
GETFST:
    LD      C,0             ;prepare for special search.
    EX      DE,HL
    LD      A,(HL)          ;is first byte a '?'?
    CP      '?'
    JP      Z,GETFST1       ;yes, just get very first entry (zero length match).
    CALL    SETEXT          ;get the extension byte from fcb.
    LD      A,(HL)          ;is it '?'? if yes, then we want
    CP      '?'             ;an entry with a specific 's2' byte.
    CALL    NZ,CLEARS2      ;otherwise, look for a zero 's2' byte.
    CALL    AUTOSEL         ;select proper drive.
    LD      C,15            ;compare bytes 0-14 in fcb (12&13 excluded).
GETFST1:
    CALL    FINDFST         ;find an entry and then move it into
    JP      MOVEDIR         ;the users dma space.
;
;   Function to return the next occurrence of a file name.
;
GETNXT:
    LD      HL,(SAVEFCB)    ;restore pointers. note that no
    LD      (PARAMS),HL     ;other dbos calls are allowed.
    CALL    AUTOSEL         ;no error will be returned, but the
    CALL    FINDNXT         ;results will be wrong.
    JP      MOVEDIR
;
;   Function to delete a file by name.
;
DELFILE:
    CALL    AUTOSEL         ;select proper drive.
    CALL    ERAFILE         ;erase the file.
    JP      STSTATUS        ;set status and return.
;
;   Function to execute a sequential read of the specified
;   record number.
;
READSEQ:
    CALL    AUTOSEL         ;select proper drive then read.
    JP      RDSEQ
;
;   Function to write the net sequential record.
;
WRTSEQ:
    CALL    AUTOSEL         ;select proper drive then write.
    JP      WTSEQ
;
;   Create a file function.
;
FCREATE:
    CALL    CLEARS2         ;clear the 's2' byte on all creates.
    CALL    AUTOSEL         ;select proper drive and get the next
    JP      GETEMPTY        ;empty directory space.
;
;   Function to rename a file.
;
RENFILE:
    CALL    AUTOSEL         ;select proper drive and then switch
    CALL    CHGNAMES        ;file names.
    JP      STSTATUS
;
;   Function to return the login vector.
;
GETLOG:
    LD      HL,(LOGIN)
    JP      GETPRM1
;
;   Function to return the current disk assignment.
;
GETCRNT:
    LD      A,(ACTIVE)
    JP      SETSTAT
;
;   Function to set the dma address.
;
PUTDMA:
    EX      DE,HL
    LD      (USERDMA),HL    ;save in our space and then get to
    JP      DEFDMA          ;the bios with this also.
;
;   Function to return the allocation vector.
;
GETALOC:
    LD      HL,(ALOCVECT)
    JP      GETPRM1
;
;   Function to return the read-only status vector.
;
GETROV:
    LD      HL,(WRTPRT)
    JP      GETPRM1
;
;   Function to set the file attributes (read-only, system).
;
SETATTR:
    CALL    AUTOSEL         ;select proper drive then save attributes.
    CALL    SAVEATTR
    JP      STSTATUS
;
;   Function to return the address of the disk parameter block
;   for the current drive.
;
GETPARM:
    LD      HL,(DISKPB)
GETPRM1:
    LD      (STATUS),HL
    RET
;
;   Function to get or set the user number. If (E) was (FF)
;   then this is a request to return the current user number.
;   Else set the user number from (E).
;
GETUSER:
    LD      A,(EPARAM)      ;get parameter.
    CP      0FFH            ;get user number?
    JP      NZ,SETUSER
    LD      A,(USERNO)      ;yes, just do it.
    JP      SETSTAT
SETUSER:
    AND     1FH             ;no, we should set it instead. keep low
    LD      (USERNO),A      ;bits (0-4) only.
    RET
;
;   Function to read a random record from a file.
;
RDRANDOM:
    CALL    AUTOSEL         ;select proper drive and read.
    JP      READRAN
;
;   Function to compute the file size for random files.
;
WTRANDOM:
    CALL    AUTOSEL         ;select proper drive and write.
    JP      WRITERAN
;
;   Function to compute the size of a random file.
;
FILESIZE:
    CALL    AUTOSEL         ;select proper drive and check file length
    JP      RANSIZE   
;
;   Function to selectively reset disc drives.
;   This allows a program to log off any drives.
;   On entry, set (DE) to contain a word with bits set for those
;   drives that are to be logged off. The log-in vector and the
;   write protect vector will be updated.
;
LOGOFF:
    LD      HL,(PARAMS)     ;get drives to log off.
    LD      A,L             ;for each bit that is set, we want
    CPL                     ;to clear that bit in (LOGIN)
    LD      E,A             ;and (WRTPRT).
    LD      A,H
    CPL
    LD      HL,(LOGIN)      ;reset the login vector.
    AND     H
    LD      D,A
    LD      A,L
    AND     E
    LD      E,A
    LD      HL,(WRTPRT)
    EX      DE,HL
    LD      (LOGIN),HL      ;and save.
    LD      A,L             ;now do the write protect vector.
    AND     E
    LD      L,A
    LD      A,H
    AND     D
    LD      H,A
    LD    (WRTPRT),HL       ;and save. all done.
    RET
;
;   Get here to return to the user.
;
GOBACK:
    LD      A,(AUTO)        ;was auto select activated?
    OR      A
    JP      Z,RETMON
    LD      HL,(PARAMS)     ;yes, but was a change made?
    LD      (HL),0          ;(* reset first byte of fcb *)
    LD      A,(AUTOFLAG)
    OR      A
    JP      Z,RETMON
    LD      (HL),A          ;yes, reset first byte properly.
    LD      A,(OLDDRV)      ;and get the old drive and select it.
    LD      (EPARAM),A
    CALL    SETDSK
RETMON:
    LD      SP,(USRSTACK)   ;reset the users stack pointer.
    LD      HL,(STATUS)     ;get return status.
    LD      A,L             ;force version 1.4 compatability.
    LD      B,H
    RET                     ;and go back to user.
;
;   Funtion to write random with zero fill.
;   This is a special entry to do random i/o.
;   For the case where we are writing to unused disk space,
;   this space will be zeroed out first.
;
WTSPECL:
    CALL    AUTOSEL         ;select proper drive.
    LD      A,2             ;use special write mode.
    LD      (MODE),A
    LD      C,0             ;set write indicator.
    CALL    POSITN1         ;position the file.
    CALL    Z,WTSEQ1        ;and write (if no errors).
    RET
;
;   Function to load Intel HEX into TPA and launch it
;   uses  : af, bc, de, hl
;   (C) feilipu
;
EXTERN      diskchk_jp_addr ;address of jp to bios diskchk
;
PUBLIC      _hexload        ;load Intel HEX into TPA and launch it
;
_hexload:
    LD      HL,HLD_LOADER   ;return here after the cold boot sequence
    LD      (diskchk_jp_addr+1),HL  ;prepare a return address in rboot
    JP      BOOT            ;do a CP/M cold boot to establish page 0
HLD_LOADER:
    CALL    HLD_WAIT_COLON  ;wait for first colon and address data
    LD      HL,BC
    LD      (diskchk_jp_addr+1),HL  ;store first address as TPA location in rboot
    JP      HLD_READ_DATA   ;now get the first data
;
HLD_WAIT_COLON:
    CALL    CONIN           ;Rx byte in A
    JP      NC,HLD_WAIT_COLON   ;carry set if byte available
    CP      ':'             ;wait for ':'
    JP      NZ,HLD_WAIT_COLON
    LD      E,0             ;reset E to compute checksum
    CALL    HLD_READ_BYTE   ;read byte count
    LD      D,A             ;store it in D
    CALL    HLD_READ_BYTE   ;read upper byte of address
    LD      B,A             ;store in B
    CALL    HLD_READ_BYTE   ;read lower byte of address
    LD      C,A             ;store in C
    CALL    HLD_READ_BYTE   ;read record type
    DEC     A               ;check if record type is 01 (end of file)
    JP      Z,HLD_END_LOAD
    INC     A               ;check if record type is 00 (data)
    RET     Z
    JP      EXIT            ;otherwise exit gracefully
;
HLD_READ:
    CALL    HLD_WAIT_COLON  ;wait for the next colon and address data
HLD_READ_DATA:
    CALL    HLD_READ_BYTE
    LD      (BC),A          ;write the byte at the RAM address
    INC     BC
    DEC     D
    JP      NZ,HLD_READ_DATA;if d non zero, loop to get more data
;
HLD_READ_CHKSUM:
    CALL    HLD_READ_BYTE   ;read checksum, but we don't need to keep it
    LD      A,E             ;lower byte of E checksum should be 0
    AND     A
    JP      NZ,EXIT         ;non zero, we have an issue
    JP      HLD_READ
;
HLD_END_LOAD:
    CALL    HLD_READ_BYTE   ;read checksum, but we don't need to keep it
    LD      A,E             ;lower byte of E checksum should be 0
    AND     A
    JP      NZ,EXIT         ;non zero, we have an issue
    JP      WBOOT           ;warm boot, but divert into running from TPA location
;
HLD_READ_BYTE:              ;returns byte in A, checksum in E
    CALL    HLD_READ_NIBBLE ;read the first nibble
    RLCA                    ;shift it left by 4 bits
    RLCA
    RLCA
    RLCA
    LD      L,A             ;temporarily store the first nibble in L
    CALL    HLD_READ_NIBBLE ;get the second (low) nibble
    OR      L               ;assemble two nibbles into one byte in A
    LD      L,A             ;put assembled byte back into L
    ADD     A,E             ;add the byte read to E (for checksum)
    LD      E,A
    LD      A,L
    RET                     ;return the byte read in A (L = char received too)  
;
HLD_READ_NIBBLE:
    PUSH    HL
    PUSH    BC
HLD_READ_WAIT:
    CALL    CONIN           ;Rx byte in A
    JP      NC,HLD_READ_WAIT;carry set if byte available
    POP     BC
    POP     HL
    SUB     '0'
    CP      10
    RET     C               ;if A<10 just return
    SUB     7               ;else subtract 'A'-'0' (17) and add 10
    RET
;
PUBLIC  _cpm_bdos_tail
_cpm_bdos_tail:             ;tail of the cpm bdos
;
;**************************************************************
;*
;*     BDOS data storage pool.
;*
;**************************************************************
;
PUBLIC  _cpm_bdos_data
_cpm_bdos_data:             ;origin of the cpm bdos data
;
EMPTYFCB:   DEFB    $E5     ;empty directory segment indicator.
USERDMA:    DEFW    $0080   ;user's dma address (defaults to 80h).
;
STARTING:   DEFB    2       ;starting position for cursor.
;
PUBLIC  _cpm_bdos_data_tail
_cpm_bdos_data_tail:        ;tail of the cpm bios data
;
PUBLIC  _cpm_bdos_bss_bridge
_cpm_bdos_bss_bridge:
;
DEPHASE
;
;------------------------------------------------------------------------------
; end of data tables - non aligned data
;------------------------------------------------------------------------------
;
SECTION bss_user
;
PHASE _cpm_bdos_bss_bridge
;
PUBLIC  _cpm_bdos_bss_head
_cpm_bdos_bss_head:         ;head of the cpm bdos bss
;
OUTFLAG:    DEFB    0       ;output flag (non zero means no output).
CURPOS:     DEFB    0       ;cursor position (0=start of line).
PRTFLAG:    DEFB    0       ;printer flag (control-p toggle). List if non zero.
CHARBUF:    DEFB    0       ;single input character buffer.
;
USERNO:     DEFB    0       ;current user number.
ACTIVE:     DEFB    0       ;currently active drive.
PARAMS:     DEFW    0       ;save (DE) parameters here on entry.
STATUS:     DEFW    0       ;status returned from bdos function.
;
WRTPRT:     DEFW    0       ;write protect status for all 16 drives.
LOGIN:      DEFW    0       ;drive active word (1 bit per drive).
;
;   Scratch areas from parameter block.
;
SCRATCH1:   DEFW    0       ;relative position within dir segment for file (0-3).
SCRATCH2:   DEFW    0       ;last selected track number.
SCRATCH3:   DEFW    0       ;last selected sector number.
;
;   Disk storage areas from parameter block.
;
DIRBUF:     DEFW    0       ;address of directory buffer to use.
DISKPB:     DEFW    0       ;contains address of disk parameter block.
CHKVECT:    DEFW    0       ;address of check vector.
ALOCVECT:   DEFW    0       ;address of allocation vector (bit map).
;
;   Parameter block returned from the bios.
;
SECTORS:    DEFW    0       ;sectors per track from bios.
BLKSHFT:    DEFB    0       ;block shift.
BLKMASK:    DEFB    0       ;block mask.
EXTMASK:    DEFB    0       ;extent mask.
DSKSIZE:    DEFW    0       ;disk size from bios (number of blocks-1).
DIRSIZE:    DEFW    0       ;directory size.
ALLOC0:     DEFW    0       ;storage for first bytes of bit map (dir space used).
ALLOC1:     DEFW    0
OFFSET:     DEFW    0       ;first usable track number.
;
XLATE:      DEFW    0       ;sector translation table address.
;
CLOSEFLG:   DEFB    0       ;close flag (=0ffh is extent written ok).
RDWRTFLG:   DEFB    0       ;read/write flag (0ffh=read, 0=write).
FNDSTAT:    DEFB    0       ;filename found status (0=found first entry).
MODE:       DEFB    0       ;I/o mode select (0=random, 1=sequential, 2=special random).
EPARAM:     DEFB    0       ;storage for register (E) on entry to bdos.
RELBLOCK:   DEFB    0       ;relative position within fcb of block number written.
COUNTER:    DEFB    0       ;byte counter for directory name searches.
SAVEFCB:    DEFW    0       ;save space for address of fcb (for directory searches).
BIGDISK:    DEFB    0       ;if =0 then disk is > 256 blocks long.
AUTO:       DEFB    0       ;if non-zero, then auto select activated.
OLDDRV:     DEFB    0       ;on auto select, storage for previous drive.
AUTOFLAG:   DEFB    0       ;if non-zero, then auto select changed drives.
SAVNXT:     DEFB    0       ;storage for next record number to access.
SAVEXT:     DEFB    0       ;storage for extent number of file.
SAVNREC:    DEFW    0       ;storage for number of records in file.
BLKNMBR:    DEFW    0       ;block number (physical sector) used within a file or logical sect
LOGSECT:    DEFW    0       ;starting logical (128 byte) sector of block (physical sector).
FCBPOS:     DEFB    0       ;relative position within buffer for fcb of file of interest.
FILEPOS:    DEFW    0       ;files position within directory (0 to max entries -1).
USRSTACK:   DEFW    0       ;save users stack pointer here.
;
;   Disk directory buffer checksum bytes. One for each of the
;   16 possible drives. Maximum 4 drives configured in BIOS.
;
CKSUMTBL:   DEFS    16,0
;
;   Stack area for BDOS calls.
;
            DEFS    48,0    ;minimum BDOS stack allocation.
;
ALIGN       0x100
;
STKAREA:                    ;top of BDOS stack.
;
PUBLIC  _cpm_bdos_bss_tail
_cpm_bdos_bss_tail:         ;tail of the cpm bdos bss
;
DEPHASE
;
;**************************************************************
;*
;*        B I O S   J U M P   T A B L E
;*
;**************************************************************
;
EXTERN    cboot     ;cold start
EXTERN    wboot     ;warm start
EXTERN    const     ;console status
EXTERN    conin     ;console character in
EXTERN    conout    ;console character out
EXTERN    list      ;list character out
EXTERN    punch     ;punch character out
EXTERN    reader    ;reader character out
EXTERN    home      ;move head to home position
EXTERN    seldsk    ;select disk
EXTERN    settrk    ;set track number
EXTERN    setsec    ;set sector number
EXTERN    setdma    ;set dma address
EXTERN    read      ;read disk
EXTERN    write     ;write disk
EXTERN    listst    ;return list status
EXTERN    sectran   ;sector translate
;
DEFC    BOOT    =   cboot
DEFC    WBOOT   =   wboot
DEFC    CONST   =   const
DEFC    CONIN   =   conin
DEFC    CONOUT  =   conout
DEFC    LIST    =   list
DEFC    PUNCH   =   punch
DEFC    READER  =   reader
DEFC    HOME    =   home
DEFC    SELDSK  =   seldsk
DEFC    SETTRK  =   settrk
DEFC    SETSEC  =   setsec
DEFC    SETDMA  =   setdma
DEFC    READ    =   read
DEFC    WRITE   =   write
DEFC    PRSTAT  =   listst
DEFC    SECTRN  =   sectran
;
;*
;******************   E N D   O F   C P / M   *****************
;*

