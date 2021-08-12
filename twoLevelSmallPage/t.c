

int again;
char *table = "0123456789ABCDEF";
char resp[9];
char concat_aux[256];

volatile unsigned int *const UART0DR = (unsigned int *)0x101f1000;
char getCharVal(unsigned int dig);
void convertNum(unsigned int num, unsigned int base, char *str);
void concat(char *str1, char *str2, char *concat);

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
  print_uart0("             Inicializacao do programa: mapeamento direto de paginas\n");
  print_uart0("1. Constroi uma tabela de pagina de 1 nivel em 16 KB para mapear 258 MB\n");

  // A tabela de paginas comeca no endereco 0x4000
  ptable = (unsigned int *)0x4000;

  // Limpeza das 4096 entradas da tabela de paginas
  for (i = 0; i < 4096; i++)
  {
    ptable[i] = 0;
  }

  pentry = 0 | 0x412;

  /**
   * Vamos olhar mais de perto o pentry:
   * 
   * 0x412 = 0100 0001 0010 em binario
   * 
   * Olhando a definicao da descricao de secoes temos:
   *  
   * Indice dos bits: | 31   -   20  | 19   -   12 | 11 - 10 | 9 | 8  -  5 | 4 | 3 | 2 | 1 | 0 | 
   * Funcao:          |   Endereco   |      SBZ    |   AP    |SBZ|  Domain | 1 | C | B | 1 | 0 |
   * 0x412:           | 000000000000 |   00000000  |   00    | 1 |  00000  | 1 | 0 | 0 | 1 | 0 |  
   * **/

  print_uart0("2. Vamos preencher 258 entradas do diretorio com 258 tabelas de paginas\n");

  for (i = 0; i < 258; i++)
  {
    ptable[i] = (0x500000 + i * 1024) | 0x11; // domain = 0, CB = 00,type = 01
  }

  /**
   * Vamos olhar mais de perto o ptable[1]:
   * 
   * 0x00500411 = 0000 0000 0101 000 0 0000 0100 0001 0001  em binario
   * 
   * Olhando a definicao da descricao de coarse page table temos:
   *  
   * Indice dos bits: |  31   -   10    |  9  |  8 - 5  | 4 | 3 - 2 | 1 | 0 | 
   * Funcao:          |    Endereco     | SBZ |  Domain | 1 |  SBZ  | 0 | 1 |
   * 0x00500411:      | 000000000101000 |  0  |  00000  | 1 |   00  | 0 | 1 |  
   * 
   * Agora vamos olhar como ocorre a indexacao:
   * Esse indice L2 vem dos bits 19-12 do endereco virtual
   *  
   * Indice dos bits: |    31 - 10      | 9 - 2     | 1 | 0 
   * Funcao:          |   endereco      | indice L2 | 0 | 0
   * Endereco:        | 000000000101000 | xxxxxxxx  | 0 | 0
   * 
   * **/

  print_uart0("3. Constroi 258 tabelas de segundo nivel em 5MB\n");

  for (i = 0; i < 258; i++)
  {
    pgtable = (unsigned int *)((unsigned int)0x500000 + (unsigned int)i * 1024); // inicializa o ponteiro
    paddr = i * 0x100000 | 0x55E;                                                // 01 | 01 | 01 | 01 | CB = 11 | type = 10
    for (j = 0; j < 256; j++)
    {
      pgtable[j] = paddr + j * 4096;
    }
  }

  print_uart0("4. Construcao das tabelas de dois niveis concluida\n");
  print_uart0("4. Saida de mkTable para configurar a MMU (TTB, domain, enable)\n");
}

// Tratamento das interrupcoes de dados
int data_abort_handler()
{

  print_uart0("[Erro] Data_abort exception!");
  unsigned int fault_status, fault_addr, domain, status;
  int spsr = get_spsr();
  again++;
  if ((spsr & 0x1F) == 0x13)
    print_uart0("Modo: SVC\n");
  if ((spsr & 0x1F) == 0x10)
    print_uart0("Modo: USER\n");

  fault_status = get_fault_status();
  char *fault_char = "Valor do fault status: ";
  convertNum(fault_status, 16, resp);
  concat(fault_char, resp, concat_aux);
  print_uart0(concat_aux);

  fault_addr = get_fault_addr();
  char *fault_addr_char = "Valor do fault address: ";
  convertNum(fault_addr, 16, resp);
  concat(fault_addr_char, resp, concat_aux);
  print_uart0(concat_aux);

  domain = (fault_status & 0xF0) >> 4;
  char *domain_char = "Valor do dominio: ";
  convertNum(domain, 16, resp);
  concat(domain_char, resp, concat_aux);
  print_uart0(concat_aux);

  status = fault_status & 0xF;
  char *status_char = "Valor do status: ";
  convertNum(status, 16, resp);
  concat(status_char, resp, concat_aux);
  print_uart0(concat_aux);

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

  print_uart0("Programa principal utilizando 2 niveis enderecando paginas de 4 KB\n");
  print_uart0("Neste exercicio mapeamos os 258 MB mais baixos da memoria:\n");
  print_uart0("   O espaco de enderecamento vai de: 0x0 ate 0x10200000\n");

  print_uart0("[TESTE] Protecao da MMU: tentativa de acesso ao endereco virtual 0x00200000 - 2 MB\n");
  p = (int *)0x00200000;
  *p = 123;

  print_uart0("[TESTE] Protecao da MMU: tentativa de acesso ao endereco virtual 0x02000000 - 16 MB\n");
  p = (int *)0x02000000;
  *p = 123;

  print_uart0("t[TESTE] Protecao da MMU: tentativa de acesso ao endereco virtual 0xA0000000 - Fora dos 258 MB\n");
  p = (int *)0xA0000000;
  *p = 123;

  while (1)
  {
  }
}

char getCharVal(unsigned int dig)
{

  char resp;
  resp = table[dig];
  return resp;
}

unsigned int divide(unsigned int divisor, unsigned int dividend)
{
  unsigned int quotient = 0;
  while (divisor >= dividend)
  {
    divisor = divisor - dividend;
    quotient++;
  }
  return quotient;
}

unsigned int modulo(unsigned divisor, unsigned int dividend)
{
  unsigned int mod;
  mod = divisor - (divide(divisor, dividend) * dividend);
  return mod;
}

void convertNum(unsigned int num, unsigned int base, char *str)
{

  char aux[9];
  unsigned int dig, idx, i;
  char ch;

  idx = 0;
  while (num != 0)
  {
    dig = modulo(num, base);
    ch = getCharVal(dig);
    aux[idx] = ch;

    idx++;
    num = divide(num, base);
  }

  while (idx < 8)
    aux[idx++] = '0';
  for (i = 0; i < 8; i++)
  {
    str[i] = aux[7 - i];
  }

  str[idx] = '\0';
}

void concat(char *str1, char *str2, char *concat)
{

  unsigned int i, j, k;

  i = 0;
  k = 0;
  while (str1[i])
  {
    concat[k++] = str1[i++];
  }

  j = 0;
  while (str2[j])
  {
    concat[k++] = str2[j++];
  }
  concat[k++] = '\n';
  concat[k++] = '\0';
}