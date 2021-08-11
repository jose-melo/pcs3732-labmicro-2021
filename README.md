# Gerenciamento de Memória no ARM (MMU)

Esse reposítório destina-se a apresentar vários exemplos de programas que ilustram como configurar a MMU do ARM para gerenciamento de memória.

## Memória Virtual
A ideia da memória virtual é prover uma maneira para que cada processo tenha seu próprio espaço de endereçamento, que é separado em páginas. Cada página é constituída por uma sequência contínua de endereços e são mapeadas em páginas físicas. 

O conceito fundamental por trás é a paginação, indicando que nem todas as páginas precisam estar na memória ao mesmo tempo para que um processo possa executar corretamente. Dessa forma, temos endereços virtuais que são criados pelo programa e devem ser traduzidos para endereços físicos por meio da MMU. Ao acessar um endereço virtual de uma página que não está presente na memória, o gerenciador de memória irá realizar o mapeamento dinâmico entre o endereço virtual e o endereço físico, trazendo a página requisitada para a memória.

## Exemplos
- [Paginação de um nível usando seções de 1 MB](https://github.com/jose-melo/pcs3732-labmicro-2021/tree/master/sectionPaging)
- [Paginação de dois níveis usando páginas de 4 KB](https://github.com/jose-melo/pcs3732-labmicro-2021/tree/master/twoLevelSmallPage)