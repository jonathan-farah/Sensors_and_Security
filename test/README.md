# Test Directory

This directory is reserved for Tiny Tapeout test files (optional).

## What Goes Here

- **Cocotb testbenches** (Python-based)
- **Test vectors**
- **Expected outputs**
- **Test configuration files**

## Current Testbenches

The main testbench is located at:
- `../tb_moving_average_filter_tt.sv` (SystemVerilog testbench)

## Running Tests

To run tests locally:

```bash
# Navigate to parent directory
cd ..

# Run with Icarus Verilog
iverilog -g2012 -o sim_tt \
    src/tt_um_jonathan_farah_moving_average_filter.sv \
    tb_moving_average_filter_tt.sv
    
vvp sim_tt

# View waveforms
gtkwave dumpfile_tt.fst
```

## Cocotb Tests (Optional)

For Tiny Tapeout submission, Cocotb tests are optional but recommended for complex designs.

To add Cocotb tests:
1. Create `test_moving_average_filter.py`
2. Add test cases using Cocotb framework
3. Create `Makefile` for test automation

## More Information

- [Tiny Tapeout Testing Guide](https://tinytapeout.com/hdl/testing/)
- [Cocotb Documentation](https://docs.cocotb.org/)
