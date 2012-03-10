#include "kernel.h"
#include "memory.h"
#include "filesystem.h"
#include "console.h"

extern struct Task *currentTask;

//================================================
// Read noBytes into buffer from the file fHandle
//================================================
long ReadFromFile(struct FCB *fHandle, char *buffer, long noBytes)
{
   long retval;

   struct Message *FSMsg;

   FSMsg = (struct Message *) AllocKMem(sizeof(struct Message));
   char *buff = AllocKMem(noBytes);
   int i;

   FSMsg->nextMessage = 0;
   FSMsg->byte = READFILE;
   FSMsg->quad = (long) fHandle;
   FSMsg->quad2 = (long) buff;
   FSMsg->quad3 = noBytes;
   SendReceiveMessage((struct MessagePort *) FSPort, FSMsg);
   for (i = 0; i < noBytes; i++)
   {
      buffer[i] = buff[i];
   }
   DeallocMem(buff);
   retval = FSMsg->quad;
   DeallocMem(FSMsg);
   return (retval);
}

//===========================================
// A utility function to copy a memory range
//===========================================
void copyMem(unsigned char *source, unsigned char *dest, long size)
{
   int i;

   if (dest < (unsigned char *) 0x10000)
   {
      KWriteString("OOps!!!", 20, 40);
      asm("cli;"
            "hlt;");
   }

   for (i = 0; i < size; i++)
   {
      dest[i] = source[i];
   }
}

/*
//=======================================================
// Copy null-terminates string s1 to s2
//=======================================================
void copyString(unsigned char *source, unsigned char * destination)
{
	while (*source)
   	{
      *destination++ = *source++;
   	}
   	*destination = 0;
}
*/

//===========================================================================
// A kernel library function to write a null-terminated string to the screen.
//===========================================================================
void KWriteString(char *str, int row, int col)
{
   char *VideoBuffer = (char *) 0xB8000;

   int temp = 160 * row + 2 * col;
   int i = 0;
   while (str[i] != 0)
   {
      VideoBuffer[temp + 2 * i] = str[i];
      i++;
   }
}

//==========================================================================
// A kernel library function to write a quad character to the screen.
//==========================================================================
void KWriteHex(long c, int row) //, int col)
{
   char *VideoBuffer = (char *) 0xB8000;

   int i;
   for (i == 0; i < 8; i++)
   {
      char lo = c & 0xF;
      lo += 0x30;
      if (lo > 0x39)
      {
         lo += 7;
      }
      char hi = (c & 0xF0) >> 4;
      hi += 0x30;
      if (hi > 0x39)
      {
         hi += 7;
      }
      VideoBuffer[160 * row + 28 - 4 * i] = hi;
      VideoBuffer[160 * row + 30 - 4 * i] = lo;
      c = c >> 8;
   }
}

//=========================================================
//  Opens the file s.
//  Returns a FD for the file in RAX
//=========================================================
FD KOpenFile(char *s)
{
   	char *S = AllocKMem(strlen(s) + 1);
   	char *str = S;
	struct FCB * fcb = 0;

   	strcpy(S, s);
	struct Message *msg = (struct Message *) AllocKMem(sizeof(struct Message));
   	msg->nextMessage = 0;
   	msg->byte = OPENFILE;
   	msg->quad = (long) str;
   	SendReceiveMessage((struct MessagePort *)FSPort, msg);
	fcb = (struct FCB *) msg->quad;
   	DeallocMem(S);
	if (fcb)
	{
		struct FCB * temp = currentTask->fcbList;
		int tempID = 2;
		while (temp->nextFCB && (temp->nextFCB->fileDescriptor == tempID))
		{
			temp = temp->nextFCB;
			tempID++;
		}
		fcb->nextFCB = temp->nextFCB;
		fcb->fileDescriptor = tempID;
		temp->nextFCB = fcb;
		return tempID;
	}
   	return -1;
}

