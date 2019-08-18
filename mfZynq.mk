ifndef PETA_STAGE
$(error "Error: PETA_STAGE environment variable not set.")
endif

CFLAGS= -fomit-frame-pointer -pipe -fno-common -fno-builtin \
	-Wall -std=c++14 \
	-march=armv7-a -mfpu=neon -mfloat-abi=hard \
	-mthumb-interwork -mtune=cortex-a9 \
	-DEMBED -Dlinux -D__linux__ -Dunix -fPIC \
	--sysroot=$(PETA_STAGE) \
	-I$(PETA_STAGE)/usr/include \
	-I$(PETA_STAGE)/include

LDLIBS= -L$(PETA_STAGE)/lib \
	-L$(PETA_STAGE)/usr/lib \
	-L$(PETA_STAGE)/ncurses

LDFLAGS+=$(LDLIBS)

INSTALL_PATH=/mnt/persistent/$(Project)

GEM_PLATFORM:=xilinx-peta
GEM_ARCH:=armv7l
GEM_OS:=peta

CXX:=arm-linux-gnueabihf-g++
CC:=arm-linux-gnueabihf-gcc
