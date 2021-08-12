/********************************************************************
Copyright 2010-2017 K.C. Wang, <kwang@eecs.wsu.edu>
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http:@www.gnu.org/licenses/>.
********************************************************************/

	.text
.code 32
.global reset_handler
.global vectors_start, vectors_end

.global inton, getcsr
.global switchPtable
.global lock, unlock, int_off, int_on, getpgdir
.global irq_handler, data_handler, data_abort_handler
.global svc_entry
.global getsp, Mtable
.global get_fault_status, get_fault_addr, get_spsr
.global main
.global switchPgdir

reset_handler:
  LDR sp, =svc_stack_top

@ Versatilepb: 128MB RAM, 3 I/O sections at 256MB
/*********L1 section entry ***********************************
 |3            2|1|1111111|11|0|0000|0|00|00
 |1            0|9|8765432|10|9|8765|4|32|10|
 |     addr     | |       |AP|0|DOMN|1|CB|10|
 |              |000000000|01|0|0000|1|00|10|
                           KRW  dom0
                          0x 4    1      2
*********************************************/
@ clear pgtable to 0
  mov r0, #0x4000            @ ptable at 0x4000=16 KB
  mov r1, #4096              @ 4096 entries
  mov r2, #0                 @ fill all with 0
1:
  str r2, [r0],#0x04         @ store r3 to [r0]; inc r0 by 4
  subs r1, r1, #1            @ r1-- 
  bgt 1b                     @ loop r1=4096 times

@ Versatilepb, arm926ej-s only have 256MB RAM + 2MB I/O at 256MB,
@ pgtable[0-257] ID map to low 258MB PA
@ pgtable[2048, 2048+257]: VA=2G map to low 258MB PA
  mov r0, #0x4000            @ r0 => ptable[0]
  mov r1, r0 
  add r1, #(2048*4)          @ r1 => ptable[2048]
	
  mov r2, #256               @ r2=256
  add r2, r2, #2             @ r2=258 entries for 256MB RAM + 2MB I/O space
  mov r3, #0x100000          @ r3=1M increments

  mov r4, #0x400             @ create r4=0x412
  orr r4, r4, #0x12          @ r4 = 0x412 OR 0xC12 if AP=11: used 0xC12

@ KCW: seems must ID map lowest 1MB
  str r4, [r0]               @ set ptable[0] to ID map 1MB PA	
2:
  str r4, [r1], #4           @ store r4 to [r1]; inc r1 by 4
  add r4, r4, r3             @ inc r4 by 1M
  subs r2, r2, #1            @ r2-- 
  bgt 2b                     @ loop r2=258 times

@ set TTB pointing at ptable at 0x4000 = 16 KB
  mov r0, #0x4000
  mcr p15, 0, r0, c2, c0, 0  @ set TTBase with PHYSICAL address 0x400000
  mcr p15, 0, r0, c8, c7, 0  @ flush TLB

@ set domain0: 01=client(check permission) 11=master(no check)
  mov r0, #0x1               @ 01 for CLIENT
  mcr p15, 0, r0, c3, c0, 0  @ write 0x11=MASTER to domain REG c3

@ enable MMU 
  mrc p15, 0, r0, c1, c0, 0   @ read control REG c1 into r0
@ c1 bit-13 = 1 => remap Vectors to 0xFFFF0000-0xFFFF001C
  mov r0, #0
  orr r0, r0, #0x00002000      @ set C1 bit 13 (remap vectors) and bit 0
  ORR r0, r0, #0x00000001     @ set bit0 of r0 to 1
  mcr p15, 0, r0, c1, c0, 0   @ write to control REG c1 ==> MMU on
  nop
  nop
  nop
  mrc p15, 0, r2, c2, c0, 0   @ read TLB base reg c2 into r2
  mov r2, r2                  @ time ??   

  adr pc, start               @ force PC-relative addresssing

start:	 
@ set SVC stack to high end of int svc_stack[1024]
  LDR r5, =svc_stack      @ r5 points svc_stack[]
  ADD r5, #4096           @ r4 -> high end of svc_stack[]
  MOV sp, r5

