// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Configuration Register File
// =============================================================================
// Description: Memory-mapped register file for system configuration and control
// Author: Cognichip Co-Designer
// =============================================================================

module proximity_sensor_regfile #(
    parameter ADDR_WIDTH = 6,      // 64 byte address space
    parameter DATA_WIDTH = 32      // 32-bit data bus
)(
    // Clock and Reset
    input  logic                    clock,
    input  logic                    reset,
    
    // Register Interface (Memory-mapped)
    input  logic                    reg_write,      // Write enable
    input  logic                    reg_read,       // Read enable
    input  logic [ADDR_WIDTH-1:0]   reg_addr,       // Register address
    input  logic [DATA_WIDTH-1:0]   reg_wdata,      // Write data
    output logic [DATA_WIDTH-1:0]   reg_rdata,      // Read data
    output logic                    reg_ready,      // Transaction ready
    output logic                    reg_error,      // Access error (security violation)
    
    // Control Outputs
    output logic                    system_enable,
    output logic                    filter_enable,
    output logic [1:0]              power_mode,     // 00=sleep, 01=idle, 10=active, 11=high-perf
    output logic [3:0]              filter_taps,    // Number of filter taps (4-16)
    output logic [DATA_WIDTH-1:0]   threshold_low,
    output logic [DATA_WIDTH-1:0]   threshold_high,
    output logic [7:0]              hysteresis,
    output logic [15:0]             sample_rate_div,
    output logic                    interrupt_en_detect,
    output logic                    interrupt_en_error,
    output logic                    security_lock,
    
    // Status Inputs
    input  logic                    detection_flag,
    input  logic [1:0]              current_power_state,
    input  logic                    filter_busy,
    input  logic                    adc_ready,
    input  logic [DATA_WIDTH-1:0]   adc_data,
    input  logic [DATA_WIDTH-1:0]   filtered_data,
    input  logic                    security_violation,
    
    // Interrupt Clear
    input  logic                    clear_interrupt
);

    // =========================================================================
    // Register Address Map
    // =========================================================================
    localparam ADDR_CONTROL_REG    = 6'h00;  // 0x00
    localparam ADDR_FILTER_CFG     = 6'h04;  // 0x04
    localparam ADDR_THRESHOLD_LOW  = 6'h08;  // 0x08
    localparam ADDR_THRESHOLD_HIGH = 6'h0C;  // 0x0C
    localparam ADDR_HYSTERESIS_CFG = 6'h10;  // 0x10
    localparam ADDR_SAMPLE_RATE    = 6'h14;  // 0x14
    localparam ADDR_STATUS_REG     = 6'h18;  // 0x18 (Read-only)
    localparam ADDR_INTERRUPT_EN   = 6'h1C;  // 0x1C
    localparam ADDR_SECURITY_CFG   = 6'h20;  // 0x20
    localparam ADDR_ADC_DATA       = 6'h24;  // 0x24 (Read-only)
    localparam ADDR_FILTERED_DATA  = 6'h28;  // 0x28 (Read-only)
    
    // =========================================================================
    // Internal Registers
    // =========================================================================
    logic [DATA_WIDTH-1:0] control_reg;
    logic [DATA_WIDTH-1:0] filter_cfg;
    logic [DATA_WIDTH-1:0] threshold_low_reg;
    logic [DATA_WIDTH-1:0] threshold_high_reg;
    logic [DATA_WIDTH-1:0] hysteresis_cfg;
    logic [DATA_WIDTH-1:0] sample_rate_reg;
    logic [DATA_WIDTH-1:0] status_reg;
    logic [DATA_WIDTH-1:0] interrupt_en_reg;
    logic [DATA_WIDTH-1:0] security_cfg_reg;
    
    // Interrupt status flags (sticky)
    logic interrupt_detect_pending;
    logic interrupt_error_pending;
    
    // =========================================================================
    // Register Write Logic
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            control_reg         <= 32'h0000_0000;
            filter_cfg          <= 32'h0000_0008;  // Default: 8 taps
            threshold_low_reg   <= 32'h0000_0100;  // Default threshold
            threshold_high_reg  <= 32'h0000_0200;  // Default threshold
            hysteresis_cfg      <= 32'h0000_0010;  // Default hysteresis
            sample_rate_reg     <= 32'h0000_0064;  // Default: divide by 100
            interrupt_en_reg    <= 32'h0000_0000;
            security_cfg_reg    <= 32'h0000_0000;
            interrupt_detect_pending <= 1'b0;
            interrupt_error_pending  <= 1'b0;
        end else begin
            // Clear interrupts on acknowledge
            if (clear_interrupt) begin
                interrupt_detect_pending <= 1'b0;
                interrupt_error_pending  <= 1'b0;
            end
            
            // Set interrupt flags
            if (detection_flag) begin
                interrupt_detect_pending <= 1'b1;
            end
            if (security_violation) begin
                interrupt_error_pending <= 1'b1;
            end
            
            // Register writes (only if not locked)
            if (reg_write && !security_cfg_reg[0]) begin
                case (reg_addr)
                    ADDR_CONTROL_REG: begin
                        control_reg <= reg_wdata;
                    end
                    ADDR_FILTER_CFG: begin
                        filter_cfg <= reg_wdata;
                    end
                    ADDR_THRESHOLD_LOW: begin
                        threshold_low_reg <= reg_wdata;
                    end
                    ADDR_THRESHOLD_HIGH: begin
                        threshold_high_reg <= reg_wdata;
                    end
                    ADDR_HYSTERESIS_CFG: begin
                        hysteresis_cfg <= reg_wdata;
                    end
                    ADDR_SAMPLE_RATE: begin
                        sample_rate_reg <= reg_wdata;
                    end
                    ADDR_INTERRUPT_EN: begin
                        interrupt_en_reg <= reg_wdata;
                    end
                    ADDR_SECURITY_CFG: begin
                        security_cfg_reg <= reg_wdata;
                    end
                    default: begin
                        // Read-only or invalid address - no action
                    end
                endcase
            end
        end
    end
    
    // =========================================================================
    // Register Read Logic
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            reg_rdata <= 32'h0000_0000;
            reg_ready <= 1'b0;
            reg_error <= 1'b0;
        end else begin
            reg_ready <= 1'b0;
            reg_error <= 1'b0;
            
            if (reg_read || reg_write) begin
                reg_ready <= 1'b1;
                
                // Check for security violation on write to locked registers
                if (reg_write && security_cfg_reg[0]) begin
                    reg_error <= 1'b1;
                end
                
                case (reg_addr)
                    ADDR_CONTROL_REG:    reg_rdata <= control_reg;
                    ADDR_FILTER_CFG:     reg_rdata <= filter_cfg;
                    ADDR_THRESHOLD_LOW:  reg_rdata <= threshold_low_reg;
                    ADDR_THRESHOLD_HIGH: reg_rdata <= threshold_high_reg;
                    ADDR_HYSTERESIS_CFG: reg_rdata <= hysteresis_cfg;
                    ADDR_SAMPLE_RATE:    reg_rdata <= sample_rate_reg;
                    ADDR_STATUS_REG:     reg_rdata <= status_reg;
                    ADDR_INTERRUPT_EN:   reg_rdata <= interrupt_en_reg;
                    ADDR_SECURITY_CFG:   reg_rdata <= security_cfg_reg;
                    ADDR_ADC_DATA:       reg_rdata <= adc_data;
                    ADDR_FILTERED_DATA:  reg_rdata <= filtered_data;
                    default: begin
                        reg_rdata <= 32'hDEAD_BEEF;  // Invalid address marker
                        reg_error <= 1'b1;
                    end
                endcase
            end
        end
    end
    
    // =========================================================================
    // Status Register Construction (Dynamic)
    // =========================================================================
    always_comb begin
        status_reg = {
            16'h0000,                           // [31:16] Reserved
            adc_ready,                          // [15] ADC ready
            filter_busy,                        // [14] Filter busy
            interrupt_error_pending,            // [13] Error interrupt pending
            interrupt_detect_pending,           // [12] Detection interrupt pending
            4'h0,                               // [11:8] Reserved
            2'b00,                              // [7:6] Reserved
            current_power_state,                // [5:4] Current power state
            2'b00,                              // [3:2] Reserved
            detection_flag,                     // [1] Proximity detected
            security_cfg_reg[0]                 // [0] Security lock status
        };
    end
    
    // =========================================================================
    // Output Assignments
    // =========================================================================
    assign system_enable        = control_reg[0];
    assign filter_enable        = control_reg[1];
    assign power_mode           = control_reg[3:2];
    assign filter_taps          = filter_cfg[3:0];
    assign threshold_low        = threshold_low_reg;
    assign threshold_high       = threshold_high_reg;
    assign hysteresis           = hysteresis_cfg[7:0];
    assign sample_rate_div      = sample_rate_reg[15:0];
    assign interrupt_en_detect  = interrupt_en_reg[0];
    assign interrupt_en_error   = interrupt_en_reg[1];
    assign security_lock        = security_cfg_reg[0];

endmodule
