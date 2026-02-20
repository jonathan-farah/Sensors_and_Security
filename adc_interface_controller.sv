// =============================================================================
// ADC Interface Controller
// =============================================================================
// Description: Controls ADC sampling, data synchronization, and error handling
// Features:
//   - Configurable sampling rate control
//   - Multi-cycle ADC transaction handling
//   - Data valid synchronization
//   - Error detection and reporting
//   - FIFO interface for data buffering
// Author: Cognichip Co-Designer
// =============================================================================

module adc_interface_controller #(
    parameter DATA_WIDTH = 32,
    parameter SAMPLE_RATE_WIDTH = 16
)(
    // Clock and Reset
    input  logic                        clock,
    input  logic                        reset,
    
    // Configuration Interface
    input  logic                        enable,
    input  logic [SAMPLE_RATE_WIDTH-1:0] sample_rate_divider,
    input  logic [3:0]                  adc_settling_cycles,  // ADC settling time
    input  logic                        continuous_mode,      // Continuous vs single-shot
    input  logic                        trigger_sample,       // Manual trigger for single-shot
    
    // ADC Physical Interface
    output logic                        adc_sample_request,
    output logic                        adc_power_enable,
    output logic                        adc_reset_n,
    input  logic                        adc_data_valid,
    input  logic [DATA_WIDTH-1:0]       adc_data_in,
    input  logic                        adc_ready,
    input  logic                        adc_error,
    
    // Data Output Interface (to FIFO or processing pipeline)
    output logic                        data_valid_out,
    output logic [DATA_WIDTH-1:0]       data_out,
    input  logic                        data_ready_in,
    
    // Status and Control
    output logic                        busy,
    output logic                        adc_timeout_error,
    output logic                        adc_interface_error,
    output logic [15:0]                 samples_captured,
    output logic [2:0]                  adc_state_out
);

    // =========================================================================
    // State Machine Definitions
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE            = 3'b000,
        POWER_UP        = 3'b001,
        WAIT_SETTLING   = 3'b010,
        SAMPLE_REQUEST  = 3'b011,
        WAIT_DATA       = 3'b100,
        DATA_VALID      = 3'b101,
        ERROR_STATE     = 3'b110,
        POWER_DOWN      = 3'b111
    } adc_state_t;
    
    adc_state_t current_state, next_state;
    
    // =========================================================================
    // Internal Registers and Signals
    // =========================================================================
    logic [SAMPLE_RATE_WIDTH-1:0]   sample_timer;
    logic                           sample_trigger_edge;
    logic                           trigger_sample_reg;
    logic [3:0]                     settling_counter;
    logic [7:0]                     timeout_counter;
    logic                           timeout_flag;
    logic [15:0]                    sample_count;
    logic                           data_handshake_complete;
    
    // =========================================================================
    // Sample Rate Timer
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            sample_timer <= '0;
        end else begin
            if (!enable || current_state == IDLE) begin
                sample_timer <= '0;
            end else if (sample_timer >= sample_rate_divider) begin
                sample_timer <= '0;
            end else begin
                sample_timer <= sample_timer + 1'b1;
            end
        end
    end
    
    logic sample_time_reached;
    assign sample_time_reached = (sample_timer >= sample_rate_divider);
    
    // =========================================================================
    // Trigger Edge Detection (for single-shot mode)
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            trigger_sample_reg <= 1'b0;
        end else begin
            trigger_sample_reg <= trigger_sample;
        end
    end
    
    assign sample_trigger_edge = trigger_sample && !trigger_sample_reg;
    
    // =========================================================================
    // Settling Time Counter
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            settling_counter <= '0;
        end else begin
            if (current_state == WAIT_SETTLING) begin
                settling_counter <= settling_counter + 1'b1;
            end else begin
                settling_counter <= '0;
            end
        end
    end
    
    // =========================================================================
    // Timeout Counter (watchdog for ADC response)
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            timeout_counter <= '0;
            timeout_flag <= 1'b0;
        end else begin
            if (current_state == WAIT_DATA) begin
                if (timeout_counter >= 8'd200) begin  // 200 cycle timeout
                    timeout_flag <= 1'b1;
                end else begin
                    timeout_counter <= timeout_counter + 1'b1;
                end
            end else begin
                timeout_counter <= '0;
                timeout_flag <= 1'b0;
            end
        end
    end
    
    // =========================================================================
    // Sample Counter
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            sample_count <= '0;
        end else begin
            if (!enable) begin
                sample_count <= '0;
            end else if (current_state == DATA_VALID && data_handshake_complete) begin
                sample_count <= sample_count + 1'b1;
            end
        end
    end
    
    assign samples_captured = sample_count;
    
    // =========================================================================
    // Data Handshake
    // =========================================================================
    assign data_handshake_complete = data_valid_out && data_ready_in;
    
    // =========================================================================
    // State Machine: Sequential Logic
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // =========================================================================
    // State Machine: Combinational Logic
    // =========================================================================
    always_comb begin
        // Default assignments
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (enable) begin
                    next_state = POWER_UP;
                end
            end
            
            POWER_UP: begin
                next_state = WAIT_SETTLING;
            end
            
            WAIT_SETTLING: begin
                if (settling_counter >= adc_settling_cycles) begin
                    if (continuous_mode) begin
                        if (sample_time_reached) begin
                            next_state = SAMPLE_REQUEST;
                        end
                    end else begin
                        if (sample_trigger_edge) begin
                            next_state = SAMPLE_REQUEST;
                        end
                    end
                end
            end
            
            SAMPLE_REQUEST: begin
                if (adc_ready) begin
                    next_state = WAIT_DATA;
                end else if (adc_error) begin
                    next_state = ERROR_STATE;
                end
            end
            
            WAIT_DATA: begin
                if (adc_data_valid) begin
                    next_state = DATA_VALID;
                end else if (timeout_flag || adc_error) begin
                    next_state = ERROR_STATE;
                end
            end
            
            DATA_VALID: begin
                if (data_handshake_complete) begin
                    if (!enable) begin
                        next_state = POWER_DOWN;
                    end else if (continuous_mode) begin
                        next_state = WAIT_SETTLING;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            
            ERROR_STATE: begin
                if (!enable) begin
                    next_state = POWER_DOWN;
                end else begin
                    next_state = WAIT_SETTLING;  // Retry after error
                end
            end
            
            POWER_DOWN: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // =========================================================================
    // Output Logic
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            adc_sample_request <= 1'b0;
            adc_power_enable <= 1'b0;
            adc_reset_n <= 1'b0;
            data_valid_out <= 1'b0;
            data_out <= '0;
            busy <= 1'b0;
            adc_timeout_error <= 1'b0;
            adc_interface_error <= 1'b0;
        end else begin
            // Default values
            adc_sample_request <= 1'b0;
            data_valid_out <= 1'b0;
            adc_timeout_error <= 1'b0;
            adc_interface_error <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    adc_power_enable <= 1'b0;
                    adc_reset_n <= 1'b0;
                    busy <= 1'b0;
                end
                
                POWER_UP: begin
                    adc_power_enable <= 1'b1;
                    adc_reset_n <= 1'b1;
                    busy <= 1'b1;
                end
                
                WAIT_SETTLING: begin
                    adc_power_enable <= 1'b1;
                    adc_reset_n <= 1'b1;
                    busy <= 1'b1;
                end
                
                SAMPLE_REQUEST: begin
                    adc_sample_request <= 1'b1;
                    adc_power_enable <= 1'b1;
                    adc_reset_n <= 1'b1;
                    busy <= 1'b1;
                end
                
                WAIT_DATA: begin
                    adc_power_enable <= 1'b1;
                    adc_reset_n <= 1'b1;
                    busy <= 1'b1;
                end
                
                DATA_VALID: begin
                    data_valid_out <= 1'b1;
                    data_out <= adc_data_in;
                    adc_power_enable <= 1'b1;
                    adc_reset_n <= 1'b1;
                    busy <= 1'b1;
                end
                
                ERROR_STATE: begin
                    adc_timeout_error <= timeout_flag;
                    adc_interface_error <= adc_error;
                    adc_power_enable <= 1'b1;
                    adc_reset_n <= 1'b0;  // Reset ADC on error
                    busy <= 1'b1;
                end
                
                POWER_DOWN: begin
                    adc_power_enable <= 1'b0;
                    adc_reset_n <= 1'b0;
                    busy <= 1'b0;
                end
                
                default: begin
                    adc_power_enable <= 1'b0;
                    adc_reset_n <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
    // =========================================================================
    // Debug State Output
    // =========================================================================
    assign adc_state_out = current_state;

endmodule
