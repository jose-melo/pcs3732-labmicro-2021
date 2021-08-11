

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
  int i;
  unsigned int pentry, *ptable;
  print_uart0("            Welcome to WANIX in Arm\n");
  print_uart0("1. build level-1 pgtable at 16KB\n");

  ptable = (unsigned int *)0x4000; // page table at 0x4000

  for (i = 0; i < 4096; i++)
  { // clear 4K entries to 0
    ptable[i] = 0;
  }
  print_uart0("2. fill 258 entries of ptable to ID map 258MB VA to PA\n");
  pentry = 0 | 0x412; // 01 0 0000 1 00 10
  //  pentry = 0 | 0x41E; 01 0 0000 1 11 10

  for (i = 0; i < 258; i++)
  {
    ptable[i] = pentry;
    pentry += 0x100000; // 1 0000 0000 0000 0000 0000 inc by 1MB
  }
  print_uart0("3. finished building level-1 page table\n");
  print_uart0("4. return to set TTB, doman and enable MMU\n");
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

  print_uart0("test MMU protection: try to access VA=0x00200000\n");
  p = (int *)0x00200000;
  *p = 123;

  print_uart0("test MMU protection: try to access VA=0x02000000\n");
  p = (int *)0x02000000;
  *p = 123;

  print_uart0("test MMU protection: try to access VA=0x20000000\n");
  p = (int *)0x20000000;
  *p = 123;

  while (1)
  {
  }
}
