// =============================================================================
// Calibration Engine
// =============================================================================
// Description: Applies offset and gain calibration to sensor data
// Features:
//   - Programmable offset correction (signed addition)
//   - Programmable gain correction (multiplication)
//   - Two-point calibration support
//   - Calibration bypass mode
//   - Saturation detection and clamping
// Author: Cognichip Co-Designer
// =============================================================================

module calibration_engine #(
    parameter DATA_WIDTH = 32,
    parameter GAIN_FRAC_BITS = 16    // Fractional bits for gain (fixed-point)
)(
    // Clock and Reset
    input  logic                        clock,
    input  logic                        reset,
    
    // Configuration
    input  logic                        calibration_enable,
    input  logic signed [DATA_WIDTH-1:0]     offset_correction,     // Signed offset
    input  logic [DATA_WIDTH-1:0]       gain_correction,       // Unsigned gain (fixed-point)
    input  logic                        bypass_mode,
    
    // Data Input
    input  logic                        data_valid_in,
    input  logic [DATA_WIDTH-1:0]       data_in,
    input  logic                        data_ready_out,
    
    // Data Output
    output logic                        data_valid_out,
    output logic [DATA_WIDTH-1:0]       data_out,
    output logic                        data_ready_in,
    
    // Status
    output logic                        calibration_active,
    output logic                        saturation_detected,
    output logic [15:0]                 saturation_count
);

    // =========================================================================
    // Pipeline Stages
    // =========================================================================
    typedef enum logic [1:0] {
        STAGE_IDLE      = 2'b00,
        STAGE_OFFSET    = 2'b01,
        STAGE_GAIN      = 2'b10,
        STAGE_OUTPUT    = 2'b11
    } cal_stage_t;
    
    cal_stage_t current_stage;
    
    // =========================================================================
    // Internal Registers
    // =========================================================================
    logic [DATA_WIDTH-1:0]       input_data_reg;
    logic signed [DATA_WIDTH:0]  offset_corrected;    // Extra bit for overflow
    logic signed [DATA_WIDTH:0]  offset_clamped;
    logic [2*DATA_WIDTH-1:0]     gain_product;        // Double width for multiplication
    logic [DATA_WIDTH-1:0]       gain_corrected;
    logic [DATA_WIDTH-1:0]       final_output;
    logic                        valid_stage1, valid_stage2, valid_stage3;
    logic                        saturation_flag;
    logic [15:0]                 sat_counter;
    
    // =========================================================================
    // Backpressure/Ready Logic
    // =========================================================================
    assign data_ready_in = (current_stage == STAGE_IDLE) || bypass_mode;
    assign calibration_active = calibration_enable && !bypass_mode;
    
    // =========================================================================
    // Pipeline Control
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            current_stage <= STAGE_IDLE;
            valid_stage1 <= 1'b0;
            valid_stage2 <= 1'b0;
            valid_stage3 <= 1'b0;
        end else begin
            if (bypass_mode) begin
                current_stage <= STAGE_IDLE;
                valid_stage1 <= 1'b0;
                valid_stage2 <= 1'b0;
                valid_stage3 <= 1'b0;
            end else begin
                case (current_stage)
                    STAGE_IDLE: begin
                        if (data_valid_in && calibration_enable) begin
                            current_stage <= STAGE_OFFSET;
                            valid_stage1 <= 1'b1;
                        end else begin
                            valid_stage1 <= 1'b0;
                        end
                        valid_stage2 <= 1'b0;
                        valid_stage3 <= 1'b0;
                    end
                    
                    STAGE_OFFSET: begin
                        current_stage <= STAGE_GAIN;
                        valid_stage2 <= valid_stage1;
                        valid_stage1 <= 1'b0;
                    end
                    
                    STAGE_GAIN: begin
                        current_stage <= STAGE_OUTPUT;
                        valid_stage3 <= valid_stage2;
                        valid_stage2 <= 1'b0;
                    end
                    
                    STAGE_OUTPUT: begin
                        if (data_ready_out) begin
                            current_stage <= STAGE_IDLE;
                        end
                        valid_stage3 <= 1'b0;
                    end
                    
                    default: begin
                        current_stage <= STAGE_IDLE;
                        valid_stage1 <= 1'b0;
                        valid_stage2 <= 1'b0;
                        valid_stage3 <= 1'b0;
                    end
                endcase
            end
        end
    end
    
    // =========================================================================
    // Stage 1: Input Registration
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            input_data_reg <= '0;
        end else begin
            if (data_valid_in && (current_stage == STAGE_IDLE)) begin
                input_data_reg <= data_in;
            end
        end
    end
    
    // =========================================================================
    // Stage 2: Offset Correction
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            offset_corrected <= '0;
            offset_clamped <= '0;
        end else begin
            if (current_stage == STAGE_OFFSET) begin
                // Sign-extended addition
                offset_corrected <= $signed({1'b0, input_data_reg}) + $signed(offset_correction);
                
                // Clamping logic
                if (offset_corrected > $signed({1'b0, {DATA_WIDTH{1'b1}}})) begin
                    offset_clamped <= $signed({1'b0, {DATA_WIDTH{1'b1}}});  // Max positive
                end else if (offset_corrected < $signed({(DATA_WIDTH+1){1'b0}})) begin
                    offset_clamped <= $signed({(DATA_WIDTH+1){1'b0}});      // Zero (no negative)
                end else begin
                    offset_clamped <= offset_corrected;
                end
            end
        end
    end
    
    // =========================================================================
    // Stage 3: Gain Correction (Fixed-Point Multiplication)
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            gain_product <= '0;
            gain_corrected <= '0;
        end else begin
            if (current_stage == STAGE_GAIN) begin
                // Multiply by gain (unsigned)
                gain_product <= offset_clamped[DATA_WIDTH-1:0] * gain_correction;
                
                // Scale back by removing fractional bits
                // Check for overflow in upper bits
                if (gain_product[2*DATA_WIDTH-1:DATA_WIDTH+GAIN_FRAC_BITS] != '0) begin
                    gain_corrected <= {DATA_WIDTH{1'b1}};  // Saturate to max
                end else begin
                    gain_corrected <= gain_product[DATA_WIDTH+GAIN_FRAC_BITS-1:GAIN_FRAC_BITS];
                end
            end
        end
    end
    
    // =========================================================================
    // Stage 4: Output and Saturation Detection
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            final_output <= '0;
            saturation_flag <= 1'b0;
        end else begin
            saturation_flag <= 1'b0;
            
            if (current_stage == STAGE_OUTPUT) begin
                final_output <= gain_corrected;
                
                // Detect saturation
                if ((offset_corrected > $signed({1'b0, {DATA_WIDTH{1'b1}}})) ||
                    (offset_corrected < $signed({(DATA_WIDTH+1){1'b0}})) ||
                    (gain_product[2*DATA_WIDTH-1:DATA_WIDTH+GAIN_FRAC_BITS] != '0)) begin
                    saturation_flag <= 1'b1;
                end
            end
        end
    end
    
    // =========================================================================
    // Saturation Counter
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            sat_counter <= '0;
        end else begin
            if (!calibration_enable) begin
                sat_counter <= '0;
            end else if (saturation_flag && (sat_counter != 16'hFFFF)) begin
                sat_counter <= sat_counter + 1'b1;
            end
        end
    end
    
    assign saturation_count = sat_counter;
    assign saturation_detected = saturation_flag;
    
    // =========================================================================
    // Output Mux: Bypass or Calibrated
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_out <= '0;
            data_valid_out <= 1'b0;
        end else begin
            if (bypass_mode) begin
                data_out <= data_in;
                data_valid_out <= data_valid_in;
            end else begin
                if (current_stage == STAGE_OUTPUT) begin
                    data_out <= final_output;
                    data_valid_out <= valid_stage3;
                end else begin
                    data_valid_out <= 1'b0;
                end
            end
        end
    end

endmodule
