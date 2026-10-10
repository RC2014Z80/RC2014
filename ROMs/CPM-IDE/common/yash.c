#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <cpu.h>

#include "yash.h"
#include "fatfs.h"

#pragma printf = "%c %s %d %u %lu %X"

typedef uint8_t  BYTE;
typedef uint16_t WORD;
typedef uint16_t UINT;
typedef uint32_t DWORD;
#include <arch/rc2014/diskio.h>

extern uint8_t bios_iobyte;
extern uint32_t cpm_dsk0_base[4];
extern void cpm_boot(void);

void *buffer;
FILE *input;
FILE *output;
FILE *error;

/* History survives from one command to the next. The ring is malloc RAM. */
static char *hist_ring;
static char *hist_draft;
static uint8_t hist_used;
static uint8_t hist_i;
static uint8_t hist_off;

struct Builtin {
    const char * name;
    int8_t (*func) (char ** args);
    const char * help;
};

struct Builtin builtins[] = {
  // CP/M related functions
    { "cpm", &ya_mkcpm, "file.a [file.b] [file.c] [file.d] - initiate CP/M with up to 4 drive files"},
    { "hget", &ya_hget, "<file> - ascii-xfr -s"},
    { "mkdrv", &ya_mkdrv, "<file> - empty 8 MB CP/M drive"},

// fat related functions
    { "ls", &ya_ls, "[path] - directory listing"},
    { "cd", &ya_cd, "<path> - change the current working directory"},
    { "pwd", &ya_pwd, "- show the current working directory"},
    { "rm", &ya_rm, "<file> - delete a file"},
    { "rmdir", &ya_rmdir, "<path> - remove an empty directory"},
    { "mkdir", &ya_mkdir, "<path> - create a directory"},
    { "cp", &ya_cp, "<src> <dst> - copy a file"},
    { "mv", &ya_mv, "<src> <dst> - rename or move a file"},
    { "mount", &ya_mount, "- mount a FAT file system"},
    { "frag", &ya_frag, "<file> - cluster-run count for a file"},

// disk related functions
    { "ds", &ya_ds, "- disk status"},
    { "dd", &ya_dd, "[sector] - disk dump, sector in decimal"},

// system related functions
    { "md", &ya_md, "[origin] - memory dump, origin in hexadecimal"},
    { "help", &ya_help, "- this is it"},
    { "exit", &ya_exit, "- exit and restart"}
};

/**
   @brief Number of built-in commands.
 */
uint8_t ya_num_builtins(void) {
    return sizeof(builtins) / sizeof(struct Builtin);
}


/*
  helper functions
 */

static void name83(uint8_t *dst, const char *src)
{
    uint8_t i;

    for (i = 0; i < 11; ++i)
        dst[i] = ' ';
    if (src[0] == '.' && src[1] == 0) {
        dst[0] = '.';
        return;
    }
    if (src[0] == '.' && src[1] == '.' && src[2] == 0) {
        dst[0] = '.';
        dst[1] = '.';
        return;
    }
    i = 0;
    while (*src && *src != '.' && i < 8) {
        char c = *src++;
        if (c >= 'a' && c <= 'z')
            c = (char)(c - 32);
        dst[i++] = (uint8_t)c;
    }
    while (*src && *src != '.')
        ++src;
    if (*src == '.')
        ++src;
    i = 8;
    while (*src && i < 11) {
        char c = *src++;
        if (c >= 'a' && c <= 'z')
            c = (char)(c - 32);
        dst[i++] = (uint8_t)c;
    }
}

/* Host FAT tools sometimes store "MAIN.C" in the 11-byte SFN (dot in
 * the name field) instead of "MAIN    C  ". */
static void name_pack11(uint8_t *dst, const char *src)
{
    uint8_t i;

    for (i = 0; i < 11; ++i)
        dst[i] = ' ';
    i = 0;
    while (*src && i < 11) {
        char c = *src++;
        if (c >= 'a' && c <= 'z')
            c = (char)(c - 32);
        dst[i++] = (uint8_t)c;
    }
}

static uint32_t root_clst(void)
{
    if (cpm_fat_vol.fs_type == 3)
        return cpm_fat_vol.dirbase;
    return 0;
}

static uint8_t is_root_clst(uint32_t clst)
{
    if (clst == 0 || clst == root_clst())
        return 1;
    return 0;
}

static uint32_t ent_clst(const uint8_t *ent)
{
    uint32_t c;

    c = (uint32_t)ent[26] | ((uint32_t)ent[27] << 8);
    c |= ((uint32_t)ent[20] << 16) | ((uint32_t)ent[21] << 24);
    if (cpm_fat_vol.fs_type == 3)
        c &= 0x0FFFFFFFul;
    return c;
}

static void sfn_to_name(char *dst, const uint8_t *ent)
{
    uint8_t i, n;

    n = 0;
    i = 0;
    while (i < 8 && ent[i] != ' ') {
        dst[n] = (char)ent[i];
        ++n;
        ++i;
    }
    if (ent[8] != ' ') {
        dst[n] = '.';
        ++n;
        i = 8;
        while (i < 11 && ent[i] != ' ') {
            dst[n] = (char)ent[i];
            ++n;
            ++i;
        }
    }
    dst[n] = 0;
}

static void put_vis(uint8_t c)
{
    if (c < 0x20 || c > 0x7E)
        c = '?';
    fputc(c, output);
}

static uint8_t dir_find_try(uint8_t *n)
{
    uint8_t alt[11];
    char tmp[13];

    if (dir_find(n) == 0)
        return 0;
    sfn_to_name(tmp, n);
    name_pack11(alt, tmp);
    if (memcmp(n, alt, 11) == 0)
        return 1;
    return dir_find(alt);
}

/* One path component. "." keeps clst. ".." is the parent dirent. */
static uint8_t dir_walk(uint32_t *clst, const char *comp)
{
    uint8_t n[11];

    if (comp[0] == '.' && comp[1] == 0)
        return 0;
    if (comp[0] == '.' && comp[1] == '.' && comp[2] == 0) {
        if (is_root_clst(*clst))
            return 0;
        if (fat_dir_open(clst))
            return FR_DISK_ERR;
        name83(n, "..");
        if (dir_find_try(n))
            return FR_NO_PATH;
        *clst = fat_found_sclust;
        if (*clst < 2)
            *clst = root_clst();
        return 0;
    }
    if (fat_dir_open(clst))
        return FR_DISK_ERR;
    name83(n, comp);
    if (dir_find_try(n))
        return FR_NO_PATH;
    if ((fat_dir_ptr[11] & AM_DIR) == 0)
        return FR_NO_PATH;
    *clst = fat_found_sclust;
    return 0;
}

