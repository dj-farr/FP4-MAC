# FP4 MAC Zynq Deployment Guide

## Part 1: Vivado Hardware Design

### Step 1: Create Project
```bash
cd vivado
vivado -mode gui
# In TCL console:
source enhanced_project.tcl
```

### Step 2: Package Custom IP
1. **Tools → Create and Package New IP**
2. **Package your current project**
3. **Set these parameters:**
   - Root Directory: `./ip_repo/fp4mac_v1_0`
   - Top-level source: `../rtl/fp4mac_axi.v`
   - Vendor: `user.org`
   - Name: `fp4mac_axi`
   - Version: `1.0`
4. **Complete IP packaging wizard**
5. **Close IP packaging project**

### Step 3: Add IP to Block Design
1. **Open `system.bd` block design**
2. **Refresh IP Catalog** (should see your fp4mac_axi)
3. **Add IP → Search "fp4mac" → Add fp4mac_axi_1.0**
4. **Connect interfaces:**
   ```
   axi_interconnect_0/M00_AXI → fp4mac_axi_0/s_axi
   ```
5. **Connect clocks:**
   ```
   processing_system7_0/FCLK_CLK0 → fp4mac_axi_0/s_axi_aclk
   ```
6. **Connect resets:**
   ```
   rst_ps7_0_100M/peripheral_aresetn → fp4mac_axi_0/s_axi_aresetn
   ```

### Step 4: Assign Memory Address
1. **Window → Address Editor**
2. **Assign fp4mac_axi_0:**
   - Base Address: `0x43C00000`
   - Range: `64K`

### Step 5: Generate Hardware
1. **Generate Block Design**
2. **Create HDL Wrapper** (if not done automatically)
3. **Generate Bitstream** (this takes 10-30 minutes)
4. **File → Export → Export Hardware**
   - Include bitstream: **YES**
   - Export to: `system.xsa`

---

## Part 2: Software Cross-Compilation

### Step 1: Install ARM Cross-Compiler
```bash
# Ubuntu/Debian:
sudo apt-get install gcc-arm-linux-gnueabihf

# macOS:
brew install arm-linux-gnueabihf-gcc
# or use Vivado SDK toolchain
```

### Step 2: Cross-Compile Software
```bash
cd software
make cross
# Creates: nn_demo (ARM executable)
```

---

## Part 3: FPGA Deployment

### Option A: Using PYNQ Linux (Easiest)

1. **Flash PYNQ image to SD card**
2. **Boot Zynq with PYNQ Linux**
3. **Connect via SSH/Jupyter:**
   ```bash
   ssh xilinx@192.168.2.99  # Default PYNQ IP
   # Password: xilinx
   ```
4. **Copy files to Zynq:**
   ```bash
   scp system.bit xilinx@192.168.2.99:~/
   scp software/nn_demo xilinx@192.168.2.99:~/
   ```
5. **Program FPGA:**
   ```python
   # On Zynq (Python):
   from pynq import Overlay
   ol = Overlay("system.bit")
   ```
6. **Run software:**
   ```bash
   # On Zynq (terminal):
   sudo ./nn_demo
   ```

### Option B: Using Vivado SDK/Vitis

1. **Launch SDK:** File → Launch SDK
2. **Create Application Project**
3. **Import nn_demo.c**
4. **Build and Run on hardware**

---

## Part 4: Testing & Verification

### Expected Output:
```
🔥 FP4 NEURAL NETWORK ACCELERATOR DEMO 🔥
⚡ Running on REAL FPGA HARDWARE
   Base address: 0x43C00000
   AXI-Lite interface active

🔬 PRECISION ANALYSIS
[Shows FP4 format demonstrations]

📈 MAC OPERATION STATISTICS  
[Shows timing per operation type]

🚀 PERFORMANCE BENCHMARK
[Shows FPGA vs ARM comparison]

🧠 XOR NEURAL NETWORK DEMO
[Shows neural network results]
```

---

## Troubleshooting

### Issue: "Failed to initialize FPGA MAC"
- **Check:** Bitstream loaded correctly
- **Check:** Memory address matches (0x43C00000)
- **Try:** `sudo` for /dev/mem access

### Issue: AXI Interface not responding  
- **Check:** Clock connections in block design
- **Check:** Reset polarity (active high/low)
- **Verify:** Address assignment in Vivado

### Issue: Cross-compilation fails
- **Install:** ARM GCC toolchain
- **Check:** Library paths (-lm -lrt)
- **Try:** Native compilation on ARM