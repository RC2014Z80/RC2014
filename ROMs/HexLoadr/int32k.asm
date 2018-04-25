;==============================================================================
; Contents of parts of this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==============================================================================
;
; ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to
; allow run-on from the sender. Transmit and receive are interrupt driven.
;
; https://github.com/feilipu/
; https://feilipu.me/
;
;==============================================================================
;
; HexLoadr option by @feilipu,
; derived from the work of @fbergama and @foxweb at RC2014
; https://github.com/RC2014Z80
;

;==============================================================================
;
; INCLUDES SECTION
;

INCLUDE "rc2014.h"

;==============================================================================
;
; CODE SECTION
;
SECTION z80_acia_interrupt
;------------------------------------------------------------------------------

serialInt:
        push af
        push hl
                                    ; start doing the Rx stuff
        in a, (SER_STATUS_ADDR)     ; get the status of the ACIA
        and SER_RDRF                ; check whether a byte has been received
        jr Z, im1_tx_check          ; if not, go check for bytes to transmit 

        in a, (SER_DATA_ADDR)       ; Get the received byte from the ACIA 
        ld l, a                     ; Move Rx byte to l

        ld a, (serRxBufUsed)        ; Get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE-1         ; check whether there is space in the buffer
        jr NC, im1_tx_check         ; buffer full, check if we can send something

        ld a, l                     ; get Rx byte from l
        ld hl, serRxBufUsed
        inc (hl)                    ; atomically increment Rx buffer count
        ld hl, (serRxInPtr)         ; get the pointer to where we poke
        ld (hl), a                  ; write the Rx byte to the serRxInPtr address

        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRxInPtr), hl         ; write where the next byte should be poked

im1_tx_check:                       ; now start doing the Tx stuff
        in a, (SER_STATUS_ADDR)     ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jr Z, im1_rts_check         ; if not, go check for the receive RTS selection

        ld a, (serTxBufUsed)        ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jr Z, im1_tei_clear         ; if the count is zero, then disable the Tx Interrupt

        ld hl, (serTxOutPtr)        ; get the pointer to place where we pop the Tx byte
        ld a, (hl)                  ; get the Tx byte
        out (SER_DATA_ADDR), a      ; output the Tx byte to the ACIA

        inc l                       ; move the Tx pointer, just low byte, along
        ld a, SER_TX_BUFSIZE-1      ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l, a                     ; return the low byte to l
        ld (serTxOutPtr), hl        ; write where the next byte should be popped

        ld hl, serTxBufUsed
        dec (hl)                    ; atomically decrement current Tx count

        jr NZ, im1_txa_end          ; if we've more Tx bytes to send, we're done for now

im1_tei_clear:
        ld a, (serControl)          ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; mask out (disable) the Tx Interrupt, keep RTS low
        ld (serControl), a          ; write the ACIA control byte back
        out (SER_CTRL_ADDR), a      ; Set the ACIA CTRL register

im1_rts_check:
        ld a, (serRxBufUsed)        ; get the current Rx count
        cp SER_RX_FULLSIZE          ; compare the count with the preferred full size
        jr C, im1_txa_end           ; leave the RTS low, and end

        ld a, (serControl)          ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS1             ; Set RTS high, and disable Tx Interrupt
        ld (serControl), a          ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR), a	    ; Set the ACIA CTRL register

im1_txa_end:
        pop hl
        pop af

        ei
        reti

;------------------------------------------------------------------------------
SECTION z80_acia_rxa_chk            ; ORG $00F0
RXA_CHK:
        ld a, (serRxBufUsed)
        cp $0
        ret

;------------------------------------------------------------------------------
SECTION z80_acia_rxa                ; ORG $0100
RXA:
        ld a, (serRxBufUsed)        ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jr Z, RXA                   ; wait, if there are no bytes available

        cp SER_RX_EMPTYSIZE         ; compare the count with the preferred empty size
        jr NC, rxa_clean_up         ; if the buffer is too full, don't change the RTS

        di                          ; critical section begin
        ld a, (serControl)          ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; set RTS low.
        ld (serControl), a          ; write the ACIA control echo byte back
        ei                          ; critical section end
        out (SER_CTRL_ADDR), a      ; set the ACIA CTRL register

rxa_clean_up:
        push hl                     ; store HL so we don't clobber it

        ld hl, serRxBufUsed
        di
        dec (hl)                    ; atomically decrement Rx count
        ld hl, (serRxOutPtr)        ; get the pointer to place where we pop the Rx byte
        ei
        ld a, (hl)                  ; get the Rx byte

        inc l                       ; move the Rx pointer low byte along
        ld (serRxOutPtr), hl        ; write where the next byte should be popped

        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------
