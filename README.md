# FP4 MAC Unit

A 4-bit floating point multiply-accumulate unit using E2M1 format (1 sign bit, 2 exponent bits, 1 mantissa bit). The design includes a 2-stage pipeline with proper timing synchronization between the multiplier and accumulator.

## What it does

Takes two FP4 numbers, multiplies them, and adds the result to an accumulator. Supports the full E2M1 range from -6 to +6, handles subnormals, and includes overflow protection.

## Files

- `rtl/fp4multiplier.sv` - FP4 multiplier with zero/subnormal handling
- `rtl/fp4accumulator.sv` - FP4 accumulator with pipeline synchronization  
- `rtl/fp4mac_top.sv` - Top level connecting multiplier to accumulator
- `tb/tb_fp4mac.sv` - Comprehensive testbench with 25 test cases

## Usage

```bash
make         # compile with iverilog
make run     # run simulation 
make wave    # view waveforms in gtkwave
make clean   # clean up build files
