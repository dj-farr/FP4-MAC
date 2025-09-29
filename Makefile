# -------- config --------
RTL := rtl/fp4multiplier.sv rtl/fp4accumulator.sv rtl/fp4mac_top.v
AXI_RTL := rtl/fp4mac_axi.v
TB  := tb/tb_fp4mac.sv
TOP := tb_fp4mac

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave

FLAGS := -g2012 -Wall

BUILD := build
SIM   := $(BUILD)/sim
WAVE  := tb_fp4mac.vcd

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
	rm -rf $(BUILD) *.vcd
