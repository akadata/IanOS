#include "ckstructs.h"
#include "cmemory.h"

extern struct Task * currentTask;
extern long * tempstack;
extern long * tempstack0;
extern unsigned char * PMap; // = (unsigned char *) PageMap;
extern long nPagesFree;

static long nextpid = 2;

/*
============================================
 Find the next free entry in the task table
============================================
*/
struct Task * nextfreetss()
{
	struct Task * temp = (struct Task *)TaskStruct;
	while (temp->nexttask != 0)
		temp++;
	return temp;
}

/*
===============================
 Link task into the task table
 Also allocate a pid
===============================
*/
void LinkTask(struct Task * task)
{
	struct Task * temp = currentTask->nexttask;
	currentTask->nexttask = task;
	task->nexttask = temp;
	task->pid = nextpid++;
}

/*
========================
 Create a new User task
========================
*/
void NewTask(char * name)
{
	long * stack;
	struct Task * task = nextfreetss();
	long * data;
	struct FCB * fHandle;
	long codelen, datalen;
	char header[3];

	fHandle = (struct FCB *)AllocKMem(sizeof(struct FCB));
	if (OpenFile(name, fHandle) == 0)
	{
		asm("cli");
		stack = (long *)&tempstack - 5;
		task->rsp = (long)stack;
		stack[0] = UserCode;
		stack[1] = user64 + 3;
		stack[2] = 0x2202;
		stack[3] = UserData + PageSize;
		stack[4] = udata64 + 3;
		task->waiting = 0;
		task->cr3 = VCreatePageDir();
		task->ds = udata64 + 3;
		ReadFile(fHandle, header, 4);
		ReadFile(fHandle, (char *)&codelen, 8);
		ReadFile(fHandle, (char *)&datalen, 8);
		ReadFile(fHandle, (char *)TempUserCode, codelen);
		ReadFile(fHandle, (char *)TempUserData, datalen);
		data = (long *)(TempUserData + datalen);
		data[0] = 0;
		//data[1] = 0;
		data[1] = PageSize - datalen - 0x10;
		task->firstfreemem = UserData + datalen;
		CloseFile(fHandle);
		LinkTask(task);
		asm("sti");
	}
	DeallocMem(fHandle);
}

/*
==========================
 Create a new Kernel task
==========================
*/
void NewKernelTask(void * TaskCode)
{
	long * stack;
	struct Task * task = nextfreetss();
	long * data;

	asm("cli");
	stack = (long *)&tempstack - 5;
	task->rsp = (long)stack;
	stack[0] = (long)TaskCode;
	stack[1] = code64;
	stack[2] = 0x2202;
	stack[3] = (long)&tempstack0;
	stack[4] = data64;
	task->waiting = 0;
	task->cr3 = VCreatePageDir();
	task->ds = data64;
	LinkTask(task);
	data = (long *)TempUserData;
	data[0] = 0;
	data[1] = 0xFFE;
	task->firstfreemem = UserData;
	asm("sti");
}

/*
=======================
 Kill the current task
=======================
*/
void KillTask(void)
{
	/* Don't want to task switch whilst destroying task */
	asm("cli");
	/* Unlink from the list of runnable tasks */
	struct Task * temp = currentTask;
	while (temp->nexttask != currentTask) temp = temp->nexttask;
	temp->nexttask = currentTask->nexttask;
	currentTask->nexttask = 0;
	/* Release allocated memory */
	long * mem = (long *)PageTableL12;
	long count;
	for (count = 0x0; count < 0x3; count++)
	{
		PMap[mem[count] >> 12] = 0;
		nPagesFree++;
	}
	for (count = 0x4; count < 0x200; count++)
	{
		if (mem[count] != 0 )
		{
			PMap[mem[count] >> 12] = 0;
			nPagesFree++;
		}
	}
	SwTasks15(temp->nexttask);
}
