	.include "../../include/syscalls.inc"
	
	.global getwd

	.text

getwd:
	push %rcx
	push %r9
	push %r11
	mov $SYS_GETCWD, %r9
	syscall
	pop %r11
	pop %r9
	pop %rcx
	ret

