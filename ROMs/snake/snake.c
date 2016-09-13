/***********************************************************************************
 *
 *  Snake game for RC2014 homebrew computer
 *
 *  This game is designed to run with an ANSI-capable terminal emulator
 *  like PiGFX.
 *
 *  Can be controlled by keyboard (wasd keys) or the Z80 input port 0x01:
 *    1 - up
 *    2 - down
 *    4 - left
 *    8 - right
 *
 *
 *  The MIT License (MIT)
 *  Copyright (c) 2016 Filippo Bergamasco
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is furnished to do
 * so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 *
 **********************************************************************************/

#include "rc2014.h"
#include "pigfx.h"

//#pragma output CRT_ORG_CODE = 122
#pragma output REGISTER_SP  = -1
#pragma output CLIB_MALLOC_HEAP_SIZE = 0

#define FIELD_CHAR 'F'
#define SNAKE_COLOR 48
#define FIELD_COLOR 248
#define BG_COLOR 0
#define APPLE_COLOR 160
#define FIELD_W 78
#define FIELD_H 55
#define LOOP_DELAY 5000
#define SCORE_PER_APPLE 10

unsigned char field[FIELD_W * FIELD_H];

struct {
    int i;
    int j;
} snake_head;

struct {
    int i;
    int j;
} snake_tail;

unsigned int score;
unsigned int rnd_x = 4;
unsigned int rnd_y = 113;
unsigned int rnd_z = 543;
unsigned int rnd_w = 11;

unsigned int xorshift128() {
    unsigned int t = rnd_x;
    t ^= t << 11;
    t ^= t >> 8;
    rnd_x = rnd_y;
    rnd_y = rnd_z;
    rnd_z = rnd_w;
    rnd_w ^= rnd_w >> 19;
    rnd_w ^= t;
    return rnd_w;
}

void new_apple()
{
    unsigned int apple_i;
    unsigned int apple_j;
    unsigned int apple_idx;

    while (1)
    {
        apple_i = (xorshift128() % (FIELD_H - 3)) + 2;
        apple_j = (xorshift128() % (FIELD_H - 3)) + 2;

        apple_idx = apple_i * FIELD_W + apple_j;

        if (field[apple_idx] == 0)
        {
            field[apple_idx] = 'A';
            pigfx_movecursor(apple_i + 1, apple_j + 1);
            pigfx_bgcol(APPLE_COLOR);
            rc2014_putc(' ');
            return;
        }
    }
}


void initialize()
{
    int i;
    int j;
    int head_idx;
    int tail_idx;
    unsigned char* pfield = field;

    score = 0;

    pigfx_cls();
    pigfx_hide_cursor();

    pigfx_bgcol(FIELD_COLOR);
    // Top
    pigfx_movecursor(1, 1);
    pfield = field;

    for (i = 0; i < FIELD_W; ++i)
    {
        rc2014_putc(' ');
        *pfield++ = FIELD_CHAR;
    }

    // Left-Right
    for (i = 1; i < FIELD_H - 1; ++i)
    {
        pigfx_bgcol(FIELD_COLOR);
        pigfx_movecursor(i + 1, 1);

        rc2014_putc(' ');
        *pfield++ = FIELD_CHAR;

        pigfx_bgcol(BG_COLOR);
        for (j = 1; j < FIELD_W - 1; ++j)
        {
            rc2014_putc(' ');
            *pfield++ = 0;
        }

        pigfx_bgcol(FIELD_COLOR);
        rc2014_putc(' ');
        *pfield++ = FIELD_CHAR;
    }

    // Bottom
    pigfx_movecursor(FIELD_H, 1);
    for (i = 0; i < FIELD_W; ++i)
    {
        rc2014_putc(' ');
        *pfield++ = FIELD_CHAR;
    }

    // Snake
    pigfx_bgcol(SNAKE_COLOR);

    snake_head.i = FIELD_H / 2;
    snake_head.j = FIELD_W / 2;
    snake_tail.i = snake_head.i + 2;
    snake_tail.j = snake_head.j;
    head_idx = snake_head.i * FIELD_W + snake_head.j;
    field[head_idx] = 'U';
    field[head_idx+FIELD_W] = 'U';
    field[head_idx+FIELD_W+FIELD_W] = 'U';

    pigfx_movecursor(snake_head.i + 1, snake_head.j + 1);
    rc2014_putc(' ');
    pigfx_movecursor(snake_head.i + 2, snake_head.j + 1);
    rc2014_putc(' ');
    pigfx_movecursor(snake_head.i + 3, snake_head.j + 1);
    rc2014_putc(' ');

    new_apple();

    // Credits/Help
    pigfx_bgcol(BG_COLOR);
    pigfx_movecursor(FIELD_H + 1, 1);
    pigfx_fgcol(SNAKE_COLOR);
    pigfx_print("  *RC2014 SNAKE*  ");
    pigfx_fgcol(15);
    pigfx_print("Filippo Bergamasco 2016");
    pigfx_movecursor(FIELD_H + 2, 1);
    pigfx_print("w:up, s:down, a:left, d:right, n:new game, p:pause");
    pigfx_movecursor(FIELD_H + 1, 50);
    update_score(score);
}

