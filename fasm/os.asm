include 'memory.h'
include 'syscalls.h'
include 'macros.asm'

	format ELF64

	section '.text' executable

	extrn CreateTssDesc
	extrn CreateTrapGate
	extrn CreateIntGate
	extrn message
	extrn div0message
	extrn GPFmessage
	extrn PFmessage

	public start64

;======================================
; From here on we are using 64 bit code
;======================================
start64:
	mov ax, udata64 + 3
	mov ds, ax
	mov ax, data64
	mov ss, ax
	mov ecx, 0xC0000081
	mov edx, 0x00230018
	mov eax, SysCalls
	wrmsr
	mov ecx, 0xC0000082
	mov edx, 0
	mov eax, SysCalls
	wrmsr
	mov ecx, 0xC0000083
	mov edx, 0
	mov eax, SysCalls
	wrmsr
	call InitIDT
	mov rax, TSS64
	mov rcx, tssd64
	call CreateTssDesc
	mov ax, tssd64
	ltr ax
	lidt tbyte [idt_64]
	call InitializeHD
; Final preparations before starting tasking
	mov r15, 0
	mov [TS.nexttask], 0
	mov [TS.waiting], 0		  	; We don't want task1 to be waiting when it starts!
	mov [TS.firstfreemem], UserData

	mov r14, StaticPort
	mov [MP.waitingProc], 0xFFFFFFFFFFFFFFFF ; Initialize StaticPort
	mov [MP.msgQueue], 0
	mov r14, KbdPort
	mov [MP.waitingProc], 0xFFFFFFFFFFFFFFFF ; Initialize KbdPort
	mov [MP.msgQueue],0

	mov al, 0xFF
	call AllocPage64			; Page for kernel stack
	mov rbx, KernelStack
	call CreatePTE
	mov eax, KernelStack + 0x1000
	mov [TSS64 + 4], eax			; Kernel stack pointer in TSS
	mov al, 0xFF			  	
	call AllocPage64			; Page for user stack
	mov rbx, UserStack
	call CreatePTE
	mov rsp, UserStack + 0x1000
	mov al, 0xFF
	call AllocPage64			; Page for task code
	mov rbx, UserCode
	call CreatePTE
	mov al, 0xFF
	call AllocPage64		  	; Page for task data
	mov rbx, UserData
	call CreatePTE

	mov rsi, tas1				; Move the task code
	mov rdi, UserCode
	mov rcx, taskend - tas1
	cld
	rep movsb
	mov rax, kbTaskCode
	call CreateKernelTask
	mov rcx, 0x11000
	mov qword [rcx], 0
	mov qword [rcx + 8], 0xFE0
	mov rcx, UserCode		  	; task 1

	REX					; Set up flags for task1
	pushfq
	pop r11
	add r11, 0x200			  	; This will enable interrupts when we sysret
	sysret				  	; Start Task1 and multitasking

	section '.data'

	public tempstack

gdt_48: dw	0x800	  ; allow up to 512 entries in GDT
	dd	GDT

idt_64: dw 0x800
	dq IDT

	dq 128 dup (0)
tempstack:
	dq 128 dup (0)
tempstack0:

include 'task1.asm'
include 'keyboard.asm'
include 'interrupts.asm'
include 'tasking.asm'
include 'messaging.asm'
include 'pagetab.asm'
include 'memory.asm'
include 'fat.asm'
include 'syscalls.asm'

	section '.data'

firstFreeKMem	dq 0x11000	;dq FFKM
nextKPage	dq 0x12		;dq (FFKM shr 12) + 1

org 0x11000
FFKM	dq 0
	dq PageSize - 0x10 ;- DataSegLen - 0x10

	org StaticPort
	SPort MessagePort
