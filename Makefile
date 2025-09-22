# -------- config --------
RTL := rtl/fp4multiplier.sv rtl/fp4accumulator.sv rtl/fp4mac_top.sv
TB  := tb/tb_fp4mac_top.sv
TOP := tb_fp4mac_top

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave

FLAGS := -g2012 -Wall

BUILD := build
SIM   := $(BUILD)/sim
WAVE  := $(BUILD)/dump.vcd

# -------- targets --------
.PHONY: all run wave clean format

all: $(SIM)

$(SIM): $(RTL) $(TB)
	@mkdir -p $(BUILD)
	$(IVERILOG) $(FLAGS) -o $@ $(RTL) $(TB)

run: $(SIM)
	$(VVP) $(SIM)

wave: run
	$(GTKWAVE) $(WAVE) &

clean:
	rm -rf $(BUILD)
