PETA_STAGE?=$(PETA_PATH)

CFLAGS= -fomit-frame-pointer -pipe -fno-common -fno-builtin \
	-Wall -std=c++14 \
	-march=armv7-a -mfpu=neon -mfloat-abi=hard \
	-mthumb-interwork -mtune=cortex-a9 \
	-DEMBED -Dlinux -D__linux__ -Dunix -fPIC \
	--sysroot=$(PETA_STAGE)/$(TARGET_BOARD)

LDFLAGS+=--sysroot=$(PETA_STAGE)/$(TARGET_BOARD)

INSTALL_PATH=/mnt/persistent/$(ShortProject)

GEM_PLATFORM:=xilinx-peta
GEM_ARCH:=armv7l
GEM_OS:=peta

CXX:=arm-linux-gnueabihf-g++
CC:=arm-linux-gnueabihf-gcc

$(info WARNING Make sure that you have set up an environment to provide $(CXX) and $(CC))
