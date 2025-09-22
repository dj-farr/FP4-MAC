# fp4-mac 

Tiny fp4 MAC: multiplier → accumulator with GRS and RNE packing.

## Layout
- `rtl/`: synthesizable modules (`fp4multiplier.sv`, `fp4accumulator.sv`, `fp4mac_top.sv`)
- `tb/`: testbench (`tb_fp4mac_top.sv`)
- `build/`: generated (sim binary, `dump.vcd`)

## Usage
```bash
make         # compile
make run     # run tests
make wave    # open dump.vcd in gtkwave
make clean   # remove build/
