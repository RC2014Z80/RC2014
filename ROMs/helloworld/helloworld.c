#include "rc2014.h"
#include "pigfx.h"

#pragma output REGISTER_SP  = -1
#pragma output CLIB_MALLOC_HEAP_SIZE = 0

void main()
{
    int a;

    for (a = 0; a < 10; ++a)
        pigfx_print("Hello World!");

    while (1);
}
