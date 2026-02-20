# Waveform Viewing Guide
## Moving Average Filter Simulation

**Authors:** Jonathan Farah, Jason Qin  
**Repository:** git@github.com:jonathan-farah/Sensors_and_Security.git

---

## Quick Start 🚀

### Option 1: Automated Script (Easiest)
```bash
# Just double-click or run:
view_waveforms.bat
```

This script automatically:
- Finds your latest simulation results
- Locates the waveform file
- Launches GTKWave with the correct file

### Option 2: Manual Launch
```bash
# Navigate to simulation results
cd simulation_results\sim_2026-02-20T02-29-40-533Z

# Open with GTKWave
gtkwave dumpfile.fst
```

### Option 3: Pre-configured View
```bash
# Load with pre-configured signals
gtkwave -f dumpfile.fst -a ../moving_average_filter.gtkw
```

---

## Installing GTKWave

### Windows
1. **Download:** http://gtkwave.sourceforge.net/
2. **Install:** Run the installer
3. **Add to PATH** (optional but recommended)

### Using Chocolatey
```bash
choco install gtkwave
```

### Using Scoop
```bash
scoop install gtkwave
```

---

## Key Signals to Observe 👀

### 1. Clock and Reset
- **clock** - System clock (10ns period = 100 MHz)
- **reset** - Active-high reset signal

### 2. Input Interface
- **data_valid** - Indicates new input sample
- **data_in[31:0]** - Input data sample
- **data_ready** - Filter ready to accept data
- **num_taps[3:0]** - Filter configuration (1-15 taps)

### 3. State Machine
- **current_state[1:0]** - Current FSM state:
  - `00` = IDLE
  - `01` = ACCUMULATE
  - `10` = DIVIDE
  - `11` = OUTPUT
- **accumulate_counter[3:0]** - Counts through buffer during accumulation

### 4. Circular Buffer
- **write_ptr[3:0]** - Buffer write position (0-14)
- **valid_samples[3:0]** - Number of valid samples (initialization)
- **delay_line[0..14][31:0]** - Circular buffer array contents

### 5. Computation
- **sum_accumulator[31:0]** - Running sum during accumulation
- **filtered_result[31:0]** - Final averaged result

### 6. Output Interface
- **result_valid** - Output data valid (pulses for 1 cycle)
- **result_out[31:0]** - Filtered output value
- **busy** - Filter is processing

---

## GTKWave Tips & Tricks 💡

### Adding Signals
1. Expand hierarchy tree: `tb_moving_average_filter` → `dut`
2. Select signal(s) you want
3. Click **Append** or press **Insert**
4. Drag to reorder signals

### Display Formats
- **Right-click signal** → Data Format:
  - **Hex** - Good for 32-bit values
  - **Decimal** - Good for counters and results
  - **Binary** - Good for state machines
  - **Analog** - Visualize data as waveform

### Navigation
- **Zoom In:** `Ctrl` + `+` or middle mouse scroll
- **Zoom Out:** `Ctrl` + `-` or middle mouse scroll
- **Zoom Fit:** `Ctrl` + `F`
- **Zoom to Selection:** Select range, then `Ctrl` + `F`

### Time Cursor
- **Primary Cursor:** Left-click on timeline
- **Secondary Cursor:** Middle-click (for measurements)
- **Show Delta:** Time difference between cursors

### Signal Grouping
- **Right-click signal** → Insert Blank
- **Right-click blank** → Insert Comment
- Group related signals together for clarity

### Saving Views
- **File** → **Write Save File** (Ctrl+S)
- Saves signal selection and display settings
- Our pre-configured view: `moving_average_filter.gtkw`

---

## What to Look For 🔍

### Test 1: Single Tap (Pass-Through)
- **num_taps = 1**
- Input value should equal output value immediately
- No averaging occurs

### Test 2: Two Tap Average
- **num_taps = 2**
- Watch buffer fill with 2 samples
- Output = (sample[0] + sample[1]) / 2

### Test 3: Four Tap Average (Detailed Example)
- **num_taps = 4**
- **Samples:** 10, 20, 30, 40, 50

**Expected Behavior:**
1. **Buffer Fill Phase:**
   - Samples 1-4 stored in circular buffer
   - `valid_samples` counts up to 4
   - State remains IDLE

2. **Filtering Triggered:**
   - Sample 5 arrives
   - State: IDLE → ACCUMULATE

