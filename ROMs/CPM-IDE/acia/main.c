/***************************************************************************//**

  @file         main.c
  @author       Phillip Stevens, inspired by Stephen Brennan
  @brief        YASH (Yet Another SHell)

  This RC2014 programme was reached working state on St Patrick's Day 2018.

*******************************************************************************/

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <arch.h>
#include <arch/rc2014.h>
#include <arch/rc2014/diskio.h>

#include "ffconf.h"
#include <lib/rc2014/ff.h>

// PRAGMA DEFINES
#pragma output REGISTER_SP = 0xD800
#pragma printf = "%c %s %d %u %lu %X"  // enables %c, %s, %d, %u, %lu, %X only 

// DEFINES

#define MAX_FILES 1             // number of files open at any time
#define BUFFER_SIZE 1024        // size of working buffer (on heap)
#define LINE_SIZE 256           // size of a command line (on heap)

static void * buffer;           /* create a scratch buffer on heap later */

static FATFS *fs;               /* Pointer to the filesystem object (on heap) */
static DIR *dir;                /* Pointer to the directory object (on heap) */

static FILINFO Finfo;           /* File Information */
static FIL File[MAX_FILES];     /* File object needed for each open file */

extern uint32_t cpm_dsk0_base[4];

/*
  Function Declarations for builtin shell commands:
 */

// CP/M related functions
int8_t ya_mkcpmb(char **args);  // initialise CP/M with up to 4 drives

// system related functions
int8_t ya_md(char **args);      // memory dump
int8_t ya_help(char **args);    // help
int8_t ya_exit(char **args);    // exit and restart

// fat related functions
int8_t ya_ls(char **args);      // directory listing
int8_t ya_mount(char **args);   // mount a FAT file system

// disk related functions
int8_t ya_ds(char **args);      // disk status
int8_t ya_dd(char **args);      // disk dump sector

// helper functions
static void put_rc (FRESULT rc);        // print error codes to defined error IO
static void put_dump (const uint8_t *buff, uint32_t ofs, uint8_t cnt);

// external functions

extern void cpm_boot(void) __preserves_regs(a,b,c,d,e,h,iyl,iyh);  // initialise cpm

/*
  List of builtin commands.
 */
struct Builtin {
  const char *name;
  int8_t (*func) (char** args);
  const char *help;
};

struct Builtin builtins[] = {
  // CP/M related functions
    { "cpm", &ya_mkcpmb, "[file][][][] - initiate CP/M with up to 4 drive files"},

// system related functions
    { "md", &ya_md, "- [origin] - memory dump"},
    { "help", &ya_help, "- this is it"},
    { "exit", &ya_exit, "- exit and restart"},

// fat related functions
    { "mount", &ya_mount, "[option] - mount a FAT file system"},
    { "ls", &ya_ls, "[path] - directory listing"},

// disk related functions
    { "ds", &ya_ds, " - disk status"},
    { "dd", &ya_dd, "[sector] - disk dump, sector in decimal"},
};

uint8_t ya_num_builtins() {
  return sizeof(builtins) / sizeof(struct Builtin);
}


/*
  Builtin function implementations.
*/


// CP/M related functions

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "cpm".  args[1][2][3][4] are names of drive files.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mkcpmb(char **args)   // initialise CP/M with up to 4 drives
{
    FRESULT res;
    uint8_t i = 0;

    if (args[1] == NULL) {
        fprintf(stdout, "Expected 4 arguments to \"cpm\"\n");
    } else {
        res = f_mount(fs, (const TCHAR*)"", 0);
        if (res != FR_OK) { put_rc(res); return 1; }

        // set up (up to 4) CPM drive LBA locations
        while(args[i+1] != NULL)
        {
            fprintf(stdout,"Opening \"%s\"", args[i+1]);
            res = f_open(&File[0], (const TCHAR *)args[i+1], FA_OPEN_EXISTING | FA_READ);
            if (res != FR_OK) { put_rc(res); return 1; }
            cpm_dsk0_base[i] = (&File[0])->obj.fs->database + ((&File[0])->obj.fs->csize * ((&File[0])->obj.sclust - 2));
            fprintf(stdout," at LBA %lu\n", cpm_dsk0_base[i]);
            f_close(&File[0]);
            i++;                // go to next file
        }
        fprintf(stdout,"Initialised CP/M\n");
        cpm_boot();
    }
    return 1;
}


// system related functions

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "md". args[1] is the origin address.
   @return Always returns 1, to continue executing.
 */
int8_t ya_md(char **args)       // dump RAM contents from nominated bank from nominated origin.
{
    static uint8_t * origin;
    static uint8_t bank;
    uint32_t ofs;
    uint8_t * ptr;

    if (args[1] != NULL) {
        origin = (uint8_t *)strtoul(args[1], NULL, 16);
    }

    memcpy(buffer, (void *)origin, 0x100); // grab a page
    fprintf(stdout, "\nOrigin: %04X\n", (uint16_t)origin);
    origin += 0x100;                       // go to next page (next time)

    for (ptr=(uint8_t *)buffer, ofs = 0; ofs < 0x100; ptr += 16, ofs += 16) {
        put_dump(ptr, ofs, 16);
    }
    return 1;
}


