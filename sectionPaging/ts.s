	.text
.code 32
@ ------------------------------------  	
@ Configuracao dos simbolos globais
@ ------------------------------------  	
.global reset_handler
.global vectors_start, vectors_end
.global get_fault_status, get_fault_addr, get_spsr
.global lock, unlock, int_off, int_on

@ ------------------------------------  	
@ Inicio da execucao
@ ------------------------------------  	
reset_handler:
  LDR sp, =svc_stack_top     @ Ajuste da pilha do supervisor 
  BL copy_vector_table       @ Copia a tabela de vetores em C
  BL mkPtable                @ Cria, em C, a tabela de páginas

@ ------------------------------------  	
@ Ajusta o registrador TTB 
@ ------------------------------------  	
  mov r0, #0x4000            @ O endereço base da tabela sera 0x4000
  mcr p15, 0, r0, c2, c0, 0  @ Usa o R0 para configurar o TTBase da MMU
  mcr p15, 0, r0, c8, c7, 0  @ Apaga o cache TLB (translate lookaside buffer)

@ ------------------------------------  	
@ Configura o dominio domain0: 
@    01 = client (Verifica a permissao)
@    11 = master (Sem verificacao das permissoes)
@ ------------------------------------  	
  mov r0,#1                   @ Escreve 01 no registrador R0  
  mcr p15, 0, r0, c3, c0, 0   @ Configura o registrador de dominio da MMU

@ ------------------------------------  	
@ Habilita a MMU
@ ------------------------------------  	
  mrc p15, 0, r0, c1, c0, 0   @ Leitura do reg. c1 da MMU para o r0
  orr r0, r0, #0x00000001     @ Ativa o primeiro bit (bit de enable da MMU)
  mcr p15, 0, r0, c1, c0, 0   @ Configura a MMU com o bit de enable ativado
  nop                         @ Essas tres instrucoes sao importantes para
  nop                         @ dar tempo suficiente para a configuracao da MMU
  nop                         @ Depende da implementacao do hw (qtd de estagios do pipeline)
	
@ ------------------------------------  	
@ Vai para o modo ABT para ajuste da pilha
@ ------------------------------------  	
  MOV r0, #0x17
  MSR cpsr, r0
  LDR sp, =abt_stack_top

@ ------------------------------------  	
@ Vai para o modo UND para ajuste da pilha
@ ------------------------------------  	
  mov r0, #0x1B
  MSR cpsr, r0
  LDR sp, =und_stack_top

@ ------------------------------------  	
@ Vai para o modo IRQ para ajuste da pilha
@ ------------------------------------  	
  mov r0, #0x12
  MSR cpsr, r0            @ Sobrescreve o cpsr para mudar o modo 
  LDR sp, =irq_stack_top  @ Ajusta a pilha
  mov r0, #0x13           @ Volta para o modo SVC
  BIC r0, r0, #0x80       @ Seta o bit de interrupcoes IRQ
  MSR cpsr, r0            @ Habilita as interrupcoes IRQ 

@ ------------------------------------  	
@ Chama a funcao principal em C
@ ------------------------------------  	
  BL main
  B .

.align 4

	
@ ------------------------------------  	
@ Handler da interrupcoes de dados
@ ------------------------------------  	
data_handler: 
  sub	lr, lr, #4             @ Ajusta o LR subtraindo 4
  stmfd	sp!, {r0-r12, lr}    @ Salva regs na pilha
  bl	data_abort_handler     @ Desvia para o handler em C
  ldmfd	sp!, {r0-r12, pc}^   @ Retorna

@ ------------------------------------  	
@ Interrupt vector
@ ------------------------------------  	
vectors_start:
  LDR PC, reset_handler_addr
  LDR PC, undef_handler_addr
  LDR PC, swi_handler_addr
  LDR PC, prefetch_abort_handler_addr
  LDR PC, data_abort_handler_addr
  B .
  LDR PC, irq_handler_addr
  LDR PC, fiq_handler_addr

@ ------------------------------------------  	
@ Tratamentos de interrupcoes: reset e data
@ ------------------------------------------  	
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

