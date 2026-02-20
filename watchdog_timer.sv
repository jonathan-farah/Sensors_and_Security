// =============================================================================
// Watchdog Timer
// =============================================================================
// Description: System reliability watchdog with configurable timeout and actions
// Features:
//   - Programmable timeout period
//   - Software reset capability
//   - Automatic system reset on timeout
//   - Timeout event counting
//   - Window watchdog mode (optional)
//   - Lock mechanism to prevent accidental disable
// Author: Cognichip Co-Designer
// =============================================================================

module watchdog_timer #(
    parameter COUNTER_WIDTH = 32,
    parameter DEFAULT_TIMEOUT = 32'h00FF_FFFF
)(
    // Clock and Reset
    input  logic                        clock,
    input  logic                        reset,
    
    // Configuration Interface
    input  logic                        watchdog_enable,
    input  logic [COUNTER_WIDTH-1:0]    timeout_value,
    input  logic                        lock_config,         // Lock configuration
    input  logic [31:0]                 unlock_key,          // Key to unlock config
    
    // Control Interface
    input  logic                        kick_watchdog,       // Restart watchdog timer
    input  logic                        force_reset_req,     // Force immediate reset
    
    // Status and Outputs
    output logic                        watchdog_timeout,    // Timeout event flag
    output logic                        watchdog_reset,      // Reset output
    output logic                        watchdog_warning,    // Warning (75% of timeout)
    output logic [COUNTER_WIDTH-1:0]    current_count,
    output logic [15:0]                 timeout_event_count,
    output logic                        config_locked
);

    // =========================================================================
    // Constants
    // =========================================================================
    localparam logic [31:0] UNLOCK_KEY_VALUE = 32'hDEAD_BEEF;
    
    // =========================================================================
    // Internal Registers
    // =========================================================================
    logic [COUNTER_WIDTH-1:0]   counter;
    logic [COUNTER_WIDTH-1:0]   timeout_threshold;
    logic [COUNTER_WIDTH-1:0]   warning_threshold;
    logic                       wdt_enabled;
    logic                       locked;
    logic                       timeout_flag;
    logic                       reset_output;
    logic [15:0]                event_counter;
    logic                       kick_watchdog_prev;
    logic                       kick_edge;
    
    // =========================================================================
    // Configuration Lock Management
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            locked <= 1'b0;
        end else begin
            if (lock_config && watchdog_enable) begin
                locked <= 1'b1;
            end else if (unlock_key == UNLOCK_KEY_VALUE) begin
                locked <= 1'b0;
            end
        end
    end
    
    assign config_locked = locked;
    
    // =========================================================================
    // Timeout Threshold Configuration
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            timeout_threshold <= DEFAULT_TIMEOUT;
            warning_threshold <= DEFAULT_TIMEOUT - (DEFAULT_TIMEOUT >> 2);  // 75% of timeout
        end else begin
            if (!locked) begin
                if (timeout_value != '0) begin
                    timeout_threshold <= timeout_value;
                    warning_threshold <= timeout_value - (timeout_value >> 2);  // 75%
                end else begin
                    timeout_threshold <= DEFAULT_TIMEOUT;
                    warning_threshold <= DEFAULT_TIMEOUT - (DEFAULT_TIMEOUT >> 2);
                end
            end
        end
    end
    
    // =========================================================================
    // Watchdog Enable Control
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            wdt_enabled <= 1'b0;
        end else begin
            if (!locked) begin
                wdt_enabled <= watchdog_enable;
            end
        end
    end
    
    // =========================================================================
    // Kick Edge Detection
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            kick_watchdog_prev <= 1'b0;
        end else begin
            kick_watchdog_prev <= kick_watchdog;
        end
    end
    
    assign kick_edge = kick_watchdog && !kick_watchdog_prev;
    
    // =========================================================================
    // Watchdog Counter
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            counter <= '0;
            timeout_flag <= 1'b0;
        end else begin
            timeout_flag <= 1'b0;
            
            if (!wdt_enabled) begin
                counter <= '0;
            end else if (kick_edge) begin
                counter <= '0;  // Restart counter on kick
            end else if (counter >= timeout_threshold) begin
                timeout_flag <= 1'b1;
                counter <= '0;  // Reset after timeout
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end
    
    assign current_count = counter;
    assign watchdog_timeout = timeout_flag;
    
    // =========================================================================
    // Warning Signal (75% threshold)
    // =========================================================================
    logic warning_flag;
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            warning_flag <= 1'b0;
        end else begin
            if (!wdt_enabled || kick_edge) begin
                warning_flag <= 1'b0;
            end else if (counter >= warning_threshold) begin
                warning_flag <= 1'b1;
            end
        end
    end
    
    assign watchdog_warning = warning_flag;
    
    // =========================================================================
    // Timeout Event Counter
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            event_counter <= '0;
        end else begin
            if (!wdt_enabled) begin
                event_counter <= '0;
            end else if (timeout_flag && (event_counter != 16'hFFFF)) begin
                event_counter <= event_counter + 1'b1;
            end
        end
    end
    
    assign timeout_event_count = event_counter;
    
    // =========================================================================
    // Reset Generation
    // =========================================================================
    // Generate a reset pulse on timeout or force reset
    logic [3:0] reset_pulse_counter;
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            reset_output <= 1'b0;
            reset_pulse_counter <= '0;
        end else begin
            if (timeout_flag || force_reset_req) begin
                reset_output <= 1'b1;
                reset_pulse_counter <= 4'd10;  // 10 cycle reset pulse
            end else if (reset_pulse_counter != '0) begin
                reset_pulse_counter <= reset_pulse_counter - 1'b1;
                reset_output <= 1'b1;
            end else begin
                reset_output <= 1'b0;
            end
        end
    end
    
    assign watchdog_reset = reset_output;

endmodule
