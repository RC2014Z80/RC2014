;
;
; Converted to z88dk z80asm for RC2014 by
; Phillip Stevens @feilipu https://feilipu.me
; March 2018
;

SECTION rodata_driver               ;read only driver (code)

INCLUDE "config_rc2014_private.inc"

;------------------------------------------------------------------------------
; location setting
;------------------------------------------------------------------------------

PUBLIC  __COMMON_AREA_PHASE_BIOS    ;base of bios
defc    __COMMON_AREA_PHASE_BIOS    = 0xF200

defc    __CPM_BIOS_BSS_HEAD         = 0xF800

;------------------------------------------------------------------------------
; start of definitions
;------------------------------------------------------------------------------

EXTERN  _cpm_ccp_head               ;base of ccp
EXTERN  _cpm_bdos_fbase             ;entry of bdos

PUBLIC  _cpm_disks

PUBLIC  _cpm_iobyte
PUBLIC  _cpm_cdisk
PUBLIC  _cpm_ccp_tfcb
PUBLIC  _cpm_ccp_tbuff
PUBLIC  _cpm_ccp_tbase

DEFC    _cpm_disks      =   4       ;XXX DO NOT CHANGE number of disks

DEFC    _cpm_iobyte     =   $0003   ;address of CP/M IOBYTE
DEFC    _cpm_cdisk      =   $0004   ;address of CP/M TDRIVE
DEFC    _cpm_ccp_tfcb   =   $005C   ;default file control block
DEFC    _cpm_ccp_tbuff  =   $0080   ;i/o buffer and command line storage
DEFC    _cpm_ccp_tbase  =   $0100   ;transient program storage area

;
;*****************************************************
;*                                                   *
;*          CP/M to host disk constants              *
;*                                                   *
;*****************************************************

DEFC    hstalb  =    2048       ;host number of drive allocation blocks
DEFC    hstsiz  =    512        ;host disk sector size
DEFC    hstspt  =    256        ;host disk sectors/trk
DEFC    hstblk  =    hstsiz/128 ;CP/M sects/host buff (4)

DEFC    cpmbls  =    4096       ;CP/M allocation block size BLS
DEFC    cpmdir  =    2048       ;CP/M number of directory blocks (each of 32 Bytes)
DEFC    cpmspt  =    hstspt * hstblk    ;CP/M sectors/track (1024 = 256 * 512 / 128)

DEFC    secmsk  =    hstblk-1   ;sector mask

;
;*****************************************************
;*                                                   *
;*          BDOS constants on entry to write         *
;*                                                   *
;*****************************************************

DEFC    wrall   =    0          ;write to allocated
DEFC    wrdir   =    1          ;write to directory
DEFC    wrual   =    2          ;write to unallocated

;=============================================================================
;
; CBIOS for CP/M 2.2 alteration
;
;=============================================================================

PUBLIC  _rodata_cpm_bios_head
_rodata_cpm_bios_head:          ;origin of the cpm bios in rodata

PHASE   __COMMON_AREA_PHASE_BIOS

PUBLIC  _cpm_bios_head
_cpm_bios_head:                 ;origin of the cpm bios

;
;   jump vector for individual subroutines
;
PUBLIC    cboot     ;cold start
PUBLIC    wboot     ;warm start
PUBLIC    const     ;console status
PUBLIC    conin     ;console character in
PUBLIC    conout    ;console character out
PUBLIC    list      ;list character out
PUBLIC    punch     ;punch character out
PUBLIC    reader    ;reader character in
PUBLIC    home      ;move head to home position
PUBLIC    seldsk    ;select disk
PUBLIC    settrk    ;set track number
PUBLIC    setsec    ;set sector number
PUBLIC    setdma    ;set dma address
PUBLIC    read      ;read disk
PUBLIC    write     ;write disk
PUBLIC    listst    ;return list status
PUBLIC    sectran   ;sector translate

    jp    cboot     ;cold start
wboote:
    jp    wboot     ;warm start
    jp    const     ;console status
    jp    conin     ;console character in
    jp    conout    ;console character out
    jp    list      ;list character out
    jp    punch     ;punch character out
    jp    reader    ;reader character out
    jp    home      ;move head to home position
    jp    seldsk    ;select disk
    jp    settrk    ;set track number
    jp    setsec    ;set sector number
    jp    setdma    ;set dma address
    jp    read      ;read disk
    jp    write     ;write disk
    jp    listst    ;return list status
    jp    sectran   ;sector translate

;   individual subroutines to perform each function

EXTERN    pboot     ;location of preamble code to load CCP/BDOS

EXTERN    asm_shadow_copy           ;RAM copy function
EXTERN    asm_shadow_relocate       ;relocate the RAM copy function

PUBLIC    qboot                     ;arrival from preamble code
PUBLIC    diskchk_jp_addr           ;address of jp to bios diskchk

PUBLIC _cpm_boot

_cpm_boot:

cboot:
    di                              ;Page 0 will be blank, after toggling ROM
                                    ;so leave interrupts off, until later

    ld      sp,bios_stack           ;temporary stack

    ld      a,$01                   ;RAM $01
    out     (__IO_ROM_TOGGLE),a     ;latch ROM out

;   Set up Page 0

    ld      a,$C9                   ;C9 is a ret instruction for:
    ld      ($0008),a               ;rst 08
    ld      ($0010),a               ;rst 10
    ld      ($0018),a               ;rst 18
    ld      ($0020),a               ;rst 20
    ld      ($0028),a               ;rst 28
    ld      ($0030),a               ;rst 30
    ld      ($0038),a               ;rst 38

    xor     a                       ;zero in the accum
    ld      (_cpm_cdisk),a          ;select disk zero

    ld      a,(_bios_iobyte)        ;get bios iobyte from shell
    ld      (_cpm_iobyte),a         ;set cpm iobyte to that selected by bios shell

IF __IO_RAM_SHADOW_AVAILABLE = 0x01

    ld      hl,asm_shadow_copy          ;prepare current RAM copy location
    ld      (__IO_RAM_SHADOW_BASE),hl   ;write it to RAM copy base

    ld      hl,shadow_copy_addr     ;new location for shadow_copy function
    call    asm_shadow_relocate     ;move it to final (?) location

ENDIF

    ld      hl,$AA55                ;enable the canary, to show CP/M bios alive
    ld      (_cpm_bios_canary),hl

    jr      rboot

wboot:                              ;from a normal restart
    di
    ld      sp,bios_stack           ;temporary stack
    xor     a                       ;A = $00 ROM
    out     (__IO_ROM_TOGGLE),a     ;latch ROM IN
    jp      pboot                   ;load the CCP/BDOS in preamble

qboot:                              ;arrive from preamble
    ld      a,$01                   ;A = $01 RAM
    out     (__IO_ROM_TOGGLE),a     ;latch ROM OUT

