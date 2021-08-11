

int again;

volatile unsigned int *const UART0DR = (unsigned int *)0x101f1000;

void print_uart0(const char *s)
{
  int i;
  while (*s != '\0')
  {
    *UART0DR = (unsigned int)(*s);
    s++;
  }
}

int mkPtable()
{
  int i, j;
  unsigned int pentry, *ptable, *pgtable, paddr;
  print_uart0("            Welcome to WANIX in Arm\n");

  ptable = (unsigned int *)0x4000; // page table at 0x4000

  print_uart0("1. build level-1 pgtable at 16KB to map 258 MB VA to PA\n");
  for (i = 0; i < 4096; i++)
  { // clear 4K entries to 0
    ptable[i] = 0;
  }
  print_uart0("2. fill 258 entries in level-1 pgdir with 258 pgtable\n");
  pentry = 0 | 0x412; // 01 0 0000 1 00 10
  //  pentry = 0 | 0x41E; 01 0 0000 1 11 10

  for (i = 0; i < 258; i++)
  {
    ptable[i] = (0x500000 + i * 1024) | 0x11; // domain = 0, CB = 00,type = 01
  }
  // 0x00500011
  // 00 0000 0001 0100 0000 0000 | 0000 0000 0000
  // 0000 0000 0101 0000 0000 00 | 00 0000 00 = index do MVA | 00 = zerados por padrão!! LoL

  print_uart0("3. build 258 level-2 pgtables at 5 MB\n");

  for (i = 0; i < 258; i++)
  {
    pgtable = (unsigned int *)((unsigned int)0x500000 + (unsigned int)i * 1024); // inicializa o ponteiro
    paddr = i * 0x100000 | 0x55E;                                                // 01 | 01 | 01 | 01 | CB = 11 | type = 10
    for (j = 0; j < 256; j++)
    {
      pgtable[j] = paddr + j * 4096;
    }
  }

  print_uart0("4. Finished build two-level page tables\n");

  print_uart0("5. Return to assembly to set TTB, domain and enable MMU\n");
}

int data_abort_handler()
{

  print_uart0("data_abort exception in ");
  unsigned int fault_status, fault_addr, domain, status;
  int spsr = get_spsr();
  again++;
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
  // kprint_uart0("status  = %x: domain=%x status=%x (0x5=Trans Invalid)\n",
  //       fault_status, domain, status);
  // kprint_uart0("VA addr = %x\n", fault_addr);

  // if assembly code used lr-8: shall return to the SAME bad instruction
  // => infinite loop. If so, set a limit to stop the program
  if (again > 3) // limit to 3 times then HANG here
    while (1)
      ;
}

void copy_vector_table(void)
{
  extern unsigned int vectors_start;
  extern unsigned int vectors_end;
  unsigned int *vectors_src = &vectors_start;
  unsigned int *vectors_dst = (unsigned int *)0;
  while (vectors_src < &vectors_end)
    *vectors_dst++ = *vectors_src++;
}

// IRQ interrupts handlers in C
void irq_chandler()
{
  print_uart0("Lulis IRQ\n");
}

int main()
{
  int *p;

  print_uart0("main running using level-1 1MB sections\n");

  print_uart0("test MMU protection: try to access VA=0x00200000 - 2 MB\n");
  p = (int *)0x00200000;
  *p = 123;

  print_uart0("test MMU protection: try to access VA=0x02000000 - 16 MB\n");
  p = (int *)0x02000000;
  *p = 123;

  print_uart0("test MMU protection: try to access VA=0xA0000000 - Fora dos 258 MB\n");
  p = (int *)0xA0000000;
  *p = 123;

  while (1)
  {
  }
}