SECTION z80_acia_txa                ; ORG $0130
TXA:
        push hl                     ; store HL so we don't clobber it
        ld l, a                     ; store Tx character

        ld a, (serTxBufUsed)        ; Get the number of bytes in the Tx buffer
        or a                        ; check whether the buffer is empty
        jr NZ, txa_buffer_out       ; buffer not empty, so abandon immediate Tx

        in a, (SER_STATUS_ADDR)     ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jr Z, txa_buffer_out        ; if not, so abandon immediate Tx

        ld a, l                     ; Retrieve Tx character for immediate Tx
        out (SER_DATA_ADDR), a      ; immediately output the Tx byte to the ACIA

        pop hl                      ; recover HL
        ret                         ; and just complete

txa_buffer_out:
        ld a, (serTxBufUsed)        ; Get the number of bytes in the Tx buffer
        cp SER_TX_BUFSIZE-1         ; check whether there is space in the buffer
        jr NC, txa_buffer_out       ; buffer full, so wait till it has space

        ld a, l                     ; Retrieve Tx character

        ld hl, serTxBufUsed
        di
        inc (hl)                    ; atomic increment of Tx count
        ld hl, (serTxInPtr)         ; get the pointer to where we poke
        ei
        ld (hl), a                  ; write the Tx byte to the serTxInPtr

        inc l                       ; move the Tx pointer, just low byte along
        ld a, SER_TX_BUFSIZE-1      ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l, a                     ; return the low byte to l
        ld (serTxInPtr), hl         ; write where the next byte should be poked

        pop hl                      ; recover HL

        ld a, (serControl)          ; get the ACIA control echo byte
        and SER_TEI_RTS0            ; test whether ACIA interrupt is set
        ret NZ                      ; if so then just return

        di                          ; critical section begin
        ld a, (serControl)          ; get the ACIA control echo byte again
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TEI_RTS0             ; set RTS low. if the TEI was not set, it will work again
        ld (serControl), a          ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR), a      ; set the ACIA CTRL register
        ei                          ; critical section end
        ret

;------------------------------------------------------------------------------
SECTION z80_acia_print              ; ORG $0180
PRINT:
        LD        A,(HL)            ; Get character
        OR        A                 ; Is it $00 ?
        RET       Z                 ; Then RETurn on terminator
        CALL      TXA               ; Print it
        INC       HL                ; Next Character
        JR        PRINT             ; Continue until $00

;------------------------------------------------------------------------------
SECTION     z80_hexloadr            ; ORG $0190
HEX_START:
        ld hl, initString
        call PRINT
HEX_WAIT_COLON:
        call RXA                    ; Rx byte
        cp ':'                      ; wait for ':'
        jr NZ, HEX_WAIT_COLON
        ld c, 0                     ; reset C to compute checksum
        call HEX_READ_BYTE          ; read byte count
        ld b, a                     ; store it in B
        call HEX_READ_BYTE          ; read upper byte of address
        ld d, a                     ; store in D
        call HEX_READ_BYTE          ; read lower byte of address
        ld e, a                     ; store in E
        call HEX_READ_BYTE          ; read record type
        cp 01                       ; check if record type is 01 (end of file)
        jr Z, HEX_END_LOAD
        cp 00                       ; check if record type is 00 (data)
        jr NZ, HEX_INVAL_TYPE       ; if not, error
HEX_READ_DATA:
        call HEX_READ_BYTE
        ld (de), a                  ; write the byte at the RAM address
        inc de
        djnz HEX_READ_DATA          ; if b non zero, loop to get more data
HEX_READ_CHKSUM:
        call HEX_READ_BYTE          ; read checksum, but we don't need to keep it
        ld a, c                     ; lower byte of C checksum should be 0
        or a
        jr NZ, HEX_BAD_CHK          ; non zero, we have an issue
        ld a, '#'                   ; "#" per line loaded
        call TXA                    ; Print it
        jr HEX_WAIT_COLON

HEX_END_LOAD:
        call HEX_READ_BYTE          ; read checksum, but we don't need to keep it
        ld a, c                     ; lower byte of C checksum should be 0
        or a
        jr NZ, HEX_BAD_CHK          ; non zero, we have an issue
        ld hl, LoadOKStr
        call PRINT
        jp WARMSTART                ; ready to run our loaded program from Basic

HEX_INVAL_TYPE:
        ld hl, invalidTypeStr
        call PRINT
        jp START                    ; go back to start

HEX_BAD_CHK:
        ld hl, badCheckSumStr
        call PRINT
        jp START                    ; go back to start

HEX_READ_BYTE:                      ; returns byte in A, checksum in C
        call HEX_READ_NIBBLE        ; read the first nibble
        rlca                        ; shift it left by 4 bits
        rlca
        rlca
        rlca
        ld l, a                     ; temporarily store the first nibble in L
        call HEX_READ_NIBBLE        ; get the second (low) nibble
        or l                        ; assemble two nibbles into one byte in A
        ld l, a                     ; put assembled byte back into L
        add a, c                    ; add the byte read to C (for checksum)
        ld c, a
        ld a, l
        ret                         ; return the byte read in A (L = char received too)  

