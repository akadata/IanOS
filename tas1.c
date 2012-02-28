#include "memory.h"
#include "syscalls.h"

extern void kbTaskCode(void);
extern void consoleTaskCode(void);
extern void fsTaskCode(void);
extern void dummyTask(void);
extern void monitorTaskCode(void);

// This task is just here to start the ball rolling

void tas1(void)
{
	// Give tasks time to set themselves up
	sys_Sleep(1);
	
	long pid = Sys_Fork();
	if (!pid)
		Sys_Execve("TASK1", 0);
   	sys_Exit();
}
