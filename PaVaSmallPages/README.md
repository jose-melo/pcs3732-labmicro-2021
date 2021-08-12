## Forma de uso

Após estar com o docker rodando (caso ainda não tenha a imagem, [clique aqui](http://linux-kernel-lab.blogspot.com/2018/04/basics-on-arm-processor.html) e siga o tutorial), dentro do docker execute:

```
chmod +x mk.sh
./mk
```

Em outro terminal (dentro desse mesmo diretório), entre novamente no docker e execute:

```
gdb --command="cmds.txt"
```