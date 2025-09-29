# Enhanced Vivado Project Creation Script with DRC Fixes
# Creates complete Zynq neural network accelerator project

set project_name "fp4_nn_accelerator"
set project_dir "./vivado_project"

# Clean up any existing project
if {[file exists $project_dir]} {
    file delete -force $project_dir
}

# Create new project
create_project $project_name $project_dir -part xc7z010clg400-1
set_property target_language Verilog [current_project]

# Add source files
add_files -norecurse {
    ../rtl/fp4multiplier.sv
    ../rtl/fp4accumulator.sv  
    ../rtl/fp4mac_top.v
    ../rtl/fp4mac_axi.v
}

# Set top module
set_property top fp4mac_axi [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

puts "✅ Source files added and compile order updated"

# Create IP repository for packaging
file mkdir "./ip_repo"

# Package the IP
ipx::package_project -root_dir "./ip_repo/fp4mac_v1_0" -vendor user.org -library user -taxonomy /UserIP -import_files -set_current true
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project

puts "✅ IP packaged successfully"

# Reopen main project  
open_project "$project_dir/$project_name.xpr"

# Set IP repository path
set_property ip_repo_paths ./ip_repo [current_project]
update_ip_catalog

puts "✅ IP repository configured"

# Create block design
create_bd_design "system"

# Add Processing System
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Configure PS for Zynq 7010
set_property -dict [list \
    CONFIG.preset {ZedBoard} \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO {MIO 1 .. 6} \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0} \
] [get_bd_cells processing_system7_0]

# Add reset generator
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_100M

# Add AXI Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells axi_interconnect_0]

# Add custom FP4 MAC IP
create_bd_cell -type ip -vlnv user.org:user:fp4mac_axi:1.0 fp4mac_axi_0

puts "✅ Block design components added"

# Connect interfaces and clocks
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins fp4mac_axi_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]

# Connect resets
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_100M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps7_0_100M/interconnect_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins fp4mac_axi_0/s_axi_aresetn]

# Connect AXI interfaces
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins fp4mac_axi_0/s_axi]

puts "✅ All connections made"

# Assign addresses  
assign_bd_address [get_bd_addr_segs {fp4mac_axi_0/s_axi/reg0 }]
set_property offset 0x43C00000 [get_bd_addr_segs {processing_system7_0/Data/SEG_fp4mac_axi_0_reg0}]
set_property range 64K [get_bd_addr_segs {processing_system7_0/Data/SEG_fp4mac_axi_0_reg0}]

puts "✅ Address assigned: 0x43C00000"

# Validate design
validate_bd_design
save_bd_design

# Generate block design
generate_target all [get_files "$project_dir/$project_name.srcs/sources_1/bd/system/system.bd"]

# Create HDL wrapper
make_wrapper -files [get_files "$project_dir/$project_name.srcs/sources_1/bd/system/system.bd"] -top
add_files -norecurse "$project_dir/$project_name.srcs/sources_1/bd/system/hdl/system_wrapper.v"
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "✅ HDL wrapper created"

# Apply DRC fixes for Zynq PS-only design
set_property STEPS.WRITE_BITSTREAM.TCL.PRE [file normalize fix_drc.tcl] [get_runs impl_1]

puts "✅ DRC fixes applied for bitstream generation"

# Run synthesis and implementation
launch_runs synth_1 -jobs 2
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "❌ Synthesis failed!"
    exit 1
}

puts "✅ Synthesis completed successfully"

# Run implementation and bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "❌ Implementation failed!"
    exit 1
}

puts "✅ Implementation and bitstream generation completed!"

# Copy bitstream to main directory
file copy -force "$project_dir/$project_name.runs/impl_1/system_wrapper.bit" "../system_wrapper.bit"

puts "✅ Bitstream copied to ../system_wrapper.bit"

puts ""
puts "🎉 COMPLETE ZYNQ PROJECT CREATED SUCCESSFULLY!"
puts "=============================================="
puts "✅ Block design with PS7 + Custom IP created"
puts "✅ All connections made (AXI, clocks, resets)"
puts "✅ Address assigned: 0x43C00000, Size: 64KB"
puts "✅ HDL wrapper generated"
puts "✅ Synthesis completed"
puts "✅ Implementation completed"
puts "✅ Bitstream generated with DRC fixes"
puts "✅ Ready for deployment!"
puts ""
puts "NEXT STEPS:"
puts "==========="
puts "1. Export hardware: File → Export → Export Hardware (include bitstream)"
puts "2. Copy nn_demo.c to Zynq board"
puts "3. Cross-compile: arm-linux-gnueabihf-gcc nn_demo.c -o nn_demo"
puts "4. Run on Zynq: sudo ./nn_demo"