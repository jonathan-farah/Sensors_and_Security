// =============================================================================
// Smart Low-Power Proximity Sensor SoC - Communication Interface
// =============================================================================
// Description: SPI-like interface with interrupt generation
// Author: Cognichip Co-Designer
// =============================================================================

module communication_interface (
    // Clock and Reset
    input  logic        clock,
    input  logic        reset,
    
    // Configuration
    input  logic        interrupt_en_detect,
    input  logic        interrupt_en_error,
    
    // Status Inputs
    input  logic        detection_flag,
    input  logic        security_violation,
    input  logic        wakeup_event,
    input  logic [1:0]  power_state,
    
    // Serial Interface (SPI-like)
    input  logic        spi_cs_n,       // Chip select (active low)
    input  logic        spi_sclk,       // Serial clock
    input  logic        spi_mosi,       // Master out, slave in
    output logic        spi_miso,       // Master in, slave out
    
    // Interrupt Output
    output logic        irq_n,          // Interrupt request (active low)
    
    // Internal Clear Signal
    output logic        clear_interrupt
);

    // =========================================================================
    // Interrupt Controller
    // =========================================================================
    logic interrupt_detect_flag;
    logic interrupt_error_flag;
    logic interrupt_wakeup_flag;
    logic interrupt_pending;
    
    // Interrupt flag registers (sticky until cleared)
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            interrupt_detect_flag <= 1'b0;
            interrupt_error_flag <= 1'b0;
            interrupt_wakeup_flag <= 1'b0;
        end else begin
            // Set interrupt flags on events
            if (detection_flag && interrupt_en_detect) begin
                interrupt_detect_flag <= 1'b1;
            end
            if (security_violation && interrupt_en_error) begin
                interrupt_error_flag <= 1'b1;
            end
            if (wakeup_event) begin
                interrupt_wakeup_flag <= 1'b1;
            end
            
            // Clear flags on acknowledge
            if (clear_interrupt) begin
                interrupt_detect_flag <= 1'b0;
                interrupt_error_flag <= 1'b0;
                interrupt_wakeup_flag <= 1'b0;
            end
        end
    end
    
    // Interrupt pending when any enabled interrupt flag is set
    assign interrupt_pending = interrupt_detect_flag | interrupt_error_flag | interrupt_wakeup_flag;
    
    // IRQ output (active low)
    assign irq_n = ~interrupt_pending;
    
    // =========================================================================
    // SPI Interface State Machine
    // =========================================================================
    typedef enum logic [2:0] {
        SPI_IDLE        = 3'b000,
        SPI_CMD         = 3'b001,
        SPI_DATA        = 3'b010,
        SPI_RESPONSE    = 3'b011
    } spi_state_t;
    
    spi_state_t spi_state;
    
    // SPI shift registers
    logic [7:0] spi_rx_shift;
    logic [7:0] spi_tx_shift;
    logic [2:0] spi_bit_count;
    logic [7:0] spi_command;
    logic spi_cs_n_sync;
    logic spi_sclk_sync;
    logic spi_sclk_prev;
    logic spi_sclk_posedge;
    logic spi_sclk_negedge;
    
    // Clock domain crossing - synchronize SPI signals
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            spi_cs_n_sync <= 1'b1;
            spi_sclk_sync <= 1'b0;
            spi_sclk_prev <= 1'b0;
        end else begin
            spi_cs_n_sync <= spi_cs_n;
            spi_sclk_sync <= spi_sclk;
            spi_sclk_prev <= spi_sclk_sync;
        end
    end
    
    assign spi_sclk_posedge = spi_sclk_sync && !spi_sclk_prev;
    assign spi_sclk_negedge = !spi_sclk_sync && spi_sclk_prev;
    
    // =========================================================================
    // SPI State Machine
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            spi_state <= SPI_IDLE;
            spi_rx_shift <= 8'h00;
            spi_tx_shift <= 8'h00;
            spi_bit_count <= 3'h0;
            spi_command <= 8'h00;
            clear_interrupt <= 1'b0;
            spi_miso <= 1'b0;
        end else begin
            clear_interrupt <= 1'b0;  // Pulse signal
            
            if (spi_cs_n_sync) begin
                // Chip select inactive - reset
                spi_state <= SPI_IDLE;
                spi_bit_count <= 3'h0;
                spi_miso <= 1'b0;
            end else begin
                case (spi_state)
                    SPI_IDLE: begin
                        if (!spi_cs_n_sync) begin
                            spi_state <= SPI_CMD;
                            spi_bit_count <= 3'h0;
                        end
                    end
                    
                    SPI_CMD: begin
                        // Receive command byte
                        if (spi_sclk_posedge) begin
                            spi_rx_shift <= {spi_rx_shift[6:0], spi_mosi};
                            spi_bit_count <= spi_bit_count + 3'h1;
                            
                            if (spi_bit_count == 3'h7) begin
                                spi_command <= {spi_rx_shift[6:0], spi_mosi};
                                spi_state <= SPI_RESPONSE;
                                spi_bit_count <= 3'h0;
                                
                                // Prepare response based on command
                                case ({spi_rx_shift[6:0], spi_mosi})
                                    8'h01: spi_tx_shift <= {5'h00, interrupt_wakeup_flag, 
                                                            interrupt_error_flag, interrupt_detect_flag};
                                    8'h02: spi_tx_shift <= {6'h00, power_state};
                                    8'h03: begin
                                        spi_tx_shift <= 8'hAA;  // ACK
                                        clear_interrupt <= 1'b1;
                                    end
                                    default: spi_tx_shift <= 8'hFF;  // Invalid command
                                endcase
                            end
                        end
                    end
                    
                    SPI_RESPONSE: begin
                        // Transmit response byte
                        if (spi_sclk_negedge) begin
                            spi_miso <= spi_tx_shift[7];
                            spi_tx_shift <= {spi_tx_shift[6:0], 1'b0};
                            spi_bit_count <= spi_bit_count + 3'h1;
                            
                            if (spi_bit_count == 3'h7) begin
                                spi_state <= SPI_IDLE;
                            end
                        end
                    end
                    
                    default: spi_state <= SPI_IDLE;
                endcase
            end
        end
    end

endmodule
