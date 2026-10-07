;
; Mini-FAT16/32 for CP/M-IDE (Z80).
;
; Same PUBLIC API, BSS names, and function contracts as fatfs_85.asm /
; fatfs.h. ROM-resident, no PHASE. Shell buffers live in fat_bss.asm
; (RAM). The CP/M deblock buffer stays in the BIOS.
;
; C: PUBLIC _names. Pointers are __z88dk_fastcall (HL).
; DWORD cluster/LBA is BCDE (E LSB); _fat_next/_fat_alloc/_fat_free/
; _fat_clst2sect/_fat_dir_open load that little-endian dword from (HL).
; Success: L=0 and carry set. Fail: L=1 and carry clear.
; sccz80 treats a char return as an int, so these exits also clear H.
;
; FatFs R0.16 map (z88dk-libraries/ff/source/ff.c):
;   check_fs / find_volume / mount_volume
;   move_window / sync_window
;   clst2sect, get_fat, put_fat, create_chain, remove_chain
;   dir_sdi, dir_next, dir_find, dir_create
;
; In scope: FAT16 and FAT32, 512-byte sectors, 8.3 SFN only.
; Out of scope: FAT12, exFAT, LFN, GPT, directory stretch.
; FAT32 FSInfo is read at mount (free count and the next-free hint).
; It is not rewritten; the hint lives in fat_last_clst for this session.
;
; FatFs cases we honour:
;   cluster < 2 invalid; n_fatent = nclst + 2
;   FAT16 EOC $FFF8..$FFFF; FAT32 EOC $0FFFFFF8..F (put_fat keeps bits 28-31)
;   nclst == $FFF5 stays FAT16 (ChaN MAX_FAT16; spec 1.03 would use FAT32)
;   FAT16 root count is a non-zero multiple of 16
;   FAT32 requires FSVer == 0 and RootEntCnt == 0 (those sectors are not in sysect)
;   csize is 2^n and at most 64 sectors (32 KB)
;   DIR_Name[0] == $05 compares as $E5; dir_create stores $E5 as $05
;   FAT16 root of 2048 entries is the whole 16-bit offset (65536 bytes)
;   dirent 0x00 = end of directory; 0xE5 = deleted (reusable)
;   A long-name entry is attribute $0F, which includes the volume bit.
;   The volume-bit test therefore skips both labels and long names.
;   dir_next stops on 16-bit ofs wrap (2048 dirents) for long directories
;   FAT32 root is BPB_RootClus32; cluster 0 means that root (ff dir_sdi)
;   FAT16 root is static dirbase LBA
;   SFD (VBR at LBA 0) then four MBR primary partitions
;   1 or 2 FATs; csize power of 2; BytsPerSec == 512
;
; FatFs cases we skip (on purpose):
;   JumpBoot $EB/$E9/$E8; GPT protective MBR; logical partitions
;   dir_next stretch (create_chain + dir_clear) when a subdir hits EOC
;   dir_zap is E5 only; the caller frees the chain with _fat_free
;
; How to read this file. Each operation is one label, top to bottom:
; mount, clst2sect, get_fat, put_fat, create_chain, remove_chain,
; dir_sdi, dir_next, dir_find, dir_create. The C entry points
; (_fat_alloc and the rest) only load or store the caller's
; little-endian dword and call that operation. They are not a
; second copy of the work.
; fat_ld32, fat_st32, and fat_move_window stay shared. Every cluster
; and every LBA is a dword in BCDE with E as the low byte, and every
; FAT or directory byte is read from the one sector window. Inlining
; those two jobs would paste the FAT16/FAT32 cases into every caller.
; fat_ld32 leaves HL on the last byte, so a caller that reads the
; next dword has to inc hl first.
;

SECTION code_lib

EXTERN  asm_disk_initialize
EXTERN  ide_read_sector
EXTERN  ide_write_sector

EXTERN  _cpm_fat_vol
EXTERN  fatwin
EXTERN  fat_winsect
EXTERN  fat_wflag
EXTERN  fat_cwd
EXTERN  fat_found_sclust
EXTERN  fat_found_size
EXTERN  dir_ptr
EXTERN  dir_sclust
EXTERN  dir_clust               ;cluster of the current directory sector
EXTERN  dir_sect
EXTERN  dir_ofs
EXTERN  fat_work
EXTERN  pack_sv
EXTERN  fat_last_clst       ;last cluster this session allocated
EXTERN  clst_cache_sclust
EXTERN  clst_cache_ci
EXTERN  clst_cache_clst

PUBLIC  clst2sect           ;cluster -> first sector LBA
PUBLIC  fat_sync_window     ;write fatwin if dirty; mirror FAT#2
PUBLIC  _fat_sync           ;C: fat_sync_window
PUBLIC  _fat_dirty          ;C: mark fatwin dirty
PUBLIC  fat_move_window     ;flush dirty, read LBA into fatwin
PUBLIC  fat_mount           ;mount FAT16/32 from LBA 0 or MBR
PUBLIC  _fat_mount          ;C: fat_mount
PUBLIC  get_fat             ;next cluster from FAT entry
PUBLIC  put_fat             ;store next cluster in FAT
PUBLIC  clst_from_off       ;cluster containing file offset
PUBLIC  create_chain        ;allocate and link a new cluster
PUBLIC  remove_chain        ;free a cluster chain
PUBLIC  dir_sdi             ;seek directory to byte offset
PUBLIC  dir_next            ;next 32-byte dirent (no stretch)
PUBLIC  dir_find            ;find 8.3 in current directory
PUBLIC  _dir_find           ;C: dir_find
PUBLIC  dir_create          ;alloc/register 8.3 (no stretch)
PUBLIC  _dir_create         ;C: dir_create
PUBLIC  dir_zap             ;mark dirent deleted (E5)
PUBLIC  _dir_zap            ;C: dir_zap
PUBLIC  _fat_dir_open       ;C: open dir from sclust dword
PUBLIC  _fat_dir_read       ;C: copy 32-byte dirent; 0x00 = EOT
PUBLIC  _fat_next           ;C: get_fat of dword at (HL)
PUBLIC  _fat_alloc          ;C: create_chain of dword at (HL)
PUBLIC  _fat_free           ;C: remove_chain of dword at (HL)
PUBLIC  _fat_clst2sect      ;C: clst2sect of dword at (HL)
PUBLIC  _fat_getfree        ;C: count free clusters into dword at (HL)
PUBLIC  _fat_clusters       ;C: bytes at (HL) -> cluster count, or 0


DEFC    FS_FAT16        = 2
DEFC    FS_FAT32        = 3
DEFC    MAX_FAT12       = $0FF5
DEFC    MAX_FAT16       = $FFF5
DEFC    BPB_BytsPerSec  = 11
DEFC    BPB_SecPerClus  = 13
DEFC    BPB_RsvdSecCnt  = 14
DEFC    BPB_NumFATs     = 16
DEFC    BPB_RootEntCnt  = 17
DEFC    BPB_TotSec16    = 19
DEFC    BPB_FATSz16     = 22
DEFC    BPB_TotSec32    = 32
DEFC    BPB_FATSz32     = 36
DEFC    BPB_FSVer       = 42
DEFC    BPB_RootClus32  = 44
DEFC    BPB_FSInfo      = 48
DEFC    BS_55AA         = 510
DEFC    MBR_PTE         = 446
DEFC    SZ_PTE          = 16
DEFC    PTE_StLba       = 8
DEFC    DIR_Attr        = 11
DEFC    DIR_ClusHI      = 20
DEFC    DIR_ClusLO      = 26
DEFC    DIR_FileSize    = 28
DEFC    AM_VOL          = $08


; ff.c clst2sect: if (clst < 2 || clst >= n_fatent) fail;
; clst -= 2; return database + csize * clst. csize is 2^n.
; IN:  BCDE = cluster (B MSB … E LSB)
; OUT: C: BCDE = LBA of first sector of cluster
;      NC: fail
; clobbers AF, HL
clst2sect:
    ld      hl,_cpm_fat_vol+4       ;n_fatent, little-endian
    ld      a,e
    sub     (hl+)
    ld      a,d
    sbc     a,(hl+)
    ld      a,c
    sbc     a,(hl+)
    ld      a,b
    sbc     a,(hl)
    ret     NC                      ;cluster >= n_fatent
    ld      a,e
    sub     2
    ld      e,a
    ld      a,d
    sbc     a,0
    ld      d,a
    ld      a,c
    sbc     a,0
    ld      c,a
    ld      a,b
    sbc     a,0
    ld      b,a
    jr      C,clst2sect_ov          ;cluster < 2
    ld      a,(_cpm_fat_vol+1)      ;csize is 2^n
clst2sect_mul:
    srl     a
    jr      Z,clst2sect_base
    sla     e
    rl      d
    rl      c
    rl      b
    jr      C,clst2sect_ov          ;csize*(clst-2) wrapped
    jr      clst2sect_mul
clst2sect_base:
    ld      hl,_cpm_fat_vol+16      ;database
    ld      a,(hl+)
    add     a,e
    ld      e,a
    ld      a,(hl+)
    adc     a,d
    ld      d,a
    ld      a,(hl+)
    adc     a,c
    ld      c,a
    ld      a,(hl)
    adc     a,b
    ld      b,a
    jr      C,clst2sect_ov          ;database + off wrapped
    scf
    ret

