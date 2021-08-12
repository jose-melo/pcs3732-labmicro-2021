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
along with this program.  If not, see <http://www.gnu.org/licenses/>.
********************************************************************/

#include "type.h"
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

// 101f1000 -> 0001 0000 0001 1111 0001 0000 0000 0000

/**************** KCW about remap vector table *********************
ARM vector table can be remapped to 0xFFFF0000 by bit-13 of C1=1
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

  // print_uart0("1. build new page table at 3MB\n");
  pgdir = (int *)0x80300000;
  pentry = 0x412;

  for (i = 0; i < 4096; i++)
  { // zero out 496 entries
    pgdir[i] = 0;
  }

  // build pgtables at 5MB
  // print_uart0("2. fill 258 entries in level-1 pgdir with 258 pgtables\n");
  // 2048 - 2305
  pgtable = (int *)(0x80300000);
  for (i = 0; i < 257; i++)
  {                                // ASSUME 256MB RAM; 2 I/O sections
    pgdir[i + 2048] = (int)pentry; // start with 0
    pentry += 0x100000;
  }

  // 0x400412

  // 0x90100000 map to 0x101f1000
  // 0x90100000 map to 0x101f1
  pgdir[257 + 2048] = 0x10100000 | 0x412; // f1000

  // 100000000000
  pgtable[4095] = 0 | 0x412; // VA 0xFFF00000 map to 0

  //print_uart0("switch to pgdir to 0x300000 (3MB) .... ");
  switchPgdir(0x300000);
  //print_uart0("switch pgdir OK\n");
}

int main()
{
  int i, j, a, sp;
  char line[128];
  int *ip;
  u32 *pt;

  lock();
  // print_uart0("Welcome to WANIX in ARM\n");
  // print_uart0("Demonstration of one-level sections with VA=0x80000000(2GB)\n");

  mkPtable();
  remap_vector_table();

  print_uart0("test MMU protection: try to access VA=2G+2MB\n");
  ip = (int *)VA(2 * 0x100000); // should be OK
  *ip = 123;

  print_uart0("test MMU protection: try to access VA=2MB\n");
  ip = (int *)(2 * 0x100000); // should be data abort fault
  *ip = 123;

  print_uart0("test MMU protection: try to access VA=2G+512MB\n");
  ip = (int *)VA(512 * 0x100000); // should data abort fault
  *ip = 123;

  unlock();
  while (1)
  {
  }
}
