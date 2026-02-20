// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Threshold Comparator
// =============================================================================
// Description: Programmable threshold detector with hysteresis
// Author: Cognichip Co-Designer
// =============================================================================

module threshold_comparator #(
    parameter DATA_WIDTH = 32
)(
    // Clock and Reset
    input  logic                    clock,
    input  logic                    reset,
    
    // Configuration
    input  logic [DATA_WIDTH-1:0]   threshold_low,      // Lower threshold
    input  logic [DATA_WIDTH-1:0]   threshold_high,     // Upper threshold
    input  logic [7:0]              hysteresis,         // Hysteresis amount
    input  logic                    enable,
    
    // Data Input
    input  logic                    data_valid,
    input  logic [DATA_WIDTH-1:0]   data_in,
    
    // Detection Output
    output logic                    detection_flag,     // Object detected
    output logic                    above_high,         // Above high threshold
    output logic                    below_low,          // Below low threshold
    output logic                    in_range            // Within threshold range
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic detection_state;          // Current detection state
    logic [DATA_WIDTH-1:0] threshold_high_with_hyst;
    logic [DATA_WIDTH-1:0] threshold_low_with_hyst;
    
    // =========================================================================
    // Hysteresis Calculation
    // =========================================================================
    always_comb begin
        // When detection is active, apply hysteresis to prevent oscillation
        if (detection_state) begin
            // Need to go below (threshold_low - hysteresis) to deactivate
            threshold_low_with_hyst = (threshold_low > hysteresis) ? 
                                      (threshold_low - hysteresis) : 
                                      32'h0000_0000;
            threshold_high_with_hyst = threshold_high;
        end else begin
            // Need to go above (threshold_high + hysteresis) to activate
            threshold_high_with_hyst = (threshold_high + hysteresis < {DATA_WIDTH{1'b1}}) ?
                                       (threshold_high + hysteresis) :
                                       {DATA_WIDTH{1'b1}};
            threshold_low_with_hyst = threshold_low;
        end
    end
    
    // =========================================================================
    // Detection Logic with Hysteresis
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            detection_state <= 1'b0;
        end else if (enable && data_valid) begin
            if (!detection_state) begin
                // Not detecting - check if we exceed high threshold
                if (data_in >= threshold_high_with_hyst) begin
                    detection_state <= 1'b1;
                end
            end else begin
                // Currently detecting - check if we drop below low threshold
                if (data_in < threshold_low_with_hyst) begin
                    detection_state <= 1'b0;
                end
            end
        end
    end
    
    // =========================================================================
    // Comparison Outputs
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            above_high <= 1'b0;
            below_low <= 1'b0;
            in_range <= 1'b0;
        end else if (enable && data_valid) begin
            above_high <= (data_in >= threshold_high);
            below_low <= (data_in < threshold_low);
            in_range <= (data_in >= threshold_low) && (data_in < threshold_high);
        end
    end
    
    // =========================================================================
    // Output Assignment
    // =========================================================================
    assign detection_flag = detection_state && enable;

endmodule
