# Vivado TCL script to create FP4 MAC Neural Network project
# Run in Vivado: source create_project.tcl

# Project settings
set project_name "fp4_nn_accelerator"
set project_dir "./vivado_project"
set part_name "xc7z010clg400-1"  # Zynq 7010

# Create project
create_project $project_name $project_dir -part $part_name

# Add RTL sources
add_files -norecurse {
    ../rtl/fp4multiplier.sv
    ../rtl/fp4accumulator.sv  
    ../rtl/fp4mac_top.v
    ../rtl/fp4mac_axi.v
}

# Update compile order
update_compile_order -fileset sources_1

# Create block design
create_bd_design "system"

# Add Zynq processor
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Configure Zynq (basic config)
set_property -dict [list \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
] [get_bd_cells processing_system7_0]

# Add your FP4 MAC IP (you'll need to package it first)
# create_bd_cell -type module -reference fp4mac_axi fp4mac_axi_0

# Add AXI Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_interconnect_0]

# Add processor system reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_100M

# Connect clocks and resets
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_100M/ext_reset_in]

# Connect AXI interfaces (after adding your IP)
# connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
# connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins fp4mac_axi_0/s_axi]

# Assign addresses (after connections)
# assign_bd_address

# Create wrapper
make_wrapper -files [get_files $project_dir/$project_name.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse $project_dir/$project_name.srcs/sources_1/bd/system/hdl/system_wrapper.v

# Set top module
set_property top system_wrapper [current_fileset]

puts "Project created successfully!"
puts "Next steps:"
puts "1. Package your fp4mac_axi module as IP"
puts "2. Add it to the block design"
puts "3. Connect AXI interfaces"
puts "4. Generate bitstream"