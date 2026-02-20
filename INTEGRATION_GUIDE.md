# Integration Guide - New Infrastructure Modules

## Quick Start

This guide explains how to integrate the newly added infrastructure modules into your existing proximity sensor SoC.

---

## What Was Added

We've added **6 new infrastructure modules** to complete your SoC:

| Module | File | Purpose |
|--------|------|---------|
| ADC Interface Controller | `adc_interface_controller.sv` | Professional ADC control with FSM |
| Data FIFO Buffer | `data_fifo_buffer.sv` | Data buffering and rate decoupling |
| Clock & Reset Manager | `clock_reset_manager.sv` | Robust clock gating and reset sync |
| Calibration Engine | `calibration_engine.sv` | Sensor offset/gain calibration |
| Watchdog Timer | `watchdog_timer.sv` | System health monitoring |
| Interrupt Controller | `interrupt_controller.sv` | Centralized interrupt management |

All modules have been:
- ✅ Linted (no errors)
- ✅ Added to DEPS.yml
- ✅ Documented in ARCHITECTURE.md

---

## Integration Options

### Option 1: Keep Existing SoC (Minimal Changes)
Use your current `proximity_sensor_soc` target. The new modules are available as standalone components when you need them.

**Use Case**: You want to integrate gradually or test modules individually.

### Option 2: Use Enhanced SoC Target (Recommended)
Use the new `proximity_sensor_soc_enhanced` DEPS target that includes all modules.

**Use Case**: You want the complete system with all infrastructure.

---

## Integration Steps

### Step 1: Choose Your Integration Approach

#### Approach A: Full Integration (Create New Top-Level)
Create a new top-level module that instantiates everything:

```systemverilog
module proximity_sensor_soc_enhanced (
    // External interfaces
    ...
);

// Instantiate clock & reset manager
clock_reset_manager u_clk_rst_mgr (
    .clock_in(clock),
    .reset_in(reset),
    .system_clock(sys_clk),
    .reset_sync(sys_rst),
    ...
);

// Instantiate ADC controller
adc_interface_controller u_adc_ctrl (
    .clock(adc_clock),
    .reset(adc_reset),
    .data_out(adc_to_fifo_data),
    .data_valid_out(adc_to_fifo_valid),
    ...
);

// Instantiate FIFO
data_fifo_buffer u_fifo (
    .clock(sys_clk),
    .reset(sys_rst),
    .write_data(adc_to_fifo_data),
    .write_enable(adc_to_fifo_valid),
    .read_data(fifo_to_cal_data),
    ...
);

// Continue with calibration, filter, etc.
...

endmodule
```

#### Approach B: Incremental Integration (Modify Existing)
Add modules one at a time to your existing `proximity_sensor_soc.sv`:

1. Start with Clock & Reset Manager
2. Add Watchdog Timer
3. Add Interrupt Controller
4. Add ADC Controller
5. Add FIFO
6. Add Calibration Engine

---

### Step 2: Update Register File

Add configuration registers for new modules:

```systemverilog
// In proximity_sensor_regfile.sv, add new registers:

// ADC Controller Configuration (address 0x0C)
logic [15:0] adc_sample_rate_div;
logic [3:0]  adc_settling_cycles;
logic        adc_continuous_mode;

// Calibration Configuration (addresses 0x0D, 0x0E)
logic signed [31:0] calibration_offset;
logic [31:0]        calibration_gain;
logic               calibration_enable;
logic               calibration_bypass;

// Watchdog Configuration (address 0x0F)
logic [31:0] watchdog_timeout;
logic        watchdog_enable;
logic        watchdog_lock;

// Interrupt Controller Configuration (address 0x10)
logic [7:0] interrupt_enable_mask;
logic [7:0] interrupt_mask;
logic [7:0] interrupt_edge_mode;
logic [2:0] interrupt_priority_mode;

// Add read/write logic in always_ff block
...
```

---

### Step 3: Wire Up Data Path

#### Standard Data Path (Without New Modules):
```
ADC → Filter → Comparator → Detection
```

#### Enhanced Data Path (With New Modules):
```
ADC → ADC Controller → FIFO → Calibration → Filter → Comparator → Detection
                                                                        ↓
                                                              Interrupt Controller
```

Example connections:

