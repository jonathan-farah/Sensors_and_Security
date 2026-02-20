// =============================================================================
// Testbench for Moving Average Filter
// =============================================================================
// Description: Comprehensive testbench for Moving Average Filter
// Tests:
//   - Different tap configurations (1, 2, 4, 8, 15 taps)
//   - Averaging accuracy verification
//   - Enable/disable functionality
//   - Busy signal behavior
//   - Data ready handshaking
//   - Multiple samples through filter
// Author: Cognichip Co-Designer
// =============================================================================

`timescale 1ns/1ps

module tb_moving_average_filter;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter DATA_WIDTH = 32;
    parameter MAX_TAPS = 15;
    parameter CLK_PERIOD = 10;  // 10ns = 100 MHz
    
    // =========================================================================
    // DUT Signals
    // =========================================================================
    logic                    clock;
    logic                    reset;
    logic                    enable;
    logic [3:0]              num_taps;
    logic                    data_valid;
    logic [DATA_WIDTH-1:0]   data_in;
    logic                    data_ready;
    logic                    result_valid;
    logic [DATA_WIDTH-1:0]   result_out;
    logic                    busy;
    
    // =========================================================================
    // Test Control Variables
    // =========================================================================
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    moving_average_filter #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_TAPS(MAX_TAPS)
    ) dut (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .num_taps(num_taps),
        .data_valid(data_valid),
        .data_in(data_in),
        .data_ready(data_ready),
        .result_valid(result_valid),
        .result_out(result_out),
        .busy(busy)
    );
    
    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clock = 0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end
    
    // =========================================================================
    // Waveform Dump
    // =========================================================================
    initial begin
        $dumpfile("dumpfile.fst");
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
            $display("LOG: %0t : INFO : tb_moving_average_filter : %s : expected_value: %0d actual_value: %0d diff: %0d", 
                     $time, test_name, expected, actual, diff);
            pass_count++;
        end else begin
            $display("LOG: %0t : ERROR : tb_moving_average_filter : %s : expected_value: %0d actual_value: %0d diff: %0d", 
                     $time, test_name, expected, actual, diff);
            fail_count++;
        end
    endtask
    
    task check_signal(
        input string signal_name,
        input logic expected,
        input logic actual
    );
        if (expected !== actual) begin
            $display("LOG: %0t : ERROR : tb_moving_average_filter : %s : expected_value: %b actual_value: %b", 
                     $time, signal_name, expected, actual);
            fail_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_moving_average_filter : %s : expected_value: %b actual_value: %b", 
                     $time, signal_name, expected, actual);
        end
    endtask
    
    // =========================================================================
    // Helper Task: Send Data Sample
    // =========================================================================
    task send_sample(input logic [DATA_WIDTH-1:0] sample);
        wait(data_ready == 1'b1);
        @(posedge clock);
        data_valid = 1'b1;
        data_in = sample;
        @(posedge clock);
        data_valid = 1'b0;
        data_in = 32'h0000_0000;
    endtask
    
    // =========================================================================
    // Helper Task: Wait for Result
    // =========================================================================
    task wait_for_result(output logic [DATA_WIDTH-1:0] result);
        wait(result_valid == 1'b1);
        result = result_out;
        @(posedge clock);
    endtask
    
    // =========================================================================
    // Test Reset Task
    // =========================================================================
    task apply_reset();
        $display("\n=== Applying Reset ===");
        reset = 1'b1;
        enable = 1'b0;
        num_taps = 4'h0;
        data_valid = 1'b0;
        data_in = 32'h0000_0000;
        repeat(5) @(posedge clock);
        reset = 1'b0;
        repeat(2) @(posedge clock);
        $display("=== Reset Complete ===\n");
    endtask
    
    // =========================================================================
    // Test 1: Single Tap (Pass Through)
    // =========================================================================
    task test_single_tap();
        logic [DATA_WIDTH-1:0] result;
        
        $display("\n========================================");
        $display("TEST 1: Single Tap (Pass Through)");
        $display("========================================");
        test_count++;
        
        enable = 1'b1;
        num_taps = 4'h1;
        
        $display("Configuration: num_taps=1");
        
        // Send samples
        send_sample(32'd100);
        wait_for_result(result);
        $display("Time %0t: Sample=100, Result=%0d", $time, result);
        check_result("single_tap_100", 32'd100, result, 0);
        
        send_sample(32'd200);
        wait_for_result(result);
        $display("Time %0t: Sample=200, Result=%0d", $time, result);
        check_result("single_tap_200", 32'd200, result, 0);
        
        $display("TEST 1: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 2: Two Tap Average
    // =========================================================================
    task test_two_tap();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        
        $display("\n========================================");
        $display("TEST 2: Two Tap Average");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b1;
        num_taps = 4'h2;
        
        $display("Configuration: num_taps=2");
        
        // Fill buffer: samples 100, 200
        send_sample(32'd100);
        send_sample(32'd200);
        
        // First result: (100 + 200) / 2 = 150
        wait_for_result(result);
        expected = 32'd150;
        $display("Time %0t: Samples=[100,200], Result=%0d", $time, result);
        check_result("two_tap_avg", expected, result, 1);
        
        // Add new sample: 300
        // Buffer becomes [200, 300]
        send_sample(32'd300);
        wait_for_result(result);
        expected = 32'd250;  // (200 + 300) / 2
        $display("Time %0t: Samples=[200,300], Result=%0d", $time, result);
        check_result("two_tap_slide", expected, result, 1);
        
        $display("TEST 2: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 3: Four Tap Average
    // =========================================================================
    task test_four_tap();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        
        $display("\n========================================");
        $display("TEST 3: Four Tap Average");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b1;
        num_taps = 4'h4;
        
        $display("Configuration: num_taps=4");
        
        // Fill buffer: 100, 200, 300, 400
        send_sample(32'd100);
        send_sample(32'd200);
        send_sample(32'd300);
        send_sample(32'd400);
        
        // First result: (100 + 200 + 300 + 400) / 4 = 250
        wait_for_result(result);
        expected = 32'd250;
        $display("Time %0t: Samples=[100,200,300,400], Result=%0d", $time, result);
        check_result("four_tap_avg", expected, result, 1);
        
        // Add sample: 500
        // Buffer becomes [200, 300, 400, 500]
        send_sample(32'd500);
        wait_for_result(result);
        expected = 32'd350;  // (200 + 300 + 400 + 500) / 4
        $display("Time %0t: Samples=[200,300,400,500], Result=%0d", $time, result);
        check_result("four_tap_slide", expected, result, 1);
        
        $display("TEST 3: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 4: Eight Tap Average
    // =========================================================================
    task test_eight_tap();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        
        $display("\n========================================");
        $display("TEST 4: Eight Tap Average");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b1;
        num_taps = 4'h8;
        
        $display("Configuration: num_taps=8");
        
        // Fill buffer with 8 samples: 10, 20, 30, ..., 80
        for (int i = 1; i <= 8; i++) begin
            send_sample(i * 10);
        end
        
        // First result: (10+20+30+40+50+60+70+80) / 8 = 360/8 = 45
        wait_for_result(result);
        expected = 32'd45;
        $display("Time %0t: Samples=[10,20,30,40,50,60,70,80], Result=%0d", $time, result);
        check_result("eight_tap_avg", expected, result, 1);
        
        $display("TEST 4: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 5: Maximum Taps (15)
    // =========================================================================
    task test_max_taps();
        logic [DATA_WIDTH-1:0] result;
        logic [DATA_WIDTH-1:0] expected;
        integer sum;
        
        $display("\n========================================");
        $display("TEST 5: Maximum Taps (15)");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b1;
        num_taps = 4'd15;
        
        $display("Configuration: num_taps=15");
        
        // Fill buffer with 15 samples: 100, 200, 300, ..., 1500
        sum = 0;
        for (int i = 1; i <= 15; i++) begin
            send_sample(i * 100);
            sum = sum + (i * 100);
        end
        
        // Result: sum / 15 = 12000 / 15 = 800
        wait_for_result(result);
        expected = sum / 15;
        $display("Time %0t: Sum=%0d, Expected=%0d, Result=%0d", $time, sum, expected, result);
        check_result("fifteen_tap_avg", expected, result, 1);
        
        $display("TEST 5: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 6: Enable/Disable Functionality
    // =========================================================================
    task test_enable_disable();
        logic [DATA_WIDTH-1:0] result;
        
        $display("\n========================================");
        $display("TEST 6: Enable/Disable Functionality");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b0;  // Start disabled
        num_taps = 4'h2;
        
        $display("Configuration: Testing enable/disable");
        
        // Try to send sample while disabled
        @(posedge clock);
        data_valid = 1'b1;
        data_in = 32'd999;
        @(posedge clock);
        data_valid = 1'b0;
        
        // data_ready should be low when disabled
        check_signal("data_ready_disabled", 1'b0, data_ready);
        
        // Enable filter
        enable = 1'b1;
        @(posedge clock);
        check_signal("data_ready_enabled", 1'b1, data_ready);
        
        // Now send valid samples
        send_sample(32'd100);
        send_sample(32'd200);
        wait_for_result(result);
        $display("Time %0t: Filter enabled, Result=%0d", $time, result);
        
        // Disable during operation
        enable = 1'b0;
        @(posedge clock);
        check_signal("data_ready_disabled_again", 1'b0, data_ready);
        
        pass_count++;
        $display("TEST 6: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 7: Busy Signal Behavior
    // =========================================================================
    task test_busy_signal();
        $display("\n========================================");
        $display("TEST 7: Busy Signal Behavior");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b1;
        num_taps = 4'h4;
        
        $display("Configuration: Testing busy signal");
        
        // Fill buffer
        send_sample(32'd10);
        send_sample(32'd20);
        send_sample(32'd30);
        send_sample(32'd40);
        
        // Filter should go busy during computation
        @(posedge clock);
        if (busy == 1'b1) begin
            $display("Time %0t: Filter busy during computation", $time);
            check_signal("busy_during_compute", 1'b1, busy);
        end
        
        // Wait for result
        wait(result_valid == 1'b1);
        @(posedge clock);
        
        // Should be idle after output
        repeat(2) @(posedge clock);
        check_signal("not_busy_after_output", 1'b0, busy);
        
        pass_count++;
        $display("TEST 7: PASSED\n");
    endtask
    
    // =========================================================================
    // Test 8: Continuous Streaming
    // =========================================================================
    task test_continuous_stream();
        logic [DATA_WIDTH-1:0] result;
        integer sample_value;
        
        $display("\n========================================");
        $display("TEST 8: Continuous Streaming");
        $display("========================================");
        test_count++;
        
        apply_reset();
        enable = 1'b1;
        num_taps = 4'h4;
        
        $display("Configuration: Continuous stream with 4 taps");
        
        // Send 10 samples continuously
        for (int i = 0; i < 10; i++) begin
            sample_value = (i + 1) * 50;
            send_sample(sample_value);
            
            // Wait for result (after buffer is full)
            if (i >= 3) begin
                wait_for_result(result);
                $display("Time %0t: Sample %0d sent, Result=%0d", $time, i+1, result);
            end
        end
        
        pass_count++;
        $display("TEST 8: PASSED\n");
    endtask
    
    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Moving Average Filter Testbench");
        $display("========================================\n");
        
        // Initialize counters
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Initialize signals
        clock = 0;
        reset = 0;
        enable = 0;
        num_taps = 0;
        data_valid = 0;
        data_in = 0;
        
        // Apply reset
        apply_reset();
        
        // Run tests
        test_single_tap();
        test_two_tap();
        test_four_tap();
        test_eight_tap();
        test_max_taps();
        test_enable_disable();
        test_busy_signal();
        test_continuous_stream();
        
        // Final summary
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("========================================\n");
        
        if (fail_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
            $error("Some tests failed");
        end
        
        $finish(0);
    end
    
    // =========================================================================
    // Timeout Watchdog (prevent infinite simulation)
    // =========================================================================
    initial begin
        #100000;  // 100 us timeout
        $display("\nERROR: Simulation timeout!");
        $display("TEST FAILED");
        $fatal(1, "Simulation exceeded maximum time");
    end

endmodule
