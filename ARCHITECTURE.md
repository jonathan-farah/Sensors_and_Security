# Smart Low-Power Proximity Sensor SoC - System Architecture

## Overview
This document describes the complete digital architecture of the Smart Low-Power Proximity Sensor SoC, including all functional modules and infrastructure components.

---

## System Block Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PROXIMITY SENSOR SOC                              │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              Clock & Reset Manager                             │ │
│  │  • Glitch-free clock gating                                    │ │
│  │  • Reset synchronization                                       │ │
│  │  • Domain-specific clocks/resets                               │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                            │                                          │
│                            ▼                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │   Watchdog   │    │  Interrupt   │    │   Security   │          │
│  │    Timer     │───▶│ Controller   │◀───│   Module     │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│                            │                     │                    │
│                            ▼                     ▼                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Register File                              │   │
│  │  • Configuration registers                                    │   │
│  │  • Status monitoring                                          │   │
│  │  • Memory-mapped interface                                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                            │                                          │
│                            ▼                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │     ADC      │───▶│    Data      │───▶│ Calibration  │          │
│  │ Interface    │    │    FIFO      │    │   Engine     │          │
│  │ Controller   │    │   Buffer     │    │              │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│         │                                        │                    │
│         ▼                                        ▼                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Moving Average Filter                            │   │
│  │  • Configurable filter taps                                   │   │
│  │  • Data smoothing                                             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                            │                                          │
│                            ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            Threshold Comparator                               │   │
│  │  • Dual-threshold detection                                   │   │
│  │  • Hysteresis support                                         │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                            │                                          │
│                            ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │          Power Management FSM                                 │   │
│  │  • Multiple power states                                      │   │
│  │  • Adaptive power control                                     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                            │                                          │
│                            ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │        Communication Interface (SPI)                          │   │
│  │  • Host communication                                         │   │
│  │  • Interrupt generation                                       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Module Descriptions

### 1. ADC Interface Controller (`adc_interface_controller.sv`)
**Purpose**: Controls the analog-to-digital converter and manages data acquisition from the sensor.

**Key Features**:
- FSM-based ADC control (IDLE → POWER_UP → WAIT_SETTLING → SAMPLE_REQUEST → WAIT_DATA → DATA_VALID)
- Configurable sampling rate
- Continuous and single-shot sampling modes
- ADC settling time management
- Timeout detection and error handling
- Sample counting and monitoring

**Interfaces**:
- **Input**: ADC physical signals (adc_data_in, adc_data_valid, adc_ready, adc_error)
- **Output**: ADC control (adc_sample_request, adc_power_enable, adc_reset_n)
- **Output**: Processed data to FIFO/pipeline

**Configuration**:
- `sample_rate_divider`: Clock divider for sampling rate
- `adc_settling_cycles`: Settling time before valid data
- `continuous_mode`: Continuous vs single-shot operation

---

### 2. Data FIFO Buffer (`data_fifo_buffer.sv`)
**Purpose**: Buffers sensor data between ADC and processing pipeline to handle burst traffic and rate mismatches.

**Key Features**:
- Synchronous FIFO with configurable depth (default: 16 entries)
- Full/empty status flags
- Almost-full/almost-empty thresholds
- Overflow/underflow detection
- Transaction counters for monitoring

**Interfaces**:
- **Write**: Accepts data from ADC interface controller
- **Read**: Provides data to calibration engine or filter
- **Status**: Full, empty, almost_full, almost_empty, fill_level

**Parameters**:
- `DATA_WIDTH`: Width of each FIFO entry (default: 32 bits)
- `FIFO_DEPTH`: Number of entries (default: 16)

---

### 3. Clock and Reset Manager (`clock_reset_manager.sv`)
**Purpose**: Provides robust clock distribution and reset synchronization for the entire SoC.

**Key Features**:
- **Glitch-free clock gating** using latch-based enable
- **Reset synchronization** (3-stage synchronizer chain)
- **Multiple clock domains**: system, filter, ADC, communication
- **Domain-specific resets** for each clock domain
- **Clock stability monitoring**