;=============================================================================
; Common code for cold and warm boot
;=============================================================================

rboot:
    ld      a,$C3           ;C3 is a jmp instruction
    ld      ($0000),a       ;for jmp to wboot
    ld      hl,wboote       ;wboot entry point
    ld      ($0001),hl      ;set address field for jmp at 0 to wboote

    ld      ($0005),a       ;C3 for jmp to bdos entry point
    ld      hl,_cpm_bdos_fbase  ;bdos entry point
    ld      ($0006),hl      ;set address field of Jump at 5 to bdos

    ld      bc,$0080        ;default dma address is 0x0080
    call    setdma

    xor     a               ;0 accumulator
    ld      (hstact),a      ;host buffer inactive
    ld      (unacnt),a      ;clear unalloc count

    ld      (_cpm_ccp_tfcb),a
    ld      hl,_cpm_ccp_tfcb
    ld      de,hl
    inc     de
    call    ldi_31          ;clear default FCB

    call    _sioa_reset     ;reset and empty the SIOA Tx & Rx buffers
    call    _siob_reset     ;reset and empty the SIOB Tx & Rx buffers
    ei

    ld      a,(_cpm_cdisk)  ;get current disk number
    cp      _cpm_disks      ;see if valid disk number

diskchk_jp_addr:            ;optional SMC, to void the LBA check and directly execute TPA

    jp      C,diskchk       ;disk number valid, check existence via valid LBA
    xor     a               ;invalid disk, change to disk 0 (A:)
    ld      (_cpm_cdisk),a  ;reset current disk number to disk 0 (A:)

diskchk:
    ld      c,a             ;send current disk number to the ccp
    call    getLBAbase      ;get the LBA base address
    ld      a,(hl)          ;check that the LBA is non Zero
    inc     hl
    or      a,(hl)
    inc     hl
    or      a,(hl)
    inc     hl
    or      a,(hl)
    jp      NZ,_cpm_ccp_head        ;valid disk, go to ccp for further processing

    ld      (_cpm_bios_canary),a    ;kill the canary
;   xor     a                       ;A = $00 ROM
    out     (__IO_ROM_TOGGLE),a     ;latch ROM IN
    ret                             ;ret directly back to ROM monitor,
                                    ;or back to preamble then ROM monitor

;=============================================================================
; Console I/O routines
;=============================================================================

const:      ;console status, return 0ffh if character ready, 00h if not
    ld      a,(_cpm_iobyte)
    and     00000011b       ;mask off console
    cp      00000010b       ;"BAT:" redirect to TTY: reader
    jr      Z,const1

    rrca                    ;manage remaining console bit
    jr      C,const0        ;------x1b CRT:
    jr      NC,const1       ;------x0b TTY:
    xor     a               ;------x-b otherwise
    ret

const0:
    call    _sioa_pollc     ;check whether any characters are in CRT (RxA) buffer
    jr      NC,dataEmpty
dataReady:
    ld      a,$FF
    ret

const1:
    call    _siob_pollc     ;check whether any characters are in TTY (RxB) buffer
    jr      C,dataReady
dataEmpty:
    xor     a
    ret

conin:      ;console character into register a
    ld      a,(_cpm_iobyte)
    and     00000011b       ;mask off console
    cp      00000010b       ;"BAT:" redirect to TTY: reader
    jr      Z,reader

    rrca                    ;manage remaining console bit
    jr      C,conin0        ;------x1b CRT:
    jr      NC,conin1       ;------x0b TTY:
    xor     a               ;------x-b otherwise
    ret

conin0:     ;------01b CRT:
   call     _sioa_getc      ;check whether any characters are in CRT RxA buffer
   jr       NC,conin0       ;if Rx buffer is empty
;  and      $7F             ;don't strip parity bit - support 8 bit XMODEM
   ret

conin1:     ;------00b TTY:
   call     _siob_getc      ;check whether any characters are in TTY RxB buffer
   jr       NC,conin1       ;if Rx buffer is empty
;  and      $7F             ;don't strip parity bit - support 8 bit XMODEM
   ret

reader:
    ld      a,(_cpm_iobyte)
    and     00001100b
    jr      Z,conin1
    ld      a,$1A           ;CTRL-Z if not TTY:
    ret

conout:    ;console character output from register c
    ld      l,c             ;Store character
    ld      a,(_cpm_iobyte)
    and     00000011b
    cp      00000010b       ;------1xb LPT: or UL1:
    jr      Z,list          ;"BAT:" redirect
    rrca
    jp      C,_sioa_putc    ;------01b CRT:
    jp      _siob_putc      ;------00b TTY:

list:
    ld      l,c             ;store character
    ld      a,(_cpm_iobyte)
    rlca
    ret     C               ;1x------b LPT: or UL1:
    rlca
    jp      C,_sioa_putc    ;01------b CRT:
    jp      _siob_putc      ;00------b TTY:

punch:
    ld      l,c             ;store character
    ld      a,(_cpm_iobyte)
    and     00110000b
    jp      Z,_siob_putc    ;--00----b TTY:
    ret                     ;--x1----b PTP: or UL1:

listst:     ;return list status
    ld      a,$FF           ;return list status of 0xFF (ready).
    ret

;=============================================================================
; Disk processing entry points
;=============================================================================

home:       ;move to the track 00 position of current drive
    ld      a,(hstwrt)      ;check for pending write
    or      a
    jr      NZ,homed
    ld      (hstact),a      ;clear host active flag
homed:
    ld      bc,$0000

settrk:     ;set track passed from BDOS in register BC
    ld      (sektrk),bc
    ret

setsec:     ;set sector passed from BDOS given by register BC
    ld      (seksec),bc
    ret

sectran:    ;translate passed from BDOS sector number BC
    ld      hl,bc
    ret

setdma:     ;set dma address given by registers BC
    ld      (dmaadr),bc     ;save the address
    ret

seldsk:    ;select disk given by register c
    ld      a,c
    cp      _cpm_disks      ;must be between 0 and 3
    jr      NC,seldskreset  ;invalid drive will result in BDOS error

chgdsk:
    call    getLBAbase      ;get the LBA base address for disk
    ld      a,(hl)          ;check that the LBA is non-Zero
    inc     hl
    or      a,(hl)
    inc     hl
    or      a,(hl)
    inc     hl
    or      a,(hl)
    jr      Z,seldskreset   ;invalid disk LBA, so return BDOS error

    ld      a,c             ;recover selected disk
    ld      (sekdsk),a      ;and set the seeked disk
    add     a,a             ;*2 calculate offset into dpbase
    add     a,a             ;*4
    add     a,a             ;*8
    add     a,a             ;*16
    ld      hl,dpbase
    add     a,l
    ld      l,a
    ret     NC              ;return the disk dpbase in HL, no carry
    inc     h
    ret                     ;return the disk dpbase in HL

