# Moving Average Filter for Tiny Tapeout

**Authors:** Jonathan Farah, Jason Qin  
**Repository:** https://github.com/jonathan-farah/Sensors_and_Security

## Overview

This project implements an 8-bit configurable moving average filter optimized for Tiny Tapeout. The filter provides runtime-adjustable noise reduction for sensor data processing applications.

## Features

- ✅ 8-bit data path (0-255)
- ✅ Configurable filter length (1-15 taps)
- ✅ Circular buffer architecture
- ✅ Power-optimized sequential accumulation
- ✅ Power-of-2 division optimization
- ✅ Ready-valid handshake protocol
- ✅ Fits perfectly in 24-pin Tiny Tapeout interface

## How It Works

The moving average filter computes a sliding window average:

```
Output = (sample[0] + sample[1] + ... + sample[N-1]) / N
```

### Architecture

1. **Circular Buffer**: Stores the last 15 samples without data shifting
2. **State Machine**: 4-state FSM (IDLE → ACCUMULATE → DIVIDE → OUTPUT)
3. **Sequential Accumulation**: One adder processes samples over multiple cycles
4. **Optimized Division**: Power-of-2 tap counts use bit-shifts (free in hardware)

## Pin Configuration

### Inputs (8 pins)
- `ui_in[0]`: enable
- `ui_in[4:1]`: num_taps[3:0] (filter configuration)
- `ui_in[5]`: data_valid
- `ui_in[7:6]`: data_in[1:0]

### Outputs (8 pins)
- `uo_out[0]`: data_ready
- `uo_out[1]`: result_valid
- `uo_out[2]`: busy
- `uo_out[7:3]`: result_out[4:0]

### Bidirectional (8 pins)
- `uio[5:0]`: data_in[7:2] (input)
- `uio[7:6]`: result_out[6:5] (output)

## How to Test

### Basic Test Procedure

1. **Reset**: Assert `rst_n = 0` for 5+ clock cycles
2. **Configure**: Set `num_taps = 4` (recommended first test)
3. **Enable**: Set `enable = 1`
4. **Send Data**:
   - Wait for `data_ready = 1`
   - Assert `data_valid = 1` with sample on `data_in`
   - Hold for one clock cycle
   - De-assert `data_valid = 0`
5. **Receive Results**:
   - Watch for `result_valid = 1` pulse
   - Read `result_out` when valid

### Test Cases

**Test 1: Pass-Through (num_taps = 1)**
```
Input:  50, 100, 150
Output: 50, 100, 150
```

**Test 2: Four-Tap Average (num_taps = 4)**
```
Input:  16, 32, 48, 64, 80
Output: (16+32+48+64)/4 = 40, (32+48+64+80)/4 = 56
```

**Test 3: Eight-Tap Average (num_taps = 8)**
```
Input:  8, 16, 24, 32, 40, 48, 56, 64
Output: (8+16+24+32+40+48+56+64)/8 = 36
```

## Performance

| Specification | Value |
|---------------|-------|
| Data Width | 8 bits |
| Max Taps | 15 |
| Clock Frequency | 50 MHz |
| Latency | num_taps + 2 cycles |
| Flip-Flops | ~140 |
| Logic Gates | ~400 |

## Applications

- Sensor data filtering (temperature, pressure, proximity)
- ADC output smoothing
- Audio processing (simple low-pass filter)
- Control systems signal conditioning
- Pre-processing for threshold detection

## Educational Value

This design teaches:
- Digital signal processing in hardware
- Circular buffer implementation
- FSM-based control
- Pipeline architecture
- Low-power design techniques
- Hardware optimization (power-of-2 division)
- Interface design (ready-valid handshake)

## External Hardware

None required. Design is self-contained.

Optional: Connect to ADC or sensor interface for real-world signal processing.

## Additional Resources

- [Complete Code Dissection](../moving_average_filter_presentation.md)
- [Waveform Viewing Guide](../WAVEFORM_VIEWING_GUIDE.md)
- [Tiny Tapeout README](../README_TINYTAPEOUT.md)
- [GitHub Repository](https://github.com/jonathan-farah/Sensors_and_Security)

---

*Ready for fabrication on Tiny Tapeout!* 🎉