static uint8_t path_to_dir(const char *path, uint32_t *out)
{
    uint32_t clst;
    char comp[13];
    uint8_t ci, rc;

    if (path == NULL || path[0] == 0) {
        *out = fat_cwd;
        return 0;
    }
    if (path[0] == '/' || path[0] == '\\') {
        clst = root_clst();
        ++path;
        if (path[0] == 0) {
            *out = clst;
            return 0;
        }
    } else {
        clst = fat_cwd;
    }

    while (*path) {
        ci = 0;
        while (*path && *path != '/' && *path != '\\' && ci < 12)
            comp[ci++] = *path++;
        comp[ci] = 0;
        while (*path == '/' || *path == '\\')
            ++path;
        if (comp[0] == 0)
            continue;
        rc = dir_walk(&clst, comp);
        if (rc)
            return rc;
    }
    *out = clst;
    return 0;
}

static uint8_t is_eoc(uint32_t clst)
{
    return (clst & 0x0FFFFFFFul) >= 0x0FFFFFF8ul;
}

static uint8_t is_dot_name(const uint8_t *n)
{
    return n[0] == '.' && (n[1] == ' ' || (n[1] == '.' && n[2] == ' '));
}

/* Walk all but the last component. Leaf 8.3 in name11. */
static uint8_t path_split(const char *path, uint32_t *parent, uint8_t *name11)
{
    uint32_t clst;
    char comp[13];
    uint8_t ci, rc;

    if (path == NULL || path[0] == 0)
        return FR_INVALID_NAME;
    if (path[0] == '/' || path[0] == '\\') {
        clst = root_clst();
        ++path;
    } else {
        clst = fat_cwd;
    }
    while (*path == '/' || *path == '\\')
        ++path;
    if (*path == 0)
        return FR_INVALID_NAME;

    while (*path) {
        ci = 0;
        while (*path && *path != '/' && *path != '\\' && ci < 12)
            comp[ci++] = *path++;
        comp[ci] = 0;
        while (*path == '/' || *path == '\\')
            ++path;
        if (comp[0] == 0)
            continue;
        if (*path == 0) {
            name83(name11, comp);
            *parent = clst;
            return 0;
        }
        rc = dir_walk(&clst, comp);
        if (rc)
            return rc;
    }
    return FR_INVALID_NAME;
}

/* Dest for cp/mv. A trailing / or an existing directory keeps the source 8.3
 * name and uses that directory as the parent. */
static uint8_t dest_resolve(const char *dst, const uint8_t *sn,
    uint32_t *parent, uint8_t *name11)
{
    const char *p;
    uint8_t rc;

    if (dst == NULL || dst[0] == 0)
        return FR_INVALID_NAME;
    p = dst;
    while (p[1])
        ++p;
    if (*p == '/' || *p == '\\') {
        rc = path_to_dir(dst, parent);
        if (rc)
            return rc;
        memcpy(name11, sn, 11);
        return FR_OK;
    }
    rc = path_split(dst, parent, name11);
    if (rc)
        return rc;
    if (is_dot_name(name11))
        return FR_INVALID_NAME;
    if (fat_dir_open(parent))
        return FR_DISK_ERR;
    if (dir_find_try(name11) == 0 && (fat_dir_ptr[11] & AM_DIR)) {
        *parent = fat_found_sclust;
        memcpy(name11, sn, 11);
    }
    return FR_OK;
}

/* Split path, refuse . / .., open the parent, find the leaf. 0 = found. */
static uint8_t open_leaf(const char *path, uint32_t *parent, uint8_t *n)
{
    uint8_t rc;

    rc = path_split(path, parent, n);
    if (rc)
        return rc;
    if (is_dot_name(n))
        return FR_INVALID_NAME;
    if (fat_dir_open(parent))
        return FR_DISK_ERR;
    if (dir_find_try(n))
        return FR_NO_FILE;
    return FR_OK;
}

/* 1 if the directory contains only . / .. (and deleted / LFN / volume). */
static uint8_t dir_is_empty(uint32_t clst)
{
    uint8_t ent[32];

    if (fat_dir_open(&clst))
        return 0;
    while (fat_dir_read(ent) == 0) {
        if (ent[0] == 0)
            break;
        if (ent[0] == 0xE5 || ent[11] == AM_LFN || (ent[11] & AM_VOL))
            continue;
        if (ent[0] == '.' && (ent[1] == ' ' || (ent[1] == '.' && ent[2] == ' ')))
            continue;
        return 0;
    }
    return 1;
}

static uint8_t dir_fill(uint8_t attr, uint32_t clst, uint32_t size)
{
    uint8_t *e = fat_dir_ptr;

    e[11] = attr;
    e[20] = (uint8_t)(clst >> 16);
    e[21] = (uint8_t)(clst >> 24);
    e[26] = (uint8_t)clst;
    e[27] = (uint8_t)(clst >> 8);
    e[28] = (uint8_t)size;
    e[29] = (uint8_t)(size >> 8);
    e[30] = (uint8_t)(size >> 16);
    e[31] = (uint8_t)(size >> 24);
    fat_dirty();
    return fat_sync();
}

static uint8_t zero_cluster(uint32_t clst, uint32_t parent)
{
    uint32_t lba;
    uint8_t s, nsec;
    uint8_t *e;

    lba = clst;
    if (fat_clst2sect(&lba))
        return 1;
    memset(buffer, 0, 512);
    e = (uint8_t *)buffer;
    e[0] = '.';
    memset(e + 1, ' ', 10);
    e[11] = AM_DIR;
    e[20] = (uint8_t)(clst >> 16);
    e[21] = (uint8_t)(clst >> 24);
    e[26] = (uint8_t)clst;
    e[27] = (uint8_t)(clst >> 8);
    e[32] = '.';
    e[33] = '.';
    memset(e + 34, ' ', 9);
    e[43] = AM_DIR;
    if (parent == root_clst())
        parent = 0;
    e[52] = (uint8_t)(parent >> 16);
    e[53] = (uint8_t)(parent >> 24);
    e[58] = (uint8_t)parent;
    e[59] = (uint8_t)(parent >> 8);
    if (disk_write(0, buffer, lba, 1))
        return 1;
    memset(buffer, 0, 512);
    nsec = cpm_fat_vol.csize;
    for (s = 1; s < nsec; ++s)
        if (disk_write(0, buffer, lba + s, 1))
            return 1;
    return 0;
}

static void release_chain(uint32_t clst)
{
    if (clst >= 2) {
        fat_free(&clst);
        fat_sync();
    }
}

