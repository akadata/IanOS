	.include "../syscalls.h"

	.global sys_AllocMem

	.text

sys_AllocMem:
	mov $ALLOCMEM, %r9
	syscall
	ret
