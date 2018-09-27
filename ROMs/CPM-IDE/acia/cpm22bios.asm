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
defc    __COMMON_AREA_PHASE_BIOS    = 0xEE00

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
;*           CP/M to host disk constants             *
;*                                                   *
;*****************************************************

DEFC    hstalb  =    4096       ;host number of drive allocation blocks
DEFC    hstsiz  =    512        ;host disk sector size
DEFC    hstspt  =    32         ;host disk sectors/trk
DEFC    hstblk  =    hstsiz/128 ;CP/M sects/host buff (4)

DEFC    cpmbls  =    4096       ;CP/M allocation block size BLS
DEFC    cpmdir  =    512        ;CP/M number of directory blocks (each of 32 Bytes)
DEFC    cpmspt  =    hstspt * hstblk    ;CP/M sectors/track (128 = 32 * 512 / 128)

DEFC    secmsk  =    hstblk-1   ;sector mask

;
;*****************************************************
;*                                                   *
;*         BDOS constants on entry to write          *
;*                                                   *
;*****************************************************

DEFC    wrall   =    0          ;write to allocated
DEFC    wrdir   =    1          ;write to directory
DEFC    wrual   =    2          ;write to unallocated

;==============================================================================
;
;           cbios for CP/M 2.2 alteration
;

PUBLIC  _rodata_cpm_bios_head
_rodata_cpm_bios_head:          ;origin of the cpm bios in rodata

PHASE   __COMMON_AREA_PHASE_BIOS

PUBLIC  _cpm_bios_head
_cpm_bios_head:                 ;origin of the cpm bios

;
;    jump vector for individual subroutines
;
PUBLIC    cboot     ;cold start
PUBLIC    wboot     ;warm start
PUBLIC    const     ;console status
PUBLIC    conin     ;console character in
PUBLIC    conout    ;console character out
PUBLIC    list      ;list character out
PUBLIC    punch     ;punch character out
PUBLIC    reader    ;reader character out
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

;    individual subroutines to perform each function

EXTERN    pboot     ;location of preamble code to load CCP/BDOS
PUBLIC    qboot     ;arrival from preamble code

PUBLIC _cpm_boot

_cpm_boot:

cboot:
    di                      ;Page 0 will be blank, after toggling ROM
                            ;so leave interrupts off, until later

    ld      sp,bios_stack   ;temporary stack

    ld      a,$01                   ;A = $01 RAM
    out     (__IO_PROM_TOGGLE),a    ;latch ROM OUT

                            ;Set up Page 0

    ld      a,$C9           ;C9 is a ret instruction for:
    ld      ($0008),a       ;rst 08
    ld      ($0010),a       ;rst 10
    ld      ($0018),a       ;rst 18
    ld      ($0020),a       ;rst 20
    ld      ($0028),a       ;rst 28
    ld      ($0030),a       ;rst 30

    ld      a,$C3           ;C3 is a jmp instruction
    ld      ($0038),a       ;for jmp to _acia_interrupt
    ld      hl,_acia_interrupt
    ld      ($0039),hl      ;enable acia interrupt at rst 38

    xor     a               ;zero in the accum
    ld      (_cpm_cdisk),a  ;select disk zero

    ld      a,$01
    ld      (_cpm_iobyte),a ;set cpm iobyte to CRT default ($01)

    ld      hl,$AA55        ;enable the canary, to show CP/M bios alive
    ld      (_cpm_bios_canary),hl
    jr      rboot

wboot:                              ;from a normal restart
    ld      sp,bios_stack           ;temporary stack
    xor     a                       ;A = $00 ROM
    out     (__IO_PROM_TOGGLE),a    ;latch ROM IN
    jp      pboot                   ;load the CCP/BDOS in preamble

qboot:                              ;arrive from preamble
    ld      a,$01                   ;A = $01 RAM
    out     (__IO_PROM_TOGGLE),a    ;latch ROM OUT

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
    ld      d,h
    ld      e,l
    inc     de
    ld      bc,0x20-1
    ldir                    ;clear default FCB

    di
    call    _acia_reset     ;flush the serial port
    ei

    ld      a,(_cpm_cdisk)  ;get current disk number
    cp      _cpm_disks      ;see if valid disk number
    jr      C,diskchk       ;disk number valid, check existence via valid LBA

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
    out     (__IO_PROM_TOGGLE),a    ;latch ROM IN
    ret                             ;ret directly back to ROM monitor,
                                    ;or back to preamble then ROM monitor

;=============================================================================
; Console I/O routines
;=============================================================================

const:      ;console status, return 0ffh if character ready, 00h if not
    ld      a,(_cpm_iobyte)
    and     00001011b       ;mask off console and high bit of reader
    cp      00001010b       ;redirected to acia
    jr      Z,const1
    cp      00000010b       ;redirected to acia
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
   call     _acia0_getc     ;check whether any characters are in CRT Rx0 buffer
   jr       NC,conin0       ;if Rx buffer is empty
;  and      $7F             ;strip parity bit - support 8 bit XMODEM
   ret

