## trap0.asm

This program is almost identical to *int4.asm*. The trap gate is used instead of the interrupt gate to trap the *divide error exception* (not the **"INTO"** interrupt (int 4); interrupt on overflow).

Trapping exception(s) reminds me of the **on error goto** statement in BASIC in the good old days.