```systemverilog
// ADC Controller to FIFO
wire [31:0] adc_data_out;
wire        adc_data_valid;
wire        adc_data_ready;

adc_interface_controller u_adc (
    .data_out(adc_data_out),
    .data_valid_out(adc_data_valid),
    .data_ready_in(adc_data_ready),
    ...
);

// FIFO connections
wire [31:0] fifo_read_data;
wire        fifo_read_valid;
wire        fifo_read_enable;

data_fifo_buffer u_fifo (
    .write_data(adc_data_out),
    .write_enable(adc_data_valid),
    .write_ready(adc_data_ready),
    .read_data(fifo_read_data),
    .read_valid(fifo_read_valid),
    .read_enable(fifo_read_enable),
    ...
);

// Calibration Engine connections
wire [31:0] calibrated_data;
wire        calibrated_valid;

calibration_engine u_cal (
    .data_in(fifo_read_data),
    .data_valid_in(fifo_read_valid),
    .data_ready_in(fifo_read_enable),
    .data_out(calibrated_data),
    .data_valid_out(calibrated_valid),
    ...
);

// Feed to existing filter
moving_average_filter u_filter (
    .data_in(calibrated_data),
    .data_valid(calibrated_valid),
    ...
);
```

---

### Step 4: Connect Interrupt Sources

Map your interrupt sources to the interrupt controller:

```systemverilog
// Define interrupt source mapping
logic [7:0] interrupt_sources;

assign interrupt_sources[0] = detection_flag;          // Detection event
assign interrupt_sources[1] = security_violation;      // Security violation
assign interrupt_sources[2] = watchdog_warning;        // Watchdog warning
assign interrupt_sources[3] = watchdog_timeout;        // Watchdog timeout
assign interrupt_sources[4] = fifo_overflow;           // FIFO overflow
assign interrupt_sources[5] = fifo_underflow;          // FIFO underflow
assign interrupt_sources[6] = cal_saturation;          // Calibration saturation
assign interrupt_sources[7] = adc_error;               // ADC error

// Instantiate interrupt controller
interrupt_controller #(
    .NUM_INTERRUPTS(8)
) u_int_ctrl (
    .interrupt_sources(interrupt_sources),
    .interrupt_request(irq_n),
    .interrupt_enable(interrupt_enable_mask),
    .interrupt_mask(interrupt_mask),
    ...
);
```

---

### Step 5: Integrate Clock & Reset Manager

Replace simple clock gating with robust manager:

**Before (in your current SoC)**:
```systemverilog
assign gated_clock = clock & clock_gate_enable;
```

**After (with Clock & Reset Manager)**:
```systemverilog
clock_reset_manager u_clk_rst (
    .clock_in(clock),
    .reset_in(reset),
    
    // Enable signals
    .system_enable(system_enable),
    .filter_clock_enable(filter_power_enable),
    .adc_clock_enable(adc_power_enable),
    .comm_clock_enable(1'b1),  // Comm always on
    
    // Gated clocks
    .system_clock(sys_clk),
    .filter_clock(filter_clk),
    .adc_clock(adc_clk),
    .comm_clock(comm_clk),
    
    // Synchronized resets
    .reset_sync(sys_rst),
    .filter_reset(filter_rst),
    .adc_reset(adc_rst),
    .comm_reset(comm_rst),
    
    .clocks_stable(clocks_stable)
);

// Use domain-specific clocks and resets
proximity_sensor_regfile u_regfile (
    .clock(sys_clk),
    .reset(sys_rst),
    ...
);

moving_average_filter u_filter (
    .clock(filter_clk),
    .reset(filter_rst),
    ...
);
```

---

### Step 6: Add Watchdog Protection

```systemverilog
// Instantiate watchdog
logic watchdog_reset_out;
logic watchdog_kick;

watchdog_timer #(
    .COUNTER_WIDTH(32),
    .DEFAULT_TIMEOUT(32'h00FF_FFFF)  // ~16M cycles at 50 MHz = 330ms
) u_watchdog (
    .clock(sys_clk),
    .reset(sys_rst),
    .watchdog_enable(watchdog_enable),
    .timeout_value(watchdog_timeout),
    .kick_watchdog(watchdog_kick),
    .watchdog_timeout(watchdog_timeout_flag),
    .watchdog_reset(watchdog_reset_out),
    .watchdog_warning(watchdog_warning_flag),
    ...
);

// Combine watchdog reset with system reset
assign combined_reset = reset_in | watchdog_reset_out;

// Add kick logic (example: kick on specific register write)
assign watchdog_kick = (reg_write && reg_addr == 6'h3F);  // Kick register
```

---

## Configuration Examples

### Example 1: Configure ADC Controller for 1 kHz Sampling at 50 MHz Clock

```systemverilog
// 50 MHz / 1 kHz = 50,000 cycles per sample
adc_sample_rate_div = 16'd50000;
adc_settling_cycles = 4'd10;  // 10 cycles settling time
adc_continuous_mode = 1'b1;   // Continuous sampling
```

### Example 2: Configure Calibration for Sensor Trim