//=========================================================
// 
//=========================================================
int KCloseFile(FD fileDescriptor)
{
	struct FCB * temp = currentTask->fcbList;
	struct FCB * temp2;
	while (temp->nextFCB)
	{
		if (temp->nextFCB->fileDescriptor == fileDescriptor)
		{
			temp2 = temp->nextFCB;
			temp->nextFCB = temp->nextFCB->nextFCB;
			temp = temp2;
			break;
		}
		temp = temp->nextFCB;
	}
	if (temp)
	{
   		struct Message *msg =
    	     (struct Message *) AllocKMem(sizeof(struct Message));

   		msg->nextMessage = 0;
   		msg->byte = CLOSEFILE;
   		msg->quad = (long) temp /*fHandle*/;
   		SendReceiveMessage((struct MessagePort *)FSPort, msg);
		return 0;
	}
	return -1;
}

int DoStat(FD fileDescriptor, struct FileInfo *info)
{
	int retval = -1;
	
	struct FCB * temp = currentTask->fcbList;
	while (temp->nextFCB)
	{
		if (temp->fileDescriptor == fileDescriptor)
			break;
		temp = temp->nextFCB;
	}
	if (temp)
	{
   		struct Message *msg =
        	 (struct Message *) AllocKMem(sizeof(struct Message));
   		char *buff = (char *) AllocKMem(sizeof(struct FileInfo));
 
   		msg->nextMessage = 0;
   		msg->byte = GETFILEINFO;
   		msg->quad = (long) temp;
   		msg->quad2 = (long) buff;
   		SendReceiveMessage((struct MessagePort *)FSPort, msg);
		copyMem(buff, (char *)info, sizeof(struct FileInfo));
   		DeallocMem(buff);
   		retval = 0; //msg->quad;
   		DeallocMem(msg);
	}
   	return (retval);
}

long DoRead(FD fileDescriptor, char *buffer, long noBytes)
{
	long retval = 0;
	
	struct FCB * temp = currentTask->fcbList;
	while (temp->nextFCB)
	{
		if (temp->fileDescriptor == fileDescriptor)
			break;
		temp = temp->nextFCB;
	}
	if (temp)
	{
		if (temp->deviceType == KBD)
		{
   			struct Message *kbdMsg;

   			kbdMsg = (struct Message *)AllocKMem(sizeof(struct Message));
   			kbdMsg->nextMessage = 0;
   			kbdMsg->byte        = 1;
   			kbdMsg->quad        = currentTask->console;
   			SendReceiveMessage((struct MessagePort *)KbdPort, kbdMsg);
   			char c = kbdMsg->byte;
			buffer[0] = c;
			buffer[1] = 0;
   			DeallocMem(kbdMsg);
   			return(1);
		}
		else
		{
 	  		struct Message *FSMsg;

   			FSMsg = (struct Message *)AllocKMem(sizeof(struct Message));
   			char *buff = AllocKMem(noBytes);
 
   			FSMsg->nextMessage = 0;
   			FSMsg->byte = READFILE;
   			FSMsg->quad = (long) temp;
   			FSMsg->quad2 = (long) buff;
   			FSMsg->quad3 = noBytes;
   			SendReceiveMessage((struct MessagePort *)FSPort, FSMsg);
			copyMem(buff, buffer, noBytes);
			DeallocMem(buff);
   			retval = FSMsg->quad;
   			DeallocMem(FSMsg);
		}
	}
   return (retval);
}