static uint8_t copy_file(uint32_t src, uint32_t size, uint32_t *out_first, uint32_t *out_size)
{
    uint32_t last = 0, first = 0, lbas, lbad, nxt, remain, chunk, steps;
    uint8_t s, nsec;

    *out_first = 0;
    *out_size = 0;
    if (size == 0)
        return 0;
    remain = size;
    steps = 0;
    while (remain) {
        /* A cyclic chain would otherwise repeat clusters until size is
         * exhausted and the new name would be stamped with those bytes.
         */
        if (steps >= cpm_fat_vol.n_fatent) {
            release_chain(first);
            return 1;
        }
        ++steps;
        if (src < 2 || is_eoc(src)) {
            release_chain(first);
            return 1;
        }
        lbas = src;
        if (fat_clst2sect(&lbas)) {
            release_chain(first);
            return 1;
        }
        nxt = last;
        if (fat_alloc(&nxt)) {
            release_chain(first);
            return 1;
        }
        if (first == 0)
            first = nxt;
        last = nxt;
        lbad = nxt;
        if (fat_clst2sect(&lbad)) {
            release_chain(first);
            return 1;
        }
        nsec = cpm_fat_vol.csize;
        for (s = 0; s < nsec && remain; ++s) {
            if (disk_read(0, buffer, lbas + s, 1) ||
                disk_write(0, buffer, lbad + s, 1)) {
                release_chain(first);
                return 1;
            }
            chunk = (remain > 512) ? 512 : remain;
            remain -= chunk;
        }
        if (remain == 0)
            break;
        nxt = src;
        if (fat_next(&nxt)) {
            release_chain(first);
            return 1;
        }
        if (is_eoc(nxt))
            break;
        src = nxt;
    }
    if (first == 0)
        return 1;
    *out_first = first;
    *out_size = size - remain;
    if (fat_sync()) {
        release_chain(first);
        return 1;
    }
    return 0;
}

/* Named FatFs FRESULT (ChaN). rc=0 is silent. */
void put_rc(uint8_t rc)
{
    static const char names[] =    /* ROM string table; not a stack copy */
        "OK\0DISK_ERR\0INT_ERR\0NOT_READY\0NO_FILE\0NO_PATH\0"
        "INVALID_NAME\0DENIED\0EXIST\0INVALID_OBJECT\0WRITE_PROTECTED\0"
        "INVALID_DRIVE\0NOT_ENABLED\0NO_FILESYSTEM\0MKFS_ABORTED\0"
        "TIMEOUT\0LOCKED\0NOT_ENOUGH_CORE\0TOO_MANY_OPEN_FILES\0"
        "INVALID_PARAMETER";
    const char *p;
    uint8_t i;

    if (rc == 0)
        return;
    if (rc > FR_INVALID_PARAMETER) {
        fprintf(error, "\nrc=%u\n", rc);
        return;
    }
    p = names;
    for (i = 0; i < rc; ++i) {
        while (*p)
            ++p;
        ++p;
    }
    fprintf(error, "\nFR_%s\n", p);
}

static uint8_t put_fail(uint8_t rc)
{
    if (rc)
        put_rc(rc);
    return rc;
}

static uint8_t need_args(char **args, uint8_t n, const char *cmd)
{
    uint8_t i;

    for (i = 1; i <= n; ++i) {
        if (args[i] == NULL) {
            fprintf(output, "Expected %u argument(s) to \"%s\"\n", n, cmd);
            return 1;
        }
    }
    return 0;
}

static char *hist_slot(uint8_t i)
{
    return hist_ring + (uint16_t)i * HIST_LEN;
}

static uint8_t hist_skip_store(const char *s)
{
    while (*s == ' ' || *s == '\t')
        ++s;
    if (*s == 0)
        return 1;
    if (s[0] == 'e' && s[1] == 'x' && s[2] == 'i' && s[3] == 't' &&
        (s[4] == 0 || s[4] == ' ' || s[4] == '\t'))
        return 1;
    return 0;
}

static void hist_store(const char *line)
{
    uint8_t last, n;

    if (hist_ring == NULL || hist_skip_store(line))
        return;
    if (hist_used) {
        last = (uint8_t)((hist_i + HIST_MAX - 1) % HIST_MAX);
        if (strcmp(hist_slot(last), line) == 0)
            return;
    }
    n = 0;
    while (line[n] && n < HIST_LEN - 1) {
        hist_slot(hist_i)[n] = line[n];
        ++n;
    }
    hist_slot(hist_i)[n] = 0;
    hist_i = (uint8_t)((hist_i + 1) % HIST_MAX);
    if (hist_used < HIST_MAX)
        ++hist_used;
}

static void line_redraw(char *line, uint16_t *pos, uint16_t maxlen, const char *src)
{
    uint16_t old, n, i;

    old = *pos;
    n = 0;
    while (src[n] && n < maxlen) {
        line[n] = src[n];
        ++n;
    }
    line[n] = 0;
    /* The Z80 console swallows CR. Back up over "> " and the old text. */
    for (i = 0; i < old + 2; ++i)
        fputc(KEY_BS, output);
    fprintf(output, "> %s", line);
    if (old > n) {
        for (i = 0; i < old - n; ++i)
            fputc(KEY_SPACE, output);
        for (i = 0; i < old - n; ++i)
            fputc(KEY_BS, output);
    }
    *pos = n;
}

static void hist_up(char *line, uint16_t *pos, uint16_t maxlen)
{
    uint8_t idx;

    if (hist_ring == NULL || hist_used == 0)
        return;
    if (hist_off == 0 && hist_draft) {
        uint16_t n = *pos;
        if (n >= LINE_SIZE)
            n = LINE_SIZE - 1;
        memcpy(hist_draft, line, n);
        hist_draft[n] = 0;
    }
    if (hist_off < hist_used)
        ++hist_off;
    idx = (uint8_t)((hist_i + HIST_MAX - hist_off) % HIST_MAX);
    line_redraw(line, pos, maxlen, hist_slot(idx));
}

static void hist_down(char *line, uint16_t *pos, uint16_t maxlen)
{
    uint8_t idx;

    if (hist_ring == NULL || hist_off == 0)
        return;
    --hist_off;
    if (hist_off == 0)
        line_redraw(line, pos, maxlen, hist_draft ? hist_draft : "");
    else {
        idx = (uint8_t)((hist_i + HIST_MAX - hist_off) % HIST_MAX);
        line_redraw(line, pos, maxlen, hist_slot(idx));
    }
}

static void put_hex(uint16_t v, uint8_t digits)
{
    uint8_t n;
    char c;

    n = digits;
    while (n) {
        --n;
        c = (char)((v >> (n << 2)) & 0x0F);
        c += (c < 10) ? '0' : ('A' - 10);
        fputc(c, output);
    }
}

void put_dump (const uint8_t * buff, uint16_t ofs, uint8_t cnt)
{
    uint8_t i;

    put_hex(ofs, 4);
    fputc(':', output);

    for(i = 0; i < cnt; ++i) {
        fputc(' ', output);
        put_hex(buff[i], 2);
    }
    fputc(' ', output);
    for(i = 0; i < cnt; ++i) {
        fputc((buff[i] >= ' ' && buff[i] <= '~') ? buff[i] : '.', output);
    }
    fputc('\n', output);
}