3. **Accumulation:**
   - State = ACCUMULATE for 4 cycles
   - `sum_accumulator` builds: 10 → 30 → 60 → 100
   - `accumulate_counter` increments: 1 → 2 → 3 → 4

4. **Division:**
   - State = DIVIDE for 1 cycle
   - `filtered_result` = 100 >> 2 = 25

5. **Output:**
   - State = OUTPUT for 1 cycle
   - `result_valid` pulses HIGH
   - `result_out` = 25

### State Machine Timing
Watch the state transitions:
```
IDLE (several cycles) → ACCUMULATE (num_taps cycles) → 
DIVIDE (1 cycle) → OUTPUT (1 cycle) → IDLE
```

### Circular Buffer Operation
- **write_ptr** wraps from 14 → 0
- New samples overwrite oldest
- No data shifting - just pointer movement

---

## Troubleshooting 🔧

### GTKWave won't open
- **Check installation:** Run `gtkwave --version` in terminal
- **Install GTKWave** if not found
- **Try absolute path:** Point directly to waveform file

### No signals visible
- **Check hierarchy:** Expand `tb_moving_average_filter` tree
- **Reload file:** File → Reload Waveform
- **Check simulation:** Verify dumpfile.fst exists and has data

### Waveform file not found
- **Run simulation first:** The testbench must complete
- **Check path:** Look in `simulation_results/sim_*/dumpfile.fst`
- **Check permissions:** Ensure read access to file

### Signals show 'x' or 'z'
- **Reset issue:** Check if reset is properly applied
- **Timing issue:** Signals may be uninitialized
- **This is expected** during reset or before first data

---

## Understanding the Tests 📊

The testbench runs 8 comprehensive tests:

1. **Single Tap** - Pass-through mode
2. **Two Tap** - Simple averaging
3. **Four Tap** - Power-of-2 optimization (right shift)
4. **Eight Tap** - Larger power-of-2 window
5. **Maximum Taps (15)** - Full buffer capacity
6. **Enable/Disable** - Control signal behavior
7. **Busy Signal** - Handshake protocol
8. **Continuous Stream** - Multiple samples back-to-back

**Total Simulation Time:** ~100 µs

---

## Signal Display Recommendations

### Minimal View (Quick Check)
- clock
- data_valid, data_in
- current_state
- result_valid, result_out

### Standard View (Debug)
- All inputs and outputs
- State machine signals
- Key internal signals (accumulator, counter)

### Detailed View (Full Analysis)
- Everything including:
  - All buffer array elements
  - Write pointer
  - Valid sample counter
  - Computation internals

---

## Example Waveform Analysis

### 4-Tap Average: Samples [10, 20, 30, 40]

**At time ~500ns:**
```
Clock Cycle | State      | accumulate_counter | sum_accumulator | Action
------------|------------|-------------------|-----------------|------------------
1           | IDLE       | 0                 | 0               | Sample 10 arrives
2           | IDLE       | 0                 | 0               | Sample 20 arrives
3           | IDLE       | 0                 | 0               | Sample 30 arrives
4           | IDLE       | 0                 | 0               | Sample 40 arrives
5           | IDLE→ACC   | 0→1               | 0→10            | Trigger + load[0]
6           | ACCUMULATE | 1→2               | 10→30           | Add delay_line[1]
7           | ACCUMULATE | 2→3               | 30→60           | Add delay_line[2]
8           | ACCUMULATE | 3→4               | 60→100          | Add delay_line[3]
9           | DIVIDE     | 4                 | 100             | 100 >> 2 = 25
10          | OUTPUT     | 4                 | 100             | result_valid=1
11          | IDLE       | 0                 | 0               | Ready for next
```

---

## Need Help? 🆘

- **Check simulation log:** Look in `simulation_results/sim_*/transcript`
- **Verify testbench:** Open `tb_moving_average_filter.sv`
- **Read code dissection:** See `moving_average_filter_presentation.md`
- **GitHub Issues:** Report problems at your repository

---

## Quick Reference Commands

```bash
# View latest waveforms
view_waveforms.bat

# View with pre-configured signals
gtkwave -a moving_average_filter.gtkw simulation_results/latest/dumpfile.fst

# List all simulation runs
dir simulation_results

# Check if GTKWave is installed
gtkwave --version
```

---

**Happy Waveform Viewing!** 🌊✨

*Understanding waveforms is key to debugging and verifying hardware designs.*
