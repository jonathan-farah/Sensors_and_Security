// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Top Level Integration
// =============================================================================
// Description: Top-level module integrating all subsystems
// Author: Cognichip Co-Designer
// =============================================================================

module proximity_sensor_soc #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6
)(
    // Clock and Reset
    input  logic                    clock,
    input  logic                    reset,
    
    // ADC Interface (from analog front end)
    input  logic                    adc_data_valid,
    input  logic [DATA_WIDTH-1:0]   adc_data_in,
    input  logic                    adc_ready,
    output logic                    adc_sample_request,
    
    // Register Interface (Memory-mapped bus)
    input  logic                    reg_write,
    input  logic                    reg_read,
    input  logic [ADDR_WIDTH-1:0]   reg_addr,
    input  logic [DATA_WIDTH-1:0]   reg_wdata,
    output logic [DATA_WIDTH-1:0]   reg_rdata,
    output logic                    reg_ready,
    output logic                    reg_error,
    
    // SPI Communication Interface
    input  logic                    spi_cs_n,
    input  logic                    spi_sclk,
    input  logic                    spi_mosi,
    output logic                    spi_miso,
    
    // Interrupt Output
    output logic                    irq_n,
    
    // Security/Authentication Interface
    input  logic                    auth_attempt,
    input  logic [31:0]             auth_key_in,
    output logic                    authenticated,
    output logic                    lockout_active,
    
    // Status Outputs (for monitoring)
    output logic                    detection_active,
    output logic [1:0]              power_state_out,
    output logic [15:0]             security_violations
);

    // =========================================================================
    // Internal Interconnect Signals
    // =========================================================================
    
    // Register File Outputs
    logic                    system_enable;
    logic                    filter_enable;
    logic [1:0]              power_mode;
    logic [3:0]              filter_taps;
    logic [DATA_WIDTH-1:0]   threshold_low;
    logic [DATA_WIDTH-1:0]   threshold_high;
    logic [7:0]              hysteresis;
    logic [15:0]             sample_rate_div;
    logic                    interrupt_en_detect;
    logic                    interrupt_en_error;
    logic                    security_lock;
    
    // Filter Signals
    logic                    filter_data_valid;
    logic                    filter_data_ready;
    logic                    filter_result_valid;
    logic [DATA_WIDTH-1:0]   filter_result;
    logic                    filter_busy;
    
    // Threshold Comparator Signals
    logic                    detection_flag;
    logic                    above_high;
    logic                    below_low;
    logic                    in_range;
    
    // Power Management Signals
    logic [1:0]              current_power_state;
    logic                    clock_gate_enable;
    logic                    adc_power_enable;
    logic                    filter_power_enable;
    logic                    wakeup_interrupt;
    
    // Security Module Signals
    logic                    security_violation;
    logic [15:0]             violation_count;
    
    // Communication Interface Signals
    logic                    clear_interrupt;
    
    // Gated Clock
    logic                    gated_clock;
    
    // =========================================================================
    // Clock Gating for Power Management
    // =========================================================================
    assign gated_clock = clock & clock_gate_enable;
    
    // =========================================================================
    // Configuration Register File
    // =========================================================================
    proximity_sensor_regfile #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_regfile (
        .clock                  (clock),
        .reset                  (reset),
        
        // Register Interface
        .reg_write              (reg_write),
        .reg_read               (reg_read),
        .reg_addr               (reg_addr),
        .reg_wdata              (reg_wdata),
        .reg_rdata              (reg_rdata),
        .reg_ready              (reg_ready),
        .reg_error              (reg_error),
        
        // Control Outputs
        .system_enable          (system_enable),
        .filter_enable          (filter_enable),
        .power_mode             (power_mode),
        .filter_taps            (filter_taps),
        .threshold_low          (threshold_low),
        .threshold_high         (threshold_high),
        .hysteresis             (hysteresis),
        .sample_rate_div        (sample_rate_div),
        .interrupt_en_detect    (interrupt_en_detect),
        .interrupt_en_error     (interrupt_en_error),
        .security_lock          (security_lock),
        
        // Status Inputs
        .detection_flag         (detection_flag),
        .current_power_state    (current_power_state),
        .filter_busy            (filter_busy),
        .adc_ready              (adc_ready),
        .adc_data               (adc_data_in),
        .filtered_data          (filter_result),
        .security_violation     (security_violation),
        
        // Interrupt Clear
        .clear_interrupt        (clear_interrupt)
    );
    
    // =========================================================================
    // Moving Average Filter
    // =========================================================================
    moving_average_filter #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_TAPS(15)
    ) u_filter (
        .clock                  (gated_clock),
        .reset                  (reset),
        
        // Control
        .enable                 (filter_enable && filter_power_enable),
        .num_taps               (filter_taps),
        
        // Data Interface
        .data_valid             (adc_data_valid && system_enable),
        .data_in                (adc_data_in),
        .data_ready             (filter_data_ready),
        .result_valid           (filter_result_valid),
        .result_out             (filter_result),
        .busy                   (filter_busy)
    );
    
    // =========================================================================
    // Threshold Comparator
    // =========================================================================
    threshold_comparator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_comparator (
        .clock                  (gated_clock),
        .reset                  (reset),
        
        // Configuration
        .threshold_low          (threshold_low),
        .threshold_high         (threshold_high),
        .hysteresis             (hysteresis),
        .enable                 (system_enable),
        
        // Data Input
        .data_valid             (filter_result_valid),
        .data_in                (filter_result),
        
        // Detection Output
        .detection_flag         (detection_flag),
        .above_high             (above_high),
        .below_low              (below_low),
        .in_range               (in_range)
    );
    
    // =========================================================================
    // Power Management FSM
    // =========================================================================
    power_management_fsm u_power_mgmt (
        .clock                  (clock),
        .reset                  (reset),
        
        // Configuration
        .system_enable          (system_enable),
        .requested_power_mode   (power_mode),
        
        // System Status
        .detection_active       (detection_flag),
        .filter_busy            (filter_busy),
        .adc_busy               (!adc_ready),
        .idle_counter_max       (sample_rate_div),
        
        // Power State Outputs
        .current_power_state    (current_power_state),
        .clock_gate_enable      (clock_gate_enable),
        .adc_power_enable       (adc_power_enable),
        .filter_power_enable    (filter_power_enable),
        .wakeup_interrupt       (wakeup_interrupt)
    );
    
    // =========================================================================
    // Communication Interface
    // =========================================================================
    communication_interface u_comm (
        .clock                  (clock),
        .reset                  (reset),
        
        // Configuration
        .interrupt_en_detect    (interrupt_en_detect),
        .interrupt_en_error     (interrupt_en_error),
        
        // Status Inputs
        .detection_flag         (detection_flag),
        .security_violation     (security_violation),
        .wakeup_event           (wakeup_interrupt),
        .power_state            (current_power_state),
        
        // Serial Interface
        .spi_cs_n               (spi_cs_n),
        .spi_sclk               (spi_sclk),
        .spi_mosi               (spi_mosi),
        .spi_miso               (spi_miso),
        
        // Interrupt Output
        .irq_n                  (irq_n),
        
        // Internal Clear Signal
        .clear_interrupt        (clear_interrupt)
    );
    
    // =========================================================================
    // Security Module
    // =========================================================================
    security_module #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_security (
        .clock                  (clock),
        .reset                  (reset),
        
        // Security Configuration
        .security_lock          (security_lock),
        .access_key             (32'hA5A5_5A5A),  // Default key (should be configurable)
        
        // Register Access Monitor
        .reg_write              (reg_write),
        .reg_read               (reg_read),
        .reg_addr               (reg_addr),
        .reg_wdata              (reg_wdata),
        
        // Authentication Interface
        .auth_attempt           (auth_attempt),
        .auth_key_in            (auth_key_in),
        
        // Security Status
        .security_violation     (security_violation),
        .authenticated          (authenticated),
        .violation_count        (violation_count),
        .lockout_active         (lockout_active)
    );
    
    // =========================================================================
    // ADC Sampling Control
    // =========================================================================
    logic [15:0] sample_counter;
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            sample_counter <= 16'h0000;
            adc_sample_request <= 1'b0;
        end else begin
            adc_sample_request <= 1'b0;
            
            if (system_enable && adc_power_enable) begin
                if (sample_counter >= sample_rate_div) begin
                    sample_counter <= 16'h0000;
                    adc_sample_request <= 1'b1;
                end else begin
                    sample_counter <= sample_counter + 16'h0001;
                end
            end else begin
                sample_counter <= 16'h0000;
            end
        end
    end
    
    // =========================================================================
    // Output Assignments
    // =========================================================================
    assign detection_active = detection_flag;
    assign power_state_out = current_power_state;
    assign security_violations = violation_count;

endmodule
