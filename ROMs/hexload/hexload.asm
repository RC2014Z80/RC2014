SECTION     CODE

main:
            ld hl, initstr
            call print
waitcolon:
            rst 10H         ; wait for Rx ':'
            cp ':'
            jr nz, waitcolon
            ld hl, 0        ; reset hl to compute checksum
            call readbyte   ; read byte count
            ld b, a         ; store it in bc
            call readbyte   ; read upper byte of address
            ld d, a         ; store in d
            call readbyte   ; read lower byte of address
            ld e, a         ; store in e
            call readbyte   ; read record type
            cp 01           ; check if record type is 01 (end of file)
            jr z, endload
            cp 00           ; check if record type is 00 (data)
            jr nz, invtype  ; if not, error
readdata:
            call readbyte
            ld (de), a
            inc de
            djnz readdata   ; if not, loop

            call readbyte   ; read checksum
            ld a, l         ; lower byte of hl should be 0
            or a
            jr nz, badck

            ld a, '#'       ; "#" per line loaded
            rst 8H          ; Tx byte
            jr waitcolon

endload:
            call readbyte   ; read last checksum (not used)
            ld a, l         ; lower byte of hl checksum should be 0
            or a
            jr nz, badck    ; non zero, we have an issue
            ld hl, loadokstr
            call print
            ret

invtype:
            ld hl, invalidtypestr
            call print
            ret

badck:
            ld hl, badchecksumstr
            call print
            ret

readbyte:                   ; Returns byte in a, checksum in hl
            push bc
            rst 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, rnib2     ; if a<10 read the second nibble
            sub 7           ; else subtract 'A'-'0' (17) and add 10
rnib2:
            rlca            ; shift accumulator left by 4 bits
            rlca
            rlca
            rlca
            ld c, a         ; temporary store the first nibble in c
            rst 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, rend      ; if a<10 finalize
            sub 7           ; else subtract 'A' (17) and add 10
rend:
            or c            ; assemble two nibbles into one byte in a
            ld b, 0         ; add the byte read to hl (for checksum)
            ld c, a
            add hl, bc
            pop bc
            ret             ; return the byte read in a

print:
            ld a, (hl)
            or a
            ret z
            rst 8H          ; Tx byte
            inc hl
            jr print

SECTION             DATA

initstr:            DEFM "HEX LOADER by Filippo Bergamasco"
                    DEFM " & feilipu for z88dk"
                    DEFM 10,13,":",0
invalidtypestr:     DEFM 10,13,"Invalid Type",10,13,0
badchecksumstr:     DEFM 10,13,"Bad Checksum",10,13,0
loadokstr:          DEFM 10,13,"Done",10,13,0