conin1:
   call     _acia1_getc     ;check whether any characters are in TTY Rx1 buffer
   jr       NC,conin1       ;if Rx buffer is empty
;  and      $7F             ;strip parity bit - support 8 bit XMODEM
   ret

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
    cp      00000010b
    jr      Z,list          ;"BAT:" redirect
    cp      00000001b
    jp      NZ,_acia1_putc
    jp      _acia0_putc

list:
    ld      l,c             ;Store character
    ld      a,(_cpm_iobyte)
    and     11000000b
    cp      01000000b
    jp      Z,_acia0_putc
    cp      00000000b
    jp      Z,_acia1_putc
    ret

punch:
    ld      l,c             ;Store character
    ld      a,(_cpm_iobyte)
    and     00110000b
    cp      00010000b
    jp      Z,_acia0_putc
    cp      00000000b
    jp      Z,_acia1_putc
    ret

listst:     ;return list status
    ld      a,$FF           ;Return list status of 0xFF (ready).
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

settrk:     ;set track passed from BDOS in register BC.
    ld      (sektrk),bc
    ret

setsec:     ;set sector passed from BDOS given by register C
    ld      a,c
    ld      (seksec),a
    ret

sectran:    ;translate passed from BDOS sector number BC
    ld      h,b
    ld      l,c
    ret

setdma:     ;set dma address given by registers BC
    ld      (dmaadr),bc     ;save the address
    ret

seldsk:    ;select disk given by register c
    ld      a,c
    cp      _cpm_disks      ;must be between 0 and 3
    jr      C,chgdsk        ;if invalid drive will result in BDOS error
    
 seldskreset:
    xor     a               ;reset default disk back to 0 (A:)
    ld      (_cpm_cdisk),a
    ld      (sekdsk),a      ;and set the seeked disk
    ld      hl,$0000        ;return error code in HL
    ret

chgdsk:
    call    getLBAbase      ;get the LBA base address for disk
    ld      a,(hl)          ;check that the LBA is non-Zero
    inc     hl
    or      a,(hl)
    inc     hl
    or      a,(hl)
    inc     hl
    or      a,(hl)
    jr      Z,seldskreset   ;invalid disk LBA, so load default disk

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

;
;*****************************************************
;*                                                   *
;*      The READ entry point takes the place of      *
;*      the previous BIOS defintion for READ.        *
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
    ld      (unacnt),a		;unacnt = 0
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
;*      the previous BIOS defintion for WRITE.       *
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
    ld      hl,(sektrk)
    ld      (unatrk),hl     ;unatrk = sectrk
    ld      a,(seksec)
    ld      (unasec),a      ;unasec = seksec

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
    ld      hl,unatrk
    call    sektrkcmp       ;sektrk = unatrk?
    jr      NZ,alloc        ;skip if not

;           tracks are the same
    ld      a,(seksec)      ;same sector?
    ld      hl,unasec
    cp      (hl)            ;seksec = unasec?
    jr      NZ,alloc        ;skip if not

;           match, move to next sector for future ref
    inc     (hl)            ;unasec = unasec+1
    ld      a,(hl)          ;end of track?
    cp      cpmspt          ;count CP/M sectors
    jr      C,noovf         ;skip if no overflow

;           overflow to next track
    ld      (hl),0          ;unasec = 0
    ld      hl,(unatrk)
    inc     hl
    ld      (unatrk),hl     ;unatrk = unatrk+1

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
    ld      a,(seksec)      ;compute host sector
                            ;assuming 4 CP/M sectors per host sector
    srl     a               ;shift right
    srl     a               ;shift right
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
    ld      hl,hsttrk
    call    sektrkcmp       ;sektrk = hsttrk?
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
    ld      hl,(sektrk)
    ld      (hsttrk),hl
    ld      a,(sekhst)
    ld      (hstsec),a
    ld      a,(rsflag)      ;need to read?
    or      a
    call    NZ,readhst      ;yes, if 1
    xor     a               ;0 to accum
    ld      (hstwrt),a      ;no pending write

match:
;           copy data to or from buffer
    ld      a,(seksec)      ;mask buffer number
    and     secmsk          ;least significant bits, shifted off in sekhst calculation
    ld      h,0             ;double count    
    ld      l,a             ;ready to shift

    xor     a               ;shift left 7, for 128 bytes x seksec LSBs
    srl     h
    rr      l
    rra
    ld      h,l
    ld      l,a

;           HL has relative host buffer address
    ld      de,hstbuf
    add     hl,de           ;HL = host address
    ex      de,hl           ;now in DE
    ld      hl,(dmaadr)     ;get/put CP/M data
    ld      bc,128          ;length of move
    ex      de,hl           ;source in HL, destination in DE
    ld      a,(readop)      ;which way?
    or      a
    jr      NZ,rwmove       ;skip if read

;           write operation, mark and switch direction
    ld      a,1
    ld      (hstwrt),a      ;hstwrt = 1
    ex      de,hl           ;source/dest swap

rwmove:
    ldir

;           data has been moved to/from host buffer
    ld      a,(wrtype)      ;write type
    and     wrdir           ;to directory?
    ld      a,(erflag)      ;in case of errors
    ret     Z               ;no further processing