clst2sect_ov:
    or      a
    ret

; ff.c sync_window, fail closed. Writes FAT #1 first. wflag stays set
; until every copy succeeds (ff clears it before FAT #2 and ignores a
; failed mirror). n_fats >= 2 and winsect in FAT #1 (unsigned
; winsect - fatbase < fatsz): write winsect + fatsz. Directory windows
; are not mirrored. Mount only allows 1 or 2 FATs.
; OUT: C: OK; NC: write failed
; clobbers AF, BC, DE, HL (ide_write_sector contract)
_fat_dirty:
    ld      a,1
    ld      (fat_wflag),a
    ret

_fat_sync:
fat_sync_window:
    ld      a,(fat_wflag)
    or      a
    jr      Z,fat_sync_ok           ;nothing dirty
    ld      de,(fat_winsect)        ;E LSB, D
    ld      bc,(fat_winsect+2)      ;C, B MSB
    ld      hl,fatwin               ;high RAM FAT window
    call    ide_write_sector        ;C: OK; HL += 512
    ld      hl,1
    ret     NC                      ;leave flag dirty
    ld      a,(_cpm_fat_vol+24)     ;n_fats
    cp      2
    jr      C,fat_sync_clear        ;n_fats < 2
    ld      hl,_cpm_fat_vol+8       ;winsect - fatbase
    ld      a,(fat_winsect)
    sub     (hl+)
    ld      e,a
    ld      a,(fat_winsect+1)
    sbc     a,(hl+)
    ld      d,a
    ld      a,(fat_winsect+2)
    sbc     a,(hl+)
    ld      c,a
    ld      a,(fat_winsect+3)
    sbc     a,(hl)
    jr      C,fat_sync_clear        ;winsect < fatbase
    ld      b,a                     ;BCDE = winsect - fatbase
    ld      hl,_cpm_fat_vol+20      ;compare to fatsz
    ld      a,e
    sub     (hl+)
    ld      a,d
    sbc     a,(hl+)
    ld      a,c
    sbc     a,(hl+)
    ld      a,b
    sbc     a,(hl)
    jr      NC,fat_sync_clear       ;not in FAT #1
    ld      hl,(fat_winsect)
    ld      de,(_cpm_fat_vol+20)
    add     hl,de
    ex      de,hl
    ld      hl,(fat_winsect+2)
    ld      bc,(_cpm_fat_vol+22)
    adc     hl,bc
    ld      bc,hl
    ld      hl,fatwin
    call    ide_write_sector
    ld      hl,1
    ret     NC                      ;FAT#2 failed: FAT #1 is on disk, retry mirror
fat_sync_clear:
    xor     a
    ld      (fat_wflag),a
fat_sync_ok:
    ld      hl,0
    scf
    ret


; ff.c move_window: flush if dirty, then read LBA into fatwin.
; IN:  BCDE = LBA (B MSB … E LSB)
; OUT: C: fatwin holds that sector
;      NC: read failed
; clobbers AF, HL; BCDE may be clobbered
fat_move_window:
    ld      hl,(fat_winsect)
    ld      a,l
    cp      e
    jr      NZ,fat_move_do
    ld      a,h
    cp      d
    jr      NZ,fat_move_do
    ld      hl,(fat_winsect+2)
    ld      a,l
    cp      c
    jr      NZ,fat_move_do
    ld      a,h
    cp      b
    jr      NZ,fat_move_do
    scf                             ;already in window
    ret
fat_move_do:
    push    bc
    push    de                      ;save LBA (ide_* and sync clobber)
    call    fat_sync_window
    pop     de
    pop     bc
    ret     NC
    push    bc
    push    de
    ld      hl,fatwin               ;high RAM FAT window
    call    ide_read_sector
    pop     de
    pop     bc
    ret     NC
    ld      (fat_winsect),de
    ld      (fat_winsect+2),bc
    xor     a
    ld      (fat_wflag),a
    scf
    ret

;------------------------------------------------------------------------------
; fat_check_vbr — ff.c check_fs (FAT/FAT32 only)
; Require 55AA, 512-byte sectors, csize 2^n and <= 64, reserved != 0, 1 or 2 FATs.
; No JumpBoot $EB/$E9/$E8 (ff accepts early MS-DOS VBRs without 55AA).
; C = looks like a FAT16/32 VBR (type decided later from nclst).
;------------------------------------------------------------------------------
fat_check_vbr:
    ld      a,(fatwin+BS_55AA)
    cp      $55
    jr      NZ,fat_check_fail
    ld      a,(fatwin+BS_55AA+1)
    cp      $AA
    jr      NZ,fat_check_fail
    ld      a,(fatwin+BPB_BytsPerSec)
    or      a
    jr      NZ,fat_check_fail
    ld      a,(fatwin+BPB_BytsPerSec+1)
    cp      2                       ;512
    jr      NZ,fat_check_fail
    ld      a,(fatwin+BPB_SecPerClus)
    or      a
    jr      Z,fat_check_fail
    ld      b,a
    dec     a
    and     b
    jr      NZ,fat_check_fail       ;not 2^n
    ld      a,b
    cp      65                      ;at most 64 sectors (32 KB)
    jr      NC,fat_check_fail
    ld      a,(fatwin+BPB_RsvdSecCnt)
    ld      hl,fatwin+BPB_RsvdSecCnt+1
    or      (hl)
    jr      Z,fat_check_fail
    ld      a,(fatwin+BPB_NumFATs)
    cp      1
    jr      Z,fat_check_ok
    cp      2
    jr      NZ,fat_check_fail
fat_check_ok:
    scf
    ret
fat_check_fail:
    or      a
    ret

; Wait for ready, then SET FEATURES 8-bit. Cold CF is BSY after power-on;
; SET FEATURES issued while BSY is ignored (warm reset then works).
fat_ide_delay:
    xor     a
fat_ide_d0:
    ex      (sp),hl
    ex      (sp),hl
    dec     a
    jr      NZ,fat_ide_d0
    ret

; 8 tries of disk_initialize with delay. C: ready. NC: still busy.
fat_ide_bringup:
    ld      b,8
fat_ide_br1:
    push    bc
    ld      l,0
    call    asm_disk_initialize
    pop     bc
    ret     C
    call    fat_ide_delay
    djnz    fat_ide_br1
    or      a
    ret

;------------------------------------------------------------------------------
; fat_mount — ff.c find_volume + mount_volume
; LBA 0 as SFD VBR; else four MBR primary PTEs (no GPT, no extended).
; nclst from (tsect - reserved - fats - rootsecs) / csize.
; FAT12 (nclst <= $0FF5) fails; FAT16 <= $FFF5; else FAT32.
; nclst == $FFF5 stays FAT16 (ChaN; spec 1.03 would call it FAT32).
; FAT32 dirbase = BPB_RootClus32 (cluster); FAT16 dirbase = root LBA.
; OUT: C OK
;------------------------------------------------------------------------------
_fat_mount:
fat_mount:
    ld      b,8
fat_mount_cold:
    push    bc
    call    fat_ide_bringup
    jr      NC,fat_mount_cold1
    xor     a
    ld      (fat_wflag),a
    ld      (_cpm_fat_vol+25),a     ;free_valid
    ld      (fat_last_clst),a
    ld      (fat_last_clst+1),a
    ld      (fat_last_clst+2),a
    ld      (fat_last_clst+3),a
    ld      hl,$FFFF
    ld      (fat_winsect),hl
    ld      (fat_winsect+2),hl
    ld      bc,0
    ld      de,0
    call    fat_move_window
    jr      NC,fat_mount_cold1
    call    fat_check_vbr
    pop     bc
    jp      C,fat_parse_bpb
    ld      a,(fatwin+BS_55AA)
    cp      $55
    jr      NZ,fat_mount_cold2
    ld      a,(fatwin+BS_55AA+1)
    cp      $AA
    jr      NZ,fat_mount_cold2
    jr      fat_mount_mbr
fat_mount_cold1:
    pop     bc
fat_mount_cold2:
    djnz    fat_mount_cold
    ld      hl,1
    or      a
    ret

fat_mount_mbr:
    ld      hl,fatwin+MBR_PTE+PTE_StLba
    ld      de,fat_work
    ld      b,4
fat_mount_savept:
    push    bc
    ld      bc,4
    ldir
    ld      bc,SZ_PTE-4
    add     hl,bc
    pop     bc
    djnz    fat_mount_savept
    ld      hl,fat_work
    ld      b,4
fat_mount_trypt:
    push    bc
    push    hl
    ld      e,(hl+)
    ld      d,(hl+)
    ld      c,(hl+)
    ld      b,(hl)
    ld      a,b
    or      c
    or      d
    or      e
    jr      Z,fat_mount_nextpt
    call    fat_move_window
    jr      NC,fat_mount_nextpt
    call    fat_check_vbr
    jr      C,fat_mount_gotpt
fat_mount_nextpt:
    pop     hl
    ld      bc,4
    add     hl,bc
    pop     bc
    djnz    fat_mount_trypt
    ld      hl,1
    or      a
    ret
fat_mount_gotpt:
    pop     hl
    pop     bc
