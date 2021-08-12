	.text
.code 32
.global reset_handler
.global vectors_start, vectors_end
.global get_fault_status, get_fault_addr, get_spsr
.global lock, unlock, int_off, int_on
.global switchPgdir, getsp
	
reset_handler:
   LDR sp, =svc_stack_top  @ set SVC stack
	
@ /* KCW: set up MM try ID map sections first */
@ @ Versatilepb: 256MB RAM, 2 I/O sections at 256MB
@ /*********L1 section entry ***********************************
@  |3            2|1|1111111|11|0|0000|0|00|00
@  |1            0|9|8765432|10|9|8765|4|32|10|
@  |     addr     | |       |AP|0|DOMN|1|CB|10|
@  |              |000000000|01|0|0000|1|00|10|
@                            KRW  dom
@                           0x 4    1      2
@	*********************************************/


@ for(i = 0; i < 4096; i++)ptable[i] = 0
  mov r0, #0x4000
  mov r1, #4096
  mov r2, #0
loop1:
  str r2, [r0], #0x04
  subs r1, r1, #1
  bgt loop1

  mov r0, #0x4000   @ ptable[0]
  mov r1, r0
  add r1, #(2048*4) @ ptable[2048]

  mov r2, #256
  add r2, r2, #2    @ r2 = 258, num. de entradas
  mov r3, #0x100000 @ incrementa 1 MB

  mov r4, #0x400
  orr r4, r4, #0x12 @ r4 = 0x412 -> |AP = 01 | 0 -> SBZ | 0000 -> domain | 1 | 00 -> CB | 10 -> section

  str r4, [r0]
loop2:
  str  r4, [r1], #4   @
  add  r4, r4, r3     @ 1 MB increment
  subs r2, r2, #1
  bgt  loop2

@ set TTB register
  mov r0, #0x4000
  mcr p15, 0, r0, c2, c0, 0  @ set TTBase
  mcr p15, 0, r0, c8, c7, 0  @ flush TLB

@@ set domain0: 01=client(check permission) 11=master(no check)
  mov r0,#1                  @ client
@  @ mov r0,#0x3             @ manager mode: NO permission check
  mcr p15, 0, r0, c3, c0, 0
@@ enable MMU
  mrc p15, 0, r0, c1, c0, 0   @ get c1 into r0
  mov r0, #0
  orr r0, r0, #0x00002000
  orr r0, r0, #0x00000001     @ set bit0 to 1
  mcr p15, 0, r0, c1, c0, 0   @ write to c1
  nop
  nop
  nop
  mrc p15, 0, r2, c2, c0, 0   @ read TLB base reg c2 into r2	
  mov r2, r2
  adr pc, start 

start:
  ldr r5, =svc_stack
  add r5, #4096
  mov sp, r5
	
@@ go in ABT mode to set ABT stack
  MOV r0, #0x17  @ORR r1, r1, #0x17
  MSR cpsr, r0
  LDR sp, =abt_stack_top
@ @ go in UND mode to set UND stack
  mov r0, #0x1B
  MSR cpsr, r0
  LDR sp, =und_stack_top
@ @ go in IRQ mode to set IRQ stack and enable IRQ interrupts
  mov r0, #0x12
  MSR cpsr, r0            @ write to cspr, so in IRQ mode now 
  LDR sp, =irq_stack_top  @ set IRQ stack poiner
  ADD sp, sp, #4096
@  /* Enable IRQs */
	
@@ go back in SVC mode
  mov r0, #0x13           @ r0 = SVC mode
  BIC r0, r0, #0x80       @ ensure IRQ interrupt mask bit=0
  MSR cpsr, r0            @ write r0 to CPSR

@@ call main() in SVC mode */
@  BL main
  LDR r0, mainstart
  mov pc, r0
  B .

mainstart: .word main

.align 4

	
data_handler: @ KCW: when data exception occur, BAD instruction is at lr-8
  sub	lr, lr, #4  @ lr-4 skip over the BAD instruction=> continue on
  stmfd	sp!, {r0-r12, lr}
  bl	data_abort_handler  
  ldmfd	sp!, {r0-r12, pc}^   



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

  adr pc, go
go:	
  mov pc, lr

getpgdir: @ read tlb base register C2
    mrc p15, 0, r0, c2,c0, 0  @ read P15's C2 into r0
    mov pc,lr              @ return

vectors_start:
  LDR PC, reset_handler_addr
  LDR PC, undef_handler_addr
  LDR PC, swi_handler_addr
  LDR PC, prefetch_abort_handler_addr
  LDR PC, data_abort_handler_addr
  B .
  LDR PC, irq_handler_addr
  LDR PC, fiq_handler_addr

@  reset_handler_addr:          .word reset_handler
@  undef_handler_addr:          .word undef_handler
@  swi_handler_addr:            .word swi_handler
@  prefetch_abort_handler_addr: .word prefetch_abort_handler
@  data_abort_handler_addr:     .word data_handler
@  irq_handler_addr:            .word irq_handler
@  fiq_handler_addr:            .word fiq_handler

  reset_handler_addr:          .word reset_handler   
  undef_handler_addr:          .word loopBobo
  swi_handler_addr:            .word loopBobo
  prefetch_abort_handler_addr: .word loopBobo
  data_abort_handler_addr:     .word data_handler 
  irq_handler_addr:            .word loopBobo
  fiq_handler_addr:            .word loopBobo

vectors_end:                 .word 0x0

loopBobo:
  b .

unlock:	
  MRS r0, cpsr
  BIC r0, r0, #0x80   @ clear bit means UNMASK IRQ interrupt
  MSR cpsr, r0
  mov pc, lr	

lock:	
  MRS r0, cpsr
  ORR r0, r0, #0x80    @ set bit means MASK off IRQ interrupt 
  MSR cpsr, r0
  mov pc, lr	

int_on:	  @ int_on(sr)
  MSR cpsr, r0
  mov pc, lr	

int_off:	@ sr = int_off()
  MRS r0, cpsr
  MOV r1, r0
  ORR r1, r1, #0x80     @ set bit means MASK off IRQ interrupt 
  MSR cpsr, r1
  mov pc, lr            @ retunr CPSR in r0	

get_fault_status:	@ read and return MMU reg 5
  MRC p15,0,r0,c5,c0,0  @ read DFSR
  mov pc, lr	

get_fault_addr:	        @ read and return MMU reg 6
  MRC p15,0,r0,c6,c0,0  @ read DFSR
  mov pc, lr	

get_spsr:
  mrs r0, spsr
  mov pc, lr

