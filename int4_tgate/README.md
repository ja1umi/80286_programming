## int4_tgate.asm

### Task as Interrupt Handler

According to Intel's iAPX286 Programmers Reference, interrupts and exceptions can also be handled with a task gate. This program works just like *int4.asm*, but the difference is that the task gate is placed in the IDT instead of the interrupt gate. The task state segment (TSS) and its descriptor are also prepared for task switching.