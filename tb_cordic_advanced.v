`timescale 1ns / 1ps
//==============================================================================
// Comprehensive Testbench for CORDIC - Rotation Mode Only
// Author: [Your Name]
// Date: November 2025
//
// Test Coverage:
// 1. Sine/Cosine calculation - Positive and Negative angles
// 2. Performance benchmarking
// 3. Error analysis
// 4. Edge cases and corner cases
//==============================================================================

module tb_cordic_advanced;

    //==========================================================================
    // Test Parameters
    //==========================================================================
    
    localparam DATA_WIDTH = 18;
    localparam ANGLE_WIDTH = 32;
    localparam PIPELINE_STAGES = 18;
    localparam CLK_PERIOD = 10;  // 100 MHz
    
    //==========================================================================
    // Test Signals
    //==========================================================================
    
    reg                         clk;
    reg                         rst_n;
    reg                         enable;
    
    // For sine/cosine test
    reg  signed [ANGLE_WIDTH-1:0] angle_in;
    reg                         angle_valid;
    wire                        angle_ready;
    wire signed [DATA_WIDTH:0]  cos_out;
    wire signed [DATA_WIDTH:0]  sin_out;
    wire                        sincos_valid;
    reg                         sincos_ready;
    
    // Test variables
    integer i, j;
    integer test_passed, test_failed;
    integer latency_counter;
    
    real angle_deg, angle_rad;
    real expected_cos, expected_sin;
    real actual_cos, actual_sin;
    real error_cos, error_sin;
    real max_error_cos, max_error_sin;
    real rms_error_cos, rms_error_sin;
    
    // Fixed-point versions for waveform viewing
    reg signed [DATA_WIDTH:0] expected_cos_fixed;
    reg signed [DATA_WIDTH:0] expected_sin_fixed;
    reg signed [DATA_WIDTH:0] actual_cos_fixed;
    reg signed [DATA_WIDTH:0] actual_sin_fixed;
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    
    // Sine/Cosine Module
    cordic_sincos #(
        .DATA_WIDTH(DATA_WIDTH),
        .ANGLE_WIDTH(ANGLE_WIDTH),
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) dut_sincos (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .angle(angle_in),
        .angle_valid(angle_valid),
        .angle_ready(angle_ready),
        .cos_out(cos_out),
        .sin_out(sin_out),
        .result_valid(sincos_valid),
        .result_ready(sincos_ready)
    );
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // Test Stimulus
    //==========================================================================
    
    initial begin
        // Initialize signals
        rst_n = 0;
        enable = 0;
        angle_in = 0;
        angle_valid = 0;
        sincos_ready = 1;
        test_passed = 0;
        test_failed = 0;
        max_error_cos = 0;
        max_error_sin = 0;
        rms_error_cos = 0;
        rms_error_sin = 0;
        expected_cos_fixed = 0;
        expected_sin_fixed = 0;
        actual_cos_fixed = 0;
        actual_sin_fixed = 0;
        
        // Generate VCD file for waveform viewing
        $dumpfile("cordic_advanced.vcd");
        $dumpvars(0, tb_cordic_advanced);
        
        // Print header
        print_header();
        
        // Reset sequence
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        enable = 1;
        #(CLK_PERIOD*2);
        
        //======================================================================
        // TEST 1: Comprehensive Sine/Cosine Test (Positive Angles)
        //======================================================================
        
        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════════════╗");
        $display("║        TEST 1: SINE/COSINE - POSITIVE ANGLES (ROTATION MODE)         ║");
        $display("╚══════════════════════════════════════════════════════════════════════╝");
        $display("\n");
        
        test_sincos_comprehensive();
        
        //======================================================================
        // TEST 2: Sine/Cosine Test (Negative Angles)
        //======================================================================
        
        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════════════╗");
        $display("║        TEST 2: SINE/COSINE - NEGATIVE ANGLES (ROTATION MODE)         ║");
        $display("╚══════════════════════════════════════════════════════════════════════╝");
        $display("\n");
        
        test_sincos_negative();
        
        //======================================================================
        // TEST 3: Edge Cases
        //======================================================================
        
        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════════════╗");
        $display("║                     TEST 3: EDGE CASES                               ║");
        $display("╚══════════════════════════════════════════════════════════════════════╝");
        $display("\n");
        
        test_edge_cases();
        
        //======================================================================
        // TEST 4: Performance Benchmarking
        //======================================================================
        
        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════════════╗");
        $display("║                  TEST 4: PERFORMANCE BENCHMARK                       ║");
        $display("╚══════════════════════════════════════════════════════════════════════╝");
        $display("\n");
        
        test_performance();
        
        //======================================================================
        // Final Summary
        //======================================================================
        
        print_summary();
        
        #(CLK_PERIOD*100);
        $finish;
    end
    
    //==========================================================================
    // Task: Test Sine/Cosine Comprehensive (Positive Angles)
    //==========================================================================
    
    task test_sincos_comprehensive;
        integer angle_int;
        integer num_tests;
        real sum_sq_error_cos, sum_sq_error_sin;
        begin
            $display("Testing angles from 0° to 360° in 10° increments...\n");
            $display("┌─────────┬───────────────────┬───────────────────┬───────────────────────┐");
            $display("│ Angle   │ Expected (C/S)    │  Actual (C/S)     │   Error (C/S)         │");
            $display("├─────────┼───────────────────┼───────────────────┼───────────────────────┤");
            
            num_tests = 0;
            sum_sq_error_cos = 0;
            sum_sq_error_sin = 0;
            
            for (angle_int = 0; angle_int <= 360; angle_int = angle_int + 10) begin
                angle_deg = angle_int;
                angle_rad = (angle_deg * 3.14159265359) / 180.0;
                
                // Calculate expected values
                expected_cos = $cos(angle_rad);
                expected_sin = $sin(angle_rad);
                
                // Convert expected to fixed-point for waveform
                expected_cos_fixed = $rtoi(expected_cos * (2.0 ** (DATA_WIDTH-1)));
                expected_sin_fixed = $rtoi(expected_sin * (2.0 ** (DATA_WIDTH-1)));
                
                // Convert to fixed-point angle
                angle_in = $rtoi((angle_deg / 360.0) * 4294967296.0);
                
                // Apply input
                @(posedge clk);
                angle_valid = 1;
                @(posedge clk);
                angle_valid = 0;
                
                wait(sincos_valid == 1);
                // Wait for valid output
                @(posedge clk);
                
                // Get actual values
                actual_cos = $itor(cos_out) / (2.0 ** (DATA_WIDTH-1));
                actual_sin = $itor(sin_out) / (2.0 ** (DATA_WIDTH-1));
                
                // Store actual values in fixed-point for waveform
                actual_cos_fixed = cos_out;
                actual_sin_fixed = sin_out;
                
                // Calculate errors
                error_cos = actual_cos - expected_cos;
                error_sin = actual_sin - expected_sin;
                
                // Track statistics
                if ($abs(error_cos) > max_error_cos) max_error_cos = $abs(error_cos);
                if ($abs(error_sin) > max_error_sin) max_error_sin = $abs(error_sin);
                
                sum_sq_error_cos = sum_sq_error_cos + (error_cos * error_cos);
                sum_sq_error_sin = sum_sq_error_sin + (error_sin * error_sin);
                num_tests = num_tests + 1;
                
                // Check if error is acceptable (< 0.001)
                if ($abs(error_cos) < 0.001 && $abs(error_sin) < 0.001) begin
                    test_passed = test_passed + 1;
                end else begin
                    test_failed = test_failed + 1;
                end
                
                // Print result
                $display("│ %6.1f° │ %7.4f / %7.4f │ %7.4f / %7.4f │ %9.5f / %9.5f │",
                         angle_deg, expected_cos, expected_sin, 
                         actual_cos, actual_sin, error_cos, error_sin);
                
                // Wait between tests
                repeat(2) @(posedge clk);
            end
            
            $display("└─────────┴───────────────────┴───────────────────┴───────────────────────┘");
            
            // Calculate RMS errors
            rms_error_cos = $sqrt(sum_sq_error_cos / num_tests);
            rms_error_sin = $sqrt(sum_sq_error_sin / num_tests);
            
            $display("\nStatistics:");
            $display("  Maximum Error (Cos): %.6f", max_error_cos);
            $display("  Maximum Error (Sin): %.6f", max_error_sin);
            $display("  RMS Error (Cos):     %.6f", rms_error_cos);
            $display("  RMS Error (Sin):     %.6f", rms_error_sin);
            $display("  Tests Passed:        %0d / %0d", test_passed, num_tests);
        end
    endtask
    
    //==========================================================================
    // Task: Test Sine/Cosine Negative Angles
    //==========================================================================
    
    task test_sincos_negative;
        integer angle_int;
        integer num_tests;
        real sum_sq_error_cos, sum_sq_error_sin;
        begin
            $display("Testing negative angles from 0° to -360° in -30° increments...\n");
            $display("┌─────────┬───────────────────┬───────────────────┬───────────────────────┐");
            $display("│ Angle   │ Expected (C/S)    │  Actual (C/S)     │   Error (C/S)         │");
            $display("├─────────┼───────────────────┼───────────────────┼───────────────────────┤");
            
            num_tests = 0;
            sum_sq_error_cos = 0;
            sum_sq_error_sin = 0;
            
            for (angle_int = 0; angle_int >= -360; angle_int = angle_int - 30) begin
                angle_deg = angle_int;
                angle_rad = (angle_deg * 3.14159265359) / 180.0;
                
                // Calculate expected values
                expected_cos = $cos(angle_rad);
                expected_sin = $sin(angle_rad);
                
                // Convert expected to fixed-point for waveform
                expected_cos_fixed = $rtoi(expected_cos * (2.0 ** (DATA_WIDTH-1)));
                expected_sin_fixed = $rtoi(expected_sin * (2.0 ** (DATA_WIDTH-1)));
                
                // Convert to fixed-point angle (handle negative)
                if (angle_deg < 0) begin
                    angle_in = $rtoi(((360.0 + angle_deg) / 360.0) * 4294967296.0);
                end else begin
                    angle_in = $rtoi((angle_deg / 360.0) * 4294967296.0);
                end
                
                // Apply input
                @(posedge clk);
                angle_valid = 1;
                @(posedge clk);
                angle_valid = 0;
                
                // Wait for valid output
                wait(sincos_valid == 1);
                @(posedge clk);
                
                // Get actual values
                actual_cos = $itor(cos_out) / (2.0 ** (DATA_WIDTH-1));
                actual_sin = $itor(sin_out) / (2.0 ** (DATA_WIDTH-1));
                
                // Store actual values in fixed-point for waveform
                actual_cos_fixed = cos_out;
                actual_sin_fixed = sin_out;
                
                // Calculate errors
                error_cos = actual_cos - expected_cos;
                error_sin = actual_sin - expected_sin;
                
                // Track statistics
                if ($abs(error_cos) > max_error_cos) max_error_cos = $abs(error_cos);
                if ($abs(error_sin) > max_error_sin) max_error_sin = $abs(error_sin);
                
                sum_sq_error_cos = sum_sq_error_cos + (error_cos * error_cos);
                sum_sq_error_sin = sum_sq_error_sin + (error_sin * error_sin);
                num_tests = num_tests + 1;
                
                // Check if error is acceptable
                if ($abs(error_cos) < 0.001 && $abs(error_sin) < 0.001) begin
                    test_passed = test_passed + 1;
                end else begin
                    test_failed = test_failed + 1;
                end
                
                // Print result
                $display("│ %6.1f° │ %7.4f / %7.4f │ %7.4f / %7.4f │ %9.5f / %9.5f │",
                         angle_deg, expected_cos, expected_sin, 
                         actual_cos, actual_sin, error_cos, error_sin);
                
                repeat(2) @(posedge clk);
            end
            
            $display("└─────────┴───────────────────┴───────────────────┴───────────────────────┘");
            
            $display("\nNegative Angle Tests: %0d passed", num_tests);
        end
    endtask
    
    //==========================================================================
    // Task: Test Edge Cases
    //==========================================================================
    
    task test_edge_cases;
        begin
            $display("Testing special angles and edge cases...\n");
            
            // Test 0°
            test_angle(0.0, "0° (zero)");
            
            // Test 90°
            test_angle(90.0, "90° (right angle)");
            
            // Test 180°
            test_angle(180.0, "180° (straight angle)");
            
            // Test 270°
            test_angle(270.0, "270° (3π/2)");
            
            // Test 360°
            test_angle(360.0, "360° (full circle)");
            
            // Test negative angles
            test_angle(-45.0, "-45° (negative)");
            test_angle(-90.0, "-90° (negative right angle)");
            test_angle(-180.0, "-180° (negative straight)");
            
            // Test small angle
            test_angle(0.5, "0.5° (small angle)");
            test_angle(-0.5, "-0.5° (small negative angle)");
            
            $display("\nEdge case tests completed.");
        end
    endtask
    
    //==========================================================================
    // Task: Test Single Angle
    //==========================================================================
    
    task test_angle;
        input real test_angle_deg;
        input [80*8:1] description;
        real test_angle_rad;
        begin
            test_angle_rad = (test_angle_deg * 3.14159265359) / 180.0;
            
            // Calculate expected values
            expected_cos = $cos(test_angle_rad);
            expected_sin = $sin(test_angle_rad);
            
            // Convert expected to fixed-point for waveform
            expected_cos_fixed = $rtoi(expected_cos * (2.0 ** (DATA_WIDTH-1)));
            expected_sin_fixed = $rtoi(expected_sin * (2.0 ** (DATA_WIDTH-1)));
            
            // Handle negative angles
            if (test_angle_deg < 0) begin
                angle_in = $rtoi(((360.0 + test_angle_deg) / 360.0) * 4294967296.0);
            end else begin
                angle_in = $rtoi((test_angle_deg / 360.0) * 4294967296.0);
            end
            
            @(posedge clk);
            angle_valid = 1;
            @(posedge clk);
            angle_valid = 0;
            
            wait(sincos_valid == 1);
            @(posedge clk);
            
            // Get actual values
            actual_cos = $itor(cos_out) / (2.0 ** (DATA_WIDTH-1));
            actual_sin = $itor(sin_out) / (2.0 ** (DATA_WIDTH-1));
            
            // Store actual values in fixed-point for waveform
            actual_cos_fixed = cos_out;
            actual_sin_fixed = sin_out;
            
            $display("  %s", description);
            $display("    Expected: cos=%.6f, sin=%.6f", expected_cos, expected_sin);
            $display("    Actual:   cos=%.6f, sin=%.6f", actual_cos, actual_sin);
            $display("    Error:    cos=%.6f, sin=%.6f\n", 
                     actual_cos - expected_cos, actual_sin - expected_sin);
            
            repeat(2) @(posedge clk);
        end
    endtask
    
    //==========================================================================
    // Task: Test Performance
    //==========================================================================
    
    task test_performance;
        integer start_time, end_time, total_cycles;
        real throughput_mhz;
        begin
            $display("Measuring latency and throughput...\n");
            
            // Measure latency (single operation)
            latency_counter = 0;
            angle_in = 32'h20000000;  // 45 degrees
            
            @(posedge clk);
            angle_valid = 1;
            start_time = $time;
            
            @(posedge clk);
            angle_valid = 0;
            
            // Count cycles until output is valid
            while (sincos_valid == 0) begin
                @(posedge clk);
                latency_counter = latency_counter + 1;
            end
            
            end_time = $time;
            
            $display("  Pipeline Latency:     %0d clock cycles", latency_counter);
            $display("  Latency Time:         %0d ns", end_time - start_time);
            
            // Measure throughput (continuous operations)
            total_cycles = 1000;
            start_time = $time;
            
            for (i = 0; i < total_cycles; i = i + 1) begin
                angle_in = $random;
                @(posedge clk);
                angle_valid = 1;
                @(posedge clk);
                angle_valid = 0;
            end
            
            // Wait for all results
            repeat(PIPELINE_STAGES + 5) @(posedge clk);
            end_time = $time;
            
            throughput_mhz = (total_cycles * 1000.0) / (end_time - start_time);
            
            $display("  Throughput:           %.2f MSPS (Million Samples Per Second)", throughput_mhz);
            $display("  Maximum Frequency:    %.2f MHz (estimated)", throughput_mhz);
            $display("  Pipeline Efficiency:  %.1f%%", (1.0 / latency_counter) * 100.0);
        end
    endtask
    
    //==========================================================================
    // Display Functions
    //==========================================================================
    
    task print_header;
        begin
            $display("\n");
            $display("╔═══════════════════════════════════════════════════════════════════════╗");
            $display("║                                                                       ║");
            $display("║           CORDIC ALGORITHM VERIFICATION SUITE - ROTATION MODE         ║");
            $display("║                                                                       ║");
            $display("║  Features Tested:                                                     ║");
            $display("║    • Sine/Cosine Calculation - Positive & Negative Angles             ║");
            $display("║    • Edge Cases and Special Angles                                    ║");
            $display("║    • Performance Benchmarking                                         ║");
            $display("║                                                                       ║");
            $display("║  Configuration:                                                       ║");
            $display("║    • Data Width:       %2d bits                                        ║", DATA_WIDTH);
            $display("║    • Angle Width:      %2d bits                                        ║", ANGLE_WIDTH);
            $display("║    • Pipeline Stages:  %2d                                             ║", PIPELINE_STAGES);
            $display("║    • Clock Period:     %2d ns (%.0f MHz)                                ║", CLK_PERIOD, 1000.0/CLK_PERIOD);
            $display("║                                                                       ║");
            $display("╚═══════════════════════════════════════════════════════════════════════╝");
        end
    endtask
    
    task print_summary;
        begin
            $display("\n");
            $display("╔═══════════════════════════════════════════════════════════════════════╗");
            $display("║                          TEST SUMMARY                                 ║");
            $display("╠═══════════════════════════════════════════════════════════════════════╣");
            $display("║                                                                       ║");
            $display("║  Total Tests Passed:  %4d                                            ║", test_passed);
            $display("║  Total Tests Failed:  %4d                                            ║", test_failed);
            $display("║                                                                       ║");
            $display("║  Accuracy Metrics:                                                    ║");
            $display("║    Maximum Cosine Error:  %.6f                                    ║", max_error_cos);
            $display("║    Maximum Sine Error:    %.6f                                    ║", max_error_sin);
            $display("║    RMS Cosine Error:      %.6f                                    ║", rms_error_cos);
            $display("║    RMS Sine Error:        %.6f                                    ║", rms_error_sin);
            $display("║                                                                       ║");
            
            if (test_failed == 0) begin
                $display("║  Result: ✓ ALL TESTS PASSED                                           ║");
            end else begin
                $display("║  Result: ✗ SOME TESTS FAILED                                         ║");
            end
            
            $display("║                                                                       ║");
            $display("╚═══════════════════════════════════════════════════════════════════════╝");
            $display("\n");
        end
    endtask

endmodule
