/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/*
 * main.c
 * Copyright (C) 2017 Christian <hcl@web.de>
 *
 * btc is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * btc is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    int option, c, i;
    char *u="0";
    FILE *in_stream;
    unsigned int length,sum;
    char v[]="Binary to CP/M converter v0.2";
    
    while ((option = getopt(argc, argv, "hu:")) >= 0)
        switch (option)
    {
        case 'h' : printf("%s\nConverts a CP/M file to a .hex file to use it with Grant Searle's download.com.\n\nUsage: %s input-file [-u user-number, default 0] [-h help]\n", v, argv[0]);
            printf("Examples: %s mbasic.com -u1 > mbasic.hex\n", argv[0]);
            printf("          %s zork1.dat\n", argv[0]);
            break;
        case 'u' : u=optarg;
            break;
        case '?' : return(1);
    }
    
    if (argc < 2)
    {
        printf("%s\n\nMissing file name.\n",v);
        return (1);
    }
    
    for (i=optind; i<argc; i++)
    {
        if ((in_stream = fopen(argv[i], "r")) == NULL)
        {
            fprintf(stderr, "%s: Can't open file '%s' for ""input: ", argv[0], argv[i]);
            perror("");
            return (1);
        }
        length=0;
        sum=0;
        printf("A:DOWNLOAD %s\r\nU%s\r\n:",argv[i],u);
        while ((c=fgetc(in_stream)) != EOF)
        {
            if (c<16) printf("0");
            printf("%X",c);
            length++;
            sum+=c;
        }
        printf(">");
        if (length%0x100<16) printf("0");
        printf("%X", length%0x100);
        if (sum%0x100<16) printf("0");
        printf("%X",sum%0x100);
        printf("\r\n");
    }
    return (0);
}
