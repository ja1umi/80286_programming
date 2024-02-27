## tasksw.asm

A sample program that shows how to manage tasks on the 80286

Two simple tasks display a pair of characters. One task writes a solid green square on the first line and erases a square on the second line of the display. The other task is similar, but writes a red square on the second line and erases a square on the first line instead.

As you can see in the listing, each task forms an infinite loop. This is because I want the square to toggle back and forth every time the tasks change.

I created another task dispatcher that stops the current task and restarts another.
Note that the fourth task state segment (tss0) is also created to store the original state of the 80286 before the first task is started. The tss0 is loaded into the TR (task register) on ring 0 and is never used again. It is a waste of 44 bytes, but it works for me.