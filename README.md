# Moving Average Filter - Tiny Tapeout

![](https://github.com/jonathan-farah/Sensors_and_Security/workflows/gds/badge.svg) 
![](https://github.com/jonathan-farah/Sensors_and_Security/workflows/docs/badge.svg)

**Authors:** Jonathan Farah, Jason Qin  
**Project:** Smart Low-Power Proximity Sensor SoC  
**Tiny Tapeout:** TT08

## Overview

An 8-bit configurable moving average filter optimized for Tiny Tapeout. Features runtime-adjustable filter length (1-15 taps), circular buffer architecture, and power-optimized sequential accumulation.

## Features

- ✅ 8-bit data width (0-255)
- ✅ Configurable smoothing (1-15 taps)
- ✅ Circular buffer (no data shifting)
- ✅ Power-of-2 optimization
- ✅ Ready-valid handshake
- ✅ Fits in 24-pin Tiny Tapeout interface

## Repository Structure

```
├── src/
│   └── tt_um_jonathan_farah_moving_average_filter.sv  (Main design)
├── test/
│   └── (Optional testbenches)
├── docs/
│   └── info.md                                         (Documentation)
├── .github/workflows/
│   ├── gds.yaml                                        (Build workflow)
│   └── docs.yaml                                       (Docs workflow)
├── info.yaml                                           (TT configuration)
└── README.md                                           (This file)
```

## How It Works

The filter computes a sliding window average:

```
Output = (sample[0] + sample[1] + ... + sample[N-1]) / N
```

See [docs/info.md](docs/info.md) for detailed documentation.

## Quick Test

1. Reset: `rst_n = 0` for 5+ cycles
2. Configure: `num_taps = 4`
3. Enable: `enable = 1`
4. Send samples: 16, 32, 48, 64
5. Expected result: (16+32+48+64)/4 = 40

## Pin Configuration

**Inputs (8):** enable, num_taps[3:0], data_valid, data_in[1:0]  
**Outputs (8):** data_ready, result_valid, busy, result_out[4:0]  
**Bidirectional (8):** data_in[7:2], result_out[6:5]

## Resources

- [Complete Documentation](docs/info.md)
- [Code Dissection](moving_average_filter_presentation.md)
- [Tiny Tapeout Setup Guide](TINYTAPEOUT_SETUP.md)
- [GitHub Repository](https://github.com/jonathan-farah/Sensors_and_Security)

## License

Apache-2.0

---

*Ready for Tiny Tapeout TT08 fabrication!* 🎉
