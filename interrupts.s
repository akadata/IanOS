	.include "macros.s"
	.include "memory.h"
	.include "kstructs.h"

SLEEPINT = 2
KBDINT = 1
HDINT = 14

	.text

	.global WaitForInt
	.global Ps
	.global intr
	.global gpf
	.global pf
	.global SwitchTasks
	.global SpecificSwitchTasks
	.global int21
	.global TimerInt
	.global KbInt
	.global HdInt

#===================
# Keyboard interrupt
#===================
KbInt:	push %rax
	push %rbx
	in   $0x60, %al		 # MUST read byte from keyboard - else no more ints
	test $0x80, %al		 # only interested in key make events
	jnz  .kbdone
	mov  $KbdTable, %ebx
	xlat (%ebx)
	mov  $kbBuffer, %ebx
	addl kbBufCurrent, %ebx
	mov  %al, (%ebx)
	incl kbBufCurrent
	incb kbBufCount
	cmpl $128, kbBufCurrent
	jne  .kbistaskwaiting
	movl $0, kbBufCurrent
	# is any task waiting for keyboard input? If so re-enable it
.kbistaskwaiting:
	mov  currentTask, %r15
.kbagain:
	cmpb $KBDINT, TS.waiting(%r15)
	jne  .kbgoon
	movb $0, TS.waiting(%r15)
	int  $22
	jmp  .kbdone
.kbgoon:
	mov  TS.nexttask(%r15), %r15
	cmpq currentTask, %r15
	jne  .kbagain
.kbdone:
	pop  %rbx
	mov  $0x20, %al		  # clear int
	out  %al, $0x20
	pop  %rax
	iretq

#================
# Timer interrupt
#================
TimerInt:
	push %rax
	mov  $0x20, %al
	out  %al, $0x20
	incq Ticks
	cmpb $0, Timer.active
	je   .notimer
	decq Timer.interval
	jnz  .notimer
	mov  Timer.task, %r15
	movb $0, TS.waiting(%r15)
	movb $0, Timer.active
.notimer:
	pop  %rax
	decb TimeSliceCount
	jnz  .tdone
	movb $5, TimeSliceCount
	SWITCH_TASKS
.tdone:	iretq

#=====================
# Hard Disk interrupt
#=====================
HdInt:	push %rax
.istaskwaiting:
	mov  currentTask, %r15
	mov  $0x20, %al
	out  %al, $0x20
	out  %al, $0xA0
.again: cmpb $HDINT, TS.waiting(%r15)
	jne  .goon
	movb $0, TS.waiting(%r15)
	SWITCH_TASKS_R15
	jmp  .done2
.goon:	mov  TS.nexttask(%r15), %r15
	cmpq currentTask, %r15
	jne  .again
.done2:	pop  %rax
	iretq

#===========================================================================================================
# We need to wrap these two subroutines inside interrupt routines.
# Thus we can call them from, e.g., a SYSCALL. (They expect to be called from within an interrupt routine.)
#===========================================================================================================
SwitchTasks:			# int 20
	cli
	call TaskSwitch
	iretq

SpecificSwitchTasks:		# int 22
	cli
	call SpecificTaskSwitch
	iretq

intr:	mov $0x20, %al		 # clear int
	out %al, $0x20
	iretq

div0:	KWRITE_STRING $div0message, $0, $0
	KWRITE_DOUBLE (%esp), $0, $60
	KWRITE_DOUBLE 4(%esp), $1, $60
	iretq
i1:	movb $'1, 0xB8000
	iretq
i2:	movb $'2, 0xB8000
	iretq
i3:	movb $'3, 0xB8000
	iretq
i4:	movb $'4, 0xB8000
	iretq
i5:	movb $'5, 0xB8000
	iretq
i6:	movb $'6, 0xB8000
	iretq
i7:	movb $'7, 0xB8000
	iretq
i8:	movb $'8, 0xB8000
	iretq
i9:	movb $'9, 0xB8000
	iretq
ia:	movb $'a, 0xB8000
	iretq
ib:	movb $'b, 0xB8000
	iretq
ic:	movb $'c, 0xB8000
	iretq