seldskreset:
    ld      hl,$0000        ;prepare return error code in HL
    ld      a,(_cpm_cdisk)  ;get the current default drive
    cp      c               ;and see if it was requested
    ret     NZ              ;if not return, otherwise

    xor     a               ;reset default disk back to 0 (A:)
    ld      (_cpm_cdisk),a  ;and set the seeked disk
    ld      (sekdsk),a      ;otherwise a loop results
    ret
;
;*****************************************************
;*                                                   *
;*      The READ entry point takes the place of      *
;*      the previous BIOS definition for READ.       *
;*                                                   *
;*****************************************************

;Read one CP/M sector from disk.
;Return a 00h in register a if the operation completes properly, and 01h if an error occurs during the read.
;Disk number in 'sekdsk'
;Track number in 'sektrk'
;Sector number in 'seksec'
;Dma address in 'dmaadr' (0-65535)

;read the selected CP/M sector
read:
    xor     a
    ld      (unacnt),a      ;unacnt = 0
    inc     a
    ld      (readop),a      ;read operation
    ld      (rsflag),a      ;must read data
    ld      a,wrual
    ld      (wrtype),a      ;treat as unalloc
    jp      rwoper          ;to perform the read

;
;*****************************************************
;*                                                   *
;*    The WRITE entry point takes the place of       *
;*     the previous BIOS definition for WRITE.       *
;*                                                   *
;*****************************************************

;Write one CP/M sector to disk.
;Return a 00h in register a if the operation completes properly, and 0lh if an error occurs during the read or write
;Disk number in 'sekdsk'
;Track number in 'sektrk'
;Sector number in 'seksec'
;Dma address in 'dmaadr' (0-65535)

;write the selected CP/M sector
write:
    xor     a               ;0 to accumulator
    ld      (readop),a      ;not a read operation
    ld      a,c             ;write type in c
    ld      (wrtype),a
    cp      wrual           ;write unallocated?
    jr      NZ,chkuna       ;check for unalloc

;           write to unallocated, set parameters
    ld      a,cpmbls/128    ;next unalloc recs
    ld      (unacnt),a
    ld      a,(sekdsk)      ;disk to seek
    ld      (unadsk),a      ;unadsk = sekdsk
    ld      a,(sektrk)
    ld      (unatrk),a      ;unatrk = sectrk
    ld      hl,(seksec)
    ld      (unasec),hl     ;unasec = seksec

chkuna:
;           check for write to unallocated sector
    ld      a,(unacnt)      ;any unalloc remain?
    or      a
    jr      Z,alloc         ;skip if not

;           more unallocated records remain
    dec     a               ;unacnt = unacnt-1
    ld      (unacnt),a
    ld      a,(sekdsk)      ;same disk?
    ld      hl,unadsk
    cp      (hl)            ;sekdsk = unadsk?
    jr      NZ,alloc        ;skip if not

;           disks are the same
    ld      a,(sektrk)      ;same track?
    ld      hl,unatrk
    cp      (hl)            ;low byte compare sektrk = unatrk?
    jr      NZ,alloc        ;skip if not

;           tracks are the same
    ld      de,seksec       ;same sector?
    ld      hl,unasec
    ld      a,(de)          ;low byte compare seksec = unasec?
    cp      (hl)            ;same?
    jr      NZ,alloc        ;skip if not
    inc     de
    inc     hl
    ld      a,(de)          ;high byte compare seksec = unasec?
    cp      (hl)            ;same?
    jr      NZ,alloc        ;skip if not

;           match, move to next sector for future ref
    ld      hl,(unasec)
    inc     hl              ;unasec = unasec+1
    ld      (unasec),hl
    ld      de,cpmspt       ;count CP/M sectors
    sbc     hl,de           ;end of track?
    jr      C,noovf         ;skip if no overflow

;           overflow to next track
    ld      hl,0
    ld      (unasec),hl     ;unasec = 0
    ld      hl,unatrk
    inc     (hl)            ;unatrk = unatrk+1

noovf:
;           match found, mark as unnecessary read
    xor     a               ;0 to accumulator
    ld      (rsflag),a      ;rsflag = 0
    jr      rwoper          ;to perform the write

alloc:
;           not an unallocated record, requires pre-read
    xor     a               ;0 to accum
    ld      (unacnt),a      ;unacnt = 0
    inc     a               ;1 to accum
    ld      (rsflag),a      ;rsflag = 1

;
;*****************************************************
;*                                                   *
;*    Common code for READ and WRITE follows         *
;*                                                   *
;*****************************************************

rwoper:
;           enter here to perform the read/write
    xor     a               ;zero to accum
    ld      (erflag),a      ;no errors (yet)
    ld      hl,(seksec)     ;compute host sector
    ld      a,l             ;assuming 4 CP/M sectors per host sector
    srl     h               ;shift right
    rra
    srl     h               ;shift right
    rra
    ld      (sekhst),a      ;host sector to seek

;           active host sector?
    ld      hl,hstact       ;host active flag
    ld      a,(hl)
    ld      (hl),1          ;always becomes 1
    or      a               ;was it already?
    jr      Z,filhst        ;fill host if not

;           host buffer active, same as seek buffer?
    ld      a,(sekdsk)
    ld      hl,hstdsk       ;same disk?
    cp      (hl)            ;sekdsk = hstdsk?
    jr      NZ,nomatch

;           same disk, same track?
    ld      a,(sektrk)
    ld      hl,hsttrk
    cp      (hl)            ;sektrk = hsttrk?
    jr      NZ,nomatch

;           same disk, same track, same buffer?
    ld      a,(sekhst)
    ld      hl,hstsec       ;sekhst = hstsec?
    cp      (hl)
    jr      Z,match         ;skip if match

nomatch:
;           proper disk, but not correct sector
    ld      a,(hstwrt)      ;host written?
    or      a
    call    NZ,writehst     ;clear host buff

filhst:
;           may have to fill the host buffer
    ld      a,(sekdsk)
    ld      (hstdsk),a
    ld      a,(sektrk)
    ld      (hsttrk),a
    ld      a,(sekhst)
    ld      (hstsec),a
    ld      a,(rsflag)      ;need to read?
    or      a
    call    NZ,readhst      ;yes, if 1
    xor     a               ;0 to accum
    ld      (hstwrt),a      ;no pending write

match:
;           copy data to or from buffer
    ld      a,(seksec)      ;mask buffer number LSB
    and     secmsk          ;least significant bits, shifted off in sekhst calculation
    ld      h,a             ;shift left 7, for 128 bytes x seksec LSBs
    ld      l,0             ;ready to shift
    srl     h
    rr      l

