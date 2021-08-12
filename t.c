

int again;

volatile unsigned int *const UART0DR = (unsigned int *)0x101f1000;
int svc_stack[1024], irq_stack[1024];

#define u32 unsigned int
#define VA(x) ((x) + 0x80000000)
#define PA(x) ((x)-0x80000000)

void print_uart0(const char *s)
{
  int i;
  while (*s != '\0')
  {
    *UART0DR = (unsigned int)(*s);
    s++;
  }
}

int remap_vector_table()
{
  extern u32 vectors_start;
  extern u32 vectors_end;
  int i;

  u32 *vectors_src = &vectors_start;
  u32 *vectors_dst = (u32 *)0x800F0000; // highest 64KB in 1MB area

  print_uart0("REMAP: vector_src to vector_end \n");

  while (vectors_src < &vectors_end)
    *vectors_dst++ = *vectors_src++;
}

int mkPtable()
{
  int i, j;
  int *pgdir, *pgtable, paddr, pentry;

  print_uart0("1. build new page table at 3MB\n");
  pgdir = (int *)0x80300000;
  pentry = 0x412;

  for (i = 0; i < 4096; i++)
  { // zero out 496 entries
    pgdir[i] = 0;
  }

  // build pgtables at 5MB
  print_uart0("2. fill 258 entries in level-1 pgdir with 258 pgtables\n");
  pgtable = (int *)(0x80300000);
  for (i = 0; i < 258; i++)
  {                                // ASSUME 256MB RAM; 2 I/O sections
    pgdir[i + 2048] = (int)pentry; // start with 0
    pentry += 0x100000;
  }

  pgtable[4095] = 0 | 0x412; // VA 0xFFF00000 map to 0

  print_uart0("switch to pgdir to 0x300000 (3MB) .... ");
  switchPgdir(0x300000);
  print_uart0("switch pgdir OK\n");
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
  int i, j, a, sp;
  char line[128];
  int *ip;

  print_uart0("Welcome to WANIX in ARM\n");
  print_uart0("Demonstration of one-level sections with VA=0x80000000(2GB)\n");

  mkPtable();
  remap_vector_table();

  sp = getsp();

  /*************************
   print_uart0("call mkptable() to build 2-level page tables\n");  
   mkPtable();
   *************************/

  print_uart0("try to see vectors at VA=0x800F0000\n");

  print_uart0("test MMU protection: try to access VA=2G+2MB\n");
  ip = (int *)VA(2 * 0x100000); // should be OK
  *ip = 123;

  print_uart0("test MMU protection: try to access VA=2MB\n");
  ip = (int *)(2 * 0x100000); // should be data abort fault
  *ip = 123;

  print_uart0("test MMU protection: try to access VA=2G+512MB\n");
  ip = (int *)VA(512 * 0x100000); // should data abort fault
  *ip = 123;

  while (1)
  {
  }
}