**Interfaces**:
- **Input**: Primary clock and async reset
- **Output**: 4 gated clocks (system, filter, adc, comm)
- **Output**: 4 synchronized resets
- **Status**: Clock gate status, stability indicator

**Design Notes**:
- Uses negative-edge latches for glitch-free clock gating
- Each clock domain has its own synchronized reset
- 50-cycle stability delay after reset

---

### 4. Calibration Engine (`calibration_engine.sv`)
**Purpose**: Applies offset and gain corrections to raw sensor data for improved accuracy.

**Key Features**:
- **Offset correction**: Signed addition for zero-point adjustment
- **Gain correction**: Fixed-point multiplication for sensitivity adjustment
- **Saturation detection**: Monitors and clamps overflow conditions
- **Bypass mode**: Can disable calibration for raw data access
- **4-stage pipeline**: Input → Offset → Gain → Output

**Interfaces**:
- **Input**: Raw sensor data from FIFO
- **Output**: Calibrated data to filter
- **Config**: offset_correction, gain_correction, bypass_mode

**Parameters**:
- `DATA_WIDTH`: Data width (default: 32 bits)
- `GAIN_FRAC_BITS`: Fractional bits for fixed-point gain (default: 16)

**Calibration Formula**:
```
calibrated_data = (raw_data + offset) × gain
```

---

### 5. Watchdog Timer (`watchdog_timer.sv`)
**Purpose**: Monitors system health and triggers recovery actions on timeout.

**Key Features**:
- **Programmable timeout period** with 32-bit counter
- **Software "kick" mechanism** to prevent timeout
- **Warning signal** at 75% of timeout threshold
- **Automatic reset generation** on timeout
- **Configuration locking** to prevent accidental changes
- **Timeout event counting**

**Interfaces**:
- **Control**: enable, kick, force_reset
- **Config**: timeout_value, lock_config, unlock_key
- **Output**: watchdog_reset, timeout flag, warning

**Operation**:
1. Enable watchdog with desired timeout
2. Periodically "kick" before timeout expires
3. If timeout occurs → system reset pulse generated
4. Warning asserted at 75% of timeout

---

### 6. Interrupt Controller (`interrupt_controller.sv`)
**Purpose**: Centralizes interrupt management with priority handling.

**Key Features**:
- **Multiple interrupt sources** (up to 8 by default)
- **Individual enable/mask** per interrupt
- **Edge and level-sensitive modes** per interrupt
- **Priority encoding** (fixed, reverse, round-robin)
- **Interrupt status register**
- **Selective interrupt clearing**

**Interfaces**:
- **Input**: 8 interrupt sources
- **Output**: Combined interrupt request
- **Config**: enable, mask, edge_mode, priority_mode
- **Status**: pending interrupts, highest priority ID

**Interrupt Sources** (typical mapping):
0. Detection event
1. Security violation
2. Watchdog warning
3. Watchdog timeout
4. FIFO overflow
5. FIFO underflow
6. Calibration saturation
7. ADC error

---

## Data Flow

### Normal Operation Flow:
```
1. ADC Interface Controller
   ↓ (adc_data_out, data_valid)
2. Data FIFO Buffer
   ↓ (read_data, read_valid)
3. Calibration Engine
   ↓ (calibrated_data, data_valid)
4. Moving Average Filter
   ↓ (filtered_data, result_valid)
5. Threshold Comparator
   ↓ (detection_flag)
6. Interrupt Controller / Register File
   ↓ (irq_n / status registers)
7. Communication Interface (SPI)
```

### Power Management Flow:
```
Register File Configuration
   ↓
Power Management FSM
   ↓ (power state)
Clock & Reset Manager
   ↓ (gated clocks)
Individual Module Domains
```

---

## Power States

