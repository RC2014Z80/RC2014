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
defc    __COMMON_AREA_PHASE_BIOS    = 0xF100

;------------------------------------------------------------------------------
; start of definitions
;------------------------------------------------------------------------------

EXTERN  _cpm_ccp_head               ;base of ccp
EXTERN  _cpm_bdos_head              ;base of bdos

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

    ld      a,$C3                   ;C3 is a jmp instruction for:
    ld      ($0038),a               ;jmp _acia_interrupt
    ld      hl,_acia_interrupt
    ld      ($0039),hl              ;enable acia interrupt at rst 38

    xor     a                       ;zero in the accum
    ld      (_cpm_cdisk),a          ;select disk zero

    ld      a,$01
    ld      (_cpm_iobyte),a         ;set cpm iobyte to CRT: default ($01)

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
    ld      hl,_cpm_bdos_head   ;bdos entry point
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

    call    _acia_reset     ;reset and empty the ACIA Tx & Rx buffers
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
    and     00001011b       ;mask off console and high bit of reader
    cp      00001010b       ;redirected to acia1
    jr      Z,const1
    cp      00000010b       ;redirected to acia1
    jr      Z,const1

    and     00000011b       ;remove the reader from the mask - only console bits then remain
    cp      00000001b
    jr      NZ,const1

const0:
    call    _acia0_pollc    ;check whether any characters are in CRT Rx0 buffer
    jr      NC,dataEmpty
dataReady:
    ld      a,$FF
    ret

const1:
    call    _acia1_pollc    ;check whether any characters are in TTY Rx1 buffer
    jr      C,dataReady
dataEmpty:
    xor     a
    ret

conin:    ;console character into register a
    ld      a,(_cpm_iobyte)
    and     00000011b
    cp      00000010b
    jr      Z,reader        ;"BAT:" redirect
    cp      00000001b
    jr      NZ,conin1

conin0:
   jp       _acia0_getc     ;check whether any characters are in CRT Rx0 buffer
;  jr       NC,conin0       ;if Rx buffer is empty
;  and      $7F             ;don't strip parity bit - support 8 bit XMODEM
;  ret

conin1:
   jp       _acia1_getc     ;check whether any characters are in TTY Rx1 buffer
;  jr       NC,conin1       ;if Rx buffer is empty
;  and      $7F             ;don't strip parity bit - support 8 bit XMODEM
;  ret

reader:
    ld      a,(_cpm_iobyte)
    and     00001100b
    cp      00000100b
    jr      Z,conin0
    cp      00000000b
    jr      Z,conin1
    ld      a,$1A           ;CTRL-Z if not acia
    ret

conout:    ;console character output from register c
    ld      l,c             ;Store character
    ld      a,(_cpm_iobyte)
    and     00000011b
    cp      00000010b       ;------1xb LPT: or UL1:
    jr      Z,list          ;"BAT:" redirect
    rrca
    jp      C,_acia0_putc   ;------01b CRT:
    jp      _acia1_putc     ;------00b TTY:

list:
    ld      l,c             ;store character
    ld      a,(_cpm_iobyte) ;1x------b LPT: or UL1:
    rlca
    rlca
    jp      C,_acia0_putc   ;01------b CRT:
    jp      _acia1_putc     ;00------b TTY:

punch:
    ld      l,c             ;store character
    ld      a,(_cpm_iobyte)
    and     00110000b
    cp      00010000b       ;--x1----b PTP: or UL1:
    jp      Z,_acia0_putc
    cp      00000000b
    jp      Z,_acia1_putc
    ret

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
    xor     a               ;reset default disk back to 0 (A:)
    ld      (_cpm_cdisk),a
    ld      (sekdsk),a      ;and set the seeked disk
    ld      hl,$0000        ;return error code in HL
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
    and     wrual           ;write unallocated?
    jr      Z,chkuna        ;check for unalloc

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
; start of common area driver - acia functions
;------------------------------------------------------------------------------

PUBLIC acia_interrupt

PUBLIC _acia_reset
PUBLIC _acia_getc
PUBLIC _acia_putc
PUBLIC _acia_pollc

PUBLIC _acia0_reset
PUBLIC _acia0_getc
PUBLIC _acia0_putc
PUBLIC _acia0_pollc

PUBLIC _acia1_reset
PUBLIC _acia1_getc
PUBLIC _acia1_putc
PUBLIC _acia1_pollc

acia_interrupt:
_acia_interrupt:
    push af
    push hl

    in a,(__IO_ACIA_STATUS_REGISTER)    ; get the status of the ACIA
    rrca                        ; check whether a byte has been received, via __IO_ACIA_SR_RDRF
    jr NC,tx_check              ; if not, go check for bytes to transmit

