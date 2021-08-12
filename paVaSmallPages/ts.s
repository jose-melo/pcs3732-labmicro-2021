	.text
.code 32
@ ------------------------------------  	
@ Configuracao dos simbolos globais
@ ------------------------------------
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

@ ------------------------------------  	
@ Inicio da execucao
@ ------------------------------------
reset_handler:
  LDR sp, =svc_stack_top


@ ------------------------------------  
@ Limpa tabela de paginas 
@ ------------------------------------  
  mov r0, #0x4000            @ Tabela de paginas em 0x4000=16 KB
  mov r1, #4096              @ Temos 4096 entradas
  mov r2, #0                 @ Preencher tudo com zeros
1:
  str r2, [r0],#0x04         @ Zera a tabela e incrementa o ponteiro
  subs r1, r1, #1            @ Subtrai o contador r1
  bgt 1b                     @ Faz o loop 4096 vezes

@ ------------------------------------  
@ pgtable[0-257] vai mapear os 258MB mais baixos
@ pgtable[2048, 2048+257] vai mapear 2G de endereco virtual para 258MB do endereco fisico
@ ------------------------------------  
  mov r0, #0x4000            @ Inicializa o ponteiro para ptable[0]
  mov r1, r0 
  add r1, #(2048*4)          @ R1 sera o ponteiro para ptable[2048]
	
  mov r2, #256               @ Carrega r2 com 256
  add r2, r2, #2             @ R2 indicara as 258 entradas: 256MB RAM + 2MB espaco de I/O
  mov r3, #0x100000          @ O passo dos enderecos eh de 1M

  mov r4, #0x400             @ Ajuste da descricao
  orr r4, r4, #0x12          @ R4 recebe 0x412 
  str r4, [r0]               @ set ptable[0] to ID map 1MB PA	
2:
  str r4, [r1], #4           @ Armazena a descricao na tabela
  add r4, r4, r3             @ Soma com o passo
  subs r2, r2, #1            @ Subtrai o numero de entradas 
  bgt 2b                     @ Faz o loop

@ ------------------------------------  	
@ Ajusta o registrador TTB 
@ ------------------------------------
  mov r0, #0x4000            @ O endereço base da tabela sera 0x4000
  mcr p15, 0, r0, c2, c0, 0  @ Usa o R0 para configurar o TTBase da MMU
  mcr p15, 0, r0, c8, c7, 0  @ Apaga o cache TLB (translate lookaside buffer

@ ------------------------------------  	
@ Configura o dominio domain0: 
@    01 = client (Verifica a permissao)
@    11 = master (Sem verificacao das permissoes)
@ ------------------------------------  
  mov r0, #0x1               @ 01 para cliente
  mcr p15, 0, r0, c3, c0, 0  

@ ------------------------------------  	
@ Habilita a MMU
@ ------------------------------------   
  mrc p15, 0, r0, c1, c0, 0   @ Leitura do reg. c1 da MMU para o r0
  mov r0, #0
  orr r0, r0, #0x00002000     @ Ativa o 13o bit (vamos remapear o vetor de interrupt)
  ORR r0, r0, #0x00000001     @ Ativa o primeiro bit (bit de enable da MMU)
  mcr p15, 0, r0, c1, c0, 0   @ Configura a MMU
  nop
  nop
  nop
  mrc p15, 0, r2, c2, c0, 0   @ Verificacao: faz a leitura o TLBbase 
  mov r2, r2                    

  adr pc, start               @ Usamos enderecamento relativo ao PC

start:	 
@ ------------------------------------  	
@ Ajuste da pilha do supervisor (endereco virtual)
@ ------------------------------------ 
  LDR r5, =svc_stack     
  ADD r5, #4096          
  MOV sp, r5

@ ------------------------------------  	
@ Vai para o modo IRQ para ajuste da pilha
@ ------------------------------------  
  MSR cpsr, #0x12    
  ldr sp, =irq_stack 
  add sp, sp,#4096   

@ ------------------------------------  	
@ Vai para o modo ABT para ajuste da pilha
@ ------------------------------------  
  MOV r0, #0x17  
  MSR cpsr, r0
  LDR sp, =abt_stack_top

@ ------------------------------------  	
@ Volta para o modo SVC para ajuste das interrupcoes
@ ------------------------------------  
  mov r0, #0x13      
  MSR cpsr, r0       

@ ------------------------------------  	
@ Chama a funcao principal em C
@ ------------------------------------
  LDR r0, mainstart
  mov pc, r0
  B .

mainstart: .word main

.align 4
@ ------------------------------------  	
@ Handler da interrupcoes de dados
@ ------------------------------------ 
data_handler:
  sub	lr, lr, #4   @ ARM's linkReg must be -4; if write irq_handler() with
  stmfd	sp!, {r0-r12, lr}  @ save all Umode regs in kstack
  bl	data_abort_handler @ call handler in C
  ldmfd	sp!, {r0-r12, pc}^ @ pop from kstack but restore Umode SR

@ ------------------------------------  	
@ Handler da interrupcoes IRQ 
@ ------------------------------------ 
irq_handler:           
  sub	lr, lr, #4   
  stmfd	sp!, {r0-r12, lr}  
  bl	irq_chandler   
  ldmfd	sp!, {r0-r12, pc}^ 

getsp:
   mov r0, sp
   mov pc, lr
	
@ ------------------------------------  	
@ Altera o diretorio de tabela de paginas
@ ------------------------------------ 	
switchPgdir:	@ Assume-se que R0 contem o novo diretorio
  mcr p15, 0, r0, c2, c0, 0   @ Seta o novo diretorio em C2
  mov r1, #0
  mcr p15, 0, r1, c8, c7, 0  @ Limpa TLB
  mcr p15, 0, r1, c7, c10, 0 @ Limpa TLB
  mrc p15, 0, r2, c2, c0, 0  @ Realiza a leitura o endereco do TLB base
	
@ ------------------------------------  	
@ Configura o dominio domain0: 
@    01 = client (Verifica a permissao)
@    11 = master (Sem verificacao das permissoes)
@ ------------------------------------  
  mov r0, #0x3                @ 11 para master
  mcr p15, 0, r0, c3, c0, 0   @ Configura a MMU

  adr pc, isan
isan:	
  mov pc, lr

@ ------------------------------------  	
@ Faz a leitura da tabela de paginas 
@ ------------------------------------ 	
getpgdir: 
    mrc p15, 0, r0, c2,c0, 0  
    mov pc,lr              

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
