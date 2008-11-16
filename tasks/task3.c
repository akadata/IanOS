#include "cmemory.h"
#include "ckstructs.h"
#include "library/syscalls.h"

void main(void)
{
	WriteString("Task 3 is now running.", 13, 50);
	struct Message * msg = (struct Message *)sys_AllocMem(sizeof(struct Message));
	msg->nextMessage = 0;
	msg->byte = 1;
	msg->quad = 'B';
	sys_SendMessage(ConsolePort, msg);
	while (1)
	{
		WriteDouble(GetTicks(), 22, 60);
	}
}
