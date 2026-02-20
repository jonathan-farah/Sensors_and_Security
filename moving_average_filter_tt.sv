// =============================================================================
// Moving Average Filter for Tiny Tapeout - 8-bit Version
// =============================================================================
// Description: Configurable 8-bit moving-average filter optimized for Tiny Tapeout
// Authors: Jonathan Farah, Jason Qin
// Repository: git@github.com:jonathan-farah/Sensors_and_Security.git
// 
// Tiny Tapeout Constraints:
//   - 8 dedicated input pins
//   - 8 dedicated output pins
//   - 8 bidirectional pins (configurable as input or output)
//
// Pin Usage:
//   Inputs (8):  enable, num_taps[3:0], data_valid, data_in[1:0]
//   Outputs (8): data_ready, result_valid, busy, result_out[4:0]
//   Bidir (8):   data_in[7:2], result_out[7:5], state[1:0]
// =============================================================================

module tt_um_jonathan_farah_moving_average_filter #(
    parameter DATA_WIDTH = 8,           // 8-bit data for Tiny Tapeout
    parameter MAX_TAPS = 15             // Maximum number of filter taps (1-15)
)(
    // Standard Tiny Tapeout interface
    input  logic                    clk,        // System clock
    input  logic                    rst_n,      // Active-low reset (Tiny Tapeout standard)
    
    // Dedicated inputs [7:0]
    input  logic                    ui_in_0,    // enable
    input  logic                    ui_in_1,    // num_taps[0]
    input  logic                    ui_in_2,    // num_taps[1]
    input  logic                    ui_in_3,    // num_taps[2]
    input  logic                    ui_in_4,    // num_taps[3]
    input  logic                    ui_in_5,    // data_valid
    input  logic                    ui_in_6,    // data_in[0]
    input  logic                    ui_in_7,    // data_in[1]
    
    // Dedicated outputs [7:0]
    output logic                    uo_out_0,   // data_ready
    output logic                    uo_out_1,   // result_valid
    output logic                    uo_out_2,   // busy
    output logic                    uo_out_3,   // result_out[0]
    output logic                    uo_out_4,   // result_out[1]
    output logic                    uo_out_5,   // result_out[2]
    output logic                    uo_out_6,   // result_out[3]
    output logic                    uo_out_7,   // result_out[4]
    
    // Bidirectional pins [7:0]
    input  logic [7:0]              uio_in,     // Input from bidirectional pins
    output logic [7:0]              uio_out,    // Output to bidirectional pins
    output logic [7:0]              uio_oe      // Output enable (1=output, 0=input)
);

    // =========================================================================
    // Signal Mapping - Convert Tiny Tapeout interface to functional signals
    // =========================================================================
    
    // Convert active-low reset to active-high
    logic reset;
    assign reset = ~rst_n;
    
    // Map dedicated inputs
    logic enable;
    logic [3:0] num_taps;
    logic data_valid;
    logic [DATA_WIDTH-1:0] data_in;
    
    assign enable = ui_in_0;
    assign num_taps = {ui_in_4, ui_in_3, ui_in_2, ui_in_1};
    assign data_valid = ui_in_5;
    assign data_in = {uio_in[5:0], ui_in_7, ui_in_6};  // 8-bit: [7:2] from bidir, [1:0] from dedicated
    
    // Map dedicated outputs
    logic data_ready;
    logic result_valid;
    logic busy;
    logic [DATA_WIDTH-1:0] result_out;
    
    assign uo_out_0 = data_ready;
    assign uo_out_1 = result_valid;
    assign uo_out_2 = busy;
    assign {uo_out_7, uo_out_6, uo_out_5, uo_out_4, uo_out_3} = result_out[4:0];
    
    // Configure bidirectional pins
    // Bits [5:0] = input (data_in[7:2])
    // Bits [7:6] = output (result_out[7:5] and state[1:0])
    assign uio_oe = 8'b11000000;  // Only bits 7:6 are outputs
    
    // Export state machine and upper result bits on bidirectional output
    assign uio_out[5:0] = 6'b000000;  // Not used (inputs)
    assign uio_out[6] = result_out[5];
    assign uio_out[7] = result_out[6];
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic [DATA_WIDTH-1:0] delay_line [MAX_TAPS-1:0];  // Circular buffer
    logic [DATA_WIDTH-1:0] sum_accumulator;
    logic [DATA_WIDTH-1:0] filtered_result;
    logic [3:0] write_ptr;
    logic [3:0] valid_samples;
    logic computing;
    
    // State machine for pipelined operation
    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        ACCUMULATE  = 2'b01,
        DIVIDE      = 2'b10,
        OUTPUT      = 2'b11
    } filter_state_t;
    
    filter_state_t current_state, next_state;
    logic [3:0] accumulate_counter;
    
    // =========================================================================
    // Delay Line Management (Circular Buffer)
    // =========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < MAX_TAPS; i++) begin
                delay_line[i] <= '0;
            end
            write_ptr <= 4'h0;
            valid_samples <= 4'h0;
        end else if (enable && data_valid && !computing) begin
            // Write new sample to circular buffer
            delay_line[write_ptr] <= data_in;
            
            // Update write pointer (circular)
            if (write_ptr == 4'hE) begin  // MAX_TAPS - 1 = 14 (0xE)
                write_ptr <= 4'h0;
            end else begin
                write_ptr <= write_ptr + 4'h1;
            end
            
            // Track valid samples
            if (valid_samples < num_taps) begin
                valid_samples <= valid_samples + 4'h1;
            end
        end
    end
    
    // =========================================================================
    // State Machine
    // =========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (enable && data_valid && valid_samples == num_taps) begin
                    next_state = ACCUMULATE;
                end
            end
            
            ACCUMULATE: begin
                if (accumulate_counter >= num_taps) begin
                    next_state = DIVIDE;
                end
            end
            
            DIVIDE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // =========================================================================
    // Accumulation Logic
    // =========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sum_accumulator <= '0;
            accumulate_counter <= 4'h0;
            filtered_result <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    sum_accumulator <= '0;
                    accumulate_counter <= 4'h0;
                    if (enable && data_valid && valid_samples == num_taps) begin
                        // Start accumulation on next cycle
                        sum_accumulator <= delay_line[0];
                        accumulate_counter <= 4'h1;
                    end
                end
                
                ACCUMULATE: begin
                    if (accumulate_counter < num_taps) begin
                        sum_accumulator <= sum_accumulator + delay_line[accumulate_counter];
                        accumulate_counter <= accumulate_counter + 4'h1;
                    end
                end
                
                DIVIDE: begin
                    // Simple division by num_taps (right shift for power-of-2)
                    case (num_taps)
                        4'd1:  filtered_result <= sum_accumulator;
                        4'd2:  filtered_result <= sum_accumulator >> 1;
                        4'd4:  filtered_result <= sum_accumulator >> 2;
                        4'd8:  filtered_result <= sum_accumulator >> 3;
                        default: begin
                            // Approximate division for non-power-of-2
                            filtered_result <= sum_accumulator / num_taps;
                        end
                    endcase
                end
                
                OUTPUT: begin
                    // Hold result for one cycle
                end
                
                default: begin
                    sum_accumulator <= '0;
                    accumulate_counter <= 4'h0;
                end
            endcase
        end
    end
    
    // =========================================================================
    // Output Control
    // =========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result_valid <= 1'b0;
            result_out <= '0;
        end else begin
            result_valid <= 1'b0;
            
            if (current_state == OUTPUT) begin
                result_valid <= 1'b1;
                result_out <= filtered_result;
            end
        end
    end
    
    // =========================================================================
    // Status Signals
    // =========================================================================
    assign computing = (current_state != IDLE);
    assign busy = computing;
    assign data_ready = !computing && enable;

endmodule