/*
  Builtin function implementations (CLI user functions, ya_*).
*/

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "cpm". args[1..4] are .CPM container files.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mkcpm(char ** args)   /* initialise CP/M with up to 4 container files */
{
    uint8_t i;
    uint8_t n11[11];
    uint32_t parent, cl, prev, lba;

    if (args[1] == NULL) {
        fprintf(output, "Expected 1 to 4 arguments to \"cpm\"\n");
        return 1;
    }
    if (fat_mount()) {
        put_rc(1);
        return 1;
    }

    for (i = 0; i < 4; ++i)
        cpm_dsk0_base[i] = 0;

    for (i = 0; i < 4 && args[i + 1] != NULL; ++i) {
        fprintf(output, "Opening \"%s\"", args[i + 1]);
        if (put_fail(open_leaf(args[i + 1], &parent, n11)))
            return 1;
        if (fat_dir_ptr[11] & AM_DIR) {
            put_rc(FR_DENIED);
            return 1;
        }
        cl = fat_found_sclust;
        if (cl < 2) {
            put_rc(FR_INT_ERR);
            return 1;
        }
        prev = 0;
        while (is_eoc(cl) == 0) {
            if (prev && cl != prev + 1) {
                fprintf(output, " is fragmented\n");
                return 1;
            }
            prev = cl;
            if (put_fail(fat_next(&cl)))
                return 1;
        }
        lba = fat_found_sclust;
        if (put_fail(fat_clst2sect(&lba)))
            return 1;
        cpm_dsk0_base[i] = lba;
        fprintf(output, " at LBA %lu\n", lba);
    }

    fprintf(output, "Initialised CP/M\n");
    cpu_delay_ms(1);
    cpm_boot();
    return 1;
}


/*
 * Intel HEX receive. ascii-xfr -s sends CRLF lines and -e may send
 * Ctrl-Z. A type 04 record selects the 64 KB page. Data records must
 * follow the file in order. One sector is held in `buffer`. These
 * values are shared by hg_open, hg_wr, hg_record, and hg_commit.
 */
static uint32_t hg_parent;
static uint32_t hg_clst;
static uint32_t hg_first;
static uint32_t hg_lba;
static uint32_t hg_tmp;
static uint32_t hg_sz;
static uint16_t hg_page;
static uint16_t hg_low;
static uint16_t hg_pos;
static uint16_t hg_bpage;
static uint16_t hg_addr;
static int hg_v;
static uint8_t hg_name[11];
static uint8_t hg_have;
static uint8_t hg_sec;
static uint8_t hg_sum;
static uint8_t hg_n;
static uint8_t hg_typ;
static uint8_t hg_rc;

static uint8_t hg_commit(void)
{
    if (hg_have && hg_pos) {
        if (disk_write(0, buffer, hg_lba, 1))
            return 1;
    }
    if (fat_dir_open(&hg_parent))
        return 1;
    if (dir_find_try(hg_name))
        return 1;
    hg_sz = (uint32_t)hg_page << 16;
    hg_sz |= hg_low;
    return dir_fill(AM_ARC, hg_first, hg_sz);
}

/* Append one file byte. A full sector is written on the next byte. */
static uint8_t hg_wr(uint8_t val)
{
    if (hg_page >= 0x100)
        return 1;
    if (hg_pos == 512) {
        if (disk_write(0, buffer, hg_lba, 1))
            return 1;
        hg_pos = 0;
        if (++hg_sec >= cpm_fat_vol.csize) {
            hg_have = 0;
            hg_sec = 0;
        } else
            ++hg_lba;
    }
    if (hg_have == 0) {
        if (cpm_fat_vol.csize == 0)
            return 1;
        hg_tmp = hg_first ? hg_clst : 0;
        if (fat_alloc(&hg_tmp))
            return 1;
        if (hg_first == 0) {
            hg_first = hg_tmp;
            if (hg_commit())
                return 1;
        }
        hg_clst = hg_tmp;
        if (fat_clst2sect(&hg_tmp))
            return 1;
        hg_lba = hg_tmp;
        hg_sec = 0;
        hg_pos = 0;
        hg_have = 1;
    }
    if (hg_pos == 0)
        memset(buffer, 0, 512);
    ((uint8_t *)buffer)[hg_pos++] = val;
    if (++hg_low == 0)
        ++hg_page;
    return 0;
}

static uint8_t hg_open(const char *path)
{
    hg_page = 0;
    hg_low = 0;
    hg_pos = 0;
    hg_bpage = 0;
    hg_have = 0;
    hg_sec = 0;
    hg_first = 0;
    hg_clst = 0;
    hg_rc = path_split(path, &hg_parent, hg_name);
    if (hg_rc)
        return hg_rc;
    if (is_dot_name(hg_name))
        return FR_INVALID_NAME;
    if (fat_dir_open(&hg_parent))
        return FR_DISK_ERR;
    if (dir_find_try(hg_name) == 0) {
        if (fat_dir_ptr[11] & (AM_DIR | AM_RDO))
            return FR_DENIED;
        hg_tmp = fat_found_sclust;
        if (dir_fill(AM_ARC, 0, 0))
            return FR_DISK_ERR;
        if (hg_tmp >= 2 && (fat_free(&hg_tmp) || fat_sync()))
            return FR_DISK_ERR;
        return 0;
    }
    if (dir_create(hg_name) || dir_fill(AM_ARC, 0, 0))
        return FR_DISK_ERR;
    return 0;
}