int update_score() {
  pigfx_print("SCORE: ");
  pigfx_printnum(score);
}

int update_snake()
{
    int head_idx = snake_head.i * FIELD_W + snake_head.j;
    int tail_idx = snake_tail.i * FIELD_W + snake_tail.j;
    unsigned char c_head = field[head_idx];
    unsigned char keepsize = 1;

    switch(c_head)
    {
        case 'U':
            head_idx -= FIELD_W;
            snake_head.i--;
            break;

        case 'D':
            head_idx += FIELD_W;
            snake_head.i++;
            break;

        case 'L':
            head_idx--;
            snake_head.j--;
            break;

        case 'R':
            head_idx++;
            snake_head.j++;
            break;
    }

    if (field[head_idx] == 'A')
    {
        keepsize = 0;
        score += SCORE_PER_APPLE;
        pigfx_bgcol(BG_COLOR);
        pigfx_movecursor(FIELD_H + 1, 50);
        update_score(score);
    }
    else
    {
        if (field[head_idx] != 0)
        {
            return 0;
        }
    }

    pigfx_bgcol(SNAKE_COLOR);
    field[head_idx] = c_head;
    pigfx_movecursor(snake_head.i + 1, snake_head.j + 1);
    rc2014_putc(' ');

    if (keepsize)
    {
        c_head = field[tail_idx];
        field[tail_idx] = 0;
        pigfx_bgcol(BG_COLOR);
        pigfx_movecursor(snake_tail.i + 1, snake_tail.j + 1);
        rc2014_putc(' ');

        switch(c_head)
        {
            case 'U':
                snake_tail.i--;
                break;

            case 'D':
                snake_tail.i++;
                break;

            case 'L':
                snake_tail.j--;
                break;

            case 'R':
                snake_tail.j++;
                break;
        }
    }
    else
    {
        new_apple();
    }

    return 1;
}

void main()
{
    char usercommand;
    int  head_idx;

    initialize();

    while (!rc2014_pollc() || rc2014_getc() != 'n')
        rnd_x++;

    while (1)
    {
        if (update_snake() == 0)
        {
            pigfx_movecursor(FIELD_H / 2, FIELD_W / 2 - 5);
            pigfx_print("GAME OVER!");
            while (rc2014_getc() != 'n') ;
            initialize();
            continue;
        }

        usercommand = 0; // none
        usercommand = rc2014_inp(0x01);

        if (rc2014_pollc())
        {
            usercommand = rc2014_getc();
        }

        head_idx = snake_head.i * FIELD_W + snake_head.j;

        switch(usercommand)
        {
            case 'w':
            case 'W':
            case 1:
                if (field[head_idx] != 'D')
                    field[head_idx] = 'U';
                break;

            case 'd':
            case 'D':
            case 8:
                if (field[head_idx] != 'L')
                    field[head_idx] = 'R';
                break;

            case 'a':
            case 'A':
            case 4:
                if (field[head_idx] != 'R')
                    field[head_idx] = 'L';
                break;

            case 's':
            case 'S':
            case 2:
                if (field[head_idx] != 'U')
                    field[head_idx] = 'D';
                break;

            case 'n':
            case 'N':
                initialize();
                continue;

            case 'p':
            case 'P':
                while (1)
                  if (rc2014_pollc() && rc2014_getc() == 'p')
                      break;
                break;

            case 0:
                // do nothing
                break;

            break;
        }

        // DELAY LOOP
#asm
        push af
        push bc
        ld BC, $5000 ;@ ~0.5 sec loop
DELY:   NOP
        DEC BC
        LD A,B
        OR C
        JP NZ, DELY

        pop bc
        pop af
#endasm

    }
}