;        clear host buffer for directory write
    or      a               ;errors?
    ret     NZ              ;skip if so
    xor     a               ;0 to accum
    ld      (hstwrt),a      ;buffer written
    call    writehst
    ld      a,(erflag)
    ret

;
;*****************************************************
;*                                                   *
;*    Utility subroutine for 16-bit compare          *
;*                                                   *
;*****************************************************

sektrkcmp:
;           HL = unatrk or hsttrk, compare with sektrk
    ex      de,hl
    ld      hl,sektrk
    ld      a,(de)          ;low byte compare
    cp      (hl)            ;same?
    ret     NZ              ;return if not
;           low bytes equal, test high 1s
    inc     de
    inc     hl
    ld      a,(de)
    cp      (hl)            ;sets flags
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
    ;hstdsk = host disk #,
    ;hsttrk = host track #, maximum 2048 tracks = 11 bits
    ;hstsec = host sect #. 32 sectors per track = 5 bits
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
    ;hstdsk = host disk #,
    ;hsttrk = host track #, maximum 2048 tracks = 11 bits
    ;hstsec = host sect #. 32 sectors per track = 5 bits
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
; Since hstsec is 32 sectors per track, we need to use 5 bits for hstsec.
; Also hsttrk can be any number of bits, but since we never have more than 32MB
; of data then 11 bits is a sensible maximum.
;
; This also matches nicely with the calculation, where a 16 bit addition of the
; translation can be added to the base LBA to get the sector.
;

setLBAaddr:
    ld      a,(hstdsk)      ;get disk number (0,1,2,3)
    call    getLBAbase      ;get the LBA base address
    ex      de,hl           ;DE contains address of active disk (file) LBA LSB

    ld      a,(hstsec)      ;prepare the hstsec (5 bits, 32 sectors per track)
    add     a,a             ;shift hstsec left three bits to remove irrelevant MSBs
    add     a,a
    add     a,a

    ld      hl,(hsttrk)     ;get both bytes of the hsttrk (maximum 11 bits)

    srl     h               ;shift HL&A registers (24bits) down three bits
    rr      l               ;to get the required 16 bits of CPM LBA
    rra                     ;to add to the file base LBA 28 bits
    srl     h
    rr      l
    rra
    srl     h
    rr      l
    rra

    ld      h,l             ;move LBA offset back to the 16 (11 + 5) bit pair
    ld      l,a
               
    ex      de,hl           ;HL contains address of active disk (file) base LBA LSB
                            ;DE contains the hsttrk:hstsec result

    ld      a,(hl)          ;get disk LBA LSB
    add     a,e             ;add hsttrk:hstsec LSB
    ld      e,a             ;write LBA LSB, put it in E

    inc     hl
    ld      a,(hl)          ;get disk LBA 1SB
    adc     a,d             ;add hsttrk:hstsec 1SB, with carry
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

PUBLIC _acia_interrupt
PUBLIC _acia_init
PUBLIC _acia_reset
PUBLIC _acia_getc
PUBLIC _acia_peekc
PUBLIC _acia_putc
PUBLIC _acia_pollc

PUBLIC _acia0_interrupt
PUBLIC _acia0_init
PUBLIC _acia0_reset
PUBLIC _acia0_getc
PUBLIC _acia0_peekc
PUBLIC _acia0_putc
PUBLIC _acia0_pollc

PUBLIC _acia1_interrupt
PUBLIC _acia1_init
PUBLIC _acia1_reset
PUBLIC _acia1_getc
PUBLIC _acia1_peekc
PUBLIC _acia1_putc
PUBLIC _acia1_pollc

_acia_interrupt:
    push af
    push hl

; start doing the Rx stuff

    in a,(__IO_ACIA_STATUS_REGISTER)    ; get the status of the ACIA
    and __IO_ACIA_SR_RDRF       ; check whether a byte has been received
    jr Z,tx_check               ; if not, go check for bytes to transmit 

    in a,(__IO_ACIA_DATA_REGISTER)    ; Get the received byte from the ACIA 
    ld l,a                      ; Move Rx byte to l

    ld a,(aciaRxCount)          ; Get the number of bytes in the Rx buffer
    cp __IO_ACIA_RX_SIZE - 1    ; check whether there is space in the buffer
    jr NC,tx_check              ; buffer full, check if we can send something

    ld a,l                      ; get Rx byte from l
    ld hl,aciaRxCount
    inc (hl)                    ; atomically increment Rx buffer count
    ld hl,(aciaRxIn)            ; get the pointer to where we poke
    ld (hl),a                   ; write the Rx byte to the aciaRxIn address

    inc l                       ; move the Rx pointer low byte along, 0xFF rollover
    ld (aciaRxIn),hl            ; write where the next byte should be poked

; now start doing the Tx stuff

