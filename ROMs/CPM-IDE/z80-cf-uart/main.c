/***************************************************************************//**

  @file         main.c
  @author       Phillip Stevens, inspired by Stephen Brennan
  @brief        YASH (Yet Another SHell)

  This RC2014 programme reached working state March 2025.

*******************************************************************************/

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/compiler.h>

#include <arch.h>
#include <arch/rc2014.h>

#include "ffconf.h"
#include <lib/rc2014/ff.h>

#include <arch/rc2014/diskio.h>

// PRAGMA DEFINES
#pragma output REGISTER_SP = 0xDB00     // below the CP/M CCP
#pragma printf = "%c %s %d %u %lu %X"   // enables %c, %s, %d, %u, %lu, %X only

// DEFINES

#define BUFFER_SIZE 512         // size of working buffer (on heap)
#define LINE_SIZE 256           // size of a command line (on heap)
#define TOK_BUFSIZE 64          // size of token pointer buffer (on heap)

#define TOK_DELIM " \t\r\n\a"

// GLOBALS

extern uint32_t cpm_dsk0_base[4];
extern uint8_t  bios_iobyte;

static void * buffer;           /* create a scratch buffer on heap later */

static FATFS * fs;              /* Pointer to the filesystem object (on heap) */
                                /* FatFs work area needed for each volume */

static FIL file;                /* File object needed for each open file */

static FILE * input;            /* defined input */
static FILE * output;           /* defined output */
static FILE * error;            /* defined error */

/*
  Function Declarations for built-in shell commands:
 */

// CP/M related functions
int8_t ya_mkcpm(char ** args);  // initialise CP/M with up to 4 drives
int8_t ya_hload(char ** args);  // load an Intel HEX CP/M file and run it

// system related functions
int8_t ya_md(char ** args);     // memory dump
int8_t ya_help(char ** args);   // help
int8_t ya_exit(char ** args);   // exit and restart

// fat related functions
int8_t ya_frag(char ** args);   // check file for fragmentation
int8_t ya_ls(char ** args);     // directory listing
int8_t ya_cd(char ** args);     // change the current working directory
int8_t ya_pwd(char ** args);    // show the current working directory
int8_t ya_mount(char ** args);  // mount a FAT file system

// disk related functions
int8_t ya_ds(char ** args);     // disk status
int8_t ya_dd(char ** args);     // disk dump sector

// helper functions
static void put_rc (FRESULT rc);    // print error codes to defined error IO
static void put_dump (const uint8_t * buff, uint16_t ofs, uint8_t cnt);

// external functions

extern uint8_t uarta_reset(void) __preserves_regs(b,c,d,e,h,iyl,iyh);   // UARTA flush routine
extern uint8_t uarta_pollc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);   // UARTA polling routine, checks UARTA buffer fullness
extern uint8_t uarta_getc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);    // UARTA receive routine, from UARTA buffer
extern uint8_t uartb_reset(void) __preserves_regs(b,c,d,e,h,iyl,iyh);   // UARTB flush routine
extern uint8_t uartb_pollc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);   // UARTB polling routine, checks UARTB buffer fullness
extern uint8_t uartb_getc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);    // UARTB receive routine, from UARTB buffer

extern void cpm_boot(void) __preserves_regs(a,b,c,d,e,h,iyl,iyh);   // initialise cpm
extern void hexload(void) __preserves_regs(a,b,c,d,e,h,iyl,iyh);    // initialise cpm and launch Intel HEX program in TPA

/*
  List of builtin commands.
 */

struct Builtin {
    const char * name;
    int8_t (*func) (char ** args);
    const char * help;
};

struct Builtin builtins[] = {
  // CP/M related functions
    { "cpm", &ya_mkcpm, "file.a [file.b] [file.c] [file.d] - initiate CP/M with up to 4 drive files"},
    { "hload", &ya_hload, "- load an Intel HEX CP/M file and run it"},

// fat related functions
    { "frag", &ya_frag, "[file] - check for file fragmentation"},
    { "ls", &ya_ls, "[path] - directory listing"},
    { "cd", &ya_cd, "[path] - change the current working directory"},
    { "pwd", &ya_pwd, "- show the current working directory"},
    { "mount", &ya_mount, "[option] - mount a FAT file system"},

// disk related functions
    { "ds", &ya_ds, "- disk status"},
    { "dd", &ya_dd, "[sector] - disk dump, sector in decimal"},

// system related functions
    { "md", &ya_md, "[origin] - memory dump, origin in hexadecimal"},
    { "help", &ya_help, "- this is it"},
    { "exit", &ya_exit, "- exit and restart"}
};