static int hg_nibble(void)
{
    int c;

    c = fgetc(input);
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

static int hg_hexbyte(void)
{
    int h;
    int l;

    h = hg_nibble();
    if (h < 0)
        return -1;
    l = hg_nibble();
    if (l < 0)
        return -1;
    h = (h << 4) | l;
    hg_sum = (uint8_t)(hg_sum + (uint8_t)h);
    return h;
}

static uint8_t hg_colon(void)
{
    int c;

    for (;;) {
        c = fgetc(input);
        if (c == ':')
            return 0;
        if (c == EOF || c == 26)
            return 1;
    }
}

static uint8_t hg_next(void)
{
    hg_v = hg_hexbyte();
    return (hg_v < 0) ? 2 : 0;
}

static uint8_t hg_take(uint8_t n, uint8_t store)
{
    while (n) {
        if (hg_next())
            return 2;
        if (store && hg_wr((uint8_t)hg_v))
            return 4;
        --n;
    }
    return 0;
}

static uint8_t hg_cksum(uint8_t end)
{
    if (hg_next())
        return 2;
    return hg_sum ? 3 : end;
}

/* 0 more, 1 end, 2 bad hex, 3 checksum, 4 disk or offset. */
static uint8_t hg_record(void)
{
    if (hg_colon())
        return 1;
    hg_sum = 0;
    if (hg_next())
        return 2;
    hg_n = (uint8_t)hg_v;
    if (hg_next())
        return 2;
    hg_addr = (uint16_t)((uint16_t)hg_v << 8);
    if (hg_next())
        return 2;
    hg_addr |= (uint8_t)hg_v;
    if (hg_next())
        return 2;
    hg_typ = (uint8_t)hg_v;
    if (hg_typ == 0) {
        if (hg_addr != hg_low || hg_bpage != hg_page)
            return 4;
        hg_rc = hg_take(hg_n, 1);
        if (hg_rc)
            return hg_rc;
    } else if (hg_typ == 4) {
        if (hg_n != 2)
            return 2;
        if (hg_next())
            return 2;
        hg_addr = (uint16_t)((uint16_t)hg_v << 8);
        if (hg_next())
            return 2;
        hg_bpage = (uint16_t)(hg_addr | (uint8_t)hg_v);
    } else {
        hg_rc = hg_take(hg_n, 0);
        if (hg_rc)
            return hg_rc;
        if (hg_typ == 1)
            return hg_cksum(1);
    }
    return hg_cksum(0);
}

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "hget". args[1] is the file.
   @return Always returns 1, to continue executing.
 */
int8_t ya_hget(char ** args)   /* receive an Intel HEX file */
{
    if (need_args(args, 1, "hget"))
        return 1;
    if (put_fail(hg_open(args[1])))
        return 1;
    fputs("Waiting for Intel HEX\n", output);
    fflush(output);
    cpu_delay_ms(1);
    do {
        hg_rc = hg_record();
    } while (hg_rc == 0);
    if (hg_commit() || hg_rc == 4)
        put_rc(1);
    else if (hg_rc != 1)
        fputs("bad hex\n", error);
    else
        fprintf(output, "%lu bytes\n", hg_sz);
    return 1;
}

/*
 * mkdrv NAME
 *
 * One container for the rc2014-8MB disk definition: 8388608 bytes and
 * 2048 directory entries. The BIOS uses that shape, so the command
 * takes a file name and nothing else.
 *
 * fat_alloc takes the next free cluster. The file may be several runs.
 * frag prints the run count. cpm mounts a file only when it is one run.
 *
 * The directory is 2048 records of 32 bytes, which is 65536 bytes and
 * exactly 128 sectors. Each sector is 16 copies of the empty record
 * (0xE5, eleven spaces, then zeros). The remaining clusters are
 * allocated and left untouched.
 *
 * directoryBlock is a ROM constant. The counters below are only
 * used inside ya_mkdrv. They stay file-scope: sccz80 builds a stack
 * frame at every branch once a function has an automatic, and that
 * frame pushes the 8085 PATA image past 32768 bytes.
 */
static uint8_t directoryBlock[32] = {
    0xE5, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

static uint32_t md_ncl, md_clst, md_1st, md_lba;
static uint16_t md_left;
static uint8_t md_sec, md_n;
static uint8_t *md_p;

/* 0: the name is gone. Same order as ya_rm and ChaN f_unlink:
 * remove the directory entry, sync, and only then free the chain.
 */
static uint8_t md_unlink(void)
{
    if (fat_dir_open(&hg_parent))
        return 1;
    if (dir_find_try(hg_name))
        return 1;
    if (dir_zap() || fat_sync())
        return 1;
    return 0;
}

static void md_abandon(uint32_t clst)
{
    if (md_unlink() == 0)
        release_chain(clst);
}

static int8_t md_incomplete(void)
{
    fputs("\nCP/M Directory Extents incomplete", output);
    md_abandon(md_1st);
    put_rc(1);
    return 1;
}

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "mkdrv". args[1] is the file.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mkdrv(char ** args)   /* empty 8 MB CP/M drive */
{
    if (need_args(args, 1, "mkdrv"))
        return 1;
    fprintf(output, "Creating \"%s\"", args[1]);
    if (put_fail(hg_open(args[1])))
        return 1;

    /* Round 8388608 bytes up to whole clusters. 0 means this volume
     * has no cluster size, or the count overflowed.
     */
    md_ncl = 8388608ul;
    fat_clusters(&md_ncl);
    if (md_ncl == 0) {
        md_unlink();
        put_rc(FR_INVALID_PARAMETER);
        return 1;
    }

    md_clst = 0;
    md_1st = 0;
    while (md_ncl) {
        if (fat_alloc(&md_clst)) {
            md_abandon(md_1st);
            fputs("\nInsufficient space", output);
            put_rc(1);
            return 1;
        }
        if (md_1st == 0)
            md_1st = md_clst;
        --md_ncl;
    }

    /* FAT writes move the sector window, so the entry from hg_open
     * has to be found again before it can be stamped.
     */
    if (fat_dir_open(&hg_parent) || dir_find_try(hg_name) ||
        dir_fill(AM_ARC, md_1st, 8388608ul)) {
        md_abandon(md_1st);
        put_rc(1);
        return 1;
    }

    md_p = buffer;
    md_n = 16;
    while (md_n) {
        memcpy(md_p, directoryBlock, 32);
        md_p += 32;
        --md_n;
    }

    md_clst = md_1st;
    md_lba = md_1st;
    if (fat_clst2sect(&md_lba))
        return md_incomplete();
    md_sec = 0;
    md_left = 128;
    while (md_left) {
        if (disk_write(0, buffer, md_lba, 1))
            return md_incomplete();
        --md_left;
        if (md_left == 0)
            break;
        /* Sectors inside one cluster are consecutive LBAs.
         * The next cluster is the FAT link, which may not be adjacent.
         */
        if (++md_sec < cpm_fat_vol.csize) {
            ++md_lba;
            continue;
        }
        md_sec = 0;
        if (fat_next(&md_clst) || is_eoc(md_clst))
            return md_incomplete();
        md_lba = md_clst;
        if (fat_clst2sect(&md_lba))
            return md_incomplete();
    }

    md_lba = md_1st;
    if (put_fail(fat_clst2sect(&md_lba)))
        return 1;
    fprintf(output, " at base sector LBA %lu\n", md_lba);
    return 1;
}

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "md". args[1] is an optional origin in hexadecimal.
   @return Always returns 1, to continue executing.
 */
int8_t ya_md(char ** args)      /* dump RAM contents from nominated origin. */
{
    static uint8_t * origin = 0;   /* next page, remembered across md */
    uint16_t ofs;
    uint8_t * ptr;

    if (args[1] != NULL) {
        origin = (uint8_t *)strtoul(args[1], NULL, 16);
    }

    fputc('\n', output);
    fprintf(output, "Origin: ");
    put_hex((uint16_t)origin, 4);
    fputc('\n', output);

    for (ptr=origin, ofs = 0; ofs < 0x100; ptr += 16, ofs += 16) {
        put_dump(ptr, ofs, 16);
    }

    origin += 0x100;            /* go to next page (next time) */
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "help".
   @return Always returns 1, to continue executing.
 */
int8_t ya_help(char ** args)    /* print some help. */
{
    uint8_t i;
    (void *)args;

    fprintf(output,"RC2014 - CP/M IDE Shell v2.6\n");
    fprintf(output,"The following functions are built in:\n");

    for (i = 0; i < ya_num_builtins(); ++i) {
        fprintf(output,"  %s %s\n", builtins[i].name, builtins[i].help);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "exit".
   @return Always returns 0, to terminate execution.
 */
int8_t ya_exit(char ** args)    /* exit and restart */
{
    (void *)args;

    return 0;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "ls". args[1] is an optional path.
   @return Always returns 1, to continue executing.
 */
int8_t ya_ls(char ** args)      /* print directory contents */
{
    uint32_t clst, p1;
    uint16_t s1, s2;
    uint8_t ent[32];
    uint8_t attr, i;

    if (args[1] == NULL) {
        clst = fat_cwd;
        if (clst < 2)
            clst = root_clst();
    } else if (put_fail(path_to_dir(args[1], &clst)))
        return 1;

    if (fat_dir_open(&clst)) {
        put_rc(1);
        return 1;
    }

    p1 = s1 = s2 = 0;
    while (fat_dir_read(ent) == 0) {
        if (ent[0] == 0)
            break;
        if (ent[0] == 0xE5)
            continue;
        attr = ent[11];
        if (attr == AM_LFN || (attr & AM_VOL))
            continue;
        if (attr & AM_DIR)
            s2++;
        else {
            s1++;
            p1 += (uint32_t)ent[28] | ((uint32_t)ent[29] << 8) |
                  ((uint32_t)ent[30] << 16) | ((uint32_t)ent[31] << 24);
        }
        fprintf(output, "%c%c%c%c%c %lu  ",
                (attr & AM_DIR) ? 'D' : '-',
                (attr & AM_RDO) ? 'R' : '-',
                (attr & AM_HID) ? 'H' : '-',
                (attr & AM_SYS) ? 'S' : '-',
                (attr & AM_ARC) ? 'A' : '-',
                (uint32_t)ent[28] | ((uint32_t)ent[29] << 8) |
                ((uint32_t)ent[30] << 16) | ((uint32_t)ent[31] << 24));
        for (i = 0; i < 8 && ent[i] != ' '; ++i)
            put_vis(ent[i]);
        if (ent[8] != ' ') {
            fputc('.', output);
            for (i = 8; i < 11 && ent[i] != ' '; ++i)
                put_vis(ent[i]);
        }
        fputc('\n', output);
    }
    fprintf(output, "%u File(s), %lu bytes total\n%u Dir(s)", s1, p1, s2);
    p1 = 0;
    if (put_fail(fat_getfree(&p1))) {
        fputc('\n', output);
        return 1;
    }
    /* bytes = clusters * sectors/cluster * 512 */
    fprintf(output, ", %lu bytes free\n",
            (p1 * (uint32_t)cpm_fat_vol.csize) << 9);
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "cd".  args[1] is the directory.
   @return Always returns 1, to continue executing.
 */
int8_t ya_cd(char ** args)
{
    uint32_t clst;

    if (need_args(args, 1, "cd"))
        return 1;
    if (put_fail(path_to_dir(args[1], &clst)) == 0)
        fat_cwd = clst;
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "pwd".
   @return Always returns 1, to continue executing.
 */
int8_t ya_pwd(char ** args)     /* print the current working directory path */
{
    uint32_t clst, parent, child;
    uint8_t ent[32];
    char name[13];
    char *p;
    uint8_t found, n, attr;

    (void *)args;
    clst = fat_cwd;
    if (is_root_clst(clst)) {
        fprintf(output, "/\n");
        return 1;
    }
    p = (char *)buffer + BUFFER_SIZE - 1;
    *p = 0;
    for (;;) {
        if (is_root_clst(clst))
            break;
        if (fat_dir_open(&clst)) {
            put_rc(1);
            return 1;
        }
        found = 0;
        parent = 0;
        while (fat_dir_read(ent) == 0) {
            if (ent[0] == 0)
                break;
            if (ent[0] == 0xE5)
                continue;
            if (ent[0] != '.')
                continue;
            if (ent[1] != '.')
                continue;
            parent = ent_clst(ent);
            found = 1;
            break;
        }
        if (found == 0) {
            put_rc(1);
            return 1;
        }
        if (parent < 2)
            parent = root_clst();
        child = clst;
        if (fat_dir_open(&parent)) {
            put_rc(1);
            return 1;
        }
        found = 0;
        while (fat_dir_read(ent) == 0) {
            if (ent[0] == 0)
                break;
            if (ent[0] == 0xE5)
                continue;
            attr = ent[11];
            if (attr == AM_LFN)
                continue;
            if (attr & AM_VOL)
                continue;
            if (ent_clst(ent) != child)
                continue;
            sfn_to_name(name, ent);
            found = 1;
            break;
        }
        if (found == 0) {
            put_rc(1);
            return 1;
        }
        n = 0;
        while (name[n])
            ++n;
        if (p < (char *)buffer + (uint16_t)n + 2) {
            put_rc(FR_NOT_ENOUGH_CORE);
            return 1;
        }
        while (n) {
            --n;
            --p;
            *p = name[n];
        }
        --p;
        *p = '/';
        if (is_root_clst(parent))
            break;
        clst = parent;
    }
    if (*p == 0)
        fprintf(output, "/\n");
    else
        fprintf(output, "%s\n", p);
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "rm". args[1] is the file.
   @return Always returns 1, to continue executing.
 */
int8_t ya_rm(char ** args)
{
    uint32_t parent, clst;
    uint8_t n[11];

    if (need_args(args, 1, "rm"))
        return 1;
    if (put_fail(open_leaf(args[1], &parent, n)))
        return 1;
    if (fat_dir_ptr[11] & (AM_DIR | AM_RDO)) {
        put_rc(FR_DENIED);
        return 1;
    }
    clst = fat_found_sclust;
    if (dir_zap() || fat_sync()) {
        put_rc(1);
        return 1;
    }
    if (clst >= 2) {
        if (fat_free(&clst) || fat_sync())
            put_rc(1);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "rmdir". args[1] is the directory.
   @return Always returns 1, to continue executing.
 */
int8_t ya_rmdir(char ** args)
{
    uint32_t parent, clst;
    uint8_t n[11];

    if (need_args(args, 1, "rmdir"))
        return 1;
    if (put_fail(open_leaf(args[1], &parent, n)))
        return 1;
    if ((fat_dir_ptr[11] & AM_DIR) == 0) {
        put_rc(FR_NO_PATH);
        return 1;
    }
    clst = fat_found_sclust;
    if (clst == fat_cwd || dir_is_empty(clst) == 0) {
        put_rc(FR_DENIED);
        return 1;
    }
    if (fat_dir_open(&parent) || dir_find_try(n) || dir_zap() || fat_sync()) {
        put_rc(1);
        return 1;
    }
    if (clst >= 2) {
        if (fat_free(&clst) || fat_sync())
            put_rc(1);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "mkdir". args[1] is the path.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mkdir(char ** args)
{
    uint32_t parent, clst;
    uint8_t n[11];

    if (need_args(args, 1, "mkdir"))
        return 1;
    if (put_fail(path_split(args[1], &parent, n)) || put_fail(is_dot_name(n) ? FR_INVALID_NAME : 0))
        return 1;
    if (fat_dir_open(&parent)) {
        put_rc(1);
        return 1;
    }
    if (dir_find_try(n) == 0) {
        put_rc(FR_EXIST);
        return 1;
    }
    clst = 0;
    if (fat_alloc(&clst)) {
        put_rc(1);
        return 1;
    }
    if (fat_sync() || fat_dir_open(&parent) || dir_create(n)) {
        release_chain(clst);
        put_rc(1);
        return 1;
    }
    if (dir_fill(AM_DIR, clst, 0) || zero_cluster(clst, parent)) {
        dir_zap();
        release_chain(clst);
        put_rc(1);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "cp". args[1] src, args[2] dst.
   @return Always returns 1, to continue executing.
 */
int8_t ya_cp(char ** args)
{
    uint32_t sp, dp, src, size, first, copied, old;
    uint8_t sn[11], dn[11];
    uint8_t dest_exists;

    if (need_args(args, 2, "cp"))
        return 1;
    if (put_fail(open_leaf(args[1], &sp, sn)))
        return 1;
    if (fat_dir_ptr[11] & AM_DIR) {
        put_rc(FR_DENIED);
        return 1;
    }
    src = fat_found_sclust;
    size = fat_found_size;

    if (put_fail(dest_resolve(args[2], sn, &dp, dn)))
        return 1;
    if (sp == dp && memcmp(sn, dn, 11) == 0)
        return 1;
    if (copy_file(src, size, &first, &copied)) {
        put_rc(1);
        return 1;
    }
    if (fat_dir_open(&dp)) {
        release_chain(first);
        put_rc(1);
        return 1;
    }
    dest_exists = (uint8_t)(dir_find_try(dn) == 0);
    if (dest_exists) {
        if (fat_dir_ptr[11] & AM_DIR) {
            release_chain(first);
            put_rc(FR_DENIED);
            return 1;
        }
        old = fat_found_sclust;
        if (dir_fill(AM_ARC, first, copied)) {
            release_chain(first);
            put_rc(1);
            return 1;
        }
        /* The entry names the new chain. A free failure leaks the old
         * clusters instead of leaving the name on freed ones.
         */
        if (old >= 2 && (fat_free(&old) || fat_sync()))
            put_rc(1);
        return 1;
    }
    if (dir_create(dn) || dir_fill(AM_ARC, first, copied)) {
        release_chain(first);
        put_rc(1);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "mv". args[1] src, args[2] dst.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mv(char ** args)
{
    uint32_t sp, dp, sclust, ssize;
    uint8_t sn[11], dn[11], attr;

    if (need_args(args, 2, "mv"))
        return 1;
    if (put_fail(open_leaf(args[1], &sp, sn)))
        return 1;
    if (fat_dir_ptr[11] & AM_DIR) {
        put_rc(FR_DENIED);
        return 1;
    }
    attr = fat_dir_ptr[11];
    sclust = fat_found_sclust;
    ssize = fat_found_size;

    if (put_fail(dest_resolve(args[2], sn, &dp, dn)))
        return 1;
    if (sp == dp && memcmp(sn, dn, 11) == 0)
        return 1;
    if (fat_dir_open(&dp)) {
        put_rc(1);
        return 1;
    }
    if (dir_find_try(dn) == 0) {
        put_rc((fat_dir_ptr[11] & AM_DIR) ? FR_DENIED : FR_EXIST);
        return 1;
    }
    if (sp == dp) {
        if (fat_dir_open(&sp) || dir_find_try(sn)) {
            put_rc(1);
            return 1;
        }
        memcpy(fat_dir_ptr, dn, 11);
        fat_dirty();
        if (fat_sync())
            put_rc(1);
        return 1;
    }
    if (dir_create(dn) || dir_fill(attr, sclust, ssize)) {
        put_rc(1);
        return 1;
    }
    if (fat_dir_open(&sp) || dir_find_try(sn) || dir_zap() || fat_sync())
        put_rc(1);
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "mount".
   @return Always returns 1, to continue executing.
 */
int8_t ya_mount(char ** args)    /* mount a FAT file system */
{
    (void *)args;
    put_rc(fat_mount());
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "frag". args[1] is the file.
   @return Always returns 1, to continue executing.
 */
int8_t ya_frag(char ** args)    /* cluster-run count for a file */
{
    uint32_t parent, cl, prev, ncl, nfrag, steps;
    uint8_t n[11];

    if (need_args(args, 1, "frag"))
        return 1;
    if (put_fail(open_leaf(args[1], &parent, n)))
        return 1;
    if (fat_dir_ptr[11] & AM_DIR) {
        put_rc(FR_DENIED);
        return 1;
    }
    cl = fat_found_sclust;
    ncl = 0;
    nfrag = 0;
    prev = 0;
    if (cl >= 2) {
        nfrag = 1;
        steps = 0;
        while (is_eoc(cl) == 0) {
            if (steps >= cpm_fat_vol.n_fatent) {
                put_rc(FR_INT_ERR);
                return 1;
            }
            ++steps;
            ncl++;
            if (prev && cl != prev + 1)
                nfrag++;
            prev = cl;
            if (put_fail(fat_next(&cl)))
                return 1;
        }
    }
    fprintf(output, "%lu cluster(s), %lu run(s), %lu bytes\n",
            ncl, nfrag, fat_found_size);
    return 1;
}


/*
  disk related functions
 */


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "ds".
   @return Always returns 1, to continue executing.
 */
int8_t ya_ds(char ** args)      /* disk status */
{
    const uint8_t ft[] = {0, 12, 16, 32};
    uint32_t clst;
    uint8_t ent[32], i, labelled;

    (void *)args;
    if (cpm_fat_vol.fs_type == 0) {
        put_rc(fat_mount());
        if (cpm_fat_vol.fs_type == 0)
            return 1;
    }
    labelled = 0;
    clst = 0;
    if (cpm_fat_vol.fs_type == 3)
        clst = cpm_fat_vol.dirbase;
    if (fat_dir_open(&clst) == 0) {
        while (fat_dir_read(ent) == 0) {
            if (ent[0] == 0)
                break;
            if (ent[0] == 0xE5)
                continue;
            if ((ent[11] & AM_VOL) && ent[11] != AM_LFN) {
                fprintf(output, "Volume label = ");
                for (i = 0; i < 11; ++i) {
                    if (ent[i] != ' ')
                        put_vis(ent[i]);
                }
                fputc('\n', output);
                labelled = 1;
                break;
            }
        }
    }
    if (labelled == 0)
        fprintf(output, "Volume label = (none)\n");
    fprintf(output, "FAT type = FAT%u\nBytes/Cluster = %lu\nNumber of FATs = %u\n"
        "Root DIR entries = %u\nSectors/FAT = %lu\nNumber of clusters = %lu\n"
        "FAT start (lba) = %lu\nDIR start (lba,cluster) = %lu\nData start (lba) = %lu\n",
        ft[cpm_fat_vol.fs_type & 3], (uint32_t)cpm_fat_vol.csize * 512,
        cpm_fat_vol.n_fats, cpm_fat_vol.n_rootent, cpm_fat_vol.fatsz,
        cpm_fat_vol.n_fatent > 2 ? cpm_fat_vol.n_fatent - 2 : 0,
        cpm_fat_vol.fatbase, cpm_fat_vol.dirbase, cpm_fat_vol.database);
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "dd". args[1] is an optional sector.
   @return Always returns 1, to continue executing.
 */
int8_t ya_dd(char ** args)      /* disk dump */
{
    DRESULT res;
    static uint32_t sect;          /* next sector, remembered across dd */
    uint16_t ofs;
    uint8_t * ptr;

    if (args[1] != NULL) {
        sect = strtoul(args[1], NULL, 10);
    }

    res = disk_read(0, buffer, sect, 1);
    if (res != 0) { fprintf(output, "rc=%u\n", (uint8_t)res); return 1; }
    fprintf(output, "PD#:0 LBA:%lu\n", sect++);
    for (ptr=(uint8_t *)buffer, ofs = 0; ofs < 0x200; ptr += 16, ofs += 16)
        put_dump(ptr, ofs, 16);
    return 1;
}



/*
  main loop functions
 */


/**
   @brief Execute shell built-in function.
   @param args Null terminated list of arguments.
   @return 1 if the shell should continue running, 0 if it should terminate
 */
int8_t ya_execute(char ** args)
{
    uint8_t i;

    if (args[0] == NULL) {
        // An empty command was entered.
        return 1;
    }

    for (i = 0; i < ya_num_builtins(); ++i) {
        if (strcmp(args[0], builtins[i].name) == 0) {
            return (*builtins[i].func)(args);
        }
    }
    fprintf(output, "Unknown command: %s\n", args[0]);
    return 1;
}


/**
   @brief Read a line of input. Echo printable keys, BS/DEL edit, up/down history.
   @param line Destination buffer.
   @param len Maximum characters stored.
 */
void ya_getline(char * line, uint16_t len)
{
    static uint8_t last_eol;       /* previous CR or LF, across calls */
    int c;
    uint16_t position = 0;

    if (line == NULL || len == 0) {
        return;
    }

    hist_off = 0;
    line[0] = '\0';

    for (;;) {

        c = fgetc(input);

        if (c == EOF) {
            line[position] = '\0';
            return;
        }

        /* Do not echo BS/DEL at column 0: a serial terminal wraps. */
        if (c == KEY_BS || c == KEY_DEL) {
            if (position > 0) {
                line[--position] = '\0';
                fputc(KEY_BS, output);
                fputc(KEY_SPACE, output);
                fputc(KEY_BS, output);
            }
            continue;
        }

        if (c == KEY_CTRL_P) {
            hist_up(line, &position, len);
            continue;
        }
        if (c == KEY_CTRL_N) {
            hist_down(line, &position, len);
            continue;
        }

        if (c == KEY_ESC) {
            c = fgetc(input);
            if (c == EOF) {
                line[position] = '\0';
                return;
            }
            if (c == '[') {
                do {
                    c = fgetc(input);
                    if (c == EOF)
                        break;
                } while (c < 0x40 || c > 0x7E);
                if (c == 'A')
                    hist_up(line, &position, len);
                else if (c == 'B')
                    hist_down(line, &position, len);
            } else if (c == 'O') {
                c = fgetc(input);
                if (c == 'A')
                    hist_up(line, &position, len);
                else if (c == 'B')
                    hist_down(line, &position, len);
            }
            continue;
        }

        if (c == KEY_LF || c == KEY_CR) {
            /* CR+LF (or LF+CR) is one terminator; the sibling would
               otherwise become an empty next command. */
            if (position == 0 && last_eol != 0 && (uint8_t)c != last_eol) {
                last_eol = 0;
                continue;
            }
            last_eol = (uint8_t)c;
            line[position] = '\0';
            fputc('\n', output);
            return;
        }

        /* Drop NUL / XON / other non-text. A pending 0 sits at
           line[0] and strtok treats the whole command as empty. */
        if (c < KEY_SPACE || c > 126) {
            continue;
        }

        if (position >= len) {
            continue;
        }

        line[position++] = (char)c;
        line[position] = '\0';
        fputc(c, output);
    }
}


/**
   @brief Split a line into tokens. strtok mutates the line.
   @param tokens Destination NULL-terminated list.
   @param line Line to split.
 */
void ya_split_line(char ** tokens, char * line)
{
    uint16_t position = 0;
    char * token;

    if (tokens && line) {
        token = strtok(line, TOK_DELIM);

        while ((token != NULL) && (position < TOK_BUFSIZE-1)) {
            tokens[position++] = token;
            token = strtok(NULL, TOK_DELIM);
        }

        tokens[position] = NULL;
    }
}


/**
   @brief Allocate buffers, then loop getting input and executing it.
 */
void ya_loop(void)
{
    int8_t status;
    uint16_t len = LINE_SIZE-1;

    char * line = (char *)malloc(LINE_SIZE * sizeof(char));
    if (line == NULL) return;

    char ** args = (char **)malloc(TOK_BUFSIZE * sizeof(char*));
    if (args == NULL) {
        free(line);
        return;
    }

    hist_ring = (char *)malloc((uint16_t)HIST_MAX * HIST_LEN);
    hist_draft = (char *)malloc(LINE_SIZE);
    hist_used = 0;
    hist_i = 0;

    select_console();

    do {
        fflush(input);
        fprintf(output,"\n> ");

        ya_getline(line, len);
        hist_store(line);
        ya_split_line(args, line);

        status = ya_execute(args);

    } while (status);

    free(hist_draft);
    free(hist_ring);
    hist_draft = NULL;
    hist_ring = NULL;
    free(args);
    free(line);
}
