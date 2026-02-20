// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Moving Average Filter
// =============================================================================
// Description: Configurable moving-average filter for noise reduction
// Author: Cognichip Co-Designer
// =============================================================================

module moving_average_filter #(
    parameter DATA_WIDTH = 32,
    parameter MAX_TAPS = 15         // Maximum number of filter taps (1-15)
)(
    // Clock and Reset
    input  logic                    clock,
    input  logic                    reset,
    
    // Control
    input  logic                    enable,
    input  logic [3:0]              num_taps,       // Configurable: 1 to MAX_TAPS
    
    // Data Interface
    input  logic                    data_valid,     // Input data valid
    input  logic [DATA_WIDTH-1:0]   data_in,        // Input sample
    output logic                    data_ready,     // Ready for new sample
    output logic                    result_valid,   // Output data valid
    output logic [DATA_WIDTH-1:0]   result_out,     // Filtered output
    output logic                    busy            // Filter is processing
);

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
    always_ff @(posedge clock or posedge reset) begin
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
            if (write_ptr == 4'hF) begin  // MAX_TAPS - 1 = 15
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
    always_ff @(posedge clock or posedge reset) begin
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
    always_ff @(posedge clock or posedge reset) begin
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
                    // For non-power-of-2, we use a simplified approximation
                    case (num_taps)
                        4'd1:  filtered_result <= sum_accumulator;
                        4'd2:  filtered_result <= sum_accumulator >> 1;
                        4'd4:  filtered_result <= sum_accumulator >> 2;
                        4'd8:  filtered_result <= sum_accumulator >> 3;
                        default: begin
                            // Approximate division for non-power-of-2
                            // This is a simplified approach for hardware efficiency
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
    always_ff @(posedge clock or posedge reset) begin
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