tx_check:
    in a,(__IO_ACIA_STATUS_REGISTER)    ; get the status of the ACIA
    and __IO_ACIA_SR_TDRE       ; check whether a byte can be transmitted
    jr Z,tx_rts_check           ; if not, go check for the receive RTS selection

    ld a,(aciaTxCount)          ; get the number of bytes in the Tx buffer
    or a                        ; check whether it is zero
    jr Z,tx_tei_clear           ; if the count is zero, then disable the Tx Interrupt

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
    and ~__IO_ACIA_CR_TEI_MASK  ; mask out the Tx interrupt bits
    or __IO_ACIA_CR_TDI_RTS0    ; mask out (disable) the Tx Interrupt, keep RTS low
    ld (aciaControl),a          ; write the ACIA control byte back
    out (__IO_ACIA_CONTROL_REGISTER),a  ; Set the ACIA CTRL register

tx_rts_check:
    ld a,(aciaRxCount)          ; get the current Rx count    	
    cp __IO_ACIA_RX_FULLISH     ; compare the count with the preferred full size
    jr C,tx_end                 ; leave the RTS low, and end

    ld a,(aciaControl)          ; get the ACIA control echo byte
    and ~__IO_ACIA_CR_TEI_MASK  ; mask out the Tx interrupt bits
    or __IO_ACIA_CR_TDI_RTS1    ; Set RTS high, and disable Tx Interrupt
    ld (aciaControl),a          ; write the ACIA control echo byte back
    out (__IO_ACIA_CONTROL_REGISTER),a  ; Set the ACIA CTRL register

tx_end:
    pop hl
    pop af
    ei
    reti

_acia_init:
    di
    ; initialise the ACIA
    ld a,__IO_ACIA_CR_RESET     ; Master Reset the ACIA
    out (__IO_ACIA_CONTROL_REGISTER),a

    ld a,__IO_ACIA_CR_REI|__IO_ACIA_CR_TDI_RTS0|__IO_ACIA_CR_8N1|__IO_ACIA_CR_CLK_DIV_64
                                ; load the default ACIA configuration
                                ; 8n1 at 115200 baud
                                ; receive interrupt enabled
                                ; transmit interrupt disabled
    ld (aciaControl),a          ; write the ACIA control byte echo
    out (__IO_ACIA_CONTROL_REGISTER),a    ; output to the ACIA control

    call _acia_reset            ; reset empties the Tx & Rx buffers
    im 1                        ; interrupt mode 1
    ei
    ret

_acia_flush_Rx_di:
    push af
    push hl
    di
    call _acia_flush_Rx
    ei
    pop hl
    pop af
    ret

_acia_flush_Tx_di:
    push af
    push hl
    di
    call _acia_flush_Tx
    ei
    pop hl
    pop af
    ret

_acia_flush_Rx:
    xor a
    ld (aciaRxCount),a          ; reset the Rx counter (set 0)  		
    ld hl,aciaRxBuffer          ; load Rx buffer pointer home
    ld (aciaRxIn),hl
    ld (aciaRxOut),hl
    ret

_acia_flush_Tx:
    xor a
    ld (aciaTxCount),a          ; reset the Tx counter (set 0)
    ld hl,aciaTxBuffer          ; load Tx buffer pointer home
    ld (aciaTxIn),hl
    ld (aciaTxOut),hl
    ret

_acia_reset:
    ; interrupts should be disabled
    call _acia_flush_Rx
    call _acia_flush_Tx
    ret

_acia_getc:
    ; exit     : l = char received
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, hl

    ld a,(aciaRxCount)          ; get the number of bytes in the Rx buffer
    ld l,a                      ; and put it in hl
    or a                        ; see if there are zero bytes available
    ret Z                       ; if the count is zero, then return

    cp __IO_ACIA_RX_EMPTYISH    ; compare the count with the preferred empty size
    jr NC,getc_clean_up_rx      ; if the buffer not emptyish, don't change the RTS

    di                          ; critical section begin
    ld a,(aciaControl)          ; get the ACIA control echo byte
    and ~__IO_ACIA_CR_TEI_MASK  ; mask out the Tx interrupt bits
    or __IO_ACIA_CR_TDI_RTS0    ; set RTS low.
    ld (aciaControl),a	        ; write the ACIA control echo byte back
    ei                          ; critical section end
    out (__IO_ACIA_CONTROL_REGISTER),a    ; set the ACIA CTRL register

getc_clean_up_rx:
    ld hl,aciaRxCount
    di      
    dec (hl)                    ; atomically decrement Rx count
    ld hl,(aciaRxOut)           ; get the pointer to place where we pop the Rx byte
    ei
    ld a,(hl)                   ; get the Rx byte

    inc l                       ; move the Rx pointer low byte along
    ld (aciaRxOut),hl           ; write where the next byte should be popped
    ld l,a                      ; and put it in hl
    scf                         ; indicate char received
    ret

_acia_peekc:
    ld a,(aciaRxCount)          ; get the number of bytes in the Rx buffer
    ld l,a                      ; and put it in hl
    or a                        ; see if there are zero bytes available
    ret Z                       ; if the count is zero, then return

    ld hl,(aciaRxOut)           ; get the pointer to place where we pop the Rx byte
    ld a,(hl)                   ; get the Rx byte
    ld l,a                      ; and put it in hl
    ret

