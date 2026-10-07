;
; RAM for the shell mini-FAT. CRT BSS (after data, at the rc2014 RAM
; origin). The BIOS high page has no room under the serial rings.
; The +test harness does not link this file; it defines the same names
; in bss_ram.asm.
;

SECTION bss_compiler

PUBLIC _cpm_fat_vol
PUBLIC _fatwin
PUBLIC fatwin
PUBLIC fat_winsect
PUBLIC fat_wflag
PUBLIC _fat_cwd
PUBLIC fat_cwd
PUBLIC _fat_found_sclust
PUBLIC fat_found_sclust
PUBLIC _fat_found_size
PUBLIC fat_found_size
PUBLIC _fat_dir_ptr
PUBLIC dir_ptr
PUBLIC dir_sclust
PUBLIC dir_clust
PUBLIC dir_sect
PUBLIC dir_ofs
PUBLIC fat_work
PUBLIC pack_sv
PUBLIC fat_last_clst
PUBLIC clst_cache_sclust
PUBLIC clst_cache_ci
PUBLIC clst_cache_clst
PUBLIC _cpm_dir_sclust

_cpm_dir_sclust:        defs 16
_cpm_fat_vol:           defs 32
_fatwin:
fatwin:                 defs 512
fat_winsect:            defs 4
fat_wflag:              defs 1
dir_sclust:             defs 4
dir_clust:              defs 4
dir_sect:               defs 4
dir_ofs:                defs 2
_fat_dir_ptr:
dir_ptr:                defs 2
_fat_found_sclust:
fat_found_sclust:       defs 4
_fat_found_size:
fat_found_size:         defs 4
clst_cache_sclust:      defs 4
clst_cache_ci:          defs 2
clst_cache_clst:        defs 4
_fat_cwd:
fat_cwd:                defs 4
fat_work:               defs 16
pack_sv:                defs 16
fat_last_clst:          defs 4      ;last cluster this session allocated
