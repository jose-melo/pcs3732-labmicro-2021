# Gerenciamento de Memória no ARM (MMU)

Esse reposítório destina-se a apresentar vários exemplos de programas que ilustram como configurar a MMU do ARM para gerenciamento de memória.

## Memória Virtual
A ideia da memória virtual é prover uma maneira para que cada processo tenha seu próprio espaço de endereçamento, que é separado em páginas. Cada página é constituída por uma sequência contínua de endereços e são mapeadas em páginas físicas. 

O conceito fundamental por trás é a paginação, indicando que nem todas as páginas precisam estar na memória ao mesmo tempo para que um processo possa executar corretamente. Dessa forma, temos endereços virtuais que são criados pelo programa e devem ser traduzidos para endereços físicos por meio da MMU. Ao acessar um endereço virtual de uma página que não está presente na memória, o gerenciador de memória irá realizar o mapeamento dinâmico entre o endereço virtual e o endereço físico, trazendo a página requisitada para a memória.


## Instalando a imagem Docker
Para todos os exemplos fornecidos foi usado um container Docker com as ferramentas de build para facilitar a instalação para todos os integrantes do grupo. Primeiro é necessário clonar o repositório:
```
git clone https://github.com/EpicEric/gcc-arm.git
```

Em seguida, entre dentro do repositório
```
cd gcc-arm/
```

Por fim, rode o script para gerar a imagem Docker:
```
./build_docker.sh emacs # any other editor that you prefer; perhaps, you will need sudo,and perhaps gedit suchs as: 
              sudo ./build_docker.sh gedit
```

Para executar após a geração da imagem docker:
```
docker run --rm -ti -v "$PWD/src":/home/student/src epiceric/gcc-arm
```

É importante notar que o diretório `$PWD/src` está mapeado no diretório `/home/student/src`. Assim, para rodar qualquer um dos exemplos abaixo apenas copie a pasta desejada para dentro do diretório `src`.

## Exemplos
Todos os exemplos abaixo foram adaptados para que pudessem ser rodados no ambiente Docker citado acima. Aleḿ disso, por simplicidade apenas as partes relevantes para análise da MMU foram mantidas.
- [Paginação de um nível usando seções de 1 MB](https://github.com/jose-melo/pcs3732-labmicro-2021/tree/master/sectionPaging)
- [Paginação de dois níveis usando páginas de 4 KB](https://github.com/jose-melo/pcs3732-labmicro-2021/tree/master/twoLevelSmallPage)
- [Paginação de um nível usando espaço de endereçamento virtual](https://github.com/jose-melo/pcs3732-labmicro-2021/tree/master/paVaSection)
- [Paginação de dois níveis usando espaço de endereçamento virtual](https://github.com/jose-melo/pcs3732-labmicro-2021/tree/master/paVaSmallPages)

---
Autores:
- [José Lucas de Melo Costa | @jose-melo](https://github.com/jose-melo)
- [Luiz Guilherme Kasputis Zanini | @LuizKasputis](https://github.com/LuizKasputis)
- [Wesley Pereira de Almeida | @WesPereira](https://github.com/WesPereira)