| State | Description | Active Modules | Current |
|-------|-------------|----------------|---------|
| **SLEEP** | Minimal power | Watchdog, Comm | ~1 µA |
| **IDLE** | Ready to sample | + ADC, Registers | ~10 µA |
| **ACTIVE** | Processing data | + Filter, Comparator | ~100 µA |
| **FULL_POWER** | All features | All modules | ~500 µA |

---

## Configuration Registers (Memory Map)

| Address | Register | Description |
|---------|----------|-------------|
| 0x00 | CONTROL | System enable, modes |
| 0x01 | POWER_MODE | Power state selection |
| 0x02 | FILTER_CONFIG | Filter taps, enable |
| 0x03 | THRESHOLD_LOW | Lower detection threshold |
| 0x04 | THRESHOLD_HIGH | Upper detection threshold |
| 0x05 | HYSTERESIS | Comparator hysteresis |
| 0x06 | SAMPLE_RATE | ADC sampling rate divider |
| 0x07 | INTERRUPT_EN | Interrupt enable mask |
| 0x08 | SECURITY_LOCK | Security configuration |
| 0x09 | CAL_OFFSET | Calibration offset |
| 0x0A | CAL_GAIN | Calibration gain |
| 0x0B | WATCHDOG_CFG | Watchdog timeout value |
| 0x10 | STATUS | System status flags |
| 0x11 | POWER_STATE | Current power state |
| 0x12 | ADC_STATUS | ADC interface status |
| 0x13 | FILTER_STATUS | Filter busy/ready |
| 0x14 | INT_STATUS | Interrupt pending bits |
| 0x15 | SECURITY_STATUS | Violation count |

---

## Reset Strategy

### Reset Types:
1. **Power-On Reset (POR)**: External async reset at power-up
2. **System Reset**: Synchronized reset from Clock & Reset Manager
3. **Watchdog Reset**: Generated by watchdog timeout
4. **Software Reset**: Triggered via register write

### Reset Sequence:
```
1. Async reset asserted
   ↓
2. Clock & Reset Manager synchronizes (3 stages)
   ↓
3. Global reset_sync distributed to all modules
   ↓
4. Domain-specific resets for each clock domain
   ↓
5. 50-cycle stability delay
   ↓
6. clocks_stable asserted → system ready
```

---

## Clock Architecture

### Clock Domains:
1. **system_clock**: Always-on when system enabled (register file, control logic)
2. **filter_clock**: Gated when filter disabled (moving average filter)
3. **adc_clock**: Gated when ADC powered down (ADC interface controller)
4. **comm_clock**: Stays active for host communication (SPI interface)

### Clock Gating Mechanism:
- Negative-edge latch captures enable signal
- AND gate combines clock with latched enable
- Glitch-free transitions guaranteed
- Each domain has synchronized reset

---

## Interrupt Handling

### Interrupt Priority (default fixed priority):
1. **Watchdog Timeout** (highest priority, safety critical)
2. **Security Violation** (security critical)
3. **ADC Error** (data integrity)
4. **FIFO Overflow** (data loss prevention)
5. **Detection Event** (normal operation)
6. **Calibration Saturation** (warning)
7. **Watchdog Warning** (early warning)
8. **FIFO Underflow** (lowest priority)

### Interrupt Service Flow:
```
1. Event occurs in module
   ↓
2. Interrupt source asserted
   ↓
3. Interrupt Controller latches (if edge mode) or tracks (if level mode)
   ↓
4. Priority encoder determines highest priority
   ↓
5. Combined IRQ asserted to host
   ↓
6. Host reads interrupt status register
   ↓
7. Host services interrupt
   ↓
8. Host writes to clear interrupt
```

---

## Error Handling

### Error Detection:
- **ADC Timeout**: No data received within 200 cycles
- **ADC Interface Error**: Hardware error signal from ADC
- **FIFO Overflow**: Write when full
- **FIFO Underflow**: Read when empty
- **Calibration Saturation**: Data overflow during calibration
- **Security Violation**: Unauthorized access attempt
- **Watchdog Timeout**: Software didn't kick watchdog

