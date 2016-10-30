# EP994A
My TI-99/4A clone implemented with a TMS99105 CPU and FPGA.

See the file LICENSE for license terms. At least for now (without contributors from others)
the source code is made available under the LGPL license terms.
You need to retain copyright notices in the source code.

Hackaday
--------
Project is documented to an extent at Hackaday and AtariAge TI-99/4A forums.

https://hackaday.io/project/15430-rc201699-ti-994a-clone-using-tms99105-cpu

AtariAge
--------
The AtariAge forum thread talks about my other FPGA project as well, but contains information about 
http://atariage.com/forums/topic/255855-ti-994a-with-a-pipistrello-fpga-board/page-8

About the directories
---------------------
**firmware** test software I used to debug the hardware. Written in assembler. Also some loading scripts.

**fpga** the VHDL code implementing the TI-99/4A (except the CPU).

**memloader** a program for Windows (compiled with Cygwin) to transfer data from PC to the FPGA. This program is used for a few purposes:
- load software from PC to the memory of the EP994A
- reset the EP994A
- pass keypresses from host PC to the EP994A

**schematics** the schematics of the protoboard (incl. CPU, clock, a buffer chip) connected to the FPGA board. Note: the schematics are in a need of an update, the current version lacks to wires:
- CPU reset from FPGA to buffer to CPU
- VDP interrupt signal from FPGA to buffer to CPU
