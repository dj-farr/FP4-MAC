# ARM Cross-compilation Makefile
CC = arm-linux-gnueabihf-gcc
CFLAGS = -Wall -O2 -std=c99
LDFLAGS = -lm -lrt
TARGET = nn_demo
SOURCES = nn_demo.c

# For native compilation (if running on Zynq with Linux)
native:
	gcc $(CFLAGS) -o $(TARGET) $(SOURCES) $(LDFLAGS)

# For cross-compilation  
cross:
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCES) $(LDFLAGS)

# Test compilation (works without FPGA)
test:
	gcc $(CFLAGS) -DSIMULATION_MODE -o $(TARGET)_test $(SOURCES) -lm

clean:
	rm -f $(TARGET)

.PHONY: native cross clean