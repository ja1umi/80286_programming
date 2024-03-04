# Learn the basics of 80286 protected mode programming through trial and error

## Introduction

The source codes and related files are ones I made during my small but giant leap into 80286 protected mode assembly programming. They may be helpful to others who are attempting the same step.

## Sample programs can be found in this repository

I have tried to keep them as simple as possible and as self-explanatory as possible. The programs are written to demonstrate how to 

1) enter the protected mode
2) deal with data segment descriptors with ED bit set (for stack)
3) prepare and use the Local Descriptor Table (LDT)
4) place codes on the LDT segment
5) move from ring 0 to ring 3
6) use call cate and call gate descriptors to call a ring 0 service from ring 3 (user land) with and without a parameter
7) handle interrupt(s) in the protected mode and how to set up Interrupt Descriptor Table (IDT) entry
8) quickly return to real mode by triple fault without the need for external reset circuitry
9) change I/O privilege level (IOPL)
10) use pointer (selector value) validation instructions such as arpl, verw and verr
11) perform task switching 
12) use task gate
13) use trap gate
14) use task as interrupt/trap handler

## Even now, there are reasons to consider learning the 80286 instead of the 80386 (or higher)

Learning about the 80286 is still a good starting point for understanding the modern x86 family of CPUs.

The 80286 offers segment-based memory management and a 16-bit architecture, while the 80386 is a full 32-bit CPU. It is important to note that the 80286 has a 24-bit address bus and 16 MB of physical address space, but the maximum length of a single segment is limited to 64 KB, similar to the 8086. These limitations made the 80286 much less capable of running memory hungry applications and modern operating systems.

Despite these facts, it may still be useful to learn about the 80286 today. The 80286 was the first CPU in the x86 family to support protected virtual address mode, also known as protected mode. In fact, the memory management of the 80386 (or later) is achieved by extending one with improvements already introduced in the 80286. For example, several fields added to the segment descriptor in the 80386 are placed in the fields reserved for future use in the 80286. The structure of the descriptor remains unchanged. The structure of the control register(s) is the same as above. The 80286's machine status word register becomes part of the 80386's CR0 register. All modern memory management and protection concepts found in x86 family CPUs come from the 80286. This suggests that learning the 80286 will help you understand the 80386 and its successors much more easily.

## Prerequisites

* [Bochs](https://bochs.sourceforge.io/)
* x86 Assember


x86 assembler is not required to run the provided image files. However, you will need it if you want to try your own modification(s).  I've used [Netwide Assembler](https://www.nasm.us/).

 [Flat Assember](https://flatassembler.net/) is another option but I have not tried it yet.

## What's Next

Please consider examining the assembly source along with its comments, and running the image file to observe its behavior. It is worth noting that the program is designed to fit into a 512 byte boot sector, which may make the source code easier to understand and more convenient to try out.

