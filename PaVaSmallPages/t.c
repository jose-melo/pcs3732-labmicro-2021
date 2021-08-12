
#include "type.h"

/**
 * Como acessar um dispositivo mapeado em memoria que nao esta
 * no espaco de enderecamento virtual?
 * 
 * A UART eh mapeada no endereco 0x101F1000, que esta fora do
 * espaco de enderecamento de 0x80000000 - 0x90100000. 
 * 
 * Para resolver esse problema, mapeamos a página virtual 0x901FF 
 * para a pagina fisica 0x101F1. Assim, podemos acessar e controlar
 * a UART. 
 * 
 * Essa solucao, ainda que funcione, deve ser feita com atencao:
 * em sistemas operacionais podemos nao querer que processos de
 * usuario tenham acesso a dispositivos. Como nao temos nenhum
 * SO aqui e passar o buffer do espaco do kernel para o buffer
 * do espaco do usuario seria complicado, optamos por essa solucao.
 * 
 * **/

volatile unsigned int *const UART0DR = (unsigned int *)0x901FF000;
void print_uart0(const char *s)
{
   int i;
   while (*s != '\0')
   {
      *UART0DR = (unsigned int)(*s);
      s++;
   }
}

/**************** KCW about remap vector table *********************
ARM vector table can be remapped to 0xFFFF0000 by set C1.bit13 to 1
Using 1MB sections, we must map the highest 1MB VA to a 1MB PA area 
containing the vector table in the highest 64K of that 1MB PA area.
Assume our kernel image size is < 1MB.
(1). we shall place the vector table at 1MB - 64K = 0xF0000.
(2). set pgtable[4095] = 0x0 + 0x412, i.e. map to 0 
Then the vector table will be at VA=0xFFFF0000
********************************************************************/
int remap_vector_table()
{
   extern u32 vectors_start;
   extern u32 vectors_end;
   u32 *up;
   int i;

   u32 *vectors_src = &vectors_start;
   u32 *vectors_dst = (u32 *)0x800F0000; // highest 64KB in 1MB area

   print_uart0("Remapeamento do vetor de interrupcoes para VA=0x800F0000 \n");

   while (vectors_src < &vectors_end)
      *vectors_dst++ = *vectors_src++;
}

int data_abort_handler()
{
   u32 fault_status, fault_addr, domain, status;
   int spsr = get_spsr();

   print_uart0("data_abort exception in ");
   if ((spsr & 0x1F) == 0x13)
      print_uart0("SVC mode\n");
   if ((spsr & 0x1F) == 0x10)
      print_uart0("USER mode\n");

   fault_status = get_fault_status();
   fault_addr = get_fault_addr();
   // fault_status = 7654 3210
   //                doma status
   domain = (fault_status & 0xF0) >> 4;
   status = fault_status & 0xF;
}

int svc_stack[1024], irq_stack[1024];

void irq_chandler()
{
   print_uart0("IRQ handler");
}

extern int reset_handler(), data_abort_handler(), irq_handler();
int g;

int mkPtable()
{
   int i, j;
   int *pgdir, *pgtable, paddr, pentry;

   pgdir = (int *)0x80008000;
   pentry = 0x412;

   for (i = 0; i < 4096; i++)
   { // zero out 496 entries
      pgdir[i] = 0;
   }

   // build pgtables at 32 KB
   pgtable = (int *)(0x80008000);
   for (i = 0; i < 258; i++)
   {                                 // ASSUME 256MB RAM; 2 I/O sections
      pgdir[i + 2048] = (int)pentry; // start with 0
      pentry += 0x100000;
   }

   pgtable[4095] = 0 | 0x412; // VA 0xFFF00000 map to 0

   switchPgdir(0x8000);
}

int mk2Ptable()
{
   int i, j;
   int *pgdir, *pgtable, paddr, pentry;

   pgdir = (int *)0x8000C000; // at 48KB

   for (i = 0; i < 4096; i++)
   {
      pgdir[i] = 0;
   }

   // build pgtables at 4MB
   for (i = 0; i < 258; i++)
   {                                                       // ASSUME 256MB RAM; 2 I/O sections
      pgdir[i + 2048] = (int)(0x400000 + i * 1024) | 0x11; // in 5MB

   } // 0x11:DOMAIN=0,CB=00,type=01

   // 0000 0000 0100 0000 0000 00 | 0 | 0000 | 1 | 00 | 01
   // 0000 0000 0100 0000 0000 00 | 8 bits do MVA | 00

   for (i = 0; i < 258; i++)
   {
      pgtable = (int *)(0x80400000 + (int)i * 1024);
      paddr = i * 0x100000 | 0x55E; // all APs=01|01|01|01|CB=11|type=10
      for (j = 0; j < 256; j++)
      {                                 // 256 entries, each points to 4KB PA
         pgtable[j] = paddr + j * 4096; // inc by 4KB
      }
   }

   pgdir[4095] = 0x480000 | 0x11;

   pgtable = (int *)(0x80480000);
   paddr = 0x0 | 0x55E; // all APs=01|01|01|01|CB=11|type=10
   for (j = 0; j < 256; j++)
   {                                 // 256 entries, each points to 4KB PA
      pgtable[j] = paddr + j * 4096; // inc by 4KB
   }

   /**
   * Aqui mapeamos a pag virutal 0x901FFxxx para 0x101F1xxx.
   * 
   * **/
   pgtable = (int *)(0x80400000 + (int)257 * 1024);
   pgtable[255] = 0x101F1000 | 0x55E;

   switchPgdir(0xC000);
}

int main()
{
   int i, j, a, sp;
   char line[128];
   int *ip;
   u32 *pt;

   mkPtable();
   remap_vector_table();
   mk2Ptable();

   print_uart0("Neste exercicio mapeamos 258MB da memoria virtual a partir de 2 GB :\n");
   print_uart0("   O espaco de enderecamento vai de: 0x80000000 ate 0xC01FFFFF\n");
   print_uart0("[TESTE] Protecao da MMU: tentativa de acesso à 0x80200000 - 2G+2MB\n");
   ip = (int *)0x80200000;
   *ip = 123;

   print_uart0("[TESTE] Protecao da MMU: tentativa de acesso à 0x02000000 - 32MB\n");
   ip = (int *)0x02000000;
   *ip = 123;

   // print_uart0("try to see vectors at VA=0x800F0000\n");
   // print_uart0("try to see vectors at VA=0xFFFF0000\n");

   print_uart0("[TESTE] Protecao da MMU: tentativa de acesso à 0x20000000 - 512 MB\n");
   ip = (int *)0x20000000;
   *ip = 123;

   unlock();
   while (1)
   {
   }
}
