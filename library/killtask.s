	.include "../syscalls.inc"

	.global sys_KillTask

	.text

sys_KillTask:
	mov $KILLTASK, %r9
	syscall
	ret