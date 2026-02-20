// =============================================================================
// Clock and Reset Manager
// =============================================================================
// Description: Manages clock gating and reset synchronization for the SoC
// Features:
//   - Glitch-free clock gating
//   - Synchronous reset generation
//   - Reset synchronizer chains
//   - Multiple clock gate outputs for different power domains
//   - Clock monitoring and status
// Author: Cognichip Co-Designer
// =============================================================================

module clock_reset_manager (
    // Primary Clock and Reset Inputs
    input  logic        clock_in,
    input  logic        reset_in,           // Asynchronous reset input
    
    // Clock Gate Control
    input  logic        system_enable,
    input  logic        filter_clock_enable,
    input  logic        adc_clock_enable,
    input  logic        comm_clock_enable,
    
    // Gated Clock Outputs
    output logic        system_clock,       // Main system clock (always on when enabled)
    output logic        filter_clock,       // Gated clock for filter
    output logic        adc_clock,          // Gated clock for ADC interface
    output logic        comm_clock,         // Gated clock for communication
    
    // Synchronized Reset Outputs
    output logic        reset_sync,         // Synchronized reset for entire system
    output logic        filter_reset,       // Reset for filter domain
    output logic        adc_reset,          // Reset for ADC domain
    output logic        comm_reset,         // Reset for comm domain
    
    // Status
    output logic        clocks_stable,
    output logic [3:0]  clock_gate_status
);

    // =========================================================================
    // Reset Synchronizer
    // =========================================================================
    // Three-stage synchronizer for asynchronous reset input
    logic reset_sync_stage1, reset_sync_stage2, reset_sync_stage3;
    
    always_ff @(posedge clock_in or posedge reset_in) begin
        if (reset_in) begin
            reset_sync_stage1 <= 1'b1;
            reset_sync_stage2 <= 1'b1;
            reset_sync_stage3 <= 1'b1;
        end else begin
            reset_sync_stage1 <= 1'b0;
            reset_sync_stage2 <= reset_sync_stage1;
            reset_sync_stage3 <= reset_sync_stage2;
        end
    end
    
    assign reset_sync = reset_sync_stage3;
    
    // =========================================================================
    // Glitch-Free Clock Gating for System Clock
    // =========================================================================
    logic system_enable_latched;
    
    // Latch enable signal on negative edge to avoid glitches
    always_latch begin
        if (!clock_in) begin
            system_enable_latched = system_enable;
        end
    end
    
    assign system_clock = clock_in & system_enable_latched;
    
    // =========================================================================
    // Glitch-Free Clock Gating for Filter Clock
    // =========================================================================
    logic filter_enable_latched;
    logic filter_enable_sync;
    
    // Synchronize enable signal
    always_ff @(posedge clock_in or posedge reset_sync) begin
        if (reset_sync) begin
            filter_enable_sync <= 1'b0;
        end else begin
            filter_enable_sync <= filter_clock_enable & system_enable;
        end
    end
    
    // Latch on negative edge
    always_latch begin
        if (!clock_in) begin
            filter_enable_latched = filter_enable_sync;
        end
    end
    
    assign filter_clock = clock_in & filter_enable_latched;
    
    // =========================================================================
    // Glitch-Free Clock Gating for ADC Clock
    // =========================================================================
    logic adc_enable_latched;
    logic adc_enable_sync;
    
    // Synchronize enable signal
    always_ff @(posedge clock_in or posedge reset_sync) begin
        if (reset_sync) begin
            adc_enable_sync <= 1'b0;
        end else begin
            adc_enable_sync <= adc_clock_enable & system_enable;
        end
    end
    
    // Latch on negative edge
    always_latch begin
        if (!clock_in) begin
            adc_enable_latched = adc_enable_sync;
        end
    end
    
    assign adc_clock = clock_in & adc_enable_latched;
    
    // =========================================================================
    // Glitch-Free Clock Gating for Communication Clock
    // =========================================================================
    logic comm_enable_latched;
    logic comm_enable_sync;
    
    // Synchronize enable signal
    always_ff @(posedge clock_in or posedge reset_sync) begin
        if (reset_sync) begin
            comm_enable_sync <= 1'b0;
        end else begin
            comm_enable_sync <= comm_clock_enable | system_enable;  // Comm often needs to stay active
        end
    end
    
    // Latch on negative edge
    always_latch begin
        if (!clock_in) begin
            comm_enable_latched = comm_enable_sync;
        end
    end
    
    assign comm_clock = clock_in & comm_enable_latched;
    
    // =========================================================================
    // Domain-Specific Reset Generation
    // =========================================================================
    // Generate synchronized resets for each clock domain
    
    // Filter domain reset
    logic filter_reset_stage1, filter_reset_stage2;
    always_ff @(posedge filter_clock or posedge reset_sync) begin
        if (reset_sync) begin
            filter_reset_stage1 <= 1'b1;
            filter_reset_stage2 <= 1'b1;
        end else begin
            filter_reset_stage1 <= 1'b0;
            filter_reset_stage2 <= filter_reset_stage1;
        end
    end
    assign filter_reset = filter_reset_stage2;
    
    // ADC domain reset
    logic adc_reset_stage1, adc_reset_stage2;
    always_ff @(posedge adc_clock or posedge reset_sync) begin
        if (reset_sync) begin
            adc_reset_stage1 <= 1'b1;
            adc_reset_stage2 <= 1'b1;
        end else begin
            adc_reset_stage1 <= 1'b0;
            adc_reset_stage2 <= adc_reset_stage1;
        end
    end
    assign adc_reset = adc_reset_stage2;
    
    // Communication domain reset
    logic comm_reset_stage1, comm_reset_stage2;
    always_ff @(posedge comm_clock or posedge reset_sync) begin
        if (reset_sync) begin
            comm_reset_stage1 <= 1'b1;
            comm_reset_stage2 <= 1'b1;
        end else begin
            comm_reset_stage1 <= 1'b0;
            comm_reset_stage2 <= comm_reset_stage1;
        end
    end
    assign comm_reset = comm_reset_stage2;
    
    // =========================================================================
    // Clock Stability Monitor
    // =========================================================================
    logic [7:0] stability_counter;
    
    always_ff @(posedge clock_in or posedge reset_sync) begin
        if (reset_sync) begin
            stability_counter <= '0;
            clocks_stable <= 1'b0;
        end else begin
            if (stability_counter < 8'd50) begin
                stability_counter <= stability_counter + 1'b1;
                clocks_stable <= 1'b0;
            end else begin
                clocks_stable <= 1'b1;
            end
        end
    end
    
    // =========================================================================
    // Clock Gate Status
    // =========================================================================
    assign clock_gate_status = {system_enable_latched,
                                filter_enable_latched,
                                adc_enable_latched,
                                comm_enable_latched};

endmodule
