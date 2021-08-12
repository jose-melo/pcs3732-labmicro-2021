arm-none-eabi-as -mcpu=arm926ej-s ts.s -o ts.o
arm-none-eabi-gcc -c -mcpu=arm926ej-s t.c -o t.o
arm-none-eabi-ld -T t.ld ts.o t.o -Ttext=4010000 -o t.elf
arm-none-eabi-objcopy -O binary t.elf t.bin