fat_parse_bpb:
    ld      a,(fatwin+BPB_SecPerClus)
    ld      (_cpm_fat_vol+1),a      ;csize
    ld      a,(fatwin+BPB_NumFATs)
    ld      (_cpm_fat_vol+24),a     ;n_fats
    ld      hl,(fatwin+BPB_RootEntCnt)
    ld      (_cpm_fat_vol+2),hl     ;n_rootent
    ld      de,(fatwin+BPB_FATSz16)
    ld      a,d
    or      e
    jr      NZ,fat_mount_fsz
    ld      de,(fatwin+BPB_FATSz32)
    ld      bc,(fatwin+BPB_FATSz32+2)
    jr      fat_mount_fsz32
fat_mount_fsz:
    ld      bc,0
fat_mount_fsz32:
    ld      (_cpm_fat_vol+20),de    ;fatsz
    ld      (_cpm_fat_vol+22),bc
    ld      hl,(fatwin+BPB_TotSec16)
    ld      a,h
    or      l
    jr      NZ,fat_mount_tsz16
    ld      hl,(fatwin+BPB_TotSec32)
    ld      de,(fatwin+BPB_TotSec32+2)
    jr      fat_mount_tsz
fat_mount_tsz16:
    ld      de,0
fat_mount_tsz:
    ld      (fat_work+4),hl          ;tsect
    ld      (fat_work+6),de
    ld      hl,(_cpm_fat_vol+20)    ;fatsz
    ld      de,(_cpm_fat_vol+22)
    ld      a,(_cpm_fat_vol+24)
    cp      2
    jr      NZ,fat_mount_fatarea
    add     hl,hl
    rl      de                      ;fatsz * n_fats
    jp      C,fat_mount_fail        ;CVE-2026-6682 analog
fat_mount_fatarea:
    ld      bc,(fatwin+BPB_RsvdSecCnt)
    add     hl,bc
    jr      NC,fat_mount_sy1
    inc     de
    ld      a,d
    or      e
    jp      Z,fat_mount_fail
fat_mount_sy1:
    push    hl
    ld      hl,(fatwin+BPB_FATSz16)
    ld      a,h
    or      l
    pop     hl
    jr      Z,fat_mount_r32root     ;FATSz16 == 0
    ld      bc,(_cpm_fat_vol+2)     ;n_rootent
    ld      a,b
    or      c
    jp      Z,fat_mount_fail        ;FAT16 root count is 0
    ld      a,c
    and     $0F
    jp      NZ,fat_mount_fail       ;not a whole number of sectors
    srl     b
    rr      c
    srl     b
    rr      c
    srl     b
    rr      c
    srl     b
    rr      c                       ;root sectors = n_rootent/16
    jr      fat_mount_addroot
fat_mount_r32root:
    push    hl
    ld      hl,(fatwin+BPB_RootEntCnt)
    ld      a,h
    or      l
    jr      NZ,fat_mount_r32bad
    ld      a,(fatwin+BPB_FSVer)
    ld      hl,fatwin+BPB_FSVer+1
    or      (hl)
    jr      NZ,fat_mount_r32bad
    pop     hl
    ld      bc,0                    ;FAT32 has no static root
    jr      fat_mount_addroot
fat_mount_r32bad:
    pop     hl
    jp      fat_mount_fail
fat_mount_addroot:
    add     hl,bc
    jr      NC,fat_mount_sy2
    inc     de
    ld      a,d
    or      e
    jp      Z,fat_mount_fail
fat_mount_sy2:
    ld      (fat_work+8),hl          ;sysect
    ld      (fat_work+10),de
    ld      hl,(fat_work+4)          ;tsect - sysect
    ld      bc,(fat_work+8)
    or      a
    sbc     hl,bc
    ld      (fat_work+12),hl
    ld      hl,(fat_work+6)
    ld      bc,(fat_work+10)
    sbc     hl,bc
    ld      (fat_work+14),hl
    jp      C,fat_mount_fail        ;tsect < sysect
    ld      a,(_cpm_fat_vol+1)      ;csize = 2^n
    ld      b,0
fat_mount_log:
    srl     a
    jr      Z,fat_mount_shr
    inc     b
    jr      fat_mount_log
fat_mount_shr:
    ld      hl,(fat_work+12)
    ld      de,(fat_work+14)
    ld      a,b
    or      a
    jr      Z,fat_mount_ncl
fat_mount_shrl:
    srl     d
    rr      e
    rr      h
    rr      l
    djnz    fat_mount_shrl
fat_mount_ncl:
    ld      (fat_work+12),hl         ;nclst low
    ld      (fat_work+14),de         ;nclst high
    ld      a,h
    or      l
    or      d
    or      e
    jp      Z,fat_mount_fail
    ld      a,d
    or      e
    jr      NZ,fat_mount_fat32
    ld      de,hl                   ;park low; high is 0
    ld      bc,MAX_FAT12+1
    or      a
    sbc     hl,bc
    jp      C,fat_mount_fail        ;FAT12 (ff MAX_FAT12 = $0FF5)
    ld      hl,de
    ld      bc,MAX_FAT16
    or      a
    sbc     hl,bc
    jr      Z,fat_mount_fat16
    jr      NC,fat_mount_fat32
fat_mount_fat16:
    ld      a,FS_FAT16
    jr      fat_mount_type
fat_mount_fat32:
    ld      a,FS_FAT32
fat_mount_type:
    ld      (_cpm_fat_vol),a
    ld      hl,(fat_work+12)
    ld      de,(fat_work+14)
    ld      bc,2
    add     hl,bc
    jr      NC,fat_mount_nfe
    inc     de
    ld      a,d
    or      e
    jp      Z,fat_mount_fail
fat_mount_nfe:
    ld      (_cpm_fat_vol+4),hl     ;n_fatent
    ld      (_cpm_fat_vol+6),de
    ; fatsz must cover n_fatent (Windows/Linux volumes do; undersize
    ; would let get_fat/put_fat index into dir/data).
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,fat_mount_need32
    ld      bc,255                  ;FAT16: (n_fatent+255)>>8
    add     hl,bc
    jr      NC,fat_mount_need16
    inc     de
fat_mount_need16:
    ld      l,h
    ld      h,e
    ld      e,d
    ld      d,0
    jr      fat_mount_needc
fat_mount_need32:
    ld      bc,127                  ;FAT32: (n_fatent+127)>>7
    add     hl,bc
    jr      NC,fat_mount_need32s
    inc     de
fat_mount_need32s:
    ld      b,7
fat_mount_need32l:
    srl     d
    rr      e
    rr      h
    rr      l
    djnz    fat_mount_need32l
fat_mount_needc:
    ld      bc,(_cpm_fat_vol+20)    ;fatsz - needed (C if fatsz < needed)
    ld      a,c
    sub     l
    ld      a,b
    sbc     a,h
    ld      bc,(_cpm_fat_vol+22)
    ld      a,c
    sbc     a,e
    ld      a,b
    sbc     a,d
    jp      C,fat_mount_fail
    ld      hl,(fat_winsect)        ;fatbase = bsect + nrsv
    ld      bc,(fatwin+BPB_RsvdSecCnt)
    add     hl,bc
    ld      (_cpm_fat_vol+8),hl
    ld      hl,(fat_winsect+2)
    ld      bc,0
    adc     hl,bc
    ld      (_cpm_fat_vol+10),hl
    ld      hl,(fat_winsect)        ;database = bsect + sysect
    ld      bc,(fat_work+8)
    add     hl,bc
    ld      (_cpm_fat_vol+16),hl
    ld      hl,(fat_winsect+2)
    ld      bc,(fat_work+10)
    adc     hl,bc
    ld      (_cpm_fat_vol+18),hl
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,fat_mount_r32
    ld      hl,(_cpm_fat_vol+16)    ;dirbase = database - rootsecs
    ld      bc,(_cpm_fat_vol+2)
    srl     b
    rr      c
    srl     b
    rr      c
    srl     b
    rr      c
    srl     b
    rr      c
    or      a
    sbc     hl,bc
    ld      (_cpm_fat_vol+12),hl
    ld      hl,(_cpm_fat_vol+18)
    ld      bc,0
    sbc     hl,bc
    ld      (_cpm_fat_vol+14),hl
    jr      fat_mount_ok
fat_mount_r32:
    ld      hl,(fatwin+BPB_RootClus32)
    ld      a,l
    sub     2
    ld      a,h
    sbc     a,0
    ld      de,(fatwin+BPB_RootClus32+2)
    ld      a,e
    sbc     a,0
    ld      a,d
    sbc     a,0
    jp      C,fat_mount_fail        ;RootClus < 2
    ld      hl,(fatwin+BPB_RootClus32)
    ld      (_cpm_fat_vol+12),hl
    ld      hl,(fatwin+BPB_RootClus32+2)
    ld      (_cpm_fat_vol+14),hl
    xor     a
    ld      (_cpm_fat_vol+2),a
    ld      (_cpm_fat_vol+3),a
fat_mount_ok:
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,fat_mount_cwd32
    xor     a
    ld      (fat_cwd),a
    ld      (fat_cwd+1),a
    ld      (fat_cwd+2),a
    ld      (fat_cwd+3),a
    ld      hl,0
    scf
    ret
