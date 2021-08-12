
#include "type.h"

/**
 * Como acessar um dispositivo mapeado em memoria que nao esta
 * no espaco de enderecamento virtual?
 * 
 * A UART eh mapeada no endereco 0x101F1000, que esta fora do
 * espaco de enderecamento de 0x80000000 - 0x90100000. 
 * 
 * Para resolver esse problema, mapeamos a página virtual 0x901
 * para a pagina fisica 0x101. Assim, podemos acessar e controlar
 * a UART. 
 * 
 * Essa solucao, ainda que funcione, deve ser feita com atencao:
 * em sistemas operacionais podemos nao querer que processos de
 * usuario tenham acesso a dispositivos. Como nao temos nenhum
 * SO aqui e passar o buffer do espaco do kernel para o buffer
 * do espaco do usuario seria complicado, optamos por essa solucao.
 * 
 * **/

volatile unsigned int *const UART0DR = (unsigned int *)0x901F1000;
void print_uart0(const char *s)
{
  int i;
  while (*s != '\0')
  {
    *UART0DR = (unsigned int)(*s);
    s++;
  }
}

// Remapeia o vetor de interrupções para a posicao do espaco virtual
int remap_vector_table()
{
  extern u32 vectors_start;
  extern u32 vectors_end;
  u32 *up;
  int i;

  u32 *vectors_src = &vectors_start;
  u32 *vectors_dst = (u32 *)0x800F0000; // highest 64KB in 1MB area

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
  domain = (fault_status & 0xF0) >> 4;
  status = fault_status & 0xF;
}

int svc_stack[1024], irq_stack[1024];

void irq_chandler()
{
  print_uart0("IRQ chandler");
}

extern int reset_handler(), data_abort_handler(), irq_handler(), enable_mmu(), disable_mmu();
int g;

int mkPtable()
{
  int i, j;
  int *pgdir, *pgtable, paddr, pentry;

  pgdir = (int *)0x80300000;
  pentry = 0x412;

  for (i = 0; i < 4096; i++)
  {
    pgdir[i] = 0;
  }

  pgtable = (int *)(0x80300000);
  for (i = 0; i < 257; i++)
  {                                // ASSUME 256MB RAM; 2 I/O sections
    pgdir[i + 2048] = (int)pentry; // start with 0
    pentry += 0x100000;
  }

  /**
   * Aqui mapeamos a pag virutal 0x901xxxxx para 0x101xxxxx.
   * 
   * Observe que 257 + 2048 = 2305. Em hexa = 0x901
   * 
   * **/
  pgdir[257 + 2048] = 0x10100000 | 0x412; // f1000

  pgtable[4095] = 0 | 0x412;

  switchPgdir(0x300000);
}

int main()
{
  int i, j, a, sp;
  char line[128];
  int *ip;
  u32 *pt;

  lock();

  mkPtable();
  remap_vector_table();

  print_uart0("Neste exercicio mapeamos 258MB da memoria virtual a partir de 2 GB :\n");
  print_uart0("   O espaco de enderecamento vai de: 0x80000000 ate 0xC01FFFFF\n");
  print_uart0("[TESTE] Protecao da MMU: tentativa de acesso à 0x80200000 - 2G+2MB\n");
  ip = (int *)VA(2 * 0x100000);
  *ip = 123;

  print_uart0("[TESTE] Protecao da MMU: tentativa de acesso à 0x00200000 - 2MB\n");
  ip = (int *)(2 * 0x100000);
  *ip = 123;

  print_uart0("[TESTE] Protecao da MMU: tentativa de acesso à 0xA0000000 - 2G + 512MB\n");
  ip = (int *)VA(512 * 0x100000);
  *ip = 123;

  unlock();
  while (1)
  {
  }
}
