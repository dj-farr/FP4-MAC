# FP4 MAC Unit

A 4-bit floating point multiply-accumulate unit using E2M1 format (1 sign bit, 2 exponent bits, 1 mantissa bit). The design includes a 2-stage pipeline with proper timing synchronization between the multiplier and accumulator.

## What it does

Takes two FP4 numbers, multiplies them, and adds the result to an accumulator. Supports the full E2M1 range from -6 to +6, handles subnormals, and includes overflow protection.

## Files

### RTL Design
- `rtl/fp4multiplier.sv` - FP4 multiplier with zero/subnormal handling
- `rtl/fp4accumulator.sv` - FP4 accumulator with pipeline synchronization  
- `rtl/fp4mac_top.v` - Top level module (Verilog) connecting multiplier to accumulator
- `rtl/fp4mac_axi.v` - AXI-Lite wrapper for Zynq integration
- `tb/tb_fp4mac.sv` - Comprehensive testbench with 25 test cases

### Neural Network Accelerator  
- `software/nn_demo.c` - ARM software for neural network demo
- `software/Makefile` - Cross-compilation setup
- `vivado/create_project.tcl` - Vivado project creation script

## Usage

```bash
# Simulation
make         # compile with iverilog
make run     # run simulation 
make wave    # view waveforms in gtkwave
make clean   # clean up build files

# Zynq Neural Network Accelerator
cd vivado && vivado -mode batch -source create_project.tcl  # Create Vivado project
cd software && make cross  # Cross-compile ARM software