HEX_READ_NIBBLE:
        call RXA                    ; Rx byte in A
        sub '0'
        cp 10
        ret C                       ; if A<10 just return
        sub 7                       ; else subtract 'A'-'0' (17) and add 10
        ret

;------------------------------------------------------------------------------
SECTION        z80_init             ; ORG $0240

PUBLIC  INIT

INIT:
        LD SP, TEMPSTACK            ; Set up a temporary stack

        LD HL, Z80_VECTOR_PROTO     ; Establish Z80 RST Vector Table
        LD DE, Z80_VECTOR_BASE
        LD BC, Z80_VECTOR_SIZE
        LDIR

        LD HL, serRxBuf             ; Initialise Rx Buffer
        LD (serRxInPtr), HL
        LD (serRxOutPtr), HL

        LD HL, serTxBuf             ; Initialise Tx Buffer
        LD (serTxInPtr), HL
        LD (serTxOutPtr), HL              

        XOR A                       ; 0 the RXA & TXA Buffer Counts
        LD (serRxBufUsed), A
        LD (serTxBufUsed), A

        LD A, SER_RESET             ; Master Reset the ACIA
        OUT (SER_CTRL_ADDR), A

        LD A, SER_REI|SER_TDI_RTS0|SER_8N1|SER_CLK_DIV_64
                                    ; load the default ACIA configuration
                                    ; 8n1 at 115200 baud
                                    ; receive interrupt enabled
                                    ; transmit interrupt disabled
                            
        LD (serControl),A           ; write the ACIA control byte echo
        OUT (SER_CTRL_ADDR),A       ; output to the ACIA control byte

        IM 1                        ; interrupt mode 1
        EI

START:
        LD HL, SIGNON1              ; Sign-on message
        CALL PRINT                  ; Output string
        LD A,(basicStarted)         ; Check the BASIC STARTED flag
        CP 'Y'                      ; to see if this is power-up
        JR NZ, COLDSTART            ; If not BASIC started then always do cold start
        LD HL, SIGNON2              ; Cold/warm message
        CALL PRINT                  ; Output string
CORW:
        RST 10H
        AND 11011111B               ; lower to uppercase
        CP 'H'                      ; are we trying to load an Intel HEX program?
        JP Z, HEX_START             ; then jump to HexLoadr
        CP 'C'
        JR NZ, CHECKWARM
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
COLDSTART:
        LD A,'Y'                    ; Set the BASIC STARTED flag
        LD (basicStarted),A
        JP $0390                    ; <<<< Start Basic COLD:
CHECKWARM:
        CP 'W'
        JR NZ, CORW
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
WARMSTART:
        JP $0393                    ; <<<< Start Basic WARM:

;==============================================================================
;
; STRINGS
;
SECTION         z80_init_strings    ; ORG $02D0

SIGNON1:        DEFM    CR,LF
                DEFM    "SBC - Grant Searle",CR,LF
                DEFM    "ACIA - feilipu",CR,LF
                DEFM    "z88dk",CR,LF,0

SIGNON2:        DEFM    CR,LF
                DEFM    "Cold or Warm start, "
                DEFM    "or HexLoadr (C|W|H) ? ",0

initString:     DEFM    CR,LF,"HexLoadr: "
                DEFM    CR,LF,0

invalidTypeStr: DEFM    CR,LF,"Invalid Type",CR,LF,0
badCheckSumStr: DEFM    CR,LF,"Checksum Error",CR,LF,0
LoadOKStr:      DEFM    CR,LF,"Done",CR,LF,0

;==============================================================================
;
; Z80 INTERRUPT VECTOR PROTOTYPE ASSIGNMENTS
;

EXTERN  NULL_RET, NULL_INT, NULL_NMI

PUBLIC  Z180_TRAP
PUBLIC  RST_08, RST_10, RST_18, RST_20, RST_28, RST_30
PUBLIC  INT_INT0, INT_NMI

DEFC    Z180_TRAP   =       INIT            ; Initialise, should never get here
DEFC    RST_08      =       TXA             ; TX character over ACIA, loop until space
DEFC    RST_10      =       RXA             ; RX character over ACIA, loop until byte
DEFC    RST_18      =       RXA_CHK         ; Check ACIA status, return # bytes available
DEFC    RST_20      =       NULL_RET        ; RET
DEFC    RST_28      =       NULL_RET        ; RET
DEFC    RST_30      =       NULL_RET        ; RET
DEFC    INT_INT0    =       serialInt       ; ACIA interrupt
DEFC    INT_NMI     =       NULL_NMI        ; RETN

;==============================================================================