_acia_pollc:
    ; exit     : l = number of characters in Rx buffer
    ;            carry reset if Rx buffer is empty
    ;
    ; modifies : af, hl

    ld a,(aciaRxCount)	        ; load the Rx bytes in buffer
    ld l,a	                    ; load result
    or a                        ; check whether there are non-zero count
    ret Z                       ; return if zero count
    
    scf                         ; set carry to indicate char received
    ret

_acia_putc:
    ; enter    : l = char to output
    ; exit     : l = 1 if Tx buffer is full
    ;            carry reset
    ; modifies : af, hl

    ld a,(aciaTxCount)          ; Get the number of bytes in the Tx buffer
    or a                        ; check whether the buffer is empty
    jr NZ,putc_buffer_tx        ; buffer not empty, so abandon immediate Tx
    
    in a,(__IO_ACIA_STATUS_REGISTER)    ; get the status of the ACIA
    and __IO_ACIA_SR_TDRE       ; check whether a byte can be transmitted
    jr Z,putc_buffer_tx         ; if not, so abandon immediate Tx
    
    ld a,l                      ; Retrieve Tx character
    out (__IO_ACIA_DATA_REGISTER),a ; immediately output the Tx byte to the ACIA
    ret                         ; and just complete

putc_buffer_tx:
    ld a,(aciaTxCount)          ; Get the number of bytes in the Tx buffer
    cp __IO_ACIA_TX_SIZE-1      ; check whether there is space in the buffer
    jr NC,putc_buffer_tx        ; buffer full, so keep trying

    ld a,l                      ; Tx byte
    ld hl,aciaTxCount
    di
    inc (hl)                    ; atomic increment of Tx count
    ld hl,(aciaTxIn)            ; get the pointer to where we poke
    ei
    ld (hl),a                   ; write the Tx byte to the aciaTxIn

    inc l                       ; move the Tx pointer, just low byte along
    ld a,__IO_ACIA_TX_SIZE-1    ; load the buffer size, (n^2)-1
    and l                       ; range check
    or aciaTxBuffer&0xFF        ; locate base
    ld l,a                      ; return the low byte to l
    ld (aciaTxIn),hl            ; write where the next byte should be poked

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

    defc _acia0_interrupt = _acia_interrupt
    defc _acia0_init = _acia_init
    defc _acia0_reset = _acia_reset

    defc _acia0_getc = _acia_getc
    defc _acia0_peekc = _acia_peekc
    defc _acia0_putc = _acia_putc
    defc _acia0_pollc = _acia_pollc

    defc _acia1_interrupt = _acia_interrupt
    defc _acia1_init = _acia_init
    defc _acia1_reset = _acia_reset

    defc _acia1_getc = _acia_getc
    defc _acia1_peekc = _acia_peekc
    defc _acia1_putc = _acia_putc
    defc _acia1_pollc = _acia_pollc

;------------------------------------------------------------------------------
; start of common area driver - 8255 functions
;------------------------------------------------------------------------------

PUBLIC ide_read_byte,  ide_write_byte
PUBLIC ide_read_block, ide_write_block

    ;Do a read bus cycle to the drive, using the 8255.
    ;input A = ide register address
    ;output A = lower byte read from IDE drive

ide_read_byte:
    push bc
    push de
    ld d,a                  ;copy address to D
    ld bc,__IO_PIO_IDE_CTL
    out (c),a               ;drive address onto control lines
    or __IO_IDE_RD_LINE
    out (c),a               ;and assert read pin
    ld bc,__IO_PIO_IDE_LSB
    in e,(c)                ;read the lower byte
    ld bc,__IO_PIO_IDE_CTL
    out (c),d               ;deassert read pin
    xor a
    out (c),a               ;deassert all control pins
    ld a,e
    pop de
    pop bc
    ret

    ;Read a block of 512 bytes (one sector) from the drive
    ;16 bit data register and store it in memory at (HL++)
ide_read_block:
    push bc
    push de
    ld bc,__IO_PIO_IDE_CTL
    ld d,__IO_IDE_DATA
    out (c),d               ;drive address onto control lines
    ld e,$0                 ;keep iterative count in e

IF (__IO_PIO_IDE_CTL = __IO_PIO_IDE_MSB+1) & (__IO_PIO_IDE_MSB = __IO_PIO_IDE_LSB+1)
ide_rdblk2:
    ld d,__IO_IDE_DATA|__IO_IDE_RD_LINE
    out (c),d               ;and assert read pin
    ld bc,__IO_PIO_IDE_LSB  ;drive lower lines with lsb
    ini                     ;read the lower byte (HL++)
    inc c                   ;drive upper lines with msb
    ini                     ;read the upper byte (HL++)
    inc c                   ;drive control port
    ld d,__IO_IDE_DATA
    out (c),d               ;deassert read pin
    dec e                   ;keep iterative count in e
    jr NZ,ide_rdblk2