fat_mount_cwd32:
    call    fat_seed_fsinfo
    ld      hl,(_cpm_fat_vol+12)    ;FAT32 root cluster
    ld      (fat_cwd),hl
    ld      hl,(_cpm_fat_vol+14)
    ld      (fat_cwd+2),hl
    ld      hl,0
    scf
    ret
fat_mount_fail:
    ld      hl,1
    or      a
    ret

; FAT32 FSInfo (fatgen103 section 5). The VBR is still in fatwin.
; FSI_Nxt_Free is the cluster where the next search should start,
; usually the last cluster a driver allocated. FSI_Free_Count is the
; last known free total. Either field may be $FFFFFFFF (unknown).
; A bad info sector leaves the hint clear and the mount still succeeds.
fat_seed_fsinfo:
    ld      hl,(fatwin+BPB_FSInfo)
    ld      a,h
    or      l
    ret     Z
    inc     hl
    ld      a,h
    or      l
    ret     Z                       ;offset was $FFFF
    dec     hl
    ld      de,(fat_winsect)
    add     hl,de
    ld      de,hl
    ld      hl,(fat_winsect+2)
    ld      bc,0
    adc     hl,bc
    ld      bc,hl
    call    fat_move_window
    ret     NC
    ld      hl,fatwin
    ld      a,(hl+)
    cp      $52
    ret     NZ
    ld      a,(hl+)
    cp      $61
    ret     NZ
    ld      a,(hl+)
    cp      $41
    ret     NZ
    ld      a,(hl)
    cp      $41                     ;FSI_LeadSig 0x41615252
    ret     NZ
    ld      hl,fatwin+484
    ld      a,(hl+)
    cp      $72
    ret     NZ
    ld      a,(hl+)
    cp      $72
    ret     NZ
    ld      a,(hl+)
    cp      $41
    ret     NZ
    ld      a,(hl)
    cp      $61                     ;FSI_StrucSig 0x61417272
    ret     NZ
    ld      a,(fatwin+510)
    cp      $55
    ret     NZ
    ld      a,(fatwin+511)
    cp      $AA
    ret     NZ
    ld      hl,fatwin+492           ;FSI_Nxt_Free
    call    fat_ld32
    ld      a,e
    and     d
    and     c
    and     b
    cp      $FF
    jr      Z,seed_free
    push    bc
    push    de
    ld      a,b
    or      c
    or      d
    jr      NZ,seed_nxt_hi
    ld      a,e
    cp      2
    jr      C,seed_nxt_pop
seed_nxt_hi:
    ld      hl,(_cpm_fat_vol+4)
    ld      a,l
    sub     e
    ld      l,a
    ld      a,h
    sbc     a,d
    ld      h,a
    ld      a,(_cpm_fat_vol+6)
    sbc     a,c
    ld      c,a
    ld      a,(_cpm_fat_vol+7)
    sbc     a,b
    jr      C,seed_nxt_pop          ;hint >= n_fatent
    or      c
    or      h
    or      l
    jr      Z,seed_nxt_pop
    pop     de
    pop     bc
    ld      (fat_last_clst),de
    ld      (fat_last_clst+2),bc
    jr      seed_free
seed_nxt_pop:
    pop     de
    pop     bc
seed_free:
    ld      hl,fatwin+488           ;FSI_Free_Count
    call    fat_ld32
    ld      a,e
    and     d
    and     c
    and     b
    cp      $FF
    ret     Z
    push    bc
    push    de
    ld      hl,(_cpm_fat_vol+4)     ;nclst = n_fatent - 2
    ld      de,(_cpm_fat_vol+6)
    ld      bc,2
    or      a
    sbc     hl,bc
    jr      NC,seed_ncl
    dec     de
seed_ncl:
    ld      (fat_work),hl
    ld      (fat_work+2),de
    pop     de                      ;free count
    pop     bc
    ld      hl,fat_work
    ld      a,(hl+)
    sub     e
    ld      a,(hl+)
    sbc     a,d
    ld      a,(hl+)
    sbc     a,c
    ld      a,(hl)
    sbc     a,b
    ret     C                       ;free > nclst
    ld      (_cpm_fat_vol+28),de
    ld      (_cpm_fat_vol+30),bc
    ld      a,1
    ld      (_cpm_fat_vol+25),a
    ret

;------------------------------------------------------------------------------
; fat_fatent: map cluster BCDE onto fatwin (ff get_fat/put_fat window).
; Byte offset = clst*2 (FAT16) or clst*4 (FAT32); LBA = fatbase + offset/512.
; Rejects cluster < 2 or cluster >= n_fatent. OUT C: HL -> the entry in fatwin.
;------------------------------------------------------------------------------
fat_fatent:
    ld      a,e                     ;reject clst < 2
    sub     2
    ld      a,d
    sbc     a,0
    ld      a,c
    sbc     a,0
    ld      a,b
    sbc     a,0
    ret     C
    ld      hl,_cpm_fat_vol+4       ;clst - n_fatent (BCDE live)
    ld      a,e
    sub     (hl+)
    ld      a,d
    sbc     (hl+)
    ld      a,c
    sbc     (hl+)
    ld      a,b
    sbc     a,(hl)
    ret     NC                      ;clst >= n_fatent
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,fat_fatent32
    ; FAT16: pff/ff WORD array. sect = fatbase + clst/256; off = (BYTE)clst*2
    ld      l,e
    ld      h,0
    add     hl,hl                   ;off = (BYTE)clst * 2  (< 512)
    push    hl
    ld      e,d
    ld      d,c
    ld      c,b
    ld      b,0                     ;BCDE = clst >> 8
    jr      fat_fatent_sec
fat_fatent32:
    ; FAT32: pff DWORD array. sect = fatbase + clst/128; off = (clst%128)*4
    ; (clst%128)*4 is 0..508 — must be 16-bit; add a,a wraps at 64.
    ld      a,e
    and     127
    ld      l,a
    ld      h,0
    add     hl,hl
    add     hl,hl
    push    hl                      ;off 0..508
    ld      a,e
    rla                             ;C = clst bit 7
    ld      e,d
    ld      d,c
    ld      c,b
    ld      b,0                     ;clst >> 8
    rl      e
    rl      d
    rl      c
    rl      b                       ;clst >> 7
fat_fatent_sec:
    ld      hl,_cpm_fat_vol+8       ;+ fatbase
    ld      a,(hl+)
    add     a,e
    ld      e,a
    ld      a,(hl+)
    adc     a,d
    ld      d,a
    ld      a,(hl+)
    adc     a,c
    ld      c,a
    ld      a,(hl)
    adc     a,b
    ld      b,a
    call    fat_move_window
    pop     de                      ;offset in sector (< 512)
    ret     NC
    ld      hl,fatwin
    add     hl,de
    scf
    ret

; ff.c get_fat. FAT16 word; FAT32 dword & $0FFFFFFF.
; EOC is folded to $0FFFFFFF (FAT16 $FFF8..$FFFF; FAT32 >= $0FFFFFF8).
get_fat:
    call    fat_fatent
    ret     NC
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,get_fat32
    ld      e,(hl+)
    ld      d,(hl)
    ld      a,d
    cp      $FF
    jr      NZ,get_fat16ok
    ld      a,e
    cp      $F8                     ;FAT16 EOC $FFF8..$FFFF
    jr      C,get_fat16ok
    ld      de,$FFFF
    ld      bc,$0FFF                ;fold to EOC32 for callers
    scf
    ret
get_fat16ok:
    ld      bc,0
    scf
    ret
get_fat32:
    ld      e,(hl+)
    ld      d,(hl+)
    ld      c,(hl+)
    ld      a,(hl)
    and     $0F
    ld      b,a
    cp      $0F
    jr      NZ,get_fat32ok
    ld      a,c
    inc     a
    jr      NZ,get_fat32ok
    ld      a,d
    inc     a
    jr      NZ,get_fat32ok
    ld      a,e
    cp      $F8
    jr      C,get_fat32ok
    ld      de,$FFFF
    ld      bc,$0FFF
get_fat32ok:
    scf
    ret

; ff.c put_fat. FAT16 stores 16 bits; FAT32 stores 28 bits and keeps
; the on-disk high nibble (bits 28-31).
; IN: BCDE=cluster, HL->DWORD next (LE)
; If free_valid, bump free_clst when a free entry becomes used or
; a used entry becomes free (create_chain / remove_chain).
put_fat:
    push    hl
    call    fat_fatent
    pop     de                      ;DE -> next dword
    ret     NC
    ld      a,(_cpm_fat_vol+25)
    or      a
    jr      Z,put_fat_cold
    push    de
    push    hl
    call    fat_win_is_free
    ld      a,0
    jr      NZ,put_fat_old
    inc     a
put_fat_old:
    pop     hl
    pop     de
    jr      put_fat_adj
put_fat_cold:
    xor     a                       ;dummy old_free; stack always has AF
put_fat_adj:
    push    af                      ;A = 1 if old entry was free
    push    de                      ;src for new-free test
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,put_fat32
    ld      a,(de+)
    ld      (hl+),a
    ld      a,(de)
    ld      (hl),a