@ go in IRQ mode to set IRQ stack 
  MSR cpsr, #0x12    @ write to cspr, so in IRQ mode now 
  ldr sp, =irq_stack @ u32 irq_stack[1024] in t.c
  add sp, sp,#4096   @ ensure it's a VA from 2GB

@ go in ABT mode to set ABT stack
  MOV r0, #0x17  @ORR r1, r1, #0x17
  MSR cpsr, r0
  LDR sp, =abt_stack_top
	
@ go back to SVC mode, enable IRQ interrupts
  mov r0, #0x13      @ both IRQ and FIQ bits are 0
  MSR cpsr, r0       @ write to cspr, so in SVC mode now

@ NO MORE copy vector table to address 0 
@  BL copy_vector_table
@  BL main

@ call main() in SVC mode
  LDR r0, mainstart
  mov pc, r0
  B .

mainstart: .word main

.align 4
data_handler:
  sub	lr, lr, #4   @ ARM's linkReg must be -4; if write irq_handler() with
  stmfd	sp!, {r0-r12, lr}  @ save all Umode regs in kstack
  bl	data_abort_handler @ call handler in C
  ldmfd	sp!, {r0-r12, pc}^ @ pop from kstack but restore Umode SR

irq_handler:           @ IRQ interrupts entry point
  sub	lr, lr, #4   @ ARM's linkReg must be -4; if write irq_handler() with
  stmfd	sp!, {r0-r12, lr}  @ save all Umode regs in kstack
  bl	irq_chandler  @ call irq_handler() in C in svc.c file   
  ldmfd	sp!, {r0-r12, pc}^ @ pop from kstack but restore Umode SR

getsp:
   mov r0, sp
   mov pc, lr
	
switchPgdir:	@ switch pgdir to new PROC's pgdir; passed in r0
  @ r0 contains address of PROC's pgdir address	
  mcr p15, 0, r0, c2, c0, 0  @ set TTBase to C2
  mov r1, #0
  mcr p15, 0, r1, c8, c7, 0  @ flush TLB 
  mcr p15, 0, r1, c7, c10, 0 @ flush TLB
  mrc p15, 0, r2, c2, c0, 0  @ read TLB base reg C2
	
  @ set domain: all 01=client(check permission) 11=master(no check)
  mov r0, #0x3                @ 11 for MASER
  mcr p15, 0, r0, c3, c0, 0   @ write 0x3 to domain reg C3

  adr pc, isan
isan:	
  mov pc, lr

getpgdir: @ read tlb base register C2
    mrc p15, 0, r0, c2,c0, 0  @ read P15's C2 into r0
    mov pc,lr              @ return

svc_entry:

	
get_fault_status:	@ read and return MMU reg 5
  MRC p15,0,r0,c5,c0,0    @ read DFSR
  mov pc, lr	

get_fault_addr:	         @ read and return MMU reg 6
  MRC p15,0,r0,c6,c0,0    @ read DFSR
  mov pc, lr	

get_spsr:
  mrs r0, spsr
  mov pc, lr

vectors_start:
  LDR PC, reset_handler_addr
  LDR PC, undef_handler_addr
  LDR PC, svc_handler_addr  
  LDR PC, prefetch_abort_handler_addr
  LDR PC, data_abort_handler_addr
  B .
  LDR PC, irq_handler_addr
  LDR PC, fiq_handler_addr

reset_handler_addr:          .word reset_handler
undef_handler_addr:          .word loopBobo
svc_handler_addr:            .word loopBobo
prefetch_abort_handler_addr: .word loopBobo
data_abort_handler_addr:     .word data_handler
irq_handler_addr:            .word irq_handler
fiq_handler_addr:            .word loopBobo

loopBobo:
  b .

vectors_end:

@ int_on()/int_off(): turn on/off IRQ interrupts
int_on: @ may pass parameter in r0
unlock:	
	MRS r4, cpsr
  BIC r4, r4, #0x80   @ clear bit means UNMASK IRQ interrupt
  MSR cpsr, r4
  mov pc, lr	

int_off: @ may pass parameter in r0
lock:	
	MRS r4, cpsr
  ORR r4, r4, #0x80   @ set bit means MASK off IRQ interrupt 
  MSR cpsr, r4
  mov pc, lr	



	.end
