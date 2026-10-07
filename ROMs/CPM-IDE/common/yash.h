#ifndef CPM_IDE_YASH_H
#define CPM_IDE_YASH_H

#include <stdint.h>
#include <stdio.h>

#define BUFFER_SIZE 512
#define LINE_SIZE   256
#define TOK_BUFSIZE 64
#define TOK_DELIM   " \t\r\n\a"

#define KEY_BS      8
#define KEY_LF      10
#define KEY_CR      13
#define KEY_CTRL_N  14
#define KEY_CTRL_P  16
#define KEY_ESC     27
#define KEY_SPACE   32
#define KEY_DEL     127

#define HIST_MAX    8
#define HIST_LEN    80

extern void *buffer;
extern FILE *input;
extern FILE *output;
extern FILE *error;

/* Per-tree: pick stdin/tty and set bios_iobyte. */
void select_console(void);

/* Named FatFs FRESULT (ChaN). rc=0 is silent. */
void put_rc(uint8_t rc);

int8_t ya_mkcpm(char **args);
int8_t ya_mkdrv(char **args);
int8_t ya_hget(char **args);
int8_t ya_md(char **args);
int8_t ya_help(char **args);
int8_t ya_exit(char **args);
int8_t ya_ls(char **args);
int8_t ya_cd(char **args);
int8_t ya_pwd(char **args);
int8_t ya_rm(char **args);
int8_t ya_rmdir(char **args);
int8_t ya_mkdir(char **args);
int8_t ya_cp(char **args);
int8_t ya_mv(char **args);
int8_t ya_mount(char **args);
int8_t ya_ds(char **args);
int8_t ya_dd(char **args);
int8_t ya_frag(char **args);
int8_t ya_execute(char **args);
void ya_getline(char *line, uint16_t len);
void ya_split_line(char **tokens, char *line);
void ya_loop(void);
uint8_t ya_num_builtins(void);

#endif