;           HL has relative host buffer address
    ld      de,hstbuf
    add     hl,de           ;HL = host address
    ld      de,(dmaadr)     ;get/put CP/M data in destination in DE
;   ld      bc,128          ;length of move
    ld      a,(readop)      ;which way?
    or      a
    jr      NZ,rwmove       ;skip if read

;           write operation, mark and switch direction
    ld      a,1
    ld      (hstwrt),a      ;hstwrt = 1
    ex      de,hl           ;source/dest swap

rwmove:
    call    ldi_128

;           data has been moved to/from host buffer
    ld      a,(wrtype)      ;write type
    and     wrdir           ;to directory?
    ld      a,(erflag)      ;in case of errors
    ret     Z               ;no further processing

;           clear host buffer for directory write
    or      a               ;errors?
    ret     NZ              ;skip if so
    xor     a               ;0 to accum
    ld      (hstwrt),a      ;buffer written
    call    writehst
    ld      a,(erflag)
    ret

ldi_128:
    ld bc,ldi_32
    push bc
    push bc
    push bc

ldi_32:
    ldi
ldi_31:
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi

    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi

    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi

    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi

    ret

;
;*****************************************************
;*                                                   *
;*    WRITEHST performs the physical write to        *
;*    the host disk, READHST reads the physical      *
;*    disk.                                          *
;*                                                   *
;*****************************************************

writehst:
    ;hstdsk = host disk #, 0,1,2,3
    ;hsttrk = host track #, 64 tracks = 6 bits
    ;hstsec = host sect #, 256 sectors per track = 8 bits
    ;write "hstsiz" bytes
    ;from hstbuf and return error flag in erflag.
    ;return erflag non-zero if error

    call    setLBAaddr      ;get the required LBA into BCDE
    ld      hl,hstbuf       ;get hstbuf address into HL

    ;write a sector
    ;specified by the 4 bytes in BCDE
    ;the address of the origin buffer is in HL
    ;HL is left incremented by 512 bytes
    ;return carry on success, no carry for an error
    call    ide_write_sector
    ret     C
    ld      a,$01
    ld      (erflag),a
    ret

readhst:
    ;hstdsk = host disk #, 0,1,2,3
    ;hsttrk = host track #, 64 tracks = 6 bits
    ;hstsec = host sect #, 256 sectors per track = 8 bits
    ;read "hstsiz" bytes
    ;into hstbuf and return error flag in erflag.

    call    setLBAaddr      ;get the required LBA into BCDE
    ld      hl,hstbuf       ;get hstbuf address into HL

    ;read a sector
    ;LBA specified by the 4 bytes in BCDE
    ;the address of the buffer to fill is in HL
    ;HL is left incremented by 512 bytes
    ;return carry on success, no carry for an error
    call    ide_read_sector
    ret     C
    ld      a,$01
    ld      (erflag),a
    ret

;=============================================================================
; Convert track/head/sector into LBA for physical access to the disk
;=============================================================================
;
; The bios provides us with the LBA base location for each of 4 files,
; in _cpm_dsk0_base. Each LBA is 4 bytes, total 16 bytes
;
; The translation activity is to set the LBA correctly, using the hstdsk, hstsec,
; and hsttrk information.
;
; Since hstsec is 256 sectors per track, we need to use 8 bits for hstsec.
; Since we never have more than 8MB, hsttrk is 6 bits.
;
; This also matches nicely with the calculation, where a 16 bit addition of the
; translation can be added to the base LBA to get the sector.
;

setLBAaddr:
    ld      a,(hstdsk)      ;get disk number (0,1,2,3)
    call    getLBAbase      ;get the LBA base address
                            ;HL contains address of active disk (file) LBA LSB

    ld      a,(hstsec)      ;prepare the hstsec (8 bits, 256 sectors per track)
    add     a,(hl)          ;add hstsec + LBA LSB
    ld      e,a             ;write LBA LSB, put it in E

    inc     hl
    ld      a,(hsttrk)      ;prepare the hsttrk (6 bits, 64 tracks per disk)
    adc     a,(hl)          ;add hsttrk + LBA 1SB, with carry
    ld      d,a             ;write LBA 1SB, put it in D

    inc     hl
    ld      a,(hl)          ;get disk LBA 2SB
    adc     a,$00           ;get disk LBA 2SB, with carry
    ld      c,a             ;write LBA 2SB, put it in C

    inc     hl
    ld      a,(hl)          ;get disk LBA MSB
    adc     a,$00           ;get disk LBA MSB, with carry
    ld      b,a             ;write LBA MSB, put it in B

    ret

getLBAbase:
    add     a,a             ;uint32_t off-set for each disk (file) LBA base address
    add     a,a             ;so left shift 2 (x4), to create offset to disk base address

    ld      hl,_cpm_dsk0_base;get the address for disk LBA base address
    add     a,l             ;add the offset to the base address
    ld      l,a
    ret     NC              ;LBA base address in HL, no carry
    inc     h
    ret                     ;LBA base address in HL


;------------------------------------------------------------------------------
; start of common area driver - sio functions
;------------------------------------------------------------------------------

PUBLIC _sioa_reset
PUBLIC _sioa_flush_rx_di
PUBLIC _sioa_getc
PUBLIC _sioa_putc
PUBLIC _sioa_pollc

PUBLIC _siob_reset
PUBLIC _siob_flush_rx_di
PUBLIC _siob_getc
PUBLIC _siob_putc
PUBLIC _siob_pollc

