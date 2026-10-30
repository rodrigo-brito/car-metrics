# Uso: make build | make upload | make monitor | make flash  (OBD_SOURCE=2 para o adaptador BLE)
# Placa: ESP32-2432S028 "Cheap Yellow Display" (ILI9341 320x240 + XPT2046)
FQBN  ?= esp32:esp32:esp32:UploadSpeed=115200,PartitionScheme=huge_app
OBD_SOURCE ?= 2   # 0 = simulação, 1 = ELM327 bluetooth clássico, 2 = ELM327 BLE (padrão; make build OBD_SOURCE=0 para simular)
PORT  ?= $(shell ls /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART /dev/cu.usbmodem* 2>/dev/null | head -1)
BAUD  ?= 115200

# Configuração do TFT_eSPI via flags (evita editar User_Setup.h da biblioteca)
TFT_FLAGS = -DUSER_SETUP_LOADED=1 -DILI9341_2_DRIVER=1 \
  -DTFT_WIDTH=240 -DTFT_HEIGHT=320 \
  -DTFT_MISO=12 -DTFT_MOSI=13 -DTFT_SCLK=14 -DTFT_CS=15 -DTFT_DC=2 -DTFT_RST=-1 -DTFT_BL=21 -DTFT_BACKLIGHT_ON=HIGH \
  -DUSE_HSPI_PORT=1 -DSPI_FREQUENCY=55000000 -DSPI_READ_FREQUENCY=20000000 \
  -DLOAD_GLCD=1 -DLOAD_FONT2=1 -DLOAD_FONT4=1 -DLOAD_FONT6=1 -DLOAD_FONT7=1 -DLOAD_GFXFF=1 -DSMOOTH_FONT=1
# Cores invertidas (fundo branco)? Ajuste TFT_INVERT em config.h. Se os tons ainda saírem errados, teste -DST7789_DRIVER=1 no lugar de ILI9341_2_DRIVER

build:
	arduino-cli compile --fqbn $(FQBN) --build-path build --warnings default \
	  --build-property "compiler.cpp.extra_flags=$(TFT_FLAGS) -DOBD_SOURCE=$(OBD_SOURCE)" .

upload: build
	arduino-cli upload --fqbn $(FQBN) --port $(PORT) --input-dir build .

monitor:
	arduino-cli monitor --port $(PORT) --config baudrate=$(BAUD)

flash: upload monitor

clean:
	rm -rf build

.PHONY: build upload monitor flash clean