put_fat_wrote:
    pop     de
    pop     af
    ld      c,a                     ;old free
    ld      a,(_cpm_fat_vol+25)
    or      a
    jr      Z,put_fat_dirty
    push    bc
    call    fat_src_is_free
    pop     bc
    ld      a,c
    jr      Z,put_fat_new0
    or      a
    jr      Z,put_fat_dirty         ;used -> used
    call    fat_nfree_dec           ;free -> used
    jr      put_fat_dirty
put_fat_new0:
    or      a
    jr      NZ,put_fat_dirty        ;free -> free
    call    fat_nfree_inc           ;used -> free
put_fat_dirty:
    ld      a,1
    ld      (fat_wflag),a
    scf
    ret
put_fat32:
    ld      a,(de+)
    ld      (hl+),a
    ld      a,(de+)
    ld      (hl+),a
    ld      a,(de+)
    ld      (hl+),a
    ld      a,(de)
    and     $0F                     ;keep FAT32 high nibble on disk
    ld      b,a
    ld      a,(hl)
    and     $F0
    or      b
    ld      (hl),a
    jr      put_fat_wrote

; Z if FAT entry at HL is free (ff ld_16==0 / ld_32&0x0FFFFFFF==0).
; Preserves HL. put_fat cache and f_getfree window scan.
fat_win_is_free:
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,fat_win_free32
    ld      a,(hl+)
    or      (hl-)
    ret
fat_win_free32:
    push    bc
    ld      a,(hl+)
    or      (hl+)
    or      (hl+)
    ld      b,a
    ld      a,(hl-)
    and     $0F
    dec     hl
    dec     hl
    or      b
    pop     bc
    ret

; Z if LE dword at DE is a free next-cluster. Preserves DE, HL.
fat_src_is_free:
    push    hl
    ex      de,hl
    call    fat_win_is_free
    ex      de,hl
    pop     hl
    ret

fat_nfree_inc:
    ld      hl,(_cpm_fat_vol+28)
    inc     hl
    ld      (_cpm_fat_vol+28),hl
    ld      a,h
    or      l
    ret     NZ
    ld      hl,(_cpm_fat_vol+30)
    inc     hl
    ld      (_cpm_fat_vol+30),hl
    ret

fat_nfree_dec:
    ld      hl,(_cpm_fat_vol+28)
    ld      a,h
    or      l
    ld      de,(_cpm_fat_vol+30)
    or      d
    or      e
    ret     Z
    ld      a,h
    or      l
    jr      NZ,fat_nfree_dec_lo
    ld      hl,(_cpm_fat_vol+30)
    dec     hl
    ld      (_cpm_fat_vol+30),hl
    ld      hl,(_cpm_fat_vol+28)
fat_nfree_dec_lo:
    dec     hl
    ld      (_cpm_fat_vol+28),hl
    ret

; ff.c ld_32 / st_32 as *(DWORD *). Byte stream through HL (no ld hl,(de)
; on Z80). Last byte has no post-increment: HL at offset +3. Streamed
; callers inc hl to the next dword. BCDE is E LSB.
fat_ld32:
    ld      e,(hl+)
    ld      d,(hl+)
    ld      c,(hl+)
    ld      b,(hl)
    ret

fat_st32:
    ld      (hl+),e
    ld      (hl+),d
    ld      (hl+),c
    ld      (hl),b
    ret

; IN: HL -> {sclust:4, fptr:4} LE
; OUT C: BCDE = cluster containing fptr
; Cluster index is (fptr >> 9) / csize. Sequential CP/M I/O hits
; clst_cache_* so we do not re-walk from sclust.
clst_from_off:
    call    fat_ld32
    ld      (fat_work),de            ;sclust
    ld      (fat_work+2),bc
    inc     hl
    call    fat_ld32                 ;fptr
    ; cluster index = (fptr >> 9) / csize. >>8 is a byte slide; >>1 after that.
    ld      e,d
    ld      d,c
    ld      c,b
    ld      b,0                     ;fptr >> 8
    srl     c
    rr      d
    rr      e                       ;fptr >> 9 = sector index in CDE
    ld      a,(_cpm_fat_vol+1)
    ld      b,0
cfo_log:
    srl     a
    jr      Z,cfo_div
    inc     b
    jr      cfo_log
cfo_div:
    ld      a,b
    or      a
    jr      Z,cfo_ci
cfo_shr:
    srl     c
    rr      d
    rr      e
    djnz    cfo_shr
cfo_ci:
    ld      (fat_work+4),de         ;want_ci — kept for the cache store
    ld      hl,clst_cache_sclust
    ld      a,(fat_work)
    cp      (hl)
    jr      NZ,cfo_from0
    inc     hl
    ld      a,(fat_work+1)
    cp      (hl)
    jr      NZ,cfo_from0
    inc     hl
    ld      a,(fat_work+2)
    cp      (hl)
    jr      NZ,cfo_from0
    inc     hl
    ld      a,(fat_work+3)
    cp      (hl)
    jr      NZ,cfo_from0
    ld      hl,(clst_cache_ci)
    ld      de,(fat_work+4)
    or      a
    sbc     hl,de                   ;cache_ci - want_ci
    jr      Z,cfo_cached
    jr      NC,cfo_from0            ;want is behind the cache
    ld      hl,(fat_work+4)
    ld      de,(clst_cache_ci)
    or      a                       ;C still set from cache_ci-want
    sbc     hl,de
    ld      (fat_work+8),hl         ;steps from cached cluster
    ld      de,(clst_cache_clst)
    ld      bc,(clst_cache_clst+2)
    jr      cfo_loop
cfo_from0:
    ld      hl,(fat_work+4)
    ld      (fat_work+8),hl         ;steps from sclust
    ld      de,(fat_work)
    ld      bc,(fat_work+2)
cfo_loop:
    ld      a,(fat_work+8)
    ld      hl,fat_work+9
    or      (hl)
    jr      Z,cfo_have
    call    get_fat
    ret     NC
    ld      a,b
    cp      $0F
    jr      NZ,cfo_store
    ld      a,c
    and     d
    and     e
    inc     a
    jr      Z,cfo_bad
cfo_store:
    ld      hl,(fat_work+8)
    dec     hl
    ld      (fat_work+8),hl
    jr      cfo_loop
cfo_cached:
    ld      de,(clst_cache_clst)
    ld      bc,(clst_cache_clst+2)
cfo_have:
    ld      (clst_cache_clst),de
    ld      (clst_cache_clst+2),bc
    ld      hl,(fat_work)
    ld      (clst_cache_sclust),hl
    ld      hl,(fat_work+2)
    ld      (clst_cache_sclust+2),hl
    ld      hl,(fat_work+4)
    ld      (clst_cache_ci),hl
    scf
    ret
cfo_bad:
    or      a
    ret

; Allocate one cluster and link it.
; IN: BCDE = cluster to link after, or 0 to start a new chain.
; A new chain starts at fat_last_clst when that hint is a real cluster
; (fatgen103 FSI_Nxt_Free: start where the driver last allocated).
; Otherwise it starts at cluster 2. Extending a chain starts at clst+1,
; so the next cluster is taken when it is free.
; The scan wraps once to cluster 2 and stops at the cluster where this
; search started, so the tail is not read twice.
; The new cluster is marked EOC ($0FFFFFFF), remembered as fat_last_clst,
; and linked from the previous cluster when there is one.
; OUT C: BCDE = new cluster. A failed FAT#2 mirror still returns it.
create_chain:
    ld      (fat_work+8),de          ;link-from
    ld      (fat_work+10),bc
    xor     a
    ld      (fat_work+7),a           ;wrap flag
    ld      a,b
    or      c
    or      d
    or      e
    jr      Z,cc_hint
    inc     de
    ld      a,d
    or      e
    jr      NZ,cc_mark
    inc     bc
    jr      cc_mark
cc_hint:
    ld      de,(fat_last_clst)
    ld      bc,(fat_last_clst+2)
    ld      a,b
    or      c
    or      d
    jr      NZ,cc_hint_hi
    ld      a,e
    cp      2
    jr      C,cc_from2               ;no hint, or hint is 0/1
cc_hint_hi:
    push    bc
    push    de
    ld      hl,(_cpm_fat_vol+4)
    ld      a,l
    sub     e
    ld      l,a
    ld      a,h
    sbc     a,d
    ld      h,a
    ld      a,(_cpm_fat_vol+6)
    sbc     a,c
    ld      c,a
    ld      a,(_cpm_fat_vol+7)
    sbc     a,b
    jr      C,cc_hint_bad
    or      c
    or      h
    or      l
    jr      Z,cc_hint_bad            ;hint >= n_fatent
    pop     de
    pop     bc
    jr      cc_mark
cc_hint_bad:
    pop     de
    pop     bc
cc_from2:
    ld      de,2
    ld      bc,0
cc_mark:
    ld      (fat_work),de            ;search origin
    ld      (fat_work+2),bc