gpf:
	KWRITE_STRING $GPFmessage, $0, $0
	KWRITE_DOUBLE 0x20(%esp), $0, $60
	KWRITE_DOUBLE 0x28(%esp), $1, $60
	KWRITE_DOUBLE 0x30(%esp), $2, $60
	KWRITE_DOUBLE 0x38(%esp), $3, $60
	KWRITE_DOUBLE 0x40(%esp), $4, $60
	KWRITE_DOUBLE 0x48(%esp), $5, $60
	pop %rax
	hlt
	iretq
pf:	
	KWRITE_STRING $PFmessage, $0, $0
	KWRITE_DOUBLE 0x20(%esp), $0, $60
	KWRITE_DOUBLE 0x28(%esp), $1, $60
	KWRITE_DOUBLE 0x30(%esp), $2, $60
	KWRITE_DOUBLE 0x38(%esp), $3, $60
	KWRITE_DOUBLE 0x40(%esp), $4, $60
	KWRITE_DOUBLE 0x48(%esp), $5, $60
	pop %rax
	hlt
	iretq
itf:	movb $'f, 0xB8000
	iretq
ig:	movb $'g, 0xB8000
	iretq

Pd:	mov $160, %ax
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
	mov %al, 0xB8000(%ebx)
	add $2, %bx
	loop .stillCounting
	ret

Ps:	mov $160, %ax
	mul %bh
	mov $0, %bh
	shl $1, %bx
	add %ax, %bx
.isItStringEnd:
	mov (%edx), %ah
	cmp $0, %ah
	je .done3
	mov %ah, 0xB8000(%ebx)
	add $2, %bx
	inc %edx
	jmp .isItStringEnd
.done3:	ret

#===========================================================
# Load one sector from IDE HD to memory
# %rdi = address to load to
# %esi = sector number
#===========================================================
HD_PORT=0x1F0
int21:	mov  $HD_PORT+7, %dx
.again2:
#	KWRITE_DOUBLE $0x30, $20, $70
	in  %dx, %al
	test $0x80, %al
	jnz .again2
	mov $HD_PORT+2, %dx		# 0x1F2 - sector count
	mov $1, %al
	out %al, %dx
	inc %dx		      		# 0x1F3
	mov %esi, %eax
	and $0xFF, %al
	out %al, %dx	      	# lba lo
	inc %dx		      		# 0x1F4
	mov %esi, %eax
	and $0xFF, %ah
	mov %ah, %al
	out %al, %dx	      	# lba mid
	inc %dx		      		# 0x1F5
	mov %esi, %eax
	shr $16, %eax
	and $0xFF, %al
	out %al, %dx	      	# lba hi
	inc %dx		      		# 0x1F6
	and $0xF, %ah
	mov %ah, %al
	add $0x40, %al	      	# lba mode/drive /lba top
	out %al, %dx
	inc %dx		      		# 0x1F7
	mov $0x20, %ax
	out %al, %dx
	push %rdi
#	KWRITE_DOUBLE $0x31, $20, $70
	mov $HDINT, %rdi
	call WaitForInt
#	KWRITE_DOUBLE $0x32, $20, $70
	pop %rdi
.again3:
	in  %dx, %al
	test $0x80, %al
	jnz .again3
#	KWRITE_DOUBLE $0x33, $20, $70
	mov $HD_PORT, %dx
	mov $0, %eax
	mov $256, %rcx
	cld
	rep
	insw
#	KWRITE_DOUBLE $0x34, $20, $70
	iretq

#===============================================================================
# Stop the current task and make it wait for the interrupt number passed in RDI
#===============================================================================
WaitForInt:
	mov  currentTask, %r15
	mov  %rdi, %rax
	mov  %al, TS.waiting(%r15)
	SWITCH_TASKS		       # The current task is no longer runnable
	ret

	.data

	.global Ticks
	.global Timer.active
	.global Timer.interval
	.global Timer.task

Ticks:		.quad 0
TimeSliceCount: .byte 5
Timer.active: 	.byte 0
Timer.interval:	.quad 0
Timer.task:	.quad 0