ELSE
ide_rdblk2:
    ld d,__IO_IDE_DATA|__IO_IDE_RD_LINE
    out (c),d               ;and assert read pin
    ld bc,__IO_PIO_IDE_LSB  ;drive lower lines with lsb
    ini                     ;read the lower byte (HL++)
    ld bc,__IO_PIO_IDE_MSB  ;drive upper lines with msb
    ini                     ;read the upper byte (HL++)
    ld bc,__IO_PIO_IDE_CTL
    ld d,__IO_IDE_DATA
    out (c),d               ;deassert read pin
    dec e                   ;keep iterative count in e
    jr NZ,ide_rdblk2

ENDIF
;   ld bc,__IO_PIO_IDE_CTL  ;remembering what's in bc
    ld d,$0
    out (c),d               ;deassert all control pins
    pop de
    pop bc
    ret

    ;Do a write bus cycle to the drive, via the 8255
    ;input A = ide register address
    ;input E = lsb to write to IDE drive
ide_write_byte:
    push bc
    push de
    ld d,a                  ;copy address to D
    ld bc,__IO_PIO_IDE_CONFIG
    ld a,__IO_PIO_IDE_WR
    out (c),a               ;config 8255 chip, write mode
    ld bc,__IO_PIO_IDE_CTL
    ld a,d
    out (c),a               ;drive address onto control lines
    or __IO_IDE_WR_LINE
    out (c),a               ;and assert write pin
    ld bc,__IO_PIO_IDE_LSB
    out (c),e               ;drive lower lines with lsb
    ld bc,__IO_PIO_IDE_CTL
    out (c),d               ;deassert write pin
    xor a
    out (c),a               ;deassert all control pins
    ld bc,__IO_PIO_IDE_CONFIG
    ld a,__IO_PIO_IDE_RD
    out (c),a               ;config 8255 chip, read mode
    pop de
    pop bc
    ret

    ;Write a block of 512 bytes (one sector) from (HL++) to
    ;the drive 16 bit data register
ide_write_block:
    push bc
    push de
    ld bc,__IO_PIO_IDE_CONFIG
    ld d,__IO_PIO_IDE_WR
    out (c),d               ;config 8255 chip, write mode
    ld bc,__IO_PIO_IDE_CTL
    ld d,__IO_IDE_DATA
    out (c),d               ;drive address onto control lines
    ld e,$0                 ;keep iterative count in e

IF (__IO_PIO_IDE_CTL = __IO_PIO_IDE_MSB+1) & (__IO_PIO_IDE_MSB = __IO_PIO_IDE_LSB+1)
ide_wrblk2: 
    ld d,__IO_IDE_DATA|__IO_IDE_WR_LINE
    out (c),d               ;and assert write pin
    ld bc,__IO_PIO_IDE_LSB  ;drive lower lines with lsb
    outi                    ;write the lower byte (HL++)
    inc c                   ;drive upper lines with msb
    outi                    ;write the upper byte (HL++)
    inc c                   ;drive control port
    ld d,__IO_IDE_DATA
    out (c),d               ;deassert write pin
    dec e                   ;keep iterative count in e
    jr NZ,ide_wrblk2

ELSE
ide_wrblk2: 
    ld d,__IO_IDE_DATA|__IO_IDE_WR_LINE
    out (c),d               ;and assert write pin
    ld bc,__IO_PIO_IDE_LSB  ;drive lower lines with lsb
    outi                    ;write the lower byte (HL++)
    ld bc,__IO_PIO_IDE_MSB  ;drive upper lines with msb
    outi                    ;write the upper byte (HL++)
    ld bc,__IO_PIO_IDE_CTL
    ld d,__IO_IDE_DATA
    out (c),d               ;deassert write pin
    dec e                   ;keep iterative count in e
    jr NZ,ide_wrblk2

ENDIF
;   ld bc,__IO_PIO_IDE_CTL  ;remembering what's in bc
    ld d,$0
    out (c),d               ;deassert all control pins
    ld bc,__IO_PIO_IDE_CONFIG
    ld d,__IO_PIO_IDE_RD
    out (c),d               ;config 8255 chip, read mode
    pop de
    pop bc
    ret

;------------------------------------------------------------------------------
; start of common area 1 driver - IDE functions
;------------------------------------------------------------------------------

PUBLIC ide_setup_lba
PUBLIC ide_wait_ready, ide_wait_drq, ide_test_error

; set up the drive LBA registers
; LBA is contained in BCDE registers

ide_setup_lba:
    push hl
    ld a,__IO_IDE_LBA0
    call ide_write_byte     ;set LBA0 0:7
    ld e,d
    ld a,__IO_IDE_LBA1
    call ide_write_byte     ;set LBA1 8:15
    ld e,c
    ld a,__IO_IDE_LBA2
    call ide_write_byte     ;set LBA2 16:23
    ld a,b
    and 00001111b           ;lowest 4 bits used only
    or  11100000b           ;to enable LBA address mode, Master only
;   ld hl,_ideStatus        ;set bit 4 accordingly
;   bit 0,(hl)
;   jr Z,ide_setup_master
;   or $10                  ;if it is a slave, set that bit
ide_setup_master:
    ld e,a
    ld a,__IO_IDE_LBA3
    call ide_write_byte     ;set LBA3 24:27 + bits 5:7=111
    pop hl
    ret