cc_scan:
    ld      (fat_work+12),de
    ld      (fat_work+14),bc
    ld      hl,(_cpm_fat_vol+4)
    ld      a,l
    sub     e
    ld      l,a
    ld      a,h
    sbc     a,d
    ld      h,a
    ld      a,(_cpm_fat_vol+6)
    sbc     a,c
    ld      c,a
    ld      a,(_cpm_fat_vol+7)
    sbc     a,b
    jp      C,cc_wrap
    or      c
    or      h
    or      l
    jp      Z,cc_wrap               ;candidate >= n_fatent
    ld      de,(fat_work+12)
    ld      bc,(fat_work+14)
    ld      a,(fat_work+7)
    or      a
    jr      Z,cc_look
    ld      hl,(fat_work)           ;wrapped: stop on return to origin
    ld      a,e
    cp      l
    jr      NZ,cc_look
    ld      a,d
    cp      h
    jr      NZ,cc_look
    ld      hl,(fat_work+2)
    ld      a,c
    cp      l
    jr      NZ,cc_look
    ld      a,b
    cp      h
    jp      Z,cc_fail
cc_look:
    call    get_fat
    ret     NC
    ld      a,b
    or      c
    or      d
    or      e
    jp      NZ,cc_next              ;in use
    ld      de,(fat_work+12)
    ld      bc,(fat_work+14)
    ld      hl,cc_eoc
    call    put_fat
    ret     NC
    ld      a,(fat_work+8)
    ld      hl,fat_work+9
    or      (hl+)
    or      (hl+)
    or      (hl)
    jr      Z,cc_ok
    push    bc
    push    de
    ld      de,(fat_work+8)
    ld      bc,(fat_work+10)
    ld      hl,fat_work+12
    call    put_fat
    pop     de
    pop     bc
    ret     NC
cc_ok:
    call    fat_sync_window         ;FAT#1 has the link; a failed mirror stays dirty
    ret     NC
cc_ret_cl:
    ld      de,(fat_work+12)
    ld      bc,(fat_work+14)
    ld      (fat_last_clst),de
    ld      (fat_last_clst+2),bc
    scf
    ret
cc_next:
    ld      de,(fat_work+12)
    ld      bc,(fat_work+14)
    inc     de
    ld      a,d
    or      e
    jp      NZ,cc_scan
    inc     bc
    jp      cc_scan
cc_wrap:
    ld      a,(fat_work+7)
    or      a
    jr      NZ,cc_fail
    ld      a,1
    ld      (fat_work+7),a
    ld      a,(fat_work)            ;origin == 2 means the whole volume was seen
    cp      2
    jr      NZ,cc_wrap2
    ld      a,(fat_work+1)
    or      a
    jr      NZ,cc_wrap2
    ld      a,(fat_work+2)
    or      a
    jr      NZ,cc_wrap2
    ld      a,(fat_work+3)
    or      a
    jr      Z,cc_fail
cc_wrap2:
    ld      de,2
    ld      bc,0
    jp      cc_scan
cc_fail:
    or      a
    ret
cc_eoc:
    defb    $FF,$FF,$FF,$0F

; ff.c remove_chain (entire chain, pclst=0). Walks until 0 or a link
; that is not a cluster (EOC, bad, or >= n_fatent). The step stops at
; n_fatent so a long FAT32 chain is not cut at 65535.
; IN: BCDE = start cluster
remove_chain:
    ld      a,b
    or      c
    or      d
    or      e
    scf
    ret     Z
    ld      hl,0
    ld      (fat_work),hl            ;32-bit step
    ld      (fat_work+2),hl
rc_loop:
    ld      hl,(fat_work)
    inc     hl
    ld      (fat_work),hl
    ld      a,h
    or      l
    jr      NZ,rc_cmp
    ld      hl,(fat_work+2)
    inc     hl
    ld      (fat_work+2),hl
rc_cmp:
    push    bc
    push    de
    ld      de,(fat_work)
    ld      bc,(fat_work+2)
    ld      hl,_cpm_fat_vol+4       ;step - n_fatent
    ld      a,e
    sub     (hl+)
    ld      a,d
    sbc     (hl+)
    ld      a,c
    sbc     (hl+)
    ld      a,b
    sbc     a,(hl)
    pop     de
    pop     bc
    jr      NC,rc_fail              ;step >= n_fatent
    ld      (fat_work+8),de
    ld      (fat_work+10),bc
    call    get_fat
    ret     NC
    ld      (fat_work+12),de         ;next
    ld      (fat_work+14),bc
    ld      de,(fat_work+8)
    ld      bc,(fat_work+10)
    ld      hl,cc_zero
    call    put_fat
    ret     NC
    ld      de,(fat_work+12)
    ld      bc,(fat_work+14)
    ld      a,b
    or      c
    or      d
    or      e
    jr      Z,rc_done
    ld      hl,_cpm_fat_vol+4       ;next >= n_fatent ends the walk
    ld      a,e
    sub     (hl+)
    ld      a,d
    sbc     (hl+)
    ld      a,c
    sbc     (hl+)
    ld      a,b
    sbc     a,(hl)
    jr      C,rc_loop
rc_done:
    scf
    ret
rc_fail:
    or      a
    ret
cc_zero:
    defb    0,0,0,0

; Exclusive byte end of the FAT16 static root.
; Carry set: the end is 65536, so every 16-bit offset is inside
; (2048 entries). Carry clear: offset >= HL is past the root.
; A shorter database-dirbase span still clamps the end.
fat_root16_max:
    ld      hl,(_cpm_fat_vol+2)
    ld      a,l
    and     $F0
    ld      l,a
    ld      a,h
    cp      8                       ;2048 entries * 32 = 65536
    jr      C,frm_mul
    ld      hl,0
    scf
    jr      frm_clamp
frm_mul:
    add     hl,hl
    add     hl,hl
    add     hl,hl
    add     hl,hl
    add     hl,hl                   ;*32, fits in 16 bits
    or      a
frm_clamp:
    push    hl
    push    af                      ;C = entry count covers 64K
    ld      a,(_cpm_fat_vol+18)     ;database high
    ld      hl,_cpm_fat_vol+14
    or      (hl)                    ;dirbase high
    jr      NZ,frm_keep
    ld      hl,(_cpm_fat_vol+16)
    ld      de,(_cpm_fat_vol+12)
    or      a
    sbc     hl,de                   ;database - dirbase (sectors)
    jr      C,frm_keep
    jr      Z,frm_keep
    ld      a,h
    or      a
    jr      NZ,frm_keep             ;>= 256 sectors
    ld      a,l
    cp      128
    jr      NC,frm_keep             ;>= 128 sectors is >= 64K bytes
    ld      h,l
    ld      l,0
    add     hl,hl                   ;span << 9, fits in 16 bits
    pop     af
    pop     de                      ;DE = count end
    jr      C,frm_span              ;count was 64K: span is tighter
    push    hl
    or      a
    sbc     hl,de                   ;span - count
    pop     hl
    jr      C,frm_clear
    ex      de,hl
frm_clear:
    or      a
    ret
frm_span:
    or      a
    ret
frm_keep:
    pop     af
    pop     hl
    ret

; ff.c dir_sdi. Cluster 0 = FAT16 static root at dirbase LBA.
; FAT32 cluster 0 is the root cluster (dirbase), matching ff dir_sdi.
; FAT32 / subdir: follow the chain (clst_from_off). Offset must be
; 32-byte aligned by the caller.
; IN: BCDE = dir start cluster (0 = FAT16 root / FAT32 root), HL = byte offset
dir_sdi:
    ld      (dir_sclust),de
    ld      (dir_sclust+2),bc
    ld      (dir_ofs),hl
    ld      a,b
    or      c
    or      d
    or      e
    jr      NZ,dsdi_chain
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      NZ,dsdi_root16
    ld      de,(_cpm_fat_vol+12)
    ld      bc,(_cpm_fat_vol+14)
    ld      (dir_sclust),de
    ld      (dir_sclust+2),bc
    jr      dsdi_chain
dsdi_root16:
    push    hl                      ;ofs
    ld      hl,0
    ld      (dir_clust),hl          ;static FAT16 root
    ld      (dir_clust+2),hl
    pop     hl                      ;ofs
    push    hl
    call    fat_root16_max
    jr      C,dsdi_root16_in        ;2048 entries: any 16-bit ofs
    ex      de,hl                   ;DE = max
    pop     hl                      ;HL = dir_ofs
    push    hl
    or      a
    sbc     hl,de                   ;unsigned ofs >= max
    pop     hl
    jp      NC,dsdi_end
    jr      dsdi_root
dsdi_root16_in:
    pop     hl
dsdi_root:
    ld      a,h                     ;offset >> 9
    srl     a
    ld      e,a
    ld      d,0
    ld      hl,(_cpm_fat_vol+12)    ;dirbase LBA
    add     hl,de
    ld      (dir_sect),hl
    ld      hl,(_cpm_fat_vol+14)
    ld      de,0
    adc     hl,de
    ld      (dir_sect+2),hl
    ld      a,(dir_ofs)
    ld      e,a
    ld      a,(dir_ofs+1)
    and     1
    ld      d,a
    ld      hl,fatwin
    add     hl,de
    ld      (dir_ptr),hl
    ld      de,(dir_sect)
    ld      bc,(dir_sect+2)
    call    fat_move_window
    ret
