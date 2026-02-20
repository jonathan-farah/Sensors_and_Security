// =============================================================================
// Data FIFO Buffer
// =============================================================================
// Description: Synchronous FIFO for buffering sensor data between ADC and processing
// Features:
//   - Configurable depth and width
//   - Full/empty flags and thresholds
//   - Overflow/underflow detection
//   - Almost-full/almost-empty indicators
//   - Read/write counters for monitoring
// Author: Cognichip Co-Designer
// =============================================================================

module data_fifo_buffer #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH),
    parameter ALMOST_FULL_THRESH = FIFO_DEPTH - 4,
    parameter ALMOST_EMPTY_THRESH = 4
)(
    // Clock and Reset
    input  logic                    clock,
    input  logic                    reset,
    
    // Write Interface
    input  logic                    write_enable,
    input  logic [DATA_WIDTH-1:0]   write_data,
    output logic                    write_ready,
    
    // Read Interface
    input  logic                    read_enable,
    output logic [DATA_WIDTH-1:0]   read_data,
    output logic                    read_valid,
    
    // Status Flags
    output logic                    full,
    output logic                    empty,
    output logic                    almost_full,
    output logic                    almost_empty,
    output logic                    overflow,
    output logic                    underflow,
    
    // Monitoring
    output logic [ADDR_WIDTH:0]     fill_level,
    output logic [15:0]             write_count,
    output logic [15:0]             read_count
);

    // =========================================================================
    // Internal Storage
    // =========================================================================
    logic [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    
    // =========================================================================
    // Pointers and Counters
    // =========================================================================
    logic [ADDR_WIDTH:0] write_ptr;  // Extra bit for full/empty distinction
    logic [ADDR_WIDTH:0] read_ptr;   // Extra bit for full/empty distinction
    logic [15:0]         wr_transaction_count;
    logic [15:0]         rd_transaction_count;
    
    // =========================================================================
    // Status Signals
    // =========================================================================
    logic fifo_full;
    logic fifo_empty;
    logic overflow_flag;
    logic underflow_flag;
    
    assign fifo_full = (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH]) &&
                       (write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]);
    
    assign fifo_empty = (write_ptr == read_ptr);
    
    assign fill_level = write_ptr - read_ptr;
    
    assign almost_full = (fill_level >= ALMOST_FULL_THRESH[ADDR_WIDTH:0]);
    assign almost_empty = (fill_level <= ALMOST_EMPTY_THRESH[ADDR_WIDTH:0]);
    
    assign full = fifo_full;
    assign empty = fifo_empty;
    assign write_ready = !fifo_full;
    
    // =========================================================================
    // Write Logic
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            write_ptr <= '0;
            overflow_flag <= 1'b0;
            wr_transaction_count <= '0;
        end else begin
            overflow_flag <= 1'b0;
            
            if (write_enable) begin
                if (!fifo_full) begin
                    fifo_mem[write_ptr[ADDR_WIDTH-1:0]] <= write_data;
                    write_ptr <= write_ptr + 1'b1;
                    wr_transaction_count <= wr_transaction_count + 1'b1;
                end else begin
                    overflow_flag <= 1'b1;
                end
            end
        end
    end
    
    assign overflow = overflow_flag;
    assign write_count = wr_transaction_count;
    
    // =========================================================================
    // Read Logic
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            read_ptr <= '0;
            read_data <= '0;
            read_valid <= 1'b0;
            underflow_flag <= 1'b0;
            rd_transaction_count <= '0;
        end else begin
            underflow_flag <= 1'b0;
            read_valid <= 1'b0;
            
            if (read_enable) begin
                if (!fifo_empty) begin
                    read_data <= fifo_mem[read_ptr[ADDR_WIDTH-1:0]];
                    read_valid <= 1'b1;
                    read_ptr <= read_ptr + 1'b1;
                    rd_transaction_count <= rd_transaction_count + 1'b1;
                end else begin
                    underflow_flag <= 1'b1;
                end
            end
        end
    end
    
    assign underflow = underflow_flag;
    assign read_count = rd_transaction_count;

endmodule