```systemverilog
// Offset: -100 (in sensor units)
calibration_offset = -32'd100;

// Gain: 1.05x (fixed-point: 1.05 × 2^16 = 68813)
calibration_gain = 32'd68813;

calibration_enable = 1'b1;
calibration_bypass = 1'b0;
```

### Example 3: Configure Watchdog for 100ms Timeout

```systemverilog
// At 50 MHz: 100ms × 50,000,000 Hz = 5,000,000 cycles
watchdog_timeout = 32'd5000000;
watchdog_enable = 1'b1;
watchdog_lock = 1'b1;  // Lock configuration
```

### Example 4: Configure Interrupt Controller

```systemverilog
// Enable detection and security interrupts
interrupt_enable_mask = 8'b0000_0011;

// No masking
interrupt_mask = 8'b0000_0000;

// All edge-sensitive
interrupt_edge_mode = 8'b1111_1111;

// Fixed priority (lowest index = highest priority)
interrupt_priority_mode = 3'd0;
```

---

## Testing Your Integration

### Step 1: Simulate Individual Modules
```bash
# Test ADC Controller
vsim -do "run_test.tcl" adc_controller

# Test FIFO
vsim -do "run_test.tcl" data_fifo

# Test Calibration
vsim -do "run_test.tcl" calibration

# etc.
```

### Step 2: Simulate Integrated System
```bash
# Compile with enhanced target
make proximity_sensor_soc_enhanced

# Run simulation
vsim -do "sim_soc.tcl" proximity_sensor_soc
```

### Step 3: Verify Data Path
1. Apply ADC stimulus
2. Check FIFO fill level
3. Verify calibration output
4. Confirm filter operation
5. Validate detection logic

### Step 4: Verify Power Management
1. Transition through power states
2. Verify clock gating
3. Check reset synchronization
4. Measure power consumption (if supported)

### Step 5: Verify Error Handling
1. Trigger watchdog timeout
2. Generate FIFO overflow
3. Inject ADC errors
4. Verify interrupt generation and handling

---

## Common Integration Issues

### Issue 1: Clock Domain Crossing
**Problem**: Signals crossing between different clock domains cause metastability.

**Solution**: Use the domain-specific clocks and resets from clock_reset_manager. Add synchronizers for signals crossing domains.

```systemverilog
// Synchronizer for signal from sys_clk to adc_clk
logic [2:0] enable_sync;
always_ff @(posedge adc_clk or posedge adc_rst) begin
    if (adc_rst) enable_sync <= 3'b0;
    else enable_sync <= {enable_sync[1:0], enable_signal};
end
assign enable_adc_domain = enable_sync[2];
```

### Issue 2: Reset Ordering
**Problem**: Modules reset in wrong order causing initialization issues.

**Solution**: Use the synchronized resets from clock_reset_manager. All resets are properly ordered.

### Issue 3: FIFO Overflow/Underflow
**Problem**: Data loss or invalid reads.

**Solution**: Monitor almost_full/almost_empty flags. Implement backpressure using ready/valid handshake.

```systemverilog
// Use almost_full to throttle ADC
assign adc_enable = !fifo_almost_full;
```

### Issue 4: Watchdog False Triggers
**Problem**: Watchdog resets system during normal operation.

**Solution**: Increase timeout value or add periodic kick in normal operation flow.

---

## Build Targets

### Available DEPS Targets:

```bash
# Original SoC (without new modules)
make proximity_sensor_soc

# Enhanced SoC (with all new modules)
make proximity_sensor_soc_enhanced

# Individual module testing
make adc_controller
make data_fifo
make clock_reset_mgr
make calibration
make watchdog
make interrupt_ctrl
```

---

## Next Actions

### Immediate (Required for Function):
1. ✅ New modules created and linted
2. ✅ DEPS.yml updated
3. ⏳ **Create enhanced top-level SoC** (integrates all modules)
4. ⏳ **Update register file** (add configuration for new modules)
5. ⏳ **Create testbenches** (verify each module)

### Short-term (For Verification):
6. ⏳ Unit tests for each new module
7. ⏳ Integration test for complete data path
8. ⏳ Power state transition testing
9. ⏳ Error injection testing

### Long-term (For Production):
10. ⏳ Timing analysis and constraints
11. ⏳ Power analysis with new modules
12. ⏳ Gate-level simulation
13. ⏳ FPGA prototyping

---

## Questions?

If you need help with:
- **Creating the enhanced top-level module**
- **Writing testbenches**
- **Updating the register file**
- **Any other integration tasks**

Just let me know what you'd like to work on next!

---

**Document Version**: 1.0  
**Author**: Cognichip Co-Designer  
**Last Updated**: 2024