### Error Recovery:
1. Error detected → interrupt generated
2. Error status logged in registers
3. Module enters safe state
4. Host notified via interrupt
5. Host reads error status
6. Host clears error and reconfigures
7. System resumes operation

---

## Performance Specifications

### Timing:
- **Maximum Clock Frequency**: 50 MHz
- **ADC Sample Rate**: Configurable 1 Hz - 1 kHz
- **Filter Latency**: 2-16 cycles (depends on taps)
- **Calibration Pipeline**: 4 cycles
- **Register Access**: 1-2 cycles
- **Interrupt Response**: 3-5 cycles

### Throughput:
- **Peak Data Rate**: 50 MSamples/sec (unrealistic for sensor, but supported)
- **Typical Data Rate**: 1 kSample/sec (configurable)
- **FIFO Depth**: 16 samples (handles bursts)

---

## Resource Estimates

### Logic Resources:
| Module | Flip-Flops | LUTs | RAMs | Notes |
|--------|-----------|------|------|-------|
| ADC Controller | ~100 | ~200 | 0 | FSM + counters |
| Data FIFO | ~50 | ~100 | 1 (16x32) | Small RAM |
| Clock/Reset Mgr | ~50 | ~100 | 0 | Mostly routing |
| Calibration | ~150 | ~300 | 0 | Arithmetic pipeline |
| Watchdog | ~50 | ~100 | 0 | Counter + control |
| Interrupt Ctrl | ~50 | ~100 | 0 | Priority encoder |
| **New Modules Total** | ~450 | ~900 | 1 | |
| **Existing Modules** | ~800 | ~1500 | 1 | |
| **Complete SoC** | ~1250 | ~2400 | 2 | |

---

## Integration Notes

### Connecting New Modules to Existing SoC:

1. **ADC Interface Controller**:
   - Replace simple sampling logic in proximity_sensor_soc.sv
   - Connect to external ADC pins
   - Feed data_out to Data FIFO

2. **Data FIFO**:
   - Insert between ADC Controller and Calibration Engine
   - Or between ADC Controller and Moving Average Filter
   - Provides rate decoupling

3. **Clock & Reset Manager**:
   - Replace simple clock gating logic
   - Use domain-specific clocks for each module
   - Use synchronized resets everywhere

4. **Calibration Engine**:
   - Insert before Moving Average Filter
   - Add calibration registers to Register File
   - Optional bypass for raw data

5. **Watchdog Timer**:
   - Connect to Interrupt Controller
   - Add kick register to Register File
   - watchdog_reset feeds to system reset OR gate

6. **Interrupt Controller**:
   - Centralizes all interrupt sources
   - Replace simple IRQ logic in Communication Interface
   - Add interrupt status/clear registers

---

## Next Steps

### For Complete Integration:
1. Create enhanced top-level module with all new infrastructure
2. Update Register File to include new configuration registers
3. Create comprehensive testbenches for each new module
4. Develop SoC-level testbench with realistic scenarios
5. Synthesize and verify timing constraints
6. Perform power analysis with different power states

### For Verification:
1. Unit tests for each new module
2. Integration tests for data path
3. Power state transition tests
4. Error injection and recovery tests
5. Performance characterization
6. Code coverage analysis

---

## Summary

We've added **6 critical infrastructure modules** to your proximity sensor SoC:

✅ **ADC Interface Controller** - Professional ADC control with error handling
✅ **Data FIFO Buffer** - Smooth data flow and rate decoupling
✅ **Clock & Reset Manager** - Robust clock distribution and reset sync
✅ **Calibration Engine** - Offset/gain correction for accuracy
✅ **Watchdog Timer** - System reliability and recovery
✅ **Interrupt Controller** - Centralized interrupt management

These modules provide the **missing digital infrastructure** needed for a production-quality SoC, focusing on reliability, power management, and robust operation.

---

**Document Version**: 1.0  
**Author**: Cognichip Co-Designer  
**Date**: 2024
