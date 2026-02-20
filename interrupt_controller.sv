// =============================================================================
// Interrupt Controller
// =============================================================================
// Description: Centralized interrupt management and prioritization
// Features:
//   - Multiple interrupt source inputs
//   - Individual interrupt enable/disable
//   - Priority-based interrupt handling
//   - Interrupt status register
//   - Edge and level-sensitive modes
//   - Interrupt masking
// Author: Cognichip Co-Designer
// =============================================================================

module interrupt_controller #(
    parameter NUM_INTERRUPTS = 8
)(
    // Clock and Reset
    input  logic                        clock,
    input  logic                        reset,
    
    // Configuration Interface
    input  logic [NUM_INTERRUPTS-1:0]   interrupt_enable,      // Enable each interrupt
    input  logic [NUM_INTERRUPTS-1:0]   interrupt_mask,        // Mask each interrupt
    input  logic [NUM_INTERRUPTS-1:0]   edge_mode,             // 1=edge, 0=level
    input  logic [2:0]                  priority_mode,         // Priority scheme selection
    
    // Interrupt Source Inputs
    input  logic [NUM_INTERRUPTS-1:0]   interrupt_sources,
    
    // Interrupt Clear Interface
    input  logic                        clear_all_interrupts,
    input  logic [NUM_INTERRUPTS-1:0]   clear_interrupt_select,
    
    // Interrupt Output
    output logic                        interrupt_request,     // Combined interrupt output
    output logic [NUM_INTERRUPTS-1:0]   interrupt_pending,     // Pending interrupt status
    output logic [2:0]                  highest_priority_int,  // ID of highest priority pending
    output logic                        interrupt_active
);

    // =========================================================================
    // Internal Registers
    // =========================================================================
    logic [NUM_INTERRUPTS-1:0]  interrupt_sources_prev;
    logic [NUM_INTERRUPTS-1:0]  interrupt_edge_detected;
    logic [NUM_INTERRUPTS-1:0]  interrupt_level_active;
    logic [NUM_INTERRUPTS-1:0]  interrupt_status;
    logic [NUM_INTERRUPTS-1:0]  interrupt_qualified;
    logic                       any_interrupt_pending;
    
    // =========================================================================
    // Edge Detection for Edge-Sensitive Interrupts
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            interrupt_sources_prev <= '0;
        end else begin
            interrupt_sources_prev <= interrupt_sources;
        end
    end
    
    // Detect rising edge
    always_comb begin
        for (int i = 0; i < NUM_INTERRUPTS; i++) begin
            interrupt_edge_detected[i] = interrupt_sources[i] && !interrupt_sources_prev[i];
            interrupt_level_active[i] = interrupt_sources[i];
        end
    end
    
    // =========================================================================
    // Interrupt Status Register
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            interrupt_status <= '0;
        end else begin
            for (int i = 0; i < NUM_INTERRUPTS; i++) begin
                // Clear interrupt
                if (clear_all_interrupts || clear_interrupt_select[i]) begin
                    interrupt_status[i] <= 1'b0;
                end 
                // Set interrupt based on mode
                else if (interrupt_enable[i] && !interrupt_mask[i]) begin
                    if (edge_mode[i]) begin
                        // Edge-triggered: latch on edge
                        if (interrupt_edge_detected[i]) begin
                            interrupt_status[i] <= 1'b1;
                        end
                    end else begin
                        // Level-triggered: follow input
                        interrupt_status[i] <= interrupt_level_active[i];
                    end
                end
            end
        end
    end
    
    // =========================================================================
    // Interrupt Qualification (Enable + Mask)
    // =========================================================================
    always_comb begin
        for (int i = 0; i < NUM_INTERRUPTS; i++) begin
            interrupt_qualified[i] = interrupt_status[i] && 
                                    interrupt_enable[i] && 
                                    !interrupt_mask[i];
        end
    end
    
    assign interrupt_pending = interrupt_qualified;
    
    // =========================================================================
    // Priority Encoder
    // =========================================================================
    logic [2:0] highest_priority;
    logic       priority_valid;
    
    always_comb begin
        highest_priority = 3'd0;
        priority_valid = 1'b0;
        
        case (priority_mode)
            3'd0: begin // Fixed priority (lowest index = highest priority)
                for (int i = NUM_INTERRUPTS-1; i >= 0; i--) begin
                    if (interrupt_qualified[i]) begin
                        highest_priority = i[2:0];
                        priority_valid = 1'b1;
                    end
                end
            end
            
            3'd1: begin // Reverse fixed priority (highest index = highest priority)
                for (int i = 0; i < NUM_INTERRUPTS; i++) begin
                    if (interrupt_qualified[i]) begin
                        highest_priority = i[2:0];
                        priority_valid = 1'b1;
                    end
                end
            end
            
            3'd2: begin // Round-robin (simplified - just use fixed for now)
                for (int i = NUM_INTERRUPTS-1; i >= 0; i--) begin
                    if (interrupt_qualified[i]) begin
                        highest_priority = i[2:0];
                        priority_valid = 1'b1;
                    end
                end
            end
            
            default: begin // Default to fixed priority
                for (int i = NUM_INTERRUPTS-1; i >= 0; i--) begin
                    if (interrupt_qualified[i]) begin
                        highest_priority = i[2:0];
                        priority_valid = 1'b1;
                    end
                end
            end
        endcase
    end
    
    assign highest_priority_int = highest_priority;
    
    // =========================================================================
    // Combined Interrupt Output
    // =========================================================================
    assign any_interrupt_pending = |interrupt_qualified;
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            interrupt_request <= 1'b0;
            interrupt_active <= 1'b0;
        end else begin
            interrupt_request <= any_interrupt_pending;
            interrupt_active <= any_interrupt_pending && priority_valid;
        end
    end

endmodule
