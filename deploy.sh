#!/bin/bash
# Quick deployment script for FP4 MAC on Zynq

echo "🚀 FP4 MAC Zynq Deployment Script"
echo "================================="

# Check if we're in the right directory
if [ ! -f "rtl/fp4mac_axi.v" ]; then
    echo "❌ Run this from the project root directory"
    exit 1
fi

echo "📁 Project structure verified"

# Check for Vivado
if ! command -v vivado &> /dev/null; then
    echo "⚠️  Vivado not found in PATH"
    echo "   Make sure Vivado is installed and sourced"
    echo "   Try: source /opt/Xilinx/Vivado/2023.1/settings64.sh"
    exit 1
fi

echo "✅ Vivado found"

# Cross-compile software
echo "🔨 Cross-compiling ARM software..."
cd software
if make cross; then
    echo "✅ ARM executable ready: software/nn_demo"
else
    echo "⚠️  Cross-compilation failed, trying native compilation as fallback"
    make native
fi
cd ..

# Create Vivado project (interactive)
echo ""
echo "🎯 Next steps:"
echo "1. Run Vivado: cd vivado && vivado -mode gui"
echo "2. In TCL console: source enhanced_project.tcl"  
echo "3. Follow DEPLOYMENT.md for complete instructions"
echo ""
echo "📋 Quick checklist:"
echo "   □ Vivado project created"
echo "   □ Custom IP packaged" 
echo "   □ Block design connected"
echo "   □ Address assigned (0x43C00000)"
echo "   □ Bitstream generated"
echo "   □ Hardware exported (.xsa)"
echo "   □ FPGA programmed"
echo "   □ Software deployed"
echo ""
echo "🎉 Ready for deployment!"