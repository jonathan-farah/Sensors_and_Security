// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Security Module
// =============================================================================
// Description: Access control and integrity checking for secure operation
// Author: Cognichip Co-Designer
// =============================================================================

module security_module #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6
)(
    // Clock and Reset
    input  logic                    clock,
    input  logic                    reset,
    
    // Security Configuration
    input  logic                    security_lock,      // Master lock enable
    input  logic [31:0]             access_key,         // Authentication key (from secure storage)
    
    // Register Access Monitor
    input  logic                    reg_write,
    input  logic                    reg_read,
    input  logic [ADDR_WIDTH-1:0]   reg_addr,
    input  logic [DATA_WIDTH-1:0]   reg_wdata,
    
    // Authentication Interface
    input  logic                    auth_attempt,       // Authentication request
    input  logic [31:0]             auth_key_in,        // Provided key
    
    // Security Status
    output logic                    security_violation,
    output logic                    authenticated,
    output logic [15:0]             violation_count,
    output logic                    lockout_active
);

    // =========================================================================
    // Security Configuration
    // =========================================================================
    localparam MAX_AUTH_ATTEMPTS = 5;
    localparam LOCKOUT_DURATION = 16'hFFFF;  // Lockout timeout
    
    // Protected register addresses
    localparam ADDR_SECURITY_CFG = 6'h20;
    localparam ADDR_CONTROL_REG  = 6'h00;
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic auth_valid;
    logic [3:0] failed_attempts;
    logic lockout;
    logic [15:0] lockout_timer;
    logic [15:0] violation_counter;
    logic [31:0] stored_key;
    logic key_initialized;
    
    // CRC/Checksum for data integrity
    logic [7:0] data_checksum;
    logic integrity_error;
    
    // =========================================================================
    // Key Storage and Authentication
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            stored_key <= 32'hDEADBEEF;  // Default key (should be programmed)
            key_initialized <= 1'b0;
            authenticated <= 1'b0;
            failed_attempts <= 4'h0;
        end else begin
            // One-time key programming (first write after reset)
            if (!key_initialized && auth_attempt) begin
                stored_key <= access_key;
                key_initialized <= 1'b1;
            end
            
            // Authentication attempt
            if (auth_attempt && !lockout) begin
                if (auth_key_in == stored_key) begin
                    authenticated <= 1'b1;
                    failed_attempts <= 4'h0;  // Reset on successful auth
                end else begin
                    authenticated <= 1'b0;
                    if (failed_attempts < MAX_AUTH_ATTEMPTS) begin
                        failed_attempts <= failed_attempts + 4'h1;
                    end
                end
            end
            
            // Clear authentication when lock is disabled
            if (!security_lock) begin
                authenticated <= 1'b0;
            end
        end
    end
    
    assign auth_valid = authenticated;
    
    // =========================================================================
    // Lockout Mechanism
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            lockout <= 1'b0;
            lockout_timer <= 16'h0000;
        end else begin
            if (failed_attempts >= MAX_AUTH_ATTEMPTS) begin
                lockout <= 1'b1;
                lockout_timer <= LOCKOUT_DURATION;
            end else if (lockout) begin
                // Count down lockout timer
                if (lockout_timer > 16'h0000) begin
                    lockout_timer <= lockout_timer - 16'h0001;
                end else begin
                    lockout <= 1'b0;
                    failed_attempts <= 4'h0;  // Reset attempts after lockout
                end
            end
        end
    end
    
    assign lockout_active = lockout;
    
    // =========================================================================
    // Access Control Monitor
    // =========================================================================
    logic write_violation;
    logic read_violation;
    
    always_comb begin
        write_violation = 1'b0;
        read_violation = 1'b0;
        
        // Check write access to protected registers
        if (reg_write && security_lock) begin
            case (reg_addr)
                ADDR_SECURITY_CFG: begin
                    // Security config register - requires authentication
                    if (!authenticated) begin
                        write_violation = 1'b1;
                    end
                end
                ADDR_CONTROL_REG: begin
                    // Control register - requires authentication when locked
                    if (!authenticated) begin
                        write_violation = 1'b1;
                    end
                end
                default: begin
                    // Other registers may be written without authentication
                    // when lock is active (application-specific)
                end
            endcase
        end
        
        // Monitor for suspicious read patterns (optional enhancement)
        if (reg_read && security_lock && lockout) begin
            read_violation = 1'b1;  // Block all reads during lockout
        end
    end
    
    // =========================================================================
    // Violation Counter
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            violation_counter <= 16'h0000;
        end else begin
            if (write_violation || read_violation || integrity_error) begin
                if (violation_counter < 16'hFFFF) begin
                    violation_counter <= violation_counter + 16'h0001;
                end
            end
        end
    end
    
    assign violation_count = violation_counter;
    assign security_violation = write_violation | read_violation | integrity_error;
    
    // =========================================================================
    // Data Integrity Checking (Simple Checksum)
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_checksum <= 8'h00;
            integrity_error <= 1'b0;
        end else begin
            integrity_error <= 1'b0;
            
            // Compute checksum on write operations
            if (reg_write) begin
                data_checksum <= reg_wdata[7:0] ^ reg_wdata[15:8] ^ 
                                 reg_wdata[23:16] ^ reg_wdata[31:24];
                
                // Check for obvious data corruption patterns
                if (reg_wdata == 32'hFFFF_FFFF || reg_wdata == 32'h0000_0000) begin
                    // Suspicious all-1s or all-0s pattern (could be corruption)
                    if (security_lock && reg_addr == ADDR_SECURITY_CFG) begin
                        integrity_error <= 1'b1;
                    end
                end
            end
        end
    end
    
    // =========================================================================
    // Security Status Monitoring
    // =========================================================================
    // Additional signals for debug/monitoring (can be expanded)
    logic [7:0] security_status;
    
    always_comb begin
        security_status = {
            lockout_active,         // [7]
            authenticated,          // [6]
            security_lock,          // [5]
            key_initialized,        // [4]
            failed_attempts         // [3:0]
        };
    end

endmodule