long DoWrite(FD fileDescriptor, char *buffer, long noBytes)
{
   long retval = 0;

 	struct FCB * temp = currentTask->fcbList;
	while (temp->nextFCB)
	{
		if (temp->fileDescriptor == fileDescriptor)
			break;
		temp = temp->nextFCB;
	}
	if (temp)
	{
		if (temp->deviceType == CONS)
		{
  			struct Message *FSMsg;

   			FSMsg = (struct Message *) AllocKMem(sizeof(struct Message));
   			char *buff = AllocKMem(noBytes + 1);
 			copyMem(buffer, buff, noBytes);
			buff[noBytes] = 0;

   			struct Message *msg = (struct Message *)AllocKMem(sizeof(struct Message));
   			msg->nextMessage = 0;
   			msg->byte        = WRITESTR;
   			msg->quad        = (long) buff;
			msg->quad2       = currentTask->console;
   			SendMessage((struct MessagePort *)ConsolePort, msg);
   			DeallocMem(msg);
			retval = noBytes;
		}
		else
		{
  			struct Message *FSMsg;

   			FSMsg = (struct Message *) AllocKMem(sizeof(struct Message));
   			char *buff = AllocKMem(noBytes);
 			copyMem(buffer, buff, noBytes);

   			FSMsg->nextMessage = 0;
   			FSMsg->byte = WRITEFILE;
   			FSMsg->quad = (long) temp;
   			FSMsg->quad2 = (long) buff;
   			FSMsg->quad3 = noBytes;
   			SendReceiveMessage((struct MessagePort *)FSPort, FSMsg);
   			DeallocMem(buff);
   			retval = FSMsg->quad;
   			DeallocMem(FSMsg);
		}
	}
   return (retval);
}

FD DoCreate(char * s)
{
   	char *S = AllocKMem(strlen(s) + 1);

   	strcpy(S, s);
   	struct Message *msg =
         (struct Message *) AllocKMem(sizeof(struct Message));
   	msg->nextMessage = 0;
   	msg->byte = CREATEFILE;
   	msg->quad = (long) S; //str;
   	SendReceiveMessage((struct MessagePort *)FSPort, msg);
   	DeallocMem(S);
   	long retval = msg->quad;
   	DeallocMem(msg);
	struct FCB *fcb = (struct FCB *)retval;
	if (fcb)
	{
		struct FCB * temp = currentTask->fcbList;
		int tempID = 2;
		while (temp->nextFCB && (temp->nextFCB->fileDescriptor == tempID))
		{
			temp = temp->nextFCB;
			tempID++;
		}
		fcb->nextFCB = temp->nextFCB;
		fcb->fileDescriptor = tempID;
		fcb->deviceType = FILE;
		temp->nextFCB = fcb;
		return tempID;
	}
	return -1;
}

long DoDelete(char *name)
{
	int retval = 0;
	char *S = AllocKMem(strlen(name) + 1);
	strcpy(S, name); 
   	struct Message *msg =
         (struct Message *) AllocKMem(sizeof(struct Message));

   	msg->nextMessage = 0;
   	msg->byte = DELETEFILE;
   	msg->quad = (long)S;
   	SendReceiveMessage((struct MessagePort *)FSPort, msg);
	DeallocMem(S);
	DeallocMem(msg);
   	return retval;
}

long DoChDir(unsigned char *dirName)
{
	// *** Need to add code to check that the directory exists ***
	int retval = -1;
	char *S = AllocKMem(strlen(dirName) + 3);
	strcpy(S, "");
	if (!strcmp(dirName, "/"))
		strcpy(S, "/");
	else
	{
		if (dirName[0] == '/')
			strcpy(S, dirName);
		else
		{
			if (strcmp(currentTask->currentDirName, "/"))
				strcpy(S, currentTask->currentDirName);
	    	strcat(S, "/");
			strcat(S, dirName);
		}
	}
   	struct Message *msg = (struct Message *) AllocKMem(sizeof(struct Message));

   	msg->nextMessage = 0;
   	msg->byte = TESTFILE;
   	msg->quad = (long)S;
   	SendReceiveMessage((struct MessagePort *)FSPort, msg);
	if (msg->quad)
	{
		DeallocMem(currentTask->currentDirName);
		currentTask->currentDirName = AllocKMem(strlen(S) + 1);
		strcpy(currentTask->currentDirName, S);
		retval = 0;
	}
	DeallocMem(S);
	DeallocMem(msg);
	return retval;
}

unsigned char *DoGetcwd(void)
{
	unsigned char *name = AllocUMem(strlen(currentTask->currentDirName) + 1);
	strcpy(name, currentTask->currentDirName);
	return name;
}