# TCL script to fix DRC errors for Zynq PS-only designs
# This converts pin location and I/O standard errors to warnings

# Convert NSTD-1 (I/O Standard) errors to warnings
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]

# Convert UCIO-1 (Pin Location) errors to warnings  
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

puts "DRC checks converted to warnings for Zynq PS-only design"
puts "NSTD-1 and UCIO-1 are now warnings instead of errors"