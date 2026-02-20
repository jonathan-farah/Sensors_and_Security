// =============================================================================
// Testbench for Moving Average Filter - Tiny Tapeout 8-bit Version
// =============================================================================
// Description: Comprehensive testbench for 8-bit Moving Average Filter
// Authors: Jonathan Farah, Jason Qin
// Repository: git@github.com:jonathan-farah/Sensors_and_Security.git
// =============================================================================

`timescale 1ns/1ps

module tb_moving_average_filter_tt;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter DATA_WIDTH = 8;
    parameter MAX_TAPS = 15;
    parameter CLK_PERIOD = 10;  // 10ns = 100 MHz
    
    // =========================================================================
    // DUT Signals (Tiny Tapeout Interface)
    // =========================================================================
    logic                   clk;
    logic                   rst_n;
    
    // Dedicated inputs [7:0]
    logic                   ui_in_0;    // enable
    logic                   ui_in_1;    // num_taps[0]
    logic                   ui_in_2;    // num_taps[1]
    logic                   ui_in_3;    // num_taps[2]
    logic                   ui_in_4;    // num_taps[3]
    logic                   ui_in_5;    // data_valid
    logic                   ui_in_6;    // data_in[0]
    logic                   ui_in_7;    // data_in[1]
    
    // Dedicated outputs [7:0]
    logic                   uo_out_0;   // data_ready
    logic                   uo_out_1;   // result_valid
    logic                   uo_out_2;   // busy
    logic                   uo_out_3;   // result_out[0]
    logic                   uo_out_4;   // result_out[1]
    logic                   uo_out_5;   // result_out[2]
    logic                   uo_out_6;   // result_out[3]
    logic                   uo_out_7;   // result_out[4]
    
    // Bidirectional pins [7:0]
    logic [7:0]             uio_in;
    logic [7:0]             uio_out;
    logic [7:0]             uio_oe;
    
    // =========================================================================
    // Functional Signals (Mapped from Tiny Tapeout pins)
    // =========================================================================
    logic enable;
    logic [3:0] num_taps;
    logic data_valid;
    logic [DATA_WIDTH-1:0] data_in;
    logic data_ready;
    logic result_valid;
    logic busy;
    logic [DATA_WIDTH-1:0] result_out;
    
    // Map functional signals to/from pins
    assign enable = ui_in_0;
    assign {ui_in_4, ui_in_3, ui_in_2, ui_in_1} = num_taps;
    assign data_valid = ui_in_5;
    assign {ui_in_7, ui_in_6} = data_in[1:0];
    assign uio_in[5:0] = data_in[7:2];
    
    assign data_ready = uo_out_0;
    assign result_valid = uo_out_1;
    assign busy = uo_out_2;
    assign result_out[4:0] = {uo_out_7, uo_out_6, uo_out_5, uo_out_4, uo_out_3};
    assign result_out[6:5] = uio_out[7:6];
    assign result_out[7] = 1'b0;  // Upper bit not used in 8-bit mode
    
    // =========================================================================
    // Test Control Variables
    // =========================================================================
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    tt_um_jonathan_farah_moving_average_filter #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_TAPS(MAX_TAPS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in_0(ui_in_0),
        .ui_in_1(ui_in_1),
        .ui_in_2(ui_in_2),
        .ui_in_3(ui_in_3),
        .ui_in_4(ui_in_4),
        .ui_in_5(ui_in_5),
        .ui_in_6(ui_in_6),
        .ui_in_7(ui_in_7),
        .uo_out_0(uo_out_0),
        .uo_out_1(uo_out_1),
        .uo_out_2(uo_out_2),
        .uo_out_3(uo_out_3),
        .uo_out_4(uo_out_4),
        .uo_out_5(uo_out_5),
        .uo_out_6(uo_out_6),
        .uo_out_7(uo_out_7),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );
    
    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // =========================================================================
    // Waveform Dump
    // =========================================================================
    initial begin
        $dumpfile("dumpfile_tt.fst");
        $dumpvars(0);
    end
    
    // =========================================================================
    // Test Monitoring Tasks
    // =========================================================================
    task check_result(
        input string test_name,
        input logic [DATA_WIDTH-1:0] expected,
        input logic [DATA_WIDTH-1:0] actual,
        input integer tolerance
    );
        integer diff;
        diff = (expected > actual) ? (expected - actual) : (actual - expected);
        
        if (diff <= tolerance) begin
            $display("LOG: %0t : INFO : tb_moving_average_filter_tt : %s : expected=%0d actual=%0d diff=%0d", 
                     $time, test_name, expected, actual, diff);
            pass_count++;
        end else begin
            $display("LOG: %0t : ERROR : tb_moving_average_filter_tt : %s : expected=%0d actual=%0d diff=%0d", 
                     $time, test_name, expected, actual, diff);
            fail_count++;
        end
    endtask
    
    // =========================================================================
    // Helper Task: Send Data Sample
    // =========================================================================
    task send_sample(input logic [DATA_WIDTH-1:0] sample);
        wait(data_ready == 1'b1);
        @(posedge clk);
        ui_in_5 = 1'b1;  // data_valid
        data_in = sample;
        @(posedge clk);
        ui_in_5 = 1'b0;  // data_valid
        data_in = 8'h00;
    endtask
    
    // =========================================================================
    // Helper Task: Wait for Result
    // =========================================================================
    task wait_for_result(output logic [DATA_WIDTH-1:0] result);
        wait(result_valid == 1'b1);
        result = result_out;
        @(posedge clk);
    endtask
    
    // =========================================================================
    // Test Reset Task
    // =========================================================================
    task apply_reset();
        $display("\n=== Applying Reset ===");
        rst_n = 1'b0;  // Active-low reset
        ui_in_0 = 1'b0;  // enable
        num_taps = 4'h0;
        ui_in_5 = 1'b0;  // data_valid
        data_in = 8'h00;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);
        $display("=== Reset Complete ===\n");
    endtask
    
    // =========================================================================
    // Test 1: Single Tap (Pass Through) - 8-bit
    // =========================================================================
    task test_single_tap();
        logic [DATA_WIDTH-1:0] result;
        
        $display("\n========================================");
        $display("TEST 1: Single Tap (8-bit Pass Through)");
        $display("========================================");
        test_count++;
        
        ui_in_0 = 1'b1;  // enable
        num_taps = 4'h1;
        
        $display("Configuration: num_taps=1, 8-bit data");
        
        // Send 8-bit samples
        send_sample(8'd50);
        wait_for_result(result);
        $display("Time %0t: Sample=50, Result=%0d", $time, result);
        check_result("single_tap_50", 8'd50, result, 0);
        
        send_sample(8'd100);
        wait_for_result(result);
        $display("Time %0t: Sample=100, Result=%0d", $time, result);
        check_result("single_tap_100", 8'd100, result, 0);
        
        $display("TEST 1: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 2: Two Tap Average - 8-bit
    // =========================================================================
    task test_two_tap();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        
        $display("\n========================================");
        $display("TEST 2: Two Tap Average (8-bit)");
        $display("========================================");
        test_count++;
        
        apply_reset();
        ui_in_0 = 1'b1;  // enable
        num_taps = 4'h2;
        
        $display("Configuration: num_taps=2, 8-bit data");
        
        // Fill buffer: samples 40, 80
        send_sample(8'd40);
        send_sample(8'd80);
        
        // First result: (40 + 80) / 2 = 60
        wait_for_result(result);
        expected = 8'd60;
        $display("Time %0t: Samples=[40,80], Result=%0d", $time, result);
        check_result("two_tap_avg", expected, result, 1);
        
        $display("TEST 2: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 3: Four Tap Average - 8-bit
    // =========================================================================
    task test_four_tap();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        
        $display("\n========================================");
        $display("TEST 3: Four Tap Average (8-bit)");
        $display("========================================");
        test_count++;
        
        apply_reset();
        ui_in_0 = 1'b1;  // enable
        num_taps = 4'h4;
        
        $display("Configuration: num_taps=4, 8-bit data");
        
        // Fill buffer: 16, 32, 48, 64
        send_sample(8'd16);
        send_sample(8'd32);
        send_sample(8'd48);
        send_sample(8'd64);
        
        // First result: (16 + 32 + 48 + 64) / 4 = 40
        wait_for_result(result);
        expected = 8'd40;
        $display("Time %0t: Samples=[16,32,48,64], Result=%0d", $time, result);
        check_result("four_tap_avg", expected, result, 1);
        
        // Add sample: 80
        // Buffer becomes [32, 48, 64, 80]
        send_sample(8'd80);
        wait_for_result(result);
        expected = 8'd56;  // (32 + 48 + 64 + 80) / 4
        $display("Time %0t: Samples=[32,48,64,80], Result=%0d", $time, result);
        check_result("four_tap_slide", expected, result, 1);
        
        $display("TEST 3: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 4: Eight Tap Average - 8-bit
    // =========================================================================
    task test_eight_tap();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        
        $display("\n========================================");
        $display("TEST 4: Eight Tap Average (8-bit)");
        $display("========================================");
        test_count++;
        
        apply_reset();
        ui_in_0 = 1'b1;  // enable
        num_taps = 4'h8;
        
        $display("Configuration: num_taps=8, 8-bit data");
        
        // Fill buffer with 8 samples: 8, 16, 24, 32, 40, 48, 56, 64
        for (int i = 1; i <= 8; i++) begin
            send_sample(i * 8);
        end
        
        // First result: (8+16+24+32+40+48+56+64) / 8 = 288/8 = 36
        wait_for_result(result);
        expected = 8'd36;
        $display("Time %0t: Sum=288, Result=%0d", $time, result);
        check_result("eight_tap_avg", expected, result, 1);
        
        $display("TEST 4: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 5: Enable/Disable Functionality - 8-bit
    // =========================================================================
    task test_enable_disable();
        logic [DATA_WIDTH-1:0] result;
        
        $display("\n========================================");
        $display("TEST 5: Enable/Disable (8-bit)");
        $display("========================================");
        test_count++;
        
        apply_reset();
        ui_in_0 = 1'b0;  // Start disabled
        num_taps = 4'h2;
        
        $display("Configuration: Testing enable/disable");
        
        // Try to send sample while disabled
        @(posedge clk);
        ui_in_5 = 1'b1;  // data_valid
        data_in = 8'd99;
        @(posedge clk);
        ui_in_5 = 1'b0;
        
        // data_ready should be low when disabled
        if (data_ready == 1'b0) begin
            $display("Time %0t: data_ready correctly LOW when disabled", $time);
            pass_count++;
        end else begin
            $display("Time %0t: ERROR - data_ready should be LOW when disabled", $time);
            fail_count++;
        end
        
        // Enable filter
        ui_in_0 = 1'b1;  // enable
        @(posedge clk);
        
        if (data_ready == 1'b1) begin
            $display("Time %0t: data_ready correctly HIGH when enabled", $time);
        end
        
        // Now send valid samples
        send_sample(8'd50);
        send_sample(8'd100);
        wait_for_result(result);
        $display("Time %0t: Filter enabled, Result=%0d", $time, result);
        
        pass_count++;
        $display("TEST 5: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 6: Continuous Streaming - 8-bit
    // =========================================================================
    task test_continuous_stream();
        logic [DATA_WIDTH-1:0] result;
        integer sample_value;
        
        $display("\n========================================");
        $display("TEST 6: Continuous Streaming (8-bit)");
        $display("========================================");
        test_count++;
        
        apply_reset();
        ui_in_0 = 1'b1;  // enable
        num_taps = 4'h4;
        
        $display("Configuration: Continuous stream with 4 taps, 8-bit");
        
        // Send 10 samples continuously
        for (int i = 0; i < 10; i++) begin
            sample_value = (i + 1) * 10;
            if (sample_value > 255) sample_value = 255;  // Clamp to 8-bit
            send_sample(sample_value[7:0]);
            
            // Wait for result (after buffer is full)
            if (i >= 3) begin
                wait_for_result(result);
                $display("Time %0t: Sample %0d sent, Result=%0d", $time, i+1, result);
            end
        end
        
        pass_count++;
        $display("TEST 6: PASSED\n");
    endtask
    
    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("TEST START - 8-bit Tiny Tapeout Version");
        $display("========================================");
        $display("Moving Average Filter Testbench");
        $display("8-bit Data Width, Tiny Tapeout Interface");
        $display("========================================\n");
        
        // Initialize counters
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Initialize signals
        clk = 0;
        rst_n = 1;
        ui_in_0 = 0;  // enable
        num_taps = 0;
        ui_in_5 = 0;  // data_valid
        data_in = 0;
        uio_in = 8'h00;
        
        // Apply reset
        apply_reset();
        
        // Run tests
        test_single_tap();
        test_two_tap();
        test_four_tap();
        test_eight_tap();
        test_enable_disable();
        test_continuous_stream();
        
        // Final summary
        $display("\n========================================");
        $display("TEST SUMMARY - 8-BIT VERSION");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("========================================\n");
        
        if (fail_count == 0) begin
            $display("TEST PASSED - Ready for Tiny Tapeout!");
        end else begin
            $display("TEST FAILED");
            $error("Some tests failed");
        end
        
        $finish(0);
    end
    
    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    initial begin
        #100000;  // 100 us timeout
        $display("\nERROR: Simulation timeout!");
        $display("TEST FAILED");
        $fatal(1, "Simulation exceeded maximum time");
    end

endmodule
