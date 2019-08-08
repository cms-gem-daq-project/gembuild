CFLAGS= -fomit-frame-pointer -pipe -fno-common -fno-builtin \
	-Wall -std=c++14 \
	-march=armv7-a -mfpu=neon -mfloat-abi=hard \
	-mthumb-interwork -mtune=cortex-a9 \
	-DEMBED -Dlinux -D__linux__ -Dunix -fPIC \
	--sysroot=$(PETA_STAGE)\
	-I$(PETA_STAGE)/usr/include \
	-I$(PETA_STAGE)/include

LDLIBS= -L$(PETA_STAGE)/lib \
	-L$(PETA_STAGE)/usr/lib \
	-L$(PETA_STAGE)/ncurses

LDFLAGS= -L$(PETA_STAGE)/lib \
	-L$(PETA_STAGE)/usr/lib \
	-L$(PETA_STAGE)/ncurses

INSTALL_PREFIX?=/mnt/persistent/$(Project)

CXX:=arm-linux-gnueabihf-g++
CC:=arm-linux-gnueabihf-gcc
