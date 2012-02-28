	SLEEPINT = 2

	.include "include/memory.inc"
	.include "include/kstructs.inc"
	.include "macros.s"

	.text

	.global SysCalls
	.global GoToSleep
	.global SetCurrentDirectory

CallNo:
	.quad	Sys_Exit
	.quad	Sys_Fork
	.quad	Sys_Read
	.quad	Sys_Write
	.quad	Sys_Open
	.quad	Sys_Close	
	.quad	SysWaitPID
	.quad	Sys_Creat
	.quad	Sys_Link
	.quad	Sys_UnLink
	.quad	Sys_Execve
	.quad	Sys_ChDir				
	.quad	PrintString				# PRINTSTRING
	.quad	PrintDouble				# PRINTDOUBLE
	.quad	PrintChar				# PRINTCHAR
	.quad	Newtask 				# CREATETASK
	.quad	GetTicks				# GETTICKS
	.quad	Sleep					# SLEEP
	.quad	Alloc_Mem				# ALLOCMEM
	.quad	Alloc_Message_Port		# ALLOCMSGPORT
	.quad	Send_Message			# SENDMESSAGE
	.quad	Receive_Message 		# RECEIVEMESSAGE
	.quad	Dealloc_Mem				# DEALLOCMEM
	.quad	Send_Receive			# SENDRECEIVE
	.quad 	NewKerneltask			# CREATEKTASK
	.quad	Alloc_Shared_Mem		# ALLOCSHAREDMEM
	.quad	NewLPtask				# CREATELPTASK
	.quad 	CommandLine				# GETCOMMANDLINE
	.quad	LoadProgram				# LOADPROGRAM
	.quad	GetCurrentConsole		# GETCURRENTCONSOLE
	.quad 	GetCurrentDirectory		# GETCURRENTDIR
	.quad 	SetCurrentDirectory		# SETCURRENTDIR

SysCalls:
	jmp *(CallNo - 8)(,%r9, 8)	

#=========================================================
# Kill the current task, freeing all memory owned by task
# This syscall should never return
#=========================================================
Sys_Exit:
	push %rcx
	call KillTask
	pop  %rcx
	sysretq

#=========================================================
# 
#=========================================================	
Sys_Fork:
	push %rcx
	call DoFork
	pop %rcx
	sysretq
	
#=========================================================
# 
#=========================================================	
Sys_Read:
	sysretq
	
#=========================================================
# 
#=========================================================
Sys_Write:
	sysretq
	
#=========================================================
# Opens the file whose name is pointed to by RDI.
# Returns in RAX the File Descriptor
#=========================================================
Sys_Open:
	push %rcx
	call KOpenFile
	pop %rcx
	sysretq
	
#=========================================================
# Closes the file whose FD is pointed to by RDI
#=========================================================
Sys_Close:
	push %rcx
	call KCloseFile
	pop %rcx
	sysretq				

#=========================================================
# 
#=========================================================
SysWaitPID:
	push %rcx
	call Do_Wait
	pop %rcx
	sysretq
	
#=========================================================
# 
#=========================================================
Sys_Creat:
	sysretq

#=========================================================
# 
#=========================================================
Sys_Link:
	sysretq

#=========================================================
# 
#=========================================================
Sys_UnLink:
	sysretq

#=========================================================
# 
#=========================================================
Sys_Execve:
	push %rcx
	call DoExec
	cmp $1,%rax
	je  notLoaded
	mov $(UserStack + PageSize), %rsp
	push $UserCode
notLoaded:
	pop %rcx
	sysretq

#=========================================================
# 
#=========================================================
Sys_ChDir:
	sysret				

#========================================================
# Print [EDX] as string at position row BH col BL
# Affects RAX, RBX, RDX
#========================================================
PrintString:
	mov $160, %ax
	mul %bh
	mov $0, %bh
	shl $1, %bx
	add %ax, %bx
.isItStringEnd:
	mov (%edx), %ah
	cmp $0, %ah
	je .done
	mov %ah, 0xB8000(%ebx)
	add $2, %bx
	inc %edx
	jmp .isItStringEnd
.done:	sysretq

#========================================================
# Print EDX as hex at position row BH col BL
# Affects RAX, RBX, RDX
#========================================================
PrintDouble:
	push %rcx
	mov $160, %ax
	mul %bh
	mov $0, %bh
	shl $1, %bx
	add %ax, %bx
	mov $8, %rcx
.stillCounting:
	shld $4, %edx, %eax
	shl $4, %edx
	and $0xF, %eax
	add $'0, %al
	cmp $'9, %al
	jle .under10
	add $7, %al
.under10:
	mov  %al, 0xB8000(%ebx)
	add  $2, %bx
	loop .stillCounting
	pop  %rcx
	sysretq

