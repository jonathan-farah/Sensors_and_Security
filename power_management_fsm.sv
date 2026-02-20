// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Power Management FSM
// =============================================================================
// Description: Multi-state power controller for energy-efficient operation
// Author: Cognichip Co-Designer
// =============================================================================

module power_management_fsm (
    // Clock and Reset
    input  logic        clock,
    input  logic        reset,
    
    // Configuration
    input  logic        system_enable,
    input  logic [1:0]  requested_power_mode,  // From register file
    
    // System Status
    input  logic        detection_active,      // Detection in progress
    input  logic        filter_busy,           // Filter processing
    input  logic        adc_busy,              // ADC conversion active
    input  logic [15:0] idle_counter_max,      // Configurable idle timeout
    
    // Power State Outputs
    output logic [1:0]  current_power_state,   // Current state
    output logic        clock_gate_enable,     // Clock gating control
    output logic        adc_power_enable,      // ADC power control
    output logic        filter_power_enable,   // Filter power control
    output logic        wakeup_interrupt       // Wakeup event
);

    // =========================================================================
    // Power State Definitions
    // =========================================================================
    typedef enum logic [1:0] {
        SLEEP       = 2'b00,    // Lowest power - only wake logic active
        IDLE        = 2'b01,    // Low power - periodic sampling
        ACTIVE      = 2'b10,    // Normal operation - continuous sampling
        HIGH_PERF   = 2'b11     // Maximum performance - fastest sampling
    } power_state_t;
    
    power_state_t current_state, next_state;
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic [15:0] idle_timer;
    logic idle_timeout;
    logic activity_detected;
    logic can_sleep;
    
    // =========================================================================
    // Activity Detection
    // =========================================================================
    assign activity_detected = detection_active || filter_busy || adc_busy;
    assign can_sleep = !activity_detected && !system_enable;
    
    // =========================================================================
    // Idle Timer
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            idle_timer <= 16'h0000;
        end else begin
            if (activity_detected) begin
                idle_timer <= 16'h0000;  // Reset on activity
            end else if (current_state == ACTIVE || current_state == HIGH_PERF) begin
                if (idle_timer < idle_counter_max) begin
                    idle_timer <= idle_timer + 16'h0001;
                end
            end else begin
                idle_timer <= 16'h0000;
            end
        end
    end
    
    assign idle_timeout = (idle_timer >= idle_counter_max);
    
    // =========================================================================
    // State Machine - State Register
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            current_state <= SLEEP;
        end else begin
            current_state <= next_state;
        end
    end
    
    // =========================================================================
    // State Machine - Next State Logic
    // =========================================================================
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            SLEEP: begin
                if (system_enable) begin
                    // Wake up based on requested mode
                    case (requested_power_mode)
                        2'b00: next_state = SLEEP;      // Stay in sleep
                        2'b01: next_state = IDLE;
                        2'b10: next_state = ACTIVE;
                        2'b11: next_state = HIGH_PERF;
                        default: next_state = IDLE;
                    endcase
                end
            end
            
            IDLE: begin
                if (!system_enable || can_sleep) begin
                    next_state = SLEEP;
                end else if (detection_active) begin
                    // Automatically escalate to active on detection
                    next_state = ACTIVE;
                end else if (requested_power_mode == 2'b10) begin
                    next_state = ACTIVE;
                end else if (requested_power_mode == 2'b11) begin
                    next_state = HIGH_PERF;
                end
            end
            
            ACTIVE: begin
                if (!system_enable || can_sleep) begin
                    next_state = SLEEP;
                end else if (idle_timeout && !detection_active) begin
                    // Drop to idle after timeout
                    next_state = IDLE;
                end else if (requested_power_mode == 2'b01) begin
                    next_state = IDLE;
                end else if (requested_power_mode == 2'b11) begin
                    next_state = HIGH_PERF;
                end else if (requested_power_mode == 2'b00) begin
                    next_state = SLEEP;
                end
            end
            
            HIGH_PERF: begin
                if (!system_enable || can_sleep) begin
                    next_state = SLEEP;
                end else if (requested_power_mode == 2'b00) begin
                    next_state = SLEEP;
                end else if (requested_power_mode == 2'b01) begin
                    next_state = IDLE;
                end else if (requested_power_mode == 2'b10) begin
                    next_state = ACTIVE;
                end
            end
            
            default: next_state = SLEEP;
        endcase
    end
    
    // =========================================================================
    // Output Logic - Power Control Signals
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            clock_gate_enable <= 1'b0;
            adc_power_enable <= 1'b0;
            filter_power_enable <= 1'b0;
            wakeup_interrupt <= 1'b0;
        end else begin
            // Default: no wakeup interrupt
            wakeup_interrupt <= 1'b0;
            
            case (current_state)
                SLEEP: begin
                    clock_gate_enable <= 1'b0;      // Gate clocks
                    adc_power_enable <= 1'b0;       // Power down ADC
                    filter_power_enable <= 1'b0;    // Power down filter
                    
                    // Generate wakeup interrupt on state transition
                    if (next_state != SLEEP) begin
                        wakeup_interrupt <= 1'b1;
                    end
                end
                
                IDLE: begin
                    clock_gate_enable <= 1'b1;      // Enable clocks (gated periodically)
                    adc_power_enable <= 1'b1;       // ADC on for periodic sampling
                    filter_power_enable <= 1'b0;    // Filter can be off in idle
                end
                
                ACTIVE: begin
                    clock_gate_enable <= 1'b1;      // Full clock enabled
                    adc_power_enable <= 1'b1;       // ADC fully powered
                    filter_power_enable <= 1'b1;    // Filter enabled
                end
                
                HIGH_PERF: begin
                    clock_gate_enable <= 1'b1;      // Full clock enabled
                    adc_power_enable <= 1'b1;       // ADC fully powered
                    filter_power_enable <= 1'b1;    // Filter enabled
                end
                
                default: begin
                    clock_gate_enable <= 1'b0;
                    adc_power_enable <= 1'b0;
                    filter_power_enable <= 1'b0;
                end
            endcase
        end
    end
    
    // =========================================================================
    // Current State Output
    // =========================================================================
    assign current_power_state = current_state;

endmodule