__siob_interrupt_tx_empty:      ; start doing the SIOB Tx stuff
    push af
    ld a,(siobTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether it is zero
    jr Z,siob_tx_int_pend       ; if the count is zero, disable the Tx Interrupt and exit

    push hl
    ld hl,(siobTxOut)           ; get the pointer to place where we pop the Tx byte
    ld a,(hl)                   ; get the Tx byte
    out (__IO_SIOB_DATA_REGISTER),a ; output the Tx byte to the SIOB

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_SIO_TX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or siobTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (siobTxOut),hl           ; write where the next byte should be popped

    ld hl,siobTxCount
    dec (hl)                    ; atomically decrement current Tx count

    pop hl
    jr NZ,siob_tx_end

siob_tx_int_pend:
    ld a,__IO_SIO_WR0_TX_INT_PENDING_RESET  ; otherwise pend the Tx interrupt
    out (__IO_SIOB_CONTROL_REGISTER),a      ; into the SIOB register R0

siob_tx_end:                    ; if we've more Tx bytes to send, we're done for now
    pop af

__siob_interrupt_ext_status:
    ei
    reti

__siob_interrupt_rx_char:
    push af
    push hl

siob_rx_get:
    in a,(__IO_SIOB_DATA_REGISTER)  ; move Rx byte from the SIOB to A
    ld hl,(siobRxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Rx byte to the siobRxIn target

    inc l                       ; move the Rx pointer low byte along
    ld a,__IO_SIO_RX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or siobRxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (siobRxIn),hl            ; write where the next byte should be poked

    ld hl,siobRxCount
    inc (hl)                    ; atomically increment Rx buffer count

    ld a,(siobRxCount)          ; get the current Rx count
    cp __IO_SIO_RX_FULLISH      ; compare the count with the preferred full size
    jp NZ,siob_rx_check         ; if the buffer is fullish reset the RTS line

    ld a,__IO_SIO_WR0_R5        ; prepare for a write to R5
    out (__IO_SIOB_CONTROL_REGISTER),a  ; write to SIOB control register
    ld a,__IO_SIO_WR5_TX_DTR|__IO_SIO_WR5_TX_8BIT|__IO_SIO_WR5_TX_ENABLE    ; clear RTS
    out (__IO_SIOB_CONTROL_REGISTER),a  ; write the SIOB R5 register

siob_rx_check:                  ; SIO has 4 byte Rx H/W FIFO
    in a,(__IO_SIOB_CONTROL_REGISTER)   ; get the SIOB register R0
    rrca                        ; test whether we have received on SIOB
    jr C,siob_rx_get            ; if still more bytes in H/W FIFO, get them

    pop hl                      ; or clean up
    pop af
    ei
    reti

__siob_interrupt_rx_error:
    push af
    ld a,__IO_SIO_WR0_R1                ; set request for SIOB Read Register 1
    out (__IO_SIOB_CONTROL_REGISTER),a  ; into the SIOB control register
    in a,(__IO_SIOB_CONTROL_REGISTER)   ; load Read Register 1
                                        ; test whether we have error on SIOB
    and __IO_SIO_RR1_RX_FRAMING_ERROR|__IO_SIO_RR1_RX_OVERRUN|__IO_SIO_RR1_RX_PARITY_ERROR
    jr Z,siob_interrupt_rx_exit         ; clear error, and exit
    in a,(__IO_SIOB_DATA_REGISTER)      ; remove errored Rx byte from the SIOB

siob_interrupt_rx_exit:
    ld a,__IO_SIO_WR0_ERROR_RESET       ; otherwise reset the Error flags
    out (__IO_SIOB_CONTROL_REGISTER),a  ; in the SIOB Write Register 0
    pop af                              ; and clean up
    ei
    reti

__sioa_interrupt_tx_empty:          ; start doing the SIOA Tx stuff
    push af
    ld a,(sioaTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether it is zero
    jr Z,sioa_tx_int_pend       ; if the count is zero, disable the Tx Interrupt and exit

    push hl
    ld hl,(sioaTxOut)           ; get the pointer to place where we pop the Tx byte
    ld a,(hl)                   ; get the Tx byte
    out (__IO_SIOA_DATA_REGISTER),a ; output the Tx byte to the SIOA

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_SIO_TX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or sioaTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (sioaTxOut),hl           ; write where the next byte should be popped

    ld hl,sioaTxCount
    dec (hl)                    ; atomically decrement current Tx count

    pop hl
    jr NZ,sioa_tx_end

sioa_tx_int_pend:
    ld a,__IO_SIO_WR0_TX_INT_PENDING_RESET  ; otherwise pend the Tx interrupt
    out (__IO_SIOA_CONTROL_REGISTER),a      ; into the SIOA register R0

sioa_tx_end:                    ; if we've more Tx bytes to send, we're done for now
    pop af

__sioa_interrupt_ext_status:
    ei
    reti

__sioa_interrupt_rx_char:
    push af
    push hl

sioa_rx_get:
    in a,(__IO_SIOA_DATA_REGISTER)  ; move Rx byte from the SIOA to A
    ld hl,(sioaRxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Rx byte to the sioaRxIn target

    inc l                       ; move the Rx pointer low byte along
    ld a,__IO_SIO_RX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or sioaRxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (sioaRxIn),hl            ; write where the next byte should be poked

    ld hl,sioaRxCount
    inc (hl)                    ; atomically increment Rx buffer count

    ld a,(sioaRxCount)          ; get the current Rx count
    cp __IO_SIO_RX_FULLISH      ; compare the count with the preferred full size
    jp NZ,sioa_rx_check         ; if the buffer is fullish reset the RTS line

    ld a,__IO_SIO_WR0_R5        ; prepare for a write to R5
    out (__IO_SIOA_CONTROL_REGISTER),a   ; write to SIOA control register
    ld a,__IO_SIO_WR5_TX_DTR|__IO_SIO_WR5_TX_8BIT|__IO_SIO_WR5_TX_ENABLE    ; clear RTS
    out (__IO_SIOA_CONTROL_REGISTER),a  ; write the SIOA R5 register

sioa_rx_check:                  ; SIO has 4 byte Rx H/W FIFO
    in a,(__IO_SIOA_CONTROL_REGISTER)   ; get the SIOA register R0
    rrca                        ; test whether we have received on SIOA
    jr C,sioa_rx_get            ; if still more bytes in H/W FIFO, get them

    pop hl                      ; or clean up
    pop af
    ei
    reti

__sioa_interrupt_rx_error:
    push af
    ld a,__IO_SIO_WR0_R1                ; set request for SIOA Read Register 1
    out (__IO_SIOA_CONTROL_REGISTER),a  ; into the SIOA control register
    in a,(__IO_SIOA_CONTROL_REGISTER)   ; load Read Register 1
                                        ; test whether we have error on SIOA
    and __IO_SIO_RR1_RX_FRAMING_ERROR|__IO_SIO_RR1_RX_OVERRUN|__IO_SIO_RR1_RX_PARITY_ERROR
    jr Z,sioa_interrupt_rx_exit         ; clear error, and exit

    in a,(__IO_SIOA_DATA_REGISTER)      ; remove errored Rx byte from the SIOA

sioa_interrupt_rx_exit:
    ld a,__IO_SIO_WR0_ERROR_RESET       ; otherwise reset the Error flags
    out (__IO_SIOA_CONTROL_REGISTER),a  ; in the SIOA Write Register 0
    pop af                              ; and clean up
    ei
    reti

_sioa_reset:
    ; interrupts should be disabled
    call _sioa_flush_rx
    call _sioa_flush_tx
    ret

_siob_reset:
    ; interrupts should be disabled
    call _siob_flush_rx
    call _siob_flush_tx
    ret

_sioa_flush_rx:
    xor a
    ld (sioaRxCount),a          ; reset the Rx counter (set 0)
    ld hl,sioaRxBuffer          ; load Rx buffer pointer home
    ld (sioaRxIn),hl
    ld (sioaRxOut),hl
    ret

_siob_flush_rx:
    xor a
    ld (siobRxCount),a          ; reset the Rx counter (set 0)
    ld hl,siobRxBuffer          ; load Rx buffer pointer home
    ld (siobRxIn),hl
    ld (siobRxOut),hl
    ret

_sioa_flush_tx:
    xor a
    ld (sioaTxCount),a          ; reset the Tx counter (set 0)
    ld hl,sioaTxBuffer          ; load Tx buffer pointer home
    ld (sioaTxIn),hl
    ld (sioaTxOut),hl
    ret

_siob_flush_tx:
    xor a
    ld (siobTxCount),a          ; reset the Tx counter (set 0)
    ld hl,siobTxBuffer          ; load Tx buffer pointer home
    ld (siobTxIn),hl
    ld (siobTxOut),hl
    ret

_sioa_flush_rx_di:
    push af
    push hl
    di
    call _sioa_flush_rx
    ei
    pop hl
    pop af
    ret

_siob_flush_rx_di:
    push af
    push hl
    di
    call _siob_flush_rx
    ei
    pop hl
    pop af
    ret

_sioa_getc:
    ; exit     : a, l = char received
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, bc, hl

    ld a,(sioaRxCount)          ; get the number of bytes in the Rx buffer
    ld l,a                      ; and put it in hl
    or a                        ; see if there are zero bytes available
    ret Z                       ; if the count is zero, then return

    cp __IO_SIO_RX_EMPTYISH     ; compare the count with the preferred empty size
    jp NZ,sioa_getc_clean_up    ; if the buffer NOT emptyish, don't change the RTS

    ld a,__IO_SIO_WR0_R5        ; prepare for a write to R5
    out (__IO_SIOA_CONTROL_REGISTER),a  ; write to SIOA control register
    ld a,__IO_SIO_WR5_TX_DTR|__IO_SIO_WR5_TX_8BIT|__IO_SIO_WR5_TX_ENABLE|__IO_SIO_WR5_RTS   ; set the RTS
    out (__IO_SIOA_CONTROL_REGISTER),a  ; write the SIOA R5 register

sioa_getc_clean_up:
    ld hl,(sioaRxOut)           ; get the pointer to place where we pop the Rx byte
    ld c,(hl)                   ; get the Rx byte

    inc l                       ; move the Rx pointer low byte along
    ld a,__IO_SIO_RX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or sioaRxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (sioaRxOut),hl           ; write where the next byte should be popped

    ld hl,sioaRxCount
    dec (hl)                    ; atomically decrement Rx count

    ld l,c                      ; put the byte in hl
    ld a,c                      ; put byte in a
    scf                         ; indicate char received
    ret

_siob_getc:
    ; exit     : a, l = char received
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, bc, hl

    ld a,(siobRxCount)          ; get the number of bytes in the Rx buffer
    ld l,a                      ; and put it in hl
    or a                        ; see if there are zero bytes available
    ret Z                       ; if the count is zero, then return

    cp __IO_SIO_RX_EMPTYISH     ; compare the count with the preferred empty size
    jp NZ,siob_getc_clean_up    ; if the buffer NOT emptyish, don't change the RTS

    ld a,__IO_SIO_WR0_R5        ; prepare for a write to R5
    out (__IO_SIOB_CONTROL_REGISTER),a  ; write to SIOB control register
    ld a,__IO_SIO_WR5_TX_DTR|__IO_SIO_WR5_TX_8BIT|__IO_SIO_WR5_TX_ENABLE|__IO_SIO_WR5_RTS   ; set the RTS
    out (__IO_SIOB_CONTROL_REGISTER),a  ; write the SIOB R5 register

siob_getc_clean_up:
    ld hl,(siobRxOut)           ; get the pointer to place where we pop the Rx byte
    ld c,(hl)                   ; get the Rx byte

    inc l                       ; move the Rx pointer low byte along
    ld a,__IO_SIO_RX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or siobRxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (siobRxOut),hl           ; write where the next byte should be popped

    ld hl,siobRxCount
    dec (hl)                    ; atomically decrement Rx count

    ld l,c                      ; put the byte in hl
    ld a,c                      ; put byte in a
    scf                         ; indicate char received
    ret

_sioa_pollc:
    ; exit     : a, l = number of characters in Rx buffer
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, hl

    ld a,(sioaRxCount)          ; load the Rx bytes in buffer
    ld l,a                      ; load result
    or a                        ; check whether there are non-zero count
    ret Z                       ; return if zero count

    scf                         ; set carry to indicate char received
    ret

_siob_pollc:
    ; exit     : a, l = number of characters in Rx buffer
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, hl

    ld a,(siobRxCount)          ; load the Rx bytes in buffer
    ld l,a                      ; load result
    or a                        ; check whether there are non-zero count
    ret Z                       ; return if zero count

    scf                         ; set carry to indicate char received
    ret

_sioa_putc:
    ; enter    : l = char to output
    ;
    ; modifies : af, hl

    di
    ld a,(sioaTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether the buffer is empty
    jr NZ,sioa_putc_buffer_tx   ; buffer not empty, so abandon immediate Tx

    in a,(__IO_SIOA_CONTROL_REGISTER)   ; get the SIOA register R0
    and __IO_SIO_RR0_TX_EMPTY   ; test whether we can transmit on SIOA
    jr Z,sioa_putc_buffer_tx    ; if not, so abandon immediate Tx

    ld a,l                      ; retrieve Tx character for immediate Tx
    out (__IO_SIOA_DATA_REGISTER),a ; immediately output the Tx byte to the SIOA

    ei
    ret                         ; and just complete

sioa_putc_buffer_tx_overflow:
    ei

sioa_putc_buffer_tx:
    ld a,(sioaTxCount)          ; get the number of bytes in the Tx buffer
    cp __IO_SIO_TX_SIZE-1       ; check whether there is space in the buffer
    jr NC,sioa_putc_buffer_tx_overflow   ; buffer full, so keep trying

    ld a,l                      ; Tx byte

    ld hl,sioaTxCount
    di
    inc (hl)                    ; atomic increment of Tx count
    ld hl,(sioaTxIn)            ; get the pointer to where we poke
    ei
    ld (hl),a                   ; write the Tx byte to the sioaTxIn

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_SIO_TX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or sioaTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (sioaTxIn),hl            ; write where the next byte should be poked

    ret

_siob_putc:
    ; enter    : l = char to output
    ;
    ; modifies : af, hl

    di
    ld a,(siobTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether the buffer is empty
    jr NZ,siob_putc_buffer_tx   ; buffer not empty, so abandon immediate Tx

    in a,(__IO_SIOB_CONTROL_REGISTER)   ; get the SIOB register R0
    and __IO_SIO_RR0_TX_EMPTY   ; test whether we can transmit on SIOB
    jr Z,siob_putc_buffer_tx    ; if not, so abandon immediate Tx

    ld a,l                      ; retrieve Tx character for immediate Tx
    out (__IO_SIOB_DATA_REGISTER),a ; immediately output the Tx byte to the SIOB

    ei
    ret                         ; and just complete

siob_putc_buffer_tx_overflow:
    ei

siob_putc_buffer_tx:
    ld a,(siobTxCount)          ; get the number of bytes in the Tx buffer
    cp __IO_SIO_TX_SIZE-1       ; check whether there is space in the buffer
    jr NC,siob_putc_buffer_tx_overflow   ; buffer full, so keep trying

    ld a,l                      ; Tx byte

    ld hl,siobTxCount
    di
    inc (hl)                    ; atomic increment of Tx count
    ld hl,(siobTxIn)            ; get the pointer to where we poke
    ei
    ld (hl),a                   ; write the Tx byte to the siobTxIn

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_SIO_TX_SIZE-1     ; load the buffer size, (n^2)-1
    and l                       ; range check
    or siobTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (siobTxIn),hl            ; write where the next byte should be poked

    ret

;------------------------------------------------------------------------------
; start of common area driver - Compact Flash & IDE functions
;------------------------------------------------------------------------------

; set up the drive LBA registers
; Uses AF, BC, DE
; LBA is contained in BCDE registers

.ide_setup_lba
    ld a,e
    out (__IO_CF_IDE_LBA0),a    ;set LBA0 0:7
    ld a,d
    out (__IO_CF_IDE_LBA1),a    ;set LBA1 8:15
    ld a,c
    out (__IO_CF_IDE_LBA2),a    ;set LBA2 16:23
    ld a,b
    and 00001111b               ;lowest 4 bits LBA address used only
    or  11100000b               ;to enable LBA address master mode
    out (__IO_CF_IDE_LBA3),a    ;set LBA3 24:27 + bits 5:7=111
    ret

; How to poll (waiting for the drive to be ready to transfer data):
; Read the Regular Status port until bit 7 (BSY, value = 0x80) clears,
; and bit 3 (DRQ, value = 0x08) sets.
; Or until bit 0 (ERR, value = 0x01) or bit 5 (WFT, value = 0x20) sets.
; If neither error bit is set, the device is ready right then.
; Uses AF, DE
; return carry on success

.ide_wait_ready
    in a,(__IO_CF_IDE_STATUS)
    and 00100001b               ;test for ERR or WFT
    ret NZ                      ;return clear carry flag on failure

    in a,(__IO_CF_IDE_STATUS)   ;get status byte again
    and 11000000b               ;mask off BuSY and RDY bits
    xor 01000000b               ;wait for RDY to be set and BuSY to be clear
    jp NZ,ide_wait_ready

    scf                         ;set carry flag on success
    ret

; Wait for the drive to be ready to transfer data.
; Returns the drive's status in A
; Uses AF, DE
; return carry on success

.ide_wait_drq
    in a,(__IO_CF_IDE_STATUS)
    and 00100001b               ;test for ERR or WFT
    ret NZ                      ;return clear carry flag on failure

    in a,(__IO_CF_IDE_STATUS)   ;get status byte again
    and 10001000b               ;mask off BuSY and DRQ bits
    xor 00001000b               ;wait for DRQ to be set and BuSY to be clear
    jp NZ,ide_wait_drq

    scf                         ;set carry flag on success
    ret

;------------------------------------------------------------------------------
; Routines that talk with the IDE drive, these should not be called by
; the main program.

; read a sector
; LBA specified by the 4 bytes in BCDE
; the address of the buffer to fill is in HL
; HL is left incremented by 512 bytes
; uses AF, BC, DE, HL
; return carry on success

.ide_read_sector
    call ide_wait_ready         ;make sure drive is ready
    call ide_setup_lba          ;tell it which sector we want in BCDE

    ld a,1
    out (__IO_CF_IDE_SEC_CNT),a ;set sector count to 1

    ld a,__IDE_CMD_READ
    out (__IO_CF_IDE_COMMAND),a ;ask the drive to read it

    call ide_wait_ready         ;make sure drive is ready to proceed
    call ide_wait_drq           ;wait until it's got the data

    ;Read a block of 512 bytes (one sector) from the drive
    ;8 bit data register and store it in memory at (HL++)

    ld bc,__IO_CF_IDE_DATA&0xFF ;keep iterative count in b, I/O port in c
    inir
    inir

    scf                         ;carry = 1 on return = operation ok
    ret

;------------------------------------------------------------------------------
; Routines that talk with the IDE drive, these should not be called by
; the main program.

; write a sector
; specified by the 4 bytes in BCDE
; the address of the origin buffer is in HL
; HL is left incremented by 512 bytes
; uses AF, BC, DE, HL
; return carry on success

.ide_write_sector
    call ide_wait_ready         ;make sure drive is ready
    call ide_setup_lba          ;tell it which sector we want in BCDE

    ld a,1
    out (__IO_CF_IDE_SEC_CNT),a ;set sector count to 1

    ld a,__IDE_CMD_WRITE
    out (__IO_CF_IDE_COMMAND),a ;instruct drive to write a sector

    call ide_wait_ready         ;make sure drive is ready to proceed
    call ide_wait_drq           ;wait until it wants the data

    ;Write a block of 512 bytes (one sector) from (HL++) to
    ;the drive 8 bit data register

    ld bc,__IO_CF_IDE_DATA&0xFF ;keep iterative count in b, I/O port in c
    otir
    otir

;   call ide_wait_ready
;   ld a,__IDE_CMD_CACHE_FLUSH
;   out (__IO_CF_IDE_COMMAND),a ;tell drive to flush its hardware cache

    jp ide_wait_ready           ;wait until the write is complete

PUBLIC  _cpm_bios_tail
_cpm_bios_tail:             ;tail of the cpm bios

PUBLIC  _cpm_bios_rodata_head
_cpm_bios_rodata_head:      ;origin of the cpm bios rodata

;------------------------------------------------------------------------------
; start of fixed tables - aligned rodata
;------------------------------------------------------------------------------

ALIGN $10                   ;align for sio interrupt vector table


PUBLIC  _cpm_sio_interrupt_vector_table

; origin of the SIO/2 IM2 interrupt vector table

_cpm_sio_interrupt_vector_table:
    defw    __siob_interrupt_tx_empty
    defw    __siob_interrupt_ext_status
    defw    __siob_interrupt_rx_char
    defw    __siob_interrupt_rx_error
    defw    __sioa_interrupt_tx_empty
    defw    __sioa_interrupt_ext_status
    defw    __sioa_interrupt_rx_char
    defw    __sioa_interrupt_rx_error

;------------------------------------------------------------------------------
; start of fixed tables - non aligned rodata
;------------------------------------------------------------------------------
;
;    fixed data tables for four-drive standard drives
;    no translations
;
dpbase:
;   disk Parameter header for disk 00
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv00
;   disk parameter header for disk 01
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv01
;   disk parameter header for disk 02
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv02
;   disk parameter header for disk 03
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv03
;
;   disk parameter block for all disks.
;
dpblk:
    defw    cpmspt      ;SPT - sectors per track
    defb    5           ;BSH - block shift factor from BLS
    defb    31          ;BLM - block mask from BLS
    defb    1           ;EXM - Extent mask
    defw    hstalb-1    ;DSM - Storage size (blocks - 1)
    defw    cpmdir-1    ;DRM - Number of directory entries - 1
    defb    $FF         ;AL0 - 1 bit set per directory block (ALLOC0)
    defb    $FF         ;AL1 - 1 bit set per directory block (ALLOC0)
    defw    0           ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk) (ALLOC1)
    defw    0           ;OFF - Reserved tracks offset

;------------------------------------------------------------------------------
; end of fixed tables
;------------------------------------------------------------------------------

ALIGN __CPM_BIOS_BSS_HEAD   ;align for bss head  (fixed to access _cpm_dsk0_base)

PUBLIC  _cpm_bios_rodata_tail
_cpm_bios_rodata_tail:      ;tail of the cpm bios read only data

PUBLIC  _cpm_bios_bss_bridge
_cpm_bios_bss_bridge:

DEPHASE

SECTION bss_driver

;------------------------------------------------------------------------------
; start of bss tables
;------------------------------------------------------------------------------

PHASE _cpm_bios_bss_bridge

PUBLIC  _cpm_bios_bss_head

PUBLIC  _cpm_dsk0_base
PUBLIC  _cpm_bios_canary

PUBLIC  _bios_iobyte

_cpm_bios_bss_head:         ;head of the cpm bios bss

_cpm_dsk0_base:     defs 16 ;base 32 bit LBA of host file for disk 0 (A:) &
                            ;3 additional LBA for host files (B:, C:, D:)

_cpm_bios_canary:   defw 0  ;if it matches $AA55, bios has been loaded, and CP/M is active

_bios_iobyte:       defb 0  ;transfer the IOBYTE from the bios to CP/M

sekdsk:             defs 1  ;seek disk number
sektrk:             defs 2  ;seek track number
seksec:             defs 2  ;seek sector number

hstdsk:             defs 1  ;host disk number
hsttrk:             defs 1  ;host track number
hstsec:             defs 1  ;host sector number

sekhst:             defs 1  ;seek shr secshf
hstact:             defs 1  ;host active flag
hstwrt:             defs 1  ;host written flag

unacnt:             defs 1  ;unalloc rec cnt

unadsk:             defs 1  ;last unalloc disk
unatrk:             defs 2  ;last unalloc track
unasec:             defs 2  ;last unalloc sector

erflag:             defs 1  ;error reporting
rsflag:             defs 1  ;read sector flag
readop:             defs 1  ;1 if read operation
wrtype:             defs 1  ;write operation type
dmaadr:             defs 2  ;last direct memory address

alv00:              defs ((hstalb-1)/8)+1   ;allocation vector 0
alv01:              defs ((hstalb-1)/8)+1   ;allocation vector 1
alv02:              defs ((hstalb-1)/8)+1   ;allocation vector 2
alv03:              defs ((hstalb-1)/8)+1   ;allocation vector 3

dirbf:              defs 128            ;scratch directory area
hstbuf:             defs hstsiz         ;buffer for host disk sector
bios_stack:                             ;temporary bios stack origin

PUBLIC  _cpm_bios_bss_initialised_tail
_cpm_bios_bss_initialised_tail:         ;tail of the cpm bios initialised bss

;------------------------------------------------------------------------------
; start of bss tables - uninitialised by cpm22preamble (initialised in crt)
;------------------------------------------------------------------------------

PUBLIC  sioaRxCount, sioaRxIn, sioaRxOut
PUBLIC  siobRxCount, siobRxIn, siobRxOut
PUBLIC  sioaTxCount, sioaTxIn, sioaTxOut
PUBLIC  siobTxCount, siobTxIn, siobTxOut

sioaRxCount:    defb 0                  ;space for Rx Buffer Management
sioaRxIn:       defw sioaRxBuffer       ;non-zero item in bss since it's initialized anyway
sioaRxOut:      defw sioaRxBuffer       ;non-zero item in bss since it's initialized anyway

siobRxCount:    defb 0                  ;space for Rx Buffer Management
siobRxIn:       defw siobRxBuffer       ;non-zero item in bss since it's initialized anyway
siobRxOut:      defw siobRxBuffer       ;non-zero item in bss since it's initialized anyway

sioaTxCount:    defb 0                  ;space for Tx Buffer Management
sioaTxIn:       defw sioaTxBuffer       ;non-zero item in bss since it's initialized anyway
sioaTxOut:      defw sioaTxBuffer       ;non-zero item in bss since it's initialized anyway

siobTxCount:    defb 0                  ;space for Tx Buffer Management
siobTxIn:       defw siobTxBuffer       ;non-zero item in bss since it's initialized anyway
siobTxOut:      defw siobTxBuffer       ;non-zero item in bss since it's initialized anyway

;------------------------------------------------------------------------------
; start of bss tables - aligned uninitialised data
;------------------------------------------------------------------------------

ALIGN   $10000 - $20 - __IO_SIO_TX_SIZE*2 - __IO_SIO_RX_SIZE*2

shadow_copy_addr:   defs $20            ;reserve space for relocation of shadow_copy

PUBLIC  sioaTxBuffer
PUBLIC  siobTxBuffer

ALIGN   __IO_SIO_TX_SIZE                ;ALIGN to __IO_SIO_TX_SIZE byte boundary
                                        ;when finally locating

sioaTxBuffer:   defs __IO_SIO_TX_SIZE   ;space for the Tx Buffer
siobTxBuffer:   defs __IO_SIO_TX_SIZE   ;space for the Tx Buffer

PUBLIC  sioaRxBuffer
PUBLIC  siobRxBuffer

ALIGN   __IO_SIO_RX_SIZE                ;ALIGN to __IO_SIO_RX_SIZE byte boundary
                                        ;when finally locating

sioaRxBuffer:   defs __IO_SIO_RX_SIZE   ;space for the Rx Buffer
siobRxBuffer:   defs __IO_SIO_RX_SIZE   ;space for the Rx Buffer

;------------------------------------------------------------------------------
; end of bss tables
;------------------------------------------------------------------------------

PUBLIC  _cpm_bios_bss_tail
_cpm_bios_bss_tail:                     ;tail of the cpm bios bss

DEPHASE