dsdi_chain:
    ld      hl,dir_sclust
    ld      de,fat_work
    ld      bc,4
    ldir                            ;sclust at fat_work; fptr follows
    ld      hl,(dir_ofs)
    ld      (fat_work+4),hl
    ld      hl,0
    ld      (fat_work+6),hl          ;fptr 32-bit
    ld      hl,fat_work
    call    clst_from_off
    ret     NC
    ld      (dir_clust),de          ;cluster containing ofs
    ld      (dir_clust+2),bc
    call    clst2sect
    ret     NC
    ; add sector-in-cluster: (dir_ofs >> 9) % csize
    ld      a,(dir_ofs+1)
    srl     a                       ;offset/512 low
    ld      hl,_cpm_fat_vol+1
    ld      l,(hl)                  ;csize
    dec     l
    and     l                       ;mod csize if csize 2^n
    ld      l,a
    ld      h,0
    add     hl,de
    ex      de,hl                   ;DE = LBA + sector-in-cluster
    jr      NC,dsdi_sec
    inc     bc
dsdi_sec:
    ld      (dir_sect),de
    ld      (dir_sect+2),bc
    call    fat_move_window
    ret     NC
    ld      a,(dir_ofs)
    ld      e,a
    ld      a,(dir_ofs+1)
    and     1
    ld      d,a
    ld      hl,fatwin
    add     hl,de
    ld      (dir_ptr),hl
    scf
    ret
dsdi_end:
    or      a
    ret

; ff.c dir_next with stretch=0. No create_chain + dir_clear when a
; clustered directory hits EOC — the table is fixed size.
; Same-sector: pointer walk (SZDIRE). Sector change: sect++.
; Cluster change: get_fat(dir_clust) then clst2sect (no stretch).
dir_next:
    ld      hl,(dir_ofs)
    ld      bc,32
    add     hl,bc
    jp      C,dir_next_end          ;ofs wrap: 2048 dirents (LFN-heavy dirs)
    ld      a,l
    or      a
    jr      NZ,dir_next_same        ;ofs % 512 != 0
    ld      a,h
    and     1
    jr      Z,dir_next_sect
dir_next_same:
    ld      (dir_ofs),hl
    ld      hl,(dir_ptr)
    ld      de,32
    add     hl,de
    ld      (dir_ptr),hl
    scf
    ret
dir_next_sect:
    ld      (dir_ofs),hl
    ld      hl,(dir_clust)
    ld      a,h
    or      l
    ld      hl,(dir_clust+2)
    or      h
    or      l
    jr      NZ,dir_next_dyn
    call    fat_root16_max
    jr      C,dir_next_inc          ;2048 entries: ofs still inside
    ex      de,hl                   ;DE = max
    ld      hl,(dir_ofs)
    or      a
    sbc     hl,de
    jp      NC,dir_next_end         ;unsigned ofs >= max
dir_next_inc:
    ld      hl,(dir_sect)
    inc     hl
    ld      (dir_sect),hl
    ld      a,h
    or      l
    jr      NZ,dir_next_win
    ld      hl,(dir_sect+2)
    inc     hl
    ld      (dir_sect+2),hl
    jr      dir_next_win
dir_next_dyn:
    ld      a,(dir_ofs+1)
    srl     a                       ;ofs / 512
    ld      hl,_cpm_fat_vol+1
    ld      l,(hl)                  ;csize
    dec     l
    and     l                       ;(ofs/512) & (csize-1)
    jr      NZ,dir_next_inc         ;still in this cluster
    ld      de,(dir_clust)
    ld      bc,(dir_clust+2)
    call    get_fat
    jp      NC,dir_next_end
    ld      a,b
    cp      $0F
    jr      NZ,dir_next_got
    ld      a,c
    and     d
    and     e
    inc     a
    jp      Z,dir_next_end          ;EOC
dir_next_got:
    ld      a,e
    sub     2
    ld      a,d
    sbc     a,0
    ld      a,c
    sbc     a,0
    ld      a,b
    sbc     a,0
    jp      C,dir_next_end          ;cluster < 2
    ld      (dir_clust),de
    ld      (dir_clust+2),bc
    call    clst2sect
    jp      NC,dir_next_end
    ld      (dir_sect),de
    ld      (dir_sect+2),bc
dir_next_win:
    ld      de,(dir_sect)
    ld      bc,(dir_sect+2)
    call    fat_move_window
    ret     NC
    ld      hl,fatwin               ;ofs % 512 == 0
    ld      (dir_ptr),hl
    scf
    ret
dir_next_end:
    or      a
    ret

; ff.c dir_find (no LFN). 0x00 ends the table; 0xE5 is deleted.
; Skip the volume bit. A long name is attribute $0F, so that test
; covers it. Disk $05 compares as $E5.
; IN: HL -> 11-byte 8.3
; OUT C and L=0, H=0: found, fat_found_* and dir_ptr filled. L=1: miss.
_dir_find:
dir_find:
    ld      (pack_sv),hl            ;8.3; dir_sdi clobbers fat_work
    ld      de,(dir_sclust)
    ld      bc,(dir_sclust+2)
    ld      hl,0
    call    dir_sdi
    ld      hl,1
    ret     NC
df_loop:
    ld      hl,(dir_ptr)
    ld      a,(hl)
    or      a                       ;0x00 = end of directory
    jr      Z,df_miss
    cp      $E5                     ;deleted
    jr      Z,df_next
    ld      bc,DIR_Attr
    add     hl,bc
    ld      a,(hl)
    and     AM_VOL
    jr      NZ,df_next
    ld      de,(dir_ptr)
    ld      hl,(pack_sv)
    ld      a,(de)
    cp      $05                     ;KANJI: stored $05 is the character $E5
    jr      NZ,df_cmp1
    ld      a,$E5
df_cmp1:
    cp      (hl)
    jr      NZ,df_next
    inc     de
    inc     hl
    ld      b,10
df_cmp:
    ld      a,(de+)
    cp      (hl+)
    jr      NZ,df_next
    djnz    df_cmp
    ld      hl,(dir_ptr)
    push    hl
    ld      bc,DIR_ClusHI
    add     hl,bc
    ld      e,(hl+)
    ld      d,(hl)                  ;clus hi
    ld      hl,(dir_ptr)
    ld      bc,DIR_ClusLO
    add     hl,bc
    ld      a,(hl+)
    ld      (fat_found_sclust),a
    ld      a,(hl)
    ld      (fat_found_sclust+1),a
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,df_hi
    ld      de,0
df_hi:
    ld      (fat_found_sclust+2),de
    ld      hl,(dir_ptr)
    ld      bc,DIR_FileSize
    add     hl,bc
    ld      de,fat_found_size
    ld      bc,4
    ldir
    pop     hl
    ld      hl,0
    scf
    ret
df_next:
    call    dir_next
    jr      C,df_loop
df_miss:
    ld      hl,1
    or      a
    ret

; ff.c dir_alloc(n=1) + dir_register SFN. Reuses 0x00 or 0xE5.
; Does not stretch the directory if the table is full.
; IN: HL -> 11-byte 8.3
_dir_create:
dir_create:
    ld      (pack_sv),hl            ;8.3; dir_sdi clobbers fat_work
    ld      de,(dir_sclust)
    ld      bc,(dir_sclust+2)
    ld      hl,0
    call    dir_sdi
    ld      hl,1
    ret     NC
dc_loop:
    ld      hl,(dir_ptr)
    ld      a,(hl)
    or      a                       ;free: 0x00 or 0xE5
    jr      Z,dc_fill
    cp      $E5
    jr      Z,dc_fill
    call    dir_next
    jr      C,dc_loop
    ld      hl,1
    or      a
    ret
dc_fill:
    ld      hl,(dir_ptr)
    ld      b,32
    xor     a
dc_z:
    ld      (hl+),a
    djnz    dc_z
    ld      de,(dir_ptr)
    ld      hl,(pack_sv)
    ld      bc,11
    ldir
    ld      hl,(dir_ptr)
    ld      a,(hl)
    cp      $E5                     ;KANJI lead byte is stored as $05
    jr      NZ,dc_stored
    ld      (hl),$05
dc_stored:
    ld      a,1
    ld      (fat_wflag),a
    ld      hl,0
    scf
    ret

; ff.c dir_remove (no LFN): first byte := $E5. Does not free the chain.
_dir_zap:
dir_zap:
    ld      hl,(dir_ptr)
    ld      (hl),$E5                ;DDEM; chain free is the caller's job
    ld      a,1
    ld      (fat_wflag),a
    ld      hl,0
    scf
    ret

; Open a directory at its first entry.
; HL points at the little-endian start cluster. 0 is the root
; (the FAT16 root area, or the FAT32 root cluster).
; L=0 and carry set when the first sector is in the window.
; L=1 and carry clear when that cluster is not on the volume.
_fat_dir_open:
    call    fat_ld32
    ld      hl,0
    call    dir_sdi
    ld      hl,0
    ret     C
    inc     l
    ret

; HL -> 32-byte dirent. Copy dir_ptr; first byte 0x00 is EOT (L=1).
_fat_dir_read:
    push    hl
    ld      hl,(dir_ptr)
    ld      a,(hl)
    or      a
    jr      Z,fat_dir_read_end
    pop     de
    ld      bc,32
    ldir
    call    dir_next
    jr      C,fat_dir_read_ok
    ld      hl,cc_zero              ;no trailing 0x00: next read is end
    ld      (dir_ptr),hl
