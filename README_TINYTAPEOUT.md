# Moving Average Filter for Tiny Tapeout
## 8-bit Configurable Digital Signal Processor

**Authors:** Jonathan Farah, Jason Qin  
**Repository:** https://github.com/jonathan-farah/Sensors_and_Security  
**Version:** 1.0.0 (Tiny Tapeout Optimized)

---

## 🎯 Project Overview

This project implements a **hardware-efficient moving average filter** optimized for Tiny Tapeout constraints. The filter provides configurable noise reduction for sensor data processing applications, with runtime-adjustable filter length (1-15 taps).

### Key Features

- ✅ **8-bit data width** - Optimized for Tiny Tapeout pin constraints
- ✅ **Configurable smoothing** - 1 to 15 taps (runtime configurable)
- ✅ **Circular buffer** - No data shifting required
- ✅ **Power-optimized** - Sequential accumulation instead of parallel tree
- ✅ **Area-efficient** - ~140 flip-flops, ~400 gates
- ✅ **Power-of-2 optimization** - Free bit-shifts for 1,2,4,8 taps
- ✅ **Standard handshake** - Ready-valid protocol for easy integration

---

## 📦 Tiny Tapeout Pin Assignment

### Standard TT Interface: 24 pins total

**Dedicated Inputs [7:0]** (ui_in):
- `ui_in[0]` - **enable**: Module enable (1=active, 0=disabled)
- `ui_in[4:1]` - **num_taps[3:0]**: Filter tap count (1-15)
- `ui_in[5]` - **data_valid**: Input data valid strobe
- `ui_in[7:6]` - **data_in[1:0]**: Input sample data (LSB bits)

**Dedicated Outputs [7:0]** (uo_out):
- `uo_out[0]` - **data_ready**: Filter ready to accept data
- `uo_out[1]` - **result_valid**: Output result valid (1-cycle pulse)
- `uo_out[2]` - **busy**: Filter is computing
- `uo_out[7:3]` - **result_out[4:0]**: Output result (lower 5 bits)

**Bidirectional [7:0]** (uio):
- `uio[5:0]` - **data_in[7:2]**: Input sample data (upper 6 bits) - INPUT
- `uio[6]` - **result_out[5]**: Output result bit 5 - OUTPUT
- `uio[7]` - **result_out[6]**: Output result bit 6 - OUTPUT

---

## 🔬 How It Works

The moving average filter implements a **sliding window average** over the most recent N samples:

```
Output = (sample[0] + sample[1] + ... + sample[N-1]) / N
```

### Architecture

1. **Circular Buffer (15 elements)**
   - Stores recent samples without data shifting
   - Write pointer wraps around automatically
   - Constant O(1) time operations

2. **4-State FSM**
   - **IDLE**: Wait for data and full buffer
   - **ACCUMULATE**: Sum all samples sequentially
   - **DIVIDE**: Calculate average (optimized for power-of-2)
   - **OUTPUT**: Present result for one cycle

3. **Sequential Accumulation**
   - One adder processes samples over multiple cycles
   - Lower power than parallel tree
   - Smaller silicon area

4. **Power-of-2 Optimization**
   - 1, 2, 4, 8 taps use bit-shifts (FREE in hardware)
   - Other tap counts use hardware divider

---

## 🧪 Testing

### Test 1: Pass-Through (num_taps = 1)
```
Input:  50, 100, 150
Output: 50, 100, 150
```

### Test 2: Simple Average (num_taps = 2)
```
Input:  40, 80, 120
Output: (40+80)/2=60, (80+120)/2=100
```

### Test 3: Four-Tap Average (num_taps = 4)
```
Input:  16, 32, 48, 64, 80
Output: (16+32+48+64)/4=40, (32+48+64+80)/4=56
```

### Test 4: Eight-Tap Average (num_taps = 8)
```
Input:  8, 16, 24, 32, 40, 48, 56, 64, 72
Output: (8+16+24+32+40+48+56+64)/8=36, (16+24+32+40+48+56+64+72)/8=44
```

---

## 🚀 Quick Start Guide

### 1. Reset the Design
```
rst_n = 0 (active-low)  // Hold for 5+ clock cycles
rst_n = 1               // Release reset
```

### 2. Configure Filter
```
enable = 1
num_taps = 4  // Set to desired tap count (1-15)
```

### 3. Send Data
```
Wait for: data_ready = 1
Set: data_valid = 1, data_in = <sample>
Wait: 1 clock cycle
Set: data_valid = 0
```

### 4. Receive Results
```
Wait for: result_valid = 1 (pulse)
Read: result_out = <filtered_value>
```

---

## 📊 Performance Specifications

| Specification | Value |
|---------------|-------|
| Data Width | 8 bits (0-255) |
| Max Taps | 15 |
| Clock Frequency | 50 MHz (conservative) |
| Latency | num_taps + 2 cycles |
| Throughput | 1 result / (num_taps + 3) cycles |
| Flip-Flops | ~140 |
| Logic Gates | ~400 |
| Power | Low (sequential accumulation) |