/**
   @brief Builtin command: help.
   @param args List of args.  args[0] is "help".
   @return Always returns 1, to continue executing.
 */
int8_t ya_help(char **args)
{
    uint8_t i;
    (void *)args;

    fprintf(stdout,"RC2014 - CP/M IDE Monitor v1.0\n");
    fprintf(stdout,"The following functions are built in:\n");

    for (i = 0; i < ya_num_builtins(); ++i) {
        fprintf(stdout,"  %s %s\n", builtins[i].name, builtins[i].help);
    }

    return 1;
}


/**
   @brief Builtin command: exit.
   @param args List of args.  args[0] is "exit".
   @return Always returns 0, to terminate execution.
 */
int8_t ya_exit(char **args)
{
    (void *)args;
    f_mount(0, (const TCHAR*)"", 0);        /* Unmount the default drive */
    return 0;
}


// fat related functions

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "ls".  args[1] is the path.
   @return Always returns 1, to continue executing.
 */
int8_t ya_ls(char **args)
{
    FRESULT res;
    uint32_t p1;
    uint16_t s1, s2;

    res = f_mount(fs, (const TCHAR*)"", 0);
    if (res != FR_OK) { put_rc(res); return 1; }

    if(args[1] == NULL) {
        res = f_opendir(dir, (const TCHAR*)".");
    } else {
        res = f_opendir(dir, (const TCHAR*)args[1]);
    }
    if (res != FR_OK) { put_rc(res); return 1; }

    p1 = s1 = s2 = 0;
    while(1) {
        res = f_readdir(dir, &Finfo);
        if ((res != FR_OK) || !Finfo.fname[0]) break;
        if (Finfo.fattrib & AM_DIR) {
            s2++;
        } else {
            s1++; p1 += Finfo.fsize;
        }
        fprintf(stdout, "%c%c%c%c%c %u/%02u/%02u %02u:%02u %9lu  %s\n",
                (Finfo.fattrib & AM_DIR) ? 'D' : '-',
                (Finfo.fattrib & AM_RDO) ? 'R' : '-',
                (Finfo.fattrib & AM_HID) ? 'H' : '-',
                (Finfo.fattrib & AM_SYS) ? 'S' : '-',
                (Finfo.fattrib & AM_ARC) ? 'A' : '-',
                (Finfo.fdate >> 9) + 1980, (Finfo.fdate >> 5) & 15, Finfo.fdate & 31,
                (Finfo.ftime >> 11), (Finfo.ftime >> 5) & 63,
                (DWORD)Finfo.fsize, Finfo.fname);
    }
    fprintf(stdout, "%4u File(s),%10lu bytes total\n%4u Dir(s)", s1, p1, s2);

    if(args[1] == NULL) {
        res = f_getfree( (const TCHAR*)".", (DWORD*)&p1, &fs);
    } else {
        res = f_getfree( (const TCHAR*)args[1], (DWORD*)&p1, &fs);
    }
    if (res == FR_OK) {
        fprintf(stdout, ", %10lu bytes free\n", p1 * fs->csize * 512);
    } else {
        put_rc(res);
    }

    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "mount". args[1] is the option byte.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mount(char **args)    // mount a FAT file system
{
    if (args[1] == NULL) {
        put_rc(f_mount(fs, (const TCHAR*)"", 0));
    } else {
        put_rc(f_mount(fs, (const TCHAR*)"", atoi(args[1])));
    }
    return 1;
}


// disk related functions

/**
   @brief Builtin command:
   @param args List of args.  args[0] is "ds".
   @return Always returns 1, to continue executing.
 */
int8_t ya_ds(char **args)       // disk status
{
    FRESULT res;
    int32_t p1;
    const uint8_t ft[] = {0, 12, 16, 32};   // FAT type
    (void *)args;

    res = f_getfree( (const TCHAR*)"", (DWORD*)&p1, &fs);
    if (res != FR_OK) { put_rc(res); return 1; }

    fprintf(stdout, "FAT type = FAT%u\nBytes/Cluster = %lu\nNumber of FATs = %u\n"
        "Root DIR entries = %u\nSectors/FAT = %lu\nNumber of clusters = %lu\n"
        "Volume start (lba) = %lu\nFAT start (lba) = %lu\nDIR start (lba,cluster) = %lu\nData start (lba) = %lu\n",
        ft[fs->fs_type & 3], (DWORD)fs->csize * 512, fs->n_fats,
        fs->n_rootdir, fs->fsize, (DWORD)fs->n_fatent - 2,
        fs->volbase, fs->fatbase, fs->dirbase, fs->database);
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "dd". args[1] is the sector in decimal.
   @return Always returns 1, to continue executing.
 */
int8_t ya_dd(char **args)       // disk dump
{
    FRESULT res;
    static uint32_t sect;
    uint32_t ofs;
    uint8_t * ptr;

    if (args[1] != NULL ) {
        sect = strtoul(args[1], NULL, 10);
    }

    res = disk_read( 0, buffer, sect, 1);
    if (res != FR_OK) { fprintf(stdout, "rc=%d\n", (WORD)res); return 1; }
    fprintf(stdout, "PD#:0 LBA:%lu\n", sect++);
    for (ptr=(uint8_t *)buffer, ofs = 0; ofs < 0x200; ptr += 16, ofs += 16)
        put_dump(ptr, ofs, 16);
    return 1;
}


// helper functions

static
void put_rc (FRESULT rc)
{
    const char *str =
        "OK\0" "DISK_ERR\0" "INT_ERR\0" "NOT_READY\0" "NO_FILE\0" "NO_PATH\0"
        "INVALID_NAME\0" "DENIED\0" "EXIST\0" "INVALID_OBJECT\0" "WRITE_PROTECTED\0"
        "INVALID_DRIVE\0" "NOT_ENABLED\0" "NO_FILE_SYSTEM\0" "MKFS_ABORTED\0" "TIMEOUT\0"
        "LOCKED\0" "NOT_ENOUGH_CORE\0" "TOO_MANY_OPEN_FILES\0" "INVALID_PARAMETER\0";

    FRESULT i;
    uint8_t res;

    res = (uint8_t)rc;

    for (i = 0; i != res && *str; i++) {
        while (*str++) ;
    }
    fprintf(stderr,"\r\nrc=%u FR_%s\r\n", res, str);
}


static
void put_dump (const uint8_t *buff, uint32_t ofs, uint8_t cnt)
{
    uint8_t i;

    fprintf(stdout,"%08lX:", ofs);

    for(i = 0; i < cnt; i++) {
        fprintf(stdout," %02X", buff[i]);
    }
    fputc(' ', stdout);
    for(i = 0; i < cnt; i++) {
        fputc((buff[i] >= ' ' && buff[i] <= '~') ? buff[i] : '.', stdout);
    }
    fputc('\n', stdout);
}


/**
   @brief Execute shell built-in function.
   @param args Null terminated list of arguments.
   @return 1 if the shell should continue running, 0 if it should terminate
 */
int8_t ya_execute(char **args)
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

    return 1;
}

#define YA_TOK_BUFSIZE 32
#define YA_TOK_DELIM " \t\r\n\a"
/**
   @brief Split a line into tokens (very naively).
   @param line The line.
   @return Null-terminated array of tokens.
 */
char **ya_split_line(char *line)
{
    uint16_t bufsize = YA_TOK_BUFSIZE;
    uint16_t position = 0;
    char *token;
    char **tokens, **tokens_backup;

    tokens = (char **)malloc(bufsize * sizeof(char*));

    if (tokens && line)
    {
        token = strtok(line, YA_TOK_DELIM);
        while (token != NULL) {
            tokens[position] = token;
            position++;

            // If we have exceeded the tokens buffer, reallocate.
            if (position >= bufsize) {
                bufsize += YA_TOK_BUFSIZE;
                tokens_backup = tokens;
                tokens = (char **)realloc(tokens, bufsize * sizeof(char*));
                if (tokens == NULL) {
                    free(tokens_backup);
                    fprintf(stdout, "yash: tokens realloc failure\n");
                    exit(EXIT_FAILURE);
                }
            }

            token = strtok(NULL, YA_TOK_DELIM);
        }
        tokens[position] = NULL;
    }
    return tokens;
}

/**
   @brief Loop getting input and executing it.
 */
void ya_loop(void)
{
    char **args;
    int status;
    char *line;
    uint16_t len;

    line = (char *)malloc(LINE_SIZE * sizeof(char));    /* Get work area for the line buffer */
    if (line == NULL) return;

    len = LINE_SIZE;

    do {
        fprintf(stdout,"\n> ");
        fflush(stdin);

        getline(&line, &len, stdin);
        args = ya_split_line(line);

        status = ya_execute(args);
        free(args);

    } while (status);
}


/**
   @brief Main entry point.
   @param argc Argument count.
   @param argv Argument vector.
   @return status code
 */
void main(int argc, char **argv)
{
    (void)argc;
    (void *)argv;

    fs = (FATFS *)malloc(sizeof(FATFS));                    /* Get work area for the volume */
    dir = (DIR *)malloc(sizeof(DIR));                       /* Get work area for the directory */
    buffer = (char *)malloc(BUFFER_SIZE * sizeof(char));    /* Get working buffer space */

    // Load config files, if any.

    fprintf(stdout, "\n\nRC2014 CP/M-IDE\nfeilipu 2019\n\n> :-)\n");
 
    // Run command loop if we got all the memory allocations we need.
    if ( fs && dir && buffer)
        ya_loop();

    // Perform any shutdown/cleanup.
    free(buffer);
    free(dir);
    free(fs);

    return;
}