; How to poll (waiting for the drive to be ready to transfer data):
; Read the Regular Status port until bit 7 (BSY, value = 0x80) clears,
; and bit 3 (DRQ, value = 0x08) sets.
; Or until bit 0 (ERR, value = 0x01) or bit 5 (DFE, value = 0x20) sets.
; If neither error bit is set, the device is ready right then.

; Carry is set on wait success.

ide_wait_ready:
    push af
ide_wait_ready2:
    ld a,__IO_IDE_ALT_STATUS    ;get IDE alt status register
    call ide_read_byte
    push af
    and 00100001b           ;test for ERR or DFE
    jr nz,ide_wait_error
    pop af
    and 11000000b           ;mask off BuSY and RDY bits
    xor 01000000b           ;wait for RDY to be set and BuSY to be clear
    jr nz,ide_wait_ready2
    pop af
    scf                     ;set carry flag on success
    ret

ide_wait_error:
    pop af
    or a                    ;clear carry flag on failure
    ret

; Wait for the drive to be ready to transfer data.
; Returns the drive's status in A

; Carry is set on wait success.

ide_wait_drq:
    push af
ide_wait_drq2:
    ld a,__IO_IDE_ALT_STATUS    ;get IDE alt status register
    call ide_read_byte
    push af
    and 00100001b           ;test for ERR or DFE
    jr nz,ide_wait_error
    pop af
    and 10001000b           ;mask off BuSY and DRQ bits
    xor 00001000b           ;wait for DRQ to be set and BuSY to be clear
    jr nz,ide_wait_drq2
    pop af
    scf                     ;set carry flag on success
    ret

; load the IDE status register and if there is an error noted,
; then load the IDE error register to provide details.

; Carry is set on no error.

ide_test_error:
    push af
    ld a,__IO_IDE_ALT_STATUS    ;select status register
    call ide_read_byte      ;get status in A
    bit 0,a                 ;test ERR bit
    jr Z,ide_test_success
    bit 5,a
    jr NZ,ide_test2         ;test write error bit

    ld a,__IO_IDE_ERROR     ;select error register
    call ide_read_byte      ;get error register in a
ide_test2:
    inc sp                  ;pop old af
    inc sp
    or a                    ;make carry flag zero = error!
    ret                     ;if a = 0, ide write busy timed out

ide_test_success:
    pop af
    scf                     ;set carry flag on success
    ret

;------------------------------------------------------------------------------
; Routines that talk with the IDE drive, these should not be called by
; the main program.

; read a sector
; LBA specified by the 4 bytes in BCDE
; the address of the buffer to fill is in HL
; HL is left incremented by 512 bytes

; return carry on success, no carry for an error

PUBLIC ide_read_sector

ide_read_sector:
    push af
    push bc
    push de
    call ide_wait_ready     ;make sure drive is ready
    jr NC,_disk_x_sector_error
    call ide_setup_lba      ;tell it which sector we want in BCDE
    ld e,$1
    ld a,__IO_IDE_SEC_CNT
    call ide_write_byte     ;set sector count to 1
    ld e,__IDE_CMD_READ
    ld a,__IO_IDE_COMMAND
    call ide_write_byte     ;ask the drive to read it
    call ide_wait_ready     ;make sure drive is ready to proceed
    jr NC,_disk_x_sector_error
    call ide_wait_drq       ;wait until it's got the data
    jr NC,_disk_x_sector_error
    call ide_read_block     ;grab the data into (HL++)

_ide_x_sector_ok:
    pop de
    pop bc
    pop af
    scf                     ;carry = 1 on return = operation ok
    ret

_disk_x_sector_error:
    pop de
    pop bc
    pop af
    jr ide_test_error       ;carry = 0 on return = operation failed

;------------------------------------------------------------------------------
; Routines that talk with the IDE drive, these should not be called by
; the main program.

; write a sector
; specified by the 4 bytes in BCDE
; the address of the origin buffer is in HL
; HL is left incremented by 512 bytes

; return carry on success, no carry for an error

PUBLIC ide_write_sector

ide_write_sector:
    push af
    push bc
    push de
    call ide_wait_ready     ;make sure drive is ready
    jr NC,_disk_x_sector_error
    call ide_setup_lba      ;tell it which sector we want in BCDE
    ld e,$1
    ld a,__IO_IDE_SEC_CNT
    call ide_write_byte     ;set sector count to 1
    ld e,__IDE_CMD_WRITE
    ld a,__IO_IDE_COMMAND
    call ide_write_byte     ;instruct drive to write a sector
    call ide_wait_ready     ;make sure drive is ready to proceed
    jr NC,_disk_x_sector_error
    call ide_wait_drq       ;wait until it wants the data
    jr NC,_disk_x_sector_error
    call ide_write_block    ;send the data to the drive from (HL++)
    call ide_wait_ready
    jr NC,_disk_x_sector_error
