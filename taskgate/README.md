## taskgate.asm

This program is almost the same as *tasksw.asm*. Intel's iAPX286 Programmers Reference says that the task gate provides an additional level of indirection between the target address and the TSS descriptor. The ultimate effect of referencing a task gate is the same as referencing the TSS directly. 

I tried to confirm this for myself, and so referencing the TSSes is replaced with referencing the task gates.

According to the Programmers Reference, task gates can appear in GDT or LDT. However, I could not get it to work with task gates in the LDT. Even I have not been able to shed any light on this issue.  It is noted that putting task gates in the GDT works as I expected.