---

## 📂 File Structure

```
Sensors_and_Security/
├── moving_average_filter_tt.sv          # 8-bit Tiny Tapeout version ⭐
├── tb_moving_average_filter_tt.sv       # Testbench for TT version ⭐
├── moving_average_filter.sv             # Original 32-bit version
├── tb_moving_average_filter.sv          # Testbench for 32-bit
├── info.yaml                            # Tiny Tapeout metadata ⭐
├── DEPS.yml                             # Build dependencies
├── README_TINYTAPEOUT.md                # This file ⭐
├── moving_average_filter_presentation.md # Code dissection
└── WAVEFORM_VIEWING_GUIDE.md           # Simulation guide
```

⭐ = Essential for Tiny Tapeout submission

---

## 🔧 Build Instructions

### Simulation (Icarus Verilog)
```bash
# Run testbench
iverilog -g2012 -o sim moving_average_filter_tt.sv tb_moving_average_filter_tt.sv
vvp sim

# View waveforms
gtkwave dumpfile_tt.fst
```

### Synthesis (for Tiny Tapeout)
```bash
# Uses OpenLane flow with SkyWater 130nm PDK
# Managed automatically by Tiny Tapeout infrastructure
```

---

## 📈 Timing Diagrams

### Handshake Protocol
```
Clock:      __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
data_ready: ‾‾‾‾‾‾‾‾‾‾‾‾‾|_________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
data_valid: ____________|‾‾‾|________________________
data_in:    XXXXXXXXXXXX|VAL|XXXXXXXXXXXXXXXXXXXXXXXX
busy:       ______________|‾‾‾‾‾‾‾‾‾|________________
result_valid: ________________________|‾‾|___________
result_out: XXXXXXXXXXXXXXXXXXXXXXXXXXXX|RES|XXXXXXXX
```

### 4-Tap Filter Operation
```
Cycle 1-4: Buffer fill (store samples)
Cycle 5:   Trigger (IDLE → ACCUMULATE)
Cycle 6-9: Accumulate (sum all 4 samples)
Cycle 10:  Divide (result / 4 using right-shift)
Cycle 11:  Output (result_valid pulse)
Cycle 12+: Ready for next sample
```

---

## 🎓 Educational Value

This design teaches:
- **Digital Signal Processing** - Moving average filter implementation
- **Circular Buffers** - Efficient data structure for hardware
- **FSM Design** - State machine-based control
- **Pipeline Architecture** - Multi-cycle operation sequencing
- **Low-Power Techniques** - Sequential vs. parallel trade-offs
- **Hardware Optimization** - Power-of-2 division using shifts
- **Interface Design** - Ready-valid handshake protocols

---

## 🔍 Design Decisions & Trade-offs

### Why 8-bit?
- Fits within Tiny Tapeout's 24-pin constraint
- Still useful for many sensor applications (ADC outputs, temperature, etc.)
- Reduces area by ~75% compared to 32-bit version

### Why Circular Buffer?
- **No data shifting** - Samples stay in place
- **O(1) operations** - Constant time regardless of buffer size
- **Hardware efficient** - Just a write pointer, no multiplexers

### Why Sequential Accumulation?
- **Lower power** - 1 adder vs. tree of adders
- **Smaller area** - Minimal logic gates
- **Trade-off** - More cycles but acceptable latency

### Why Power-of-2 Optimization?
- **Bit-shift division is FREE** - Just wire routing
- **No divider needed** - Saves significant area
- **Common case** - Many applications use 2, 4, or 8 samples

---

## 🌟 Applications

- **Sensor Data Filtering** - Temperature, pressure, proximity sensors
- **ADC Output Smoothing** - Reduce quantization noise
- **Audio Processing** - Simple low-pass filter
- **Control Systems** - Smooth feedback signals
- **Signal Conditioning** - Pre-processing for threshold detection

---

## 📚 Additional Resources

- **Code Dissection**: See `moving_average_filter_presentation.md` (50+ slides)
- **Waveform Viewing**: See `WAVEFORM_VIEWING_GUIDE.md`
- **Tiny Tapeout**: https://tinytapeout.com/
- **GitHub Repository**: https://github.com/jonathan-farah/Sensors_and_Security

---

## 🤝 Contributing

This project is part of the Sensors and Security SoC coursework. For questions or improvements:

1. Open an issue on GitHub
2. Submit a pull request
3. Contact authors: Jonathan Farah, Jason Qin

---

## 📜 License

Apache-2.0 License

---

## ✅ Tiny Tapeout Checklist

- [x] Design fits in pin budget (8+8+8 = 24 pins)
- [x] Uses standard TT interface (clk, rst_n, ui_in, uo_out, uio)
- [x] Thoroughly tested with comprehensive testbench
- [x] Waveform verification completed
- [x] info.yaml file configured
- [x] Documentation complete
- [x] Ready for submission! 🎉

---

**Status**: ✅ **Ready for Tiny Tapeout Submission**

---

*Last Updated: February 20, 2026*  
*Optimized for Tiny Tapeout*