#========================================================
# Print character in AH at position row BH col BL
# Affects RAX, RBX
#========================================================
PrintChar:
	push %ax
	mov  $160, %ax
	mul  %bh
	mov  $0, %bh
	shl  $1, %bx
	add  %ax, %bx
	pop  %ax
	mov  %ah, 0xB8000(%ebx)
	sysretq

#=================================================================
# Create a new task from the file whose name is pointed to by RDI
# Passes environment string in RSI
# Affects RAX, RDI
#=================================================================
Newtask:
	push %rcx
	mov %r14, %rcx
	call NewTask
	int  $20
	pop %rcx
	sysretq

#=============================================================================
# Return in RAX the number of (10ms) clock ticks since the system was started
#=============================================================================
GetTicks:
	mov Ticks, %rax
	sysretq

#=====================================================
# Suspend the current task for for RDI 1ms intervals
#=====================================================
Sleep:	push %rcx
	mov currentTask, %r15
	movb $SLEEPINT, TS.waiting(%r15)
	mov %rdi, TS.timer(%r15)
	mov %r15, %rdi
	call BlockTask
	SWITCH_TASKS		       # The current task is no longer runnable
	pop %rcx
	sysretq

#==============================================================
# Allocate some memory from the heap. RDI = amount to allocate
# Returns in RAX address of allocated memory.
#==============================================================
Alloc_Mem:
	push %rcx
	mov  currentTask, %r15
	mov  TS.firstfreemem(%r15), %rsi
	call AllocMem
	pop  %rcx
	sysretq

#=================================================
# Allocate a message port. Return the port in RAX
#=================================================
Alloc_Message_Port:
	push %rcx
	call AllocMessagePort
	pop %rcx
	sysretq

#===================================
# Send a message to a message port.
# RDI = message port
# RSI = message
#===================================
Send_Message:
	push %rcx
	call SendMessage
	pop %rcx
	sysretq

#===========================================================
# Receive a message on message port RDI
# RSI = Buffer to return message to
# If there is no message on the port block and wait for one
#===========================================================
Receive_Message:
	push %rcx
	call ReceiveMessage
	pop %rcx
	sysretq

#==================================================
# Deallocate the memory at location RDI.
# This will deallocate both user and kernel memory
#==================================================
Dealloc_Mem:
	push %rcx
	call DeallocMem
	pop %rcx
	sysretq

#======================================================
# Send a message to a message port and receive a reply
# RDI = message port
# RSI = message
#======================================================
Send_Receive:
	push %rcx
	call SendReceiveMessage
	pop %rcx
	sysretq

#=================================================================
# Create a new kernel task from the code pointed to by RDI
# Affects RAX, RDI
# Note - we really, really shouldn't have a system call to create
# a new kernel task! On the other hand, it calls code compiled
# into the kernel, so no real harm done.
#=================================================================
NewKerneltask:
	push %rcx
	call NewKernelTask
	int $20
	pop %rcx
	sysretq

#==============================================================
# Allocate some shared memory. RDI = amount to allocate
# Returns in RAX address of allocated memory.
#==============================================================
Alloc_Shared_Mem:
	push %rcx
	call AllocSharedMem
	pop  %rcx
	sysretq

#=================================================================
# Create the low-priority task from the code pointed to by RDI
# Affects RAX, RDI
# Note - we really, really shouldn't have a system call to create
# this task! We only want it to happen once.
#=================================================================
NewLPtask:
	push %rcx
	call NewLowPriTask
	int $20
	pop %rcx
	sysretq

#==================================================
# Return a pointer to the command line of the task
# Affects RAX
#==================================================
CommandLine:
	mov  currentTask, %r15
	mov  TS.environment(%r15), %rax
	sysretq

#====================================================================
# Loads a program from the hard disk and overwrites the current task
# RCX = Address to load to
# R13 = Program Name
#====================================================================
LoadProgram:
	mov %rcx, %rdi
	mov %r13, %rsi
	call LoadTheProgram
	sysretq

#=================================================
# Returns the console (0 - 3) of the current task
#=================================================
GetCurrentConsole:
	mov currentTask, %r15
	mov TS.console(%r15), %rax
	sysretq

#===================================================
# Returns the current directory of the current task
#===================================================
GetCurrentDirectory:
	mov currentTask, %r15
	mov TS.currentDir(%r15), %rax
	sysretq

#===================================================
# Sets the current directory of the current task
#===================================================
SetCurrentDirectory:
	mov currentTask, %r15
	mov %rdi, TS.currentDir(%r15)
	sysretq


GoToSleep:
	push %rdx
	mov currentTask, %r15
	movb $SLEEPINT, TS.waiting(%r15)
	mov %rdi, TS.timer(%r15)
	mov %r15, %rdi
	call BlockTask
	pop %rdx
	SWITCH_TASKS		       # The current task is no longer runnable
	ret