fat_dir_read_ok:
    ld      hl,0
    scf
    ret
fat_dir_read_end:
    pop     hl
    ld      (hl),0
    ld      hl,1
    ret

; Next cluster in a chain.
; HL points at a little-endian cluster. On success that dword
; becomes the next cluster and L is 0. An end mark is stored as
; 0x0FFFFFFF (FAT16 $FFF8-$FFFF and FAT32 >= $0FFFFFF8 both fold
; to that value). On a disk error the dword is left alone and L
; is 1. A chain that points at itself fails.
_fat_next:
    push    hl
    call    fat_ld32
    ld      (pack_sv),de
    ld      (pack_sv+2),bc
    call    get_fat
    pop     hl
    jr      NC,fat_next_fail
    ld      a,(pack_sv)
    cp      e
    jr      NZ,fat_next_store
    ld      a,(pack_sv+1)
    cp      d
    jr      NZ,fat_next_store
    ld      a,(pack_sv+2)
    cp      c
    jr      NZ,fat_next_store
    ld      a,(pack_sv+3)
    cp      b
    jr      Z,fat_next_fail
fat_next_store:
    call    fat_st32
    ld      hl,0
    ret
fat_next_fail:
    ld      hl,1
    ret

; Allocate one cluster by the next-free scan (create_chain).
; HL points at the little-endian cluster to link after. 0 starts
; a new chain. On success the new cluster number replaces that
; dword and L is 0. On failure the dword is unchanged and L is 1.
; The new cluster is marked end-of-chain, then linked from the
; previous one. This is not a search for a hole, so several calls
; can fragment the file. If the second FAT copy cannot be written
; the call still succeeds: the first FAT already holds the link.
_fat_alloc:
    push    hl
    call    fat_ld32
    call    create_chain
    pop     hl
    jr      NC,fat_alloc_fail
    call    fat_st32
    ld      hl,0
    ret
fat_alloc_fail:
    ld      hl,1
    ret

; Free a whole chain.
; HL points at the little-endian start cluster. The walk stops at
; 0 or at a link that is not a real cluster (end mark, bad mark,
; or a number past n_fatent). L=0 and carry set on success.
_fat_free:
    call    fat_ld32
    call    remove_chain
    ld      hl,0
    ret     C
    inc     l
    ret

; First sector of a cluster.
; HL points at a little-endian cluster. On success that same
; dword is overwritten with the LBA, database + (cluster-2)*csize,
; and L is 0. On failure the dword is unchanged and L is 1.
; A cluster below 2, or at or past n_fatent, fails.
_fat_clst2sect:
    push    hl
    call    fat_ld32
    call    clst2sect
    pop     hl
    jr      NC,fat_c2s_fail
    call    fat_st32
    ld      hl,0
    ret
fat_c2s_fail:
    ld      hl,1
    ret

; ff.c f_getfree FAT16/32 window scan. Count zero entries in n_fatent
; FAT slots (0 and 1 are never free on a valid volume). The scan does
; not read FSInfo; a mount may already have stored FSI_Free_Count.
; Cache: free_valid / free_clst; put_fat updates the count.
; HL -> DWORD out. L=0 success.
_fat_getfree:
    push    hl
    ld      a,(_cpm_fat_vol+25)
    or      a
    jr      Z,gf_scan
    ld      de,(_cpm_fat_vol+28)
    ld      bc,(_cpm_fat_vol+30)
    jp      gf_store
gf_scan:
    ld      hl,0
    ld      (fat_work),hl           ;nfree
    ld      (fat_work+2),hl
    ld      de,(_cpm_fat_vol+8)     ;sect = fatbase
    ld      (fat_work+4),de
    ld      de,(_cpm_fat_vol+10)
    ld      (fat_work+6),de
    ld      de,(_cpm_fat_vol+4)     ;remaining = n_fatent
    ld      (fat_work+8),de
    ld      de,(_cpm_fat_vol+6)
    ld      (fat_work+10),de
gf_loop:
    ld      hl,(fat_work+8)
    ld      a,h
    or      l
    ld      de,(fat_work+10)
    or      d
    or      e
    jp      Z,gf_scanned
    ld      de,(fat_work+4)
    ld      bc,(fat_work+6)
    call    fat_move_window
    jp      NC,gf_fail
    ld      hl,(fat_work+4)
    inc     hl
    ld      (fat_work+4),hl
    ld      a,h
    or      l
    jr      NZ,gf_sect
    ld      hl,(fat_work+6)
    inc     hl
    ld      (fat_work+6),hl
gf_sect:
    ; One 16-bit tally per sector, then one 32-bit add. B=0 counts 256.
    ld      bc,256
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      NZ,gf_wide
    ld      bc,128
gf_wide:
    ld      a,(fat_work+10)         ;remaining >= 65536 fills this sector
    or      a
    jr      NZ,gf_full
    ld      a,(fat_work+11)
    or      a
    jr      NZ,gf_full
    ld      hl,(fat_work+8)
    or      a
    sbc     hl,bc
    jr      NC,gf_full
    ld      a,(fat_work+8)          ;tail is 1..width-1
    ld      b,a
    ld      hl,fatwin
    call    gf_tally
    call    gf_add
    jp      gf_scanned
gf_full:
    push    bc
    ld      b,c                     ;0 = 256 FAT16 entries, 128 FAT32
    ld      hl,fatwin
    call    gf_tally
    call    gf_add
    pop     bc
    ld      hl,(fat_work+8)
    or      a
    sbc     hl,bc
    ld      (fat_work+8),hl
    jp      NC,gf_loop
    ld      hl,(fat_work+10)
    dec     hl
    ld      (fat_work+10),hl
    jp      gf_loop
gf_scanned:
    ld      a,1
    ld      (_cpm_fat_vol+25),a
    ld      de,(fat_work)
    ld      (_cpm_fat_vol+28),de
    ld      de,(fat_work+2)
    ld      (_cpm_fat_vol+30),de
    ld      bc,de
    ld      de,(fat_work)
gf_store:
    pop     hl
    call    fat_st32
    ld      hl,0
    scf
    ret
gf_fail:
    pop     hl
    ld      hl,1
    or      a
    ret

; HL = FAT window, B = entries (0 means 256). DE = free count on return.
gf_tally:
    ld      de,0
    ld      a,(_cpm_fat_vol)
    cp      FS_FAT32
    jr      Z,gf32_lp
gf16_lp:
    ld      a,(hl+)                 ;FAT16 free: both bytes zero
    or      (hl+)
    jr      NZ,gf16_used
    inc     de
gf16_used:
    djnz    gf16_lp
    ret
gf32_lp:
    ld      a,(hl+)                 ;FAT32 free: 28-bit value zero
    or      (hl+)
    or      (hl+)
    ld      c,a
    ld      a,(hl+)
    and     $0F
    or      c
    jr      NZ,gf32_used
    inc     de
gf32_used:
    djnz    gf32_lp
    ret

; fat_work (nfree) += DE. DE is at most one sector of entries.
gf_add:
    ld      hl,(fat_work)
    add     hl,de
    ld      (fat_work),hl
    ret     NC
    ld      hl,(fat_work+2)
    inc     hl
    ld      (fat_work+2),hl
    ret

; Round *HL bytes up to whole clusters. csize is 2^n.
; Out: that count, or 0 if csize is 0, bytes is 0, or the sum wraps.
; Shift is 9+log2(csize) and at most 16, so the mask fits in 16 bits.
_fat_clusters:
    push    hl
    ld      a,(_cpm_fat_vol+1)
    or      a
    jp      Z,fc_z1
    ld      b,9
fc_log:
    rrca
    jp      C,fc_have
    inc     b
    jp      fc_log
fc_have:
    ld      c,b                     ;C = shift
    ld      hl,0
fc_mask:
    add     hl,hl
    inc     hl                      ;(1<<shift)-1
    dec     b
    jp      NZ,fc_mask
    push    hl                      ;mask
    push    bc                      ;shift in C
    ld      hl,4
    add     hl,sp                   ;saved pointer
    ld      a,(hl+)
    ld      h,(hl)
    ld      l,a
    call    fat_ld32                ;BCDE = bytes
    ld      a,b
    or      c
    or      d
    or      e
    jp      Z,fc_z3
    ld      hl,2
    add     hl,sp                   ;mask
    ld      a,e
    add     a,(hl+)
    ld      e,a
    ld      a,d
    adc     a,(hl)
    ld      d,a
    ld      a,c
    adc     a,0
    ld      c,a
    ld      a,b
    adc     a,0
    ld      b,a
    jp      C,fc_z3
fc_shr:
    or      a
    ld      a,b
    rra
    ld      b,a
    ld      a,c
    rra
    ld      c,a
    ld      a,d
    rra
    ld      d,a
    ld      a,e
    rra
    ld      e,a
    ld      hl,0
    add     hl,sp
    dec     (hl)                    ;shift--
    jp      NZ,fc_shr
    pop     hl
    pop     hl
    pop     hl
    jp      fat_st32
fc_z3:
    ld      bc,0
    ld      de,0
    pop     hl
    pop     hl
    pop     hl
    jp      fat_st32
fc_z1:
    ld      bc,0
    ld      de,0
    pop     hl
    jp      fat_st32