rx_get:
    in a,(__IO_ACIA_DATA_REGISTER)  ; get the received byte from the ACIA
    ld hl,(aciaRxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Rx byte to the aciaRxIn address

    inc l                       ; move the Rx pointer low byte along, 0xFF rollover
    ld (aciaRxIn),hl            ; write where the next byte should be poked

    ld hl,aciaRxCount
    inc (hl)                    ; atomically increment Rx buffer count

    ld a,(aciaRxCount)          ; get the current Rx count
    cp __IO_ACIA_RX_FULLISH     ; compare the count with the preferred full size
    jp NZ,rx_check              ; leave the RTS low, and check for Rx/Tx possibility

    ld a,(aciaControl)          ; get the ACIA control echo byte
    and ~__IO_ACIA_CR_TEI_MASK  ; mask out the Tx interrupt bits
    or __IO_ACIA_CR_TDI_RTS1    ; set RTS high, and disable Tx Interrupt
    ld (aciaControl),a          ; write the ACIA control echo byte back
    out (__IO_ACIA_CONTROL_REGISTER),a  ; set the ACIA CTRL register

rx_check:
    in a,(__IO_ACIA_STATUS_REGISTER)    ; get the status of the ACIA
    rrca                        ; check whether a byte has been received, via __IO_ACIA_SR_RDRF
    jr C,rx_get                 ; another byte received, go get it

tx_check:
    rrca                        ; check whether a byte can be transmitted, via __IO_ACIA_SR_TDRE
    jr NC,tx_end                ; if not, we're done for now

    ld a,(aciaTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether it is zero
    jp Z,tx_tei_clear           ; if the count is zero, then disable the Tx Interrupt

    ld hl,(aciaTxOut)           ; get the pointer to place where we pop the Tx byte
    ld a,(hl)                   ; get the Tx byte
    out (__IO_ACIA_DATA_REGISTER),a     ; output the Tx byte to the ACIA

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_ACIA_TX_SIZE-1    ; load the buffer size, (n^2)-1
    and l                       ; range check
    or aciaTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (aciaTxOut),hl           ; write where the next byte should be popped

    ld hl,aciaTxCount
    dec (hl)                    ; atomically decrement current Tx count

    jr NZ,tx_end                ; if we've more Tx bytes to send, we're done for now

tx_tei_clear:
    ld a,(aciaControl)          ; get the ACIA control echo byte
    and ~__IO_ACIA_CR_TEI_RTS0  ; mask out (disable) the Tx Interrupt, keep RTS low
    ld (aciaControl),a          ; write the ACIA control byte back
    out (__IO_ACIA_CONTROL_REGISTER),a  ; set the ACIA CTRL register

tx_end:
    pop hl
    pop af
    ei
    ret

_acia_reset:                    ; interrupts should be disabled
    xor a

    ld (aciaRxCount),a          ; reset the Rx counter (set 0)
    ld hl,aciaRxBuffer          ; load Rx buffer pointer home
    ld (aciaRxIn),hl
    ld (aciaRxOut),hl

    ld (aciaTxCount),a          ; reset the Tx counter (set 0)
    ld hl,aciaTxBuffer          ; load Tx buffer pointer home
    ld (aciaTxIn),hl
    ld (aciaTxOut),hl
    ret

_acia_getc:
    ; exit     : a, l = char received, wait for available character
    ;
    ; modifies : af, hl

    ld a,(aciaRxCount)          ; get the number of bytes in the Rx buffer
    or a                        ; see if there are zero bytes available
    jp Z,_acia_getc             ; if the count is zero, then wait

    cp __IO_ACIA_RX_EMPTYISH    ; compare the count with the preferred empty size
    jp NZ,getc_clean_up_rx      ; if the buffer not emptyish, don't change the RTS

    di                          ; critical section begin
    ld a,(aciaControl)          ; get the ACIA control echo byte
    and ~__IO_ACIA_CR_TEI_MASK  ; mask out the Tx interrupt bits
    or __IO_ACIA_CR_TDI_RTS0    ; set RTS low.
    ld (aciaControl),a          ; write the ACIA control echo byte back
    ei                          ; critical section end
    out (__IO_ACIA_CONTROL_REGISTER),a    ; set the ACIA CTRL register

getc_clean_up_rx:
    ld hl,(aciaRxOut)           ; get the pointer to place where we pop the Rx byte
    ld a,(hl)                   ; get the Rx byte

    inc l                       ; move the Rx pointer low byte along
    ld (aciaRxOut),hl           ; write where the next byte should be popped

    ld hl,aciaRxCount
    dec (hl)                    ; atomically decrement Rx count

    ld l,a                      ; and put char in hl
    ret

_acia_pollc:
    ; exit     : l = number of characters in Rx buffer
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, hl

    ld a,(aciaRxCount)          ; load the Rx bytes in buffer
    ld l,a                      ; load result
    or a                        ; check whether there are non-zero count
    ret Z                       ; return if zero count

    scf                         ; set carry to indicate char received
    ret

_acia_putc:
    ; enter    : l = char to output
    ;
    ; modifies : af, hl

    ld a,(aciaTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether the buffer is empty
    jr NZ,putc_buffer_tx        ; buffer not empty, so abandon immediate Tx

    in a,(__IO_ACIA_STATUS_REGISTER)    ; get the status of the ACIA
    and __IO_ACIA_SR_TDRE       ; check whether a byte can be transmitted
    jr Z,putc_buffer_tx         ; if not, so abandon immediate Tx

    ld a,l                      ; retrieve Tx character
    out (__IO_ACIA_DATA_REGISTER),a ; immediately output the Tx byte to the ACIA
    ret                         ; and just complete

putc_buffer_tx:
    ld a,(aciaTxCount)          ; get the number of bytes in the Tx buffer
    cp __IO_ACIA_TX_SIZE-1      ; check whether there is space in the buffer
    jr NC,putc_buffer_tx        ; buffer full, so keep trying

    ld a,l                      ; retrieve Tx byte

    ld hl,(aciaTxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Tx byte to the aciaTxIn

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_ACIA_TX_SIZE-1    ; load the buffer size, (n^2)-1
    and l                       ; range check
    or aciaTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (aciaTxIn),hl            ; write where the next byte should be poked

    ld hl,aciaTxCount
    inc (hl)                    ; atomic increment of Tx count

    ld a,(aciaControl)          ; get the ACIA control echo byte
    and __IO_ACIA_CR_TEI_RTS0   ; test whether ACIA interrupt is set
    ret NZ                      ; if so then just return

    di                          ; critical section begin
    ld a,(aciaControl)          ; get the ACIA control echo byte
    and ~__IO_ACIA_CR_TEI_MASK  ; mask out the Tx interrupt bits
    or __IO_ACIA_CR_TEI_RTS0    ; set RTS low. if the TEI was not set, it will work again
    ld (aciaControl),a          ; write the ACIA control echo byte back
    out (__IO_ACIA_CONTROL_REGISTER),a  ; set the ACIA CTRL register
    ei                          ; critical section end
    ret

    defc _acia0_reset = _acia_reset
    defc _acia0_getc = _acia_getc
    defc _acia0_putc = _acia_putc
    defc _acia0_pollc = _acia_pollc

    defc _acia1_reset = _acia_reset
    defc _acia1_getc = _acia_getc
    defc _acia1_putc = _acia_putc
    defc _acia1_pollc = _acia_pollc


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

ALIGN $F700                 ;align for bss head  (fixed to access _cpm_dsk0_base)

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

PUBLIC  aciaRxCount, aciaRxIn, aciaRxOut
PUBLIC  aciaTxCount, aciaTxIn, aciaTxOut
PUBLIC  aciaControl

aciaRxCount:    defb 0                  ;space for Rx Buffer Management
aciaRxIn:       defw aciaRxBuffer       ;non-zero item in bss since it's initialized anyway
aciaRxOut:      defw aciaRxBuffer       ;non-zero item in bss since it's initialized anyway

aciaTxCount:    defb 0                  ;space for Tx Buffer Management
aciaTxIn:       defw aciaTxBuffer       ;non-zero item in bss since it's initialized anyway
aciaTxOut:      defw aciaTxBuffer       ;non-zero item in bss since it's initialized anyway

aciaControl:    defb 0                  ;local control echo of ACIA

;------------------------------------------------------------------------------
; start of bss tables - aligned uninitialised data
;------------------------------------------------------------------------------

ALIGN   $10000 - $20 - __IO_ACIA_TX_SIZE - __IO_ACIA_RX_SIZE

shadow_copy_addr:   defs $20            ;reserve space for relocation of shadow_copy

PUBLIC  aciaTxBuffer

ALIGN   __IO_ACIA_TX_SIZE               ;ALIGN to __IO_ACIA_TX_SIZE byte boundary
                                        ;when finally locating

aciaTxBuffer:   defs __IO_ACIA_TX_SIZE  ;space for the Tx Buffer

PUBLIC  aciaRxBuffer

ALIGN   __IO_ACIA_RX_SIZE               ;ALIGN to __IO_ACIA_RX_SIZE byte boundary
                                        ;when finally locating

aciaRxBuffer:   defs __IO_ACIA_RX_SIZE  ;space for the Rx Buffer

;------------------------------------------------------------------------------
; end of bss tables
;------------------------------------------------------------------------------

PUBLIC  _cpm_bios_bss_tail
_cpm_bios_bss_tail:                     ;tail of the cpm bios bss

DEPHASE

