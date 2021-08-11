	.text
.code 32
.global reset_handler
.global vectors_start, vectors_end
.global get_fault_status, get_fault_addr, get_spsr
.global lock, unlock, int_off, int_on
	
reset_handler:
   LDR sp, =svc_stack_top  @ set SVC stack

  BL copy_vector_table       @ call C
	
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
	
  BL mkPtable
  	
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
  orr r0, r0, #0x00000001     @ set bit0 to 1
  mcr p15, 0, r0, c1, c0, 0   @ write to c1
  nop
  nop
  nop
	
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
@  /* Enable IRQs */
	
@@ go back in SVC mode
  mov r0, #0x13           @ r0 = SVC mode
  BIC r0, r0, #0x80       @ ensure IRQ interrupt mask bit=0
  MSR cpsr, r0            @ write r0 to CPSR

@@ call main() in SVC mode */
  BL main
  B .

.align 4

	
data_handler: @ KCW: when data exception occur, BAD instruction is at lr-8
  sub	lr, lr, #4  @ lr-4 skip over the BAD instruction=> continue on
  stmfd	sp!, {r0-r12, lr}
  bl	data_abort_handler  
  ldmfd	sp!, {r0-r12, pc}^   

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

