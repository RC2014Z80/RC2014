SECTION INIT
ORG     $F800 ; 0xFFFF - 2048

start:      ;di              ; disable interrupts
            ld hl, $FFFF    ; set new stack location
            ld sp, hl       ; to $FFFF
            ld a, $03
            out ($80),a     ; ACIA master reset
            ld a, $96       ; Initialize ACIA
            out ($80),a
            ei
            ;di


mainf:      ld hl, initstr
            call print

waitcol:    call RX         ; wait for ':'
            ld a, l
            cp ':'
            jp nz, waitcol
            ld ix, 0        ; reset ix to compute checksum
            call readbyte   ; read byte count
            ld b, h         ; store it in bc
            ld c, l         ;
            call readbyte   ; read upper byte of address
            ld d, l         ; store in d
            call readbyte   ; read lower byte of address
            ld e, l         ; store in e
            call readbyte   ; read record type
            ld a, l         ; store in a
            cp 01           ; check if record type is 01 (end of file)
            jr z, endload
            cp 00           ; check if record type is 00 (data)
            jr nz, invtype  ; if not, error

readdata:   call readbyte
            ld a, l
            ld (de), a
            inc de
            dec bc
            ld a, 0         ; check if bc==0
            or b
            or c
            cp 0
            jr nz, readdata ; if not, loop

            ;ld a, '|'
            ;call TX
            call readbyte   ; read checksum
            ld a, ixl       ; lower byte of ix should be 0
            cp 0
            jr nz, badck

            ld a, '*'
            call TX
            jp waitcol

endload:    call readbyte   ; read last checksum (not used)
            ld hl, loadokstr
            call print
            ld hl, $8080
            jp (hl)
            ;jp hang

invtype:    ld hl, invalidtypestr
            call print
            jp hang

badck:      ld hl, badchecksumstr
            call print
            jp hang

hang:
            nop
            jp hang

TX:         push af
txbusy:     in a,($80)          ; read serial status
            bit 1,a             ; check status bit 1
            jr z, txbusy        ; loop if zero (serial is busy)
            pop af
            out ($81), a        ; transmit the character
            ret

RX:
            push af
waitch:     ;in a, ($80)
            ;bit 0, a
            ;jr z, waitch
            ;in a, ($81)
            ;ld h, 0
            rst $10
            ld l, a
            ;call TX
            pop af
            ret

print:
            ld a, (hl)
            or a
            ret z
            call TX
            inc hl
            jp print

readbyte:
            push af
            push de
            call RX
            ld a, l
            sub '0'
            cp 10
            jr c, rnib2    ; if a<10 read the second nibble
            sub 7          ; else subtract 'A'-'0' (17) and add 10
rnib2:      ld d, a        ; temporary store the first nibble in d
            call RX
            ld a, l
            sub '0'
            cp 10
            jr c, rend     ; if a<10 finalize
            sub 7          ; else subtract 'A' (17) and add 10
rend:       ld e, a        ; temporary store the second nibble in e
            sla d          ; shift register d left by 4 bits
            sla d
            sla d
            sla d
            or d
            pop de
            ld h, 0
            ld l, a
            pop af
            push bc         ; add the byte read to ix (for checksum)
            ld b, 0
            ld c, l
            add ix, bc
            pop bc
            ret

initstr:            DEFM "HEX LOADER by Filippo Bergamasco",10,13,0
invalidtypestr:     DEFM 10,13,"INV TYP",0
badchecksumstr:     DEFM 10,13,"BAD CHK",0
loadokstr:          DEFM 10,13,"OK",0