uint8_t ya_num_builtins(void) {
    return sizeof(builtins) / sizeof(struct Builtin);
}


/*
  Builtin function implementations.
*/


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "cpm".  args[1][2][3][4] are names of drive files.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mkcpm(char ** args)   /* initialise CP/M with up to 4 drives */
{
    FRESULT res;
    uint8_t i = 0;

    if (args[1] == NULL) {
        fprintf(output, "Expected 4 arguments to \"cpm\"\n");
    } else {
        res = f_mount(fs, (const TCHAR*)"0:", 0);
        if (res != FR_OK) { put_rc(res); return 1; }

        // set up (up to 4) CPM drive LBA locations
        while(args[i+1] != NULL)
        {
            fprintf(output,"Opening \"%s\"", args[i+1]);
            res = f_open(&file, (const TCHAR *)args[i+1], FA_OPEN_EXISTING | FA_READ);
            if (res != FR_OK) { put_rc(res); return 1; }
            cpm_dsk0_base[i] = (&file)->obj.fs->database + ((&file)->obj.fs->csize * ((&file)->obj.sclust - 2));
            fprintf(output," at LBA %lu\n", cpm_dsk0_base[i]);
            f_close(&file);
            i++;                // go to next file
        }
        fprintf(output,"Initialised CP/M\n");
        cpm_boot();
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "hload".
   @return Always returns 1, to continue executing.
 */
int8_t ya_hload(char ** args)   /* load an Intel HEX CP/M file and run it */
{
    (void *)args;

    fprintf(output,"Waiting for Intel HEX CP/M command on console\n");

    hexload();

    return 1;
}


/*
  system related functions
 */


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "md". args[1] is the origin address.
   @return Always returns 1, to continue executing.
 */
int8_t ya_md(char ** args)      /* dump RAM contents from nominated origin. */
{
    static uint8_t * origin = 0;
    uint16_t ofs;
    uint8_t * ptr;

    if (args[1] != NULL) {
        origin = (uint8_t *)strtoul(args[1], NULL, 16);
    }

    fprintf(output, "\nOrigin: %04X\n", (uint16_t)origin);

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

    fprintf(output,"RC2014 - CP/M IDE Shell v2.4\n");
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

    f_mount(0, (const TCHAR*)"", 0);    /* Unmount the default drive */
    return 0;
}


/*
  fat related functions
 */


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "frag".  args[1] is the name of the file.
   @return Always returns 1, to continue executing.
 */
int8_t ya_frag(char ** args)    /* check file for fragmentation */
{
    FRESULT res;
    DWORD clst, clsz, step;
    FSIZE_t fsz;

    if (args[1] == NULL) {
        fprintf(output, "Expected 1 argument to \"frag\"\n");
    } else {

        fprintf(output,"Checking \"%s\"", args[1]);
        res = f_open(&file, (const TCHAR *)args[1], FA_OPEN_EXISTING | FA_READ);
        if (res != FR_OK) { put_rc(res); return 1; }

        fsz = f_size(&file);                                    /* File size */
        clsz = (DWORD)(&file)->obj.fs->csize * FF_MAX_SS;       /* Cluster size */
        if (fsz > 0) {                                          /* Check file size non-zero */
            clst = (&file)->obj.sclust - 1;                     /* An initial cluster leading the first cluster for first test */
            while (fsz) {                                       /* Check clusters are contiguous */
                step = (fsz >= clsz) ? clsz : (DWORD)fsz;
                res = f_lseek(&file, f_tell(&file) + step);     /* Advances file pointer a cluster */
                if (res != FR_OK) { put_rc(res); return 1; }
                if (clst + 1 != (&file)->clust) break;          /* Is not the cluster next to previous one? */
                clst = (&file)->clust; fsz -= step;             /* Get current cluster for next test */
            }
            fprintf(output," at LBA %lu", (&file)->obj.fs->database + ((&file)->obj.fs->csize * ((&file)->obj.sclust - 2)));
            if (fsz == 0) {                                     /* All checked contiguous without fail? */
                fprintf(output," is OK\n");
            } else {
                fprintf(output," is fragmented\n");
            }
        }

        f_close(&file);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "ls".  args[1] is the path.
   @return Always returns 1, to continue executing.
 */
int8_t ya_ls(char ** args)      /* print directory contents */
{
    DIR dir;                    /* Stack Directory Object */
    FRESULT res;
    uint32_t p1;
    uint16_t s1, s2;

    static FILINFO Finfo;       /* Static File Information */

    if(args[1] == NULL) {
        res = f_opendir(&dir, (const TCHAR*)".");
    } else {
        res = f_opendir(&dir, (const TCHAR*)args[1]);
    }
    if (res != FR_OK) { put_rc(res); return 1; }

    p1 = s1 = s2 = 0;
    while(1) {
        res = f_readdir(&dir, &Finfo);
        if ((res != FR_OK) || !Finfo.fname[0]) break;
        if (Finfo.fattrib & AM_DIR) {
            s2++;
        } else {
            s1++; p1 += Finfo.fsize;
        }
        fprintf(output, "%c%c%c%c%c %u/%02u/%02u %02u:%02u %9lu  %s\n",
                (Finfo.fattrib & AM_DIR) ? 'D' : '-',
                (Finfo.fattrib & AM_RDO) ? 'R' : '-',
                (Finfo.fattrib & AM_HID) ? 'H' : '-',
                (Finfo.fattrib & AM_SYS) ? 'S' : '-',
                (Finfo.fattrib & AM_ARC) ? 'A' : '-',
                (Finfo.fdate >> 9) + 1980, (Finfo.fdate >> 5) & 15, Finfo.fdate & 31,
                (Finfo.ftime >> 11), (Finfo.ftime >> 5) & 63,
                (DWORD)Finfo.fsize, Finfo.fname);
    }
    fprintf(output, "%4u File(s),%10lu bytes total\n%4u Dir(s)", s1, p1, s2);

    if(args[1] == NULL) {
        res = f_getfree((const TCHAR*)".", (DWORD*)&p1, &fs);
    } else {
        res = f_getfree((const TCHAR*)args[1], (DWORD*)&p1, &fs);
    }
    if (res == FR_OK) {
        fprintf(output, ", %10lu bytes free\n", p1 * (DWORD)(fs->csize * 512));
    } else {
        put_rc(res);
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "cd".  args[1] is the directory.
   @return Always returns 1, to continue executing.
 */
int8_t ya_cd(char ** args)
{
    if (args[1] == NULL) {
        fprintf(output, "Expected 1 argument to \"cd\"\n");
    } else {
        put_rc(f_chdir((const TCHAR*)args[1]));
    }
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "pwd".
   @return Always returns 1, to continue executing.
 */
int8_t ya_pwd(char ** args)     /* show the current working directory */
{
    FRESULT res;
    (void *)args;

    uint8_t * directory = (uint8_t *)malloc(sizeof(uint8_t)*LINE_SIZE);     /* Get area for directory name buffer */

    if (directory != NULL) {
        res = f_getcwd((char *)directory, sizeof(uint8_t)*LINE_SIZE);
        if (res != FR_OK) {
            put_rc(res);
        } else {
            fprintf(output, "%s", directory);
        }
        free(directory);
    }

    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "mount". args[1] is the option byte.
   @return Always returns 1, to continue executing.
 */
int8_t ya_mount(char ** args)    /* mount a FAT file system */
{
    if (args[1] == NULL) {
        put_rc(f_mount(fs, (const TCHAR*)"0:", 0));
    } else {
        put_rc(f_mount(fs, (const TCHAR*)"0:", atoi(args[1])));
    }
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
    FRESULT res;
    int32_t p1;
    const uint8_t ft[] = {0, 12, 16, 32};   // FAT type

    (void *)args;

    res = f_getfree((const TCHAR*)"", (DWORD*)&p1, &fs);
    if (res != FR_OK) { put_rc(res); return 1; }

    fprintf(output, "FAT type = FAT%u\nBytes/Cluster = %lu\nNumber of FATs = %u\n"
        "Root DIR entries = %u\nSectors/FAT = %lu\nNumber of clusters = %lu\n"
        "Volume start (lba) = %lu\nFAT start (lba) = %lu\nDIR start (lba,cluster) = %lu\nData start (lba) = %lu\n",
        ft[fs->fs_type & 3], (DWORD)(fs->csize * 512), fs->n_fats,
        fs->n_rootdir, fs->fsize, (DWORD)fs->n_fatent - 2,
        fs->volbase, fs->fatbase, fs->dirbase, fs->database);
    return 1;
}


/**
   @brief Builtin command:
   @param args List of args.  args[0] is "dd". args[1] is the sector in decimal.
   @return Always returns 1, to continue executing.
 */
int8_t ya_dd(char ** args)      /* disk dump */
{
    FRESULT res;
    static uint32_t sect;
    uint16_t ofs;
    uint8_t * ptr;

    if (args[1] != NULL) {
        sect = strtoul(args[1], NULL, 10);
    }

    res = disk_read(0, buffer, sect, 1);
    if (res != FR_OK) { fprintf(output, "rc=%d\n", (WORD)res); return 1; }
    fprintf(output, "PD#:0 LBA:%lu\n", sect++);
    for (ptr=(uint8_t *)buffer, ofs = 0; ofs < 0x200; ptr += 16, ofs += 16)
        put_dump(ptr, ofs, 16);
    return 1;
}


/*
  helper functions
 */

/*  use put_rc to get a plain text interpretation of the disk return or error code. */
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

    for (i = 0; i != res && *str; ++i) {
        while (*str++) ;
    }
    fprintf(error,"\nrc=%u FR_%s\n", res, str);
}


static
void put_dump (const uint8_t * buff, uint16_t ofs, uint8_t cnt)
{
    uint8_t i;

    fprintf(output,"%04X:", ofs);

    for(i = 0; i < cnt; ++i) {
        fprintf(output," %02X", buff[i]);
    }
    fputc(' ', output);
    for(i = 0; i < cnt; ++i) {
        fputc((buff[i] >= ' ' && buff[i] <= '~') ? buff[i] : '.', output);
    }
    fputc('\n', output);
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
    return 1;
}


/**
   @brief Split a line into tokens (very naively).
   @param tokens, null terminated array of token pointers.
   @param line, the line.
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
   @brief Loop getting input and executing it.
 */
void ya_loop(void)
{
    int8_t status;
    uint16_t len = LINE_SIZE-1;

    char * line = (char *)malloc(LINE_SIZE * sizeof(char));    /* Get work area for the line buffer */
    if (line == NULL) return;

    char ** args = (char **)malloc(TOK_BUFSIZE * sizeof(char*));    /* Get tokens buffer ready */
    if (args == NULL) return;

    while (1){                                          /* look for ":" to select the valid serial port */
        if (uarta_pollc() != 0) {
            if (uarta_getc() == ':') {
                input = stdin;
                output = stdout;
                error = stderr;
                bios_iobyte = 1;
                break;
            } else {
                uarta_reset();
            }
        }
        if (uartb_pollc() != 0) {
            if (uartb_getc() == ':') {
                input = ttyin;
                output = ttyout;
                error = ttyerr;
                bios_iobyte = 0;
                break;
            } else {
                uartb_reset();
            }
        }
    }

    fprintf(output," :-)\n");

    do {
        fflush(input);
        fprintf(output,"\n> ");

        getline(&line, &len, input);
        ya_split_line(args, line);

        status = ya_execute(args);

    } while (status);

    free(args);
    free(line);
}


/**
   @brief Main entry point.
   @param argc Argument count.
   @param argv Argument vector.
   @return status code
 */
int main(int argc, char ** argv)
{
    (void)argc;
    (void *)argv;

    FRESULT res;

    fs = (FATFS *)malloc(sizeof(FATFS));                    /* Get work area for the volume */
    buffer = (char *)malloc(BUFFER_SIZE * sizeof(char));    /* Get working buffer space */

    fprintf(stdout, "\n\nRC2014 - CP/M-IDE - CF - UART\nfeilipu 2025\n\n> :?");
    fprintf(ttyout, "\n\nRC2014 - CP/M-IDE - CF - UART\nfeilipu 2025\n\n> :?");

    // Run command loop if we got all the memory allocations we need.
    if (fs && buffer) {
        if(res = f_mount(fs, (const TCHAR*)"0:", 0) != 0) put_rc(res);
        ya_loop();
    }

    // Perform any shutdown/cleanup.
    free(buffer);
    free(fs);

    return 0;
}

