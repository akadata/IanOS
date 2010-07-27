#include "kstructs.h"
#include "memory.h"
#include "library/syscalls.h"
#include "library/lib.h"
#include "console.h"

int main(void)
{
    struct Message m;
    int            column = 0;
    char           commandline[81];
    char           buffer[512];
    char           *name        = sys_AllocSharedMem(81);
    char           *environment = sys_AllocSharedMem(81);
    int            i;

    consoleclrscr(0);
    writeconsolestring("IanOS Version 0.1.1 - 2009\r", 0);
    writeconsolestring("#> _\b", 0);
    name[80] = environment[80] = 0;
    for (i = 0; i < 80; i++)
    {
        commandline[i] = ' ';
    }

    while (1)
    {
        char c = getchar(0);

        switch (c)
        {
        case BACKSPACE:
            if (column > 0)
            {
                writeconsolestring(" \b\b_\b", 0);
                commandline[column--] = 0;
            }
            break;

        case CR:
            column = 0;

            i = 0;
            while (commandline[i] != ' ')
            {
                name[i] = commandline[i];
                i++;
            }
            name[i] = 0;

            // Convert name[] to uppercase.
            i = -1;
            while (name[++i])
            {
                if (name[i] >= 'a' & name[i] <= 'z')
                    name[i] = name[i] - 0x20;
            }

            for (i = 0; i < 80; i++)
            {
                environment[i] = commandline[i];
            }

            writeconsolestring(" \r", 0);

            if (name[0] == '&')
            {
                sys_CreateTask(name + 1, environment + 1, 0);
            }
            else
            {
                struct Message *msg = (struct Message *)sys_AllocMem(sizeof(struct Message));
                struct MessagePort * parentPort = sys_AllocMessagePort();
                sys_CreateTask(name, environment, parentPort);
                sys_ReceiveMessage((long int)parentPort, msg);
                sys_DeallocMem(parentPort);
                sys_DeallocMem(msg);
            }

            writeconsolestring("#> _\b", 0);

            // Clear commandline[]
            for (i = 0; i < 80; i++)
            {
                commandline[i] = ' ';
            }
            break;

        default:
            commandline[column++] = c;
            writeconsolechar(c, 0);
            writeconsolestring("_\b", 0);
            break;
        }
    }
    return(0);
}
