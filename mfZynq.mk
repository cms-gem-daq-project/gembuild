ifndef PETA_STAGE
$(error "Error: PETA_STAGE environment variable not set.")
endif

CFLAGS= -fomit-frame-pointer -pipe -fno-common -fno-builtin \
	-Wall -std=c++14 \
	-march=armv7-a -mfpu=neon -mfloat-abi=hard \
	-mthumb-interwork -mtune=cortex-a9 \
	-DEMBED -Dlinux -D__linux__ -Dunix -fPIC \
	--sysroot=$(PETA_STAGE)

LDFLAGS+=--sysroot=$(PETA_STAGE)

INSTALL_PATH=/mnt/persistent/$(Project)

GEM_PLATFORM:=xilinx-peta
GEM_ARCH:=armv7l
GEM_OS:=peta

CXX:=arm-linux-gnueabihf-g++
CC:=arm-linux-gnueabihf-gcc

$(info WARNING Make sure that you have set up an environment to provide $(CXX) and $(CC))
