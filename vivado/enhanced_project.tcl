# Enhanced Vivado project creation and IP packaging script
# Run this in Vivado: source enhanced_project.tcl

puts "Creating FP4 MAC Neural Network Accelerator Project..."

# Project settings
set project_name "fp4_nn_accelerator"
set project_dir "./vivado_project"
set part_name "xc7z010clg400-1"

# Create project
if { [file exists $project_dir] } {
    puts "Removing existing project directory..."
    file delete -force $project_dir
}

create_project $project_name $project_dir -part $part_name -force

# Add RTL sources
add_files -norecurse {
    ../rtl/fp4multiplier.sv
    ../rtl/fp4accumulator.sv  
    ../rtl/fp4mac_top.v
    ../rtl/fp4mac_axi.v
}

# Set file types
set_property file_type {SystemVerilog} [get_files ../rtl/fp4multiplier.sv]
set_property file_type {SystemVerilog} [get_files ../rtl/fp4accumulator.sv]
set_property file_type {Verilog} [get_files ../rtl/fp4mac_top.v]
set_property file_type {Verilog} [get_files ../rtl/fp4mac_axi.v]

# Update compile order
update_compile_order -fileset sources_1

puts "Step 1: Creating IP package..."

# Package IP
ipx::package_project -root_dir ./ip_repo/fp4mac_v1_0 -vendor user.org -library user -taxonomy /UserIP -import_files -set_current false
ipx::unload_core ./ip_repo/fp4mac_v1_0/component.xml

# Create block design
puts "Step 2: Creating block design..."
create_bd_design "system"

# Add Zynq PS
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
endgroup

# Configure Zynq
set_property -dict [list \
  CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
  CONFIG.PCW_USE_M_AXI_GP0 {1} \
  CONFIG.PCW_USE_S_AXI_HP0 {0} \
  CONFIG.PCW_IRQ_F2P_INTR {0} \
  CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {533.333333} \
  CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO {MIO 1 .. 6} \
] [get_bd_cells processing_system7_0]

# Add AXI Interconnect
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
endgroup
set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_interconnect_0]

# Add processor system reset
startgroup  
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_100M
endgroup

puts "Step 3: Adding custom IP..."

# Add IP repository and custom IP
set_property ip_repo_paths ./ip_repo [current_project]
update_ip_catalog

# Create custom IP instance (this will need to be done manually after packaging)
# create_bd_cell -type ip -vlnv user.org:user:fp4mac_axi:1.0 fp4mac_axi_0

puts "Step 4: Connecting interfaces..."

# Connect clocks
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_0/M00_ACLK]

# Connect resets
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_100M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps7_0_100M/interconnect_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M00_ARESETN]

# Connect AXI interfaces  
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
# This connection will be made after adding the custom IP:
# connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins fp4mac_axi_0/s_axi]

# Create HDL wrapper
make_wrapper -files [get_files $project_dir/$project_name.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse $project_dir/$project_name.srcs/sources_1/bd/system/hdl/system_wrapper.v
set_property top system_wrapper [current_fileset]

puts "✅ Project setup complete!"
puts ""
puts "NEXT STEPS:"
puts "==========="
puts "1. Package IP: Tools → Create and Package New IP"
puts "   - Select: ../rtl/fp4mac_axi.v as top module"
puts "   - Package to: ./ip_repo/fp4mac_v1_0"
puts ""
puts "2. Add Custom IP to Block Design:"
puts "   - Refresh IP catalog"
puts "   - Add fp4mac_axi to system.bd"
puts "   - Connect AXI interface and clocks"
puts ""
puts "3. Assign Address:"
puts "   - Address Editor: Set to 0x43C00000, Size 64K"
puts ""
puts "4. Generate Bitstream:"
puts "   - Generate Block Design → Create HDL Wrapper"  
puts "   - Generate Bitstream"
puts ""
puts "5. Export Hardware:"
puts "   - File → Export → Export Hardware"
puts "   - Include bitstream: YES"