;   ld e,__IDE_CMD_CACHE_FLUSH
;   ld a,__IO_IDE_COMMAND
;   call ide_write_byte     ;tell drive to flush its hardware cache
;   call ide_wait_ready     ;wait until the write is complete
;   jr NC,_disk_x_sector_error
    jr _ide_x_sector_ok     ;carry = 1 on return = operation ok

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
;    disk Parameter header for disk 00
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv00
;    disk parameter header for disk 01
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv01
;    disk parameter header for disk 02
    defw    0000h, 0000h
    defw    0000h, 0000h
    defw    dirbf, dpblk
    defw    0000h, alv02
;    disk parameter header for disk 03
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
    defb    $F0         ;AL0 - 1 bit set per directory block (ALLOC0)
    defb    $00         ;AL1 - 1 bit set per directory block (ALLOC0)
    defw    0           ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk) (ALLOC1)
    defw    0           ;OFF - Reserved tracks offset

;------------------------------------------------------------------------------
; end of fixed tables
;------------------------------------------------------------------------------

PUBLIC  _cpm_bios_rodata_tail
_cpm_bios_rodata_tail:        ;tail of the cpm bios read only data

PUBLIC  _cpm_bios_bss_bridge
_cpm_bios_bss_bridge:

DEPHASE

SECTION bss_driver

;------------------------------------------------------------------------------
; start of bss tables
;------------------------------------------------------------------------------

PHASE _cpm_bios_bss_bridge

PUBLIC  _cpm_bios_bss_head
_cpm_bios_bss_head:         ;head of the cpm bios bss

PUBLIC  aciaRxCount, aciaRxIn, aciaRxOut
PUBLIC  aciaTxCount, aciaTxIn, aciaTxOut
PUBLIC  aciaControl

aciaRxCount:    defb 0                  ; Space for Rx Buffer Management 
aciaRxIn:       defw aciaRxBuffer       ; non-zero item in bss since it's initialized anyway
aciaRxOut:      defw aciaRxBuffer       ; non-zero item in bss since it's initialized anyway

aciaTxCount:    defb 0                  ; Space for Tx Buffer Management
aciaTxIn:       defw aciaTxBuffer       ; non-zero item in bss since it's initialized anyway
aciaTxOut:      defw aciaTxBuffer       ; non-zero item in bss since it's initialized anyway

aciaControl:    defb 0                  ; Local control echo of ACIA

PUBLIC _cpm_bios_canary
_cpm_bios_canary:   defw 0              ; if it matches $AA55, bios has been loaded, and CP/M is active

PUBLIC  _cpm_dsk0_base
_cpm_dsk0_base:     defs 16             ; base 32 bit LBA of host file for disk 0 (A:) &
                                        ; 3 additional LBA for host files (B:, C:, D:)
;
; IDE Status byte
; set bit 0 : User selects master (0) or slave (1) drive
; bit 1 : Flag 0 = master not previously accessed 
; bit 2 : Flag 0 = slave not previously accessed

;PUBLIC  _ideStatus
;_ideStatus: defb   0

;    scratch ram area for bios use
;

sekdsk:     defs    1       ;seek disk number
sektrk:     defs    2       ;seek track number
seksec:     defs    1       ;seek sector number

hstdsk:     defs    1       ;host disk number
hsttrk:     defs    2       ;host track number
hstsec:     defs    1       ;host sector number

sekhst:     defs    1       ;seek shr secshf
hstact:     defs    1       ;host active flag
hstwrt:     defs    1       ;host written flag

unacnt:     defs    1       ;unalloc rec cnt
unadsk:     defs    1       ;last unalloc disk
unatrk:     defs    2       ;last unalloc track
unasec:     defs    1       ;last unalloc sector

erflag:     defs    1       ;error reporting
rsflag:     defs    1       ;read sector flag
readop:     defs    1       ;1 if read operation
wrtype:     defs    1       ;write operation type
dmaadr:     defs    2       ;last direct memory address

alv00:      defs    ((hstalb-1)/8)+1    ;allocation vector 0
alv01:      defs    ((hstalb-1)/8)+1    ;allocation vector 1
alv02:      defs    ((hstalb-1)/8)+1    ;allocation vector 2
alv03:      defs    ((hstalb-1)/8)+1    ;allocation vector 3

dirbf:      defs    128     ;scratch directory area
hstbuf:     defs    hstsiz  ;buffer for host disk sector
bios_stack:                 ;temporary bios stack origin

;------------------------------------------------------------------------------
; start of bss tables - aligned data
;------------------------------------------------------------------------------

PUBLIC  aciaTxBuffer

ALIGN       __IO_ACIA_TX_SIZE           ;ALIGN to __IO_ACIA_TX_SIZE byte boundary
                                        ;when finally locating

aciaTxBuffer:   defs __IO_ACIA_TX_SIZE  ;Space for the Tx Buffer

PUBLIC  aciaRxBuffer

ALIGN       __IO_ACIA_RX_SIZE           ;ALIGN to __IO_ACIA_RX_SIZE byte boundary
                                        ;when finally locating

aciaRxBuffer:   defs __IO_ACIA_RX_SIZE  ;Space for the Rx Buffer

;------------------------------------------------------------------------------
; end of bss tables
;------------------------------------------------------------------------------

PUBLIC  _cpm_bios_bss_tail
_cpm_bios_bss_tail:         ;tail of the cpm bios bss

DEPHASE

