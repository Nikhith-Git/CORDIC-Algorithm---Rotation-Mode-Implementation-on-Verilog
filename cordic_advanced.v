`timescale 1ns / 1ps
//==============================================================================
// CORDIC Engine - Rotation Mode 
// Author: Nikhith
// Date: November 2025
// 
// Features:
// - Rotation mode only
// - Configurable pipeline depth
// - Ready/Valid handshaking
// - Overflow detection
// - Performance counters
//==============================================================================

module cordic_advanced #(
    parameter DATA_WIDTH = 18,          // Input/output data width
    parameter ANGLE_WIDTH = 32,         // Angle representation width
    parameter ITERATIONS = 18,          // Number of CORDIC iterations
    parameter PIPELINE_STAGES = 18      // Pipeline depth (can be < ITERATIONS)
)(
    // Clock and Reset
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Control Interface
    input  wire                         enable,
    
    // Input Data (Ready-Valid Handshake)
    input  wire signed [DATA_WIDTH-1:0] x_in,
    input  wire signed [DATA_WIDTH-1:0] y_in,
    input  wire signed [ANGLE_WIDTH-1:0] z_in,          // Angle input
    input  wire                         data_valid_in,
    output wire                         data_ready_out,
    
    // Output Data (Ready-Valid Handshake)
    output wire signed [DATA_WIDTH:0]   x_out,
    output wire signed [DATA_WIDTH:0]   y_out,
    output wire signed [ANGLE_WIDTH-1:0] z_out,
    output wire                         data_valid_out,
    input  wire                         data_ready_in,
    
    // Status and Debug
    output wire                         overflow,
    output wire [15:0]                  iterations_count,
    output wire [31:0]                  throughput_counter
);

    //==========================================================================
    // CORDIC Constants and Lookup Tables
    //==========================================================================
    
    // CORDIC gain K = 1.646760258121 (for circular coordinate system)
    // K_inv = 0.6072529350 = 19898/32768 for 16-bit
    localparam real CORDIC_GAIN = 1.646760258121;
    localparam signed [DATA_WIDTH-1:0] K_INVERSE = 
        (DATA_WIDTH == 16) ? 16'd19898 :
        (DATA_WIDTH == 18) ? 18'd79593 :
        (DATA_WIDTH == 20) ? 20'd318371 : 16'd19898;
    
    // Arctangent lookup table - 32-bit representation
    function [ANGLE_WIDTH-1:0] atan_lut;
        input integer idx;
        begin
            case(idx)
                0:  atan_lut = 32'h20000000;  // 45.000°
                1:  atan_lut = 32'h12E4051E;  // 26.565°
                2:  atan_lut = 32'h09FB385B;  // 14.036°
                3:  atan_lut = 32'h051111D4;  // 7.125°
                4:  atan_lut = 32'h028B0D43;  // 3.576°
                5:  atan_lut = 32'h0145D7E1;  // 1.790°
                6:  atan_lut = 32'h00A2F61E;  // 0.895°
                7:  atan_lut = 32'h00517C55;  // 0.448°
                8:  atan_lut = 32'h0028BE53;  // 0.224°
                9:  atan_lut = 32'h00145F2E;  // 0.112°
                10: atan_lut = 32'h000A2F98;  // 0.056°
                11: atan_lut = 32'h000517CC;  // 0.028°
                12: atan_lut = 32'h00028BE6;  // 0.014°
                13: atan_lut = 32'h000145F3;  // 0.007°
                14: atan_lut = 32'h0000A2F9;
                15: atan_lut = 32'h0000517D;
                16: atan_lut = 32'h000028BE;
                17: atan_lut = 32'h0000145F;
                18: atan_lut = 32'h00000A2F;
                19: atan_lut = 32'h00000518;
                20: atan_lut = 32'h0000028C;
                21: atan_lut = 32'h00000146;
                22: atan_lut = 32'h000000A3;
                23: atan_lut = 32'h00000051;
                24: atan_lut = 32'h00000028;
                25: atan_lut = 32'h00000014;
                26: atan_lut = 32'h0000000A;
                27: atan_lut = 32'h00000005;
                28: atan_lut = 32'h00000002;
                29: atan_lut = 32'h00000001;
                default: atan_lut = 32'h00000000;
            endcase
        end
    endfunction
    
    //==========================================================================
    // Pipeline Registers
    //==========================================================================
    
    reg signed [DATA_WIDTH:0]   x_pipe [0:PIPELINE_STAGES];
    reg signed [DATA_WIDTH:0]   y_pipe [0:PIPELINE_STAGES];
    reg signed [ANGLE_WIDTH-1:0] z_pipe [0:PIPELINE_STAGES];
    reg                         valid_pipe [0:PIPELINE_STAGES];
    
    //==========================================================================
    // Control Logic
    //==========================================================================
    
    reg [15:0] iteration_counter;
    reg [31:0] throughput_cnt;
    reg        overflow_flag;
    
    assign data_ready_out = enable;
    assign data_valid_out = valid_pipe[PIPELINE_STAGES];
    assign iterations_count = iteration_counter;
    assign throughput_counter = throughput_cnt;
    assign overflow = overflow_flag;
    
    //==========================================================================
    // Stage 0: Input Preprocessing
    //==========================================================================
    
    wire [1:0] quadrant;
    assign quadrant = z_in[ANGLE_WIDTH-1:ANGLE_WIDTH-2];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pipe[0] <= 0;
            y_pipe[0] <= 0;
            z_pipe[0] <= 0;
            valid_pipe[0] <= 0;
        end else if (enable && data_valid_in) begin
            valid_pipe[0] <= 1'b1;
            
            // Quadrant pre-rotation for rotation mode
            case (quadrant)
                2'b00, 2'b11: begin  // Q0 or Q3
                    x_pipe[0] <= {x_in[DATA_WIDTH-1], x_in};
                    y_pipe[0] <= {y_in[DATA_WIDTH-1], y_in};
                    z_pipe[0] <= z_in;
                end
                2'b01: begin  // Q1: Rotate by -90°
                    x_pipe[0] <= -{y_in[DATA_WIDTH-1], y_in};
                    y_pipe[0] <= {x_in[DATA_WIDTH-1], x_in};
                    z_pipe[0] <= {2'b00, z_in[ANGLE_WIDTH-3:0]};
                end
                2'b10: begin  // Q2: Rotate by +90°
                    x_pipe[0] <= {y_in[DATA_WIDTH-1], y_in};
                    y_pipe[0] <= -{x_in[DATA_WIDTH-1], x_in};
                    z_pipe[0] <= {2'b11, z_in[ANGLE_WIDTH-3:0]};
                end
            endcase
        end else begin
            valid_pipe[0] <= 0;
        end
    end
    
    //==========================================================================
    // Stages 1 to PIPELINE_STAGES: CORDIC Iterations
    //==========================================================================
    
    genvar i;
    generate
        for (i = 0; i < PIPELINE_STAGES; i = i + 1) begin : cordic_pipeline
            
            wire decision_sign;
            wire signed [DATA_WIDTH:0] x_shifted, y_shifted;
            
            // Arithmetic right shift by iteration number
            assign x_shifted = x_pipe[i] >>> i;
            assign y_shifted = y_pipe[i] >>> i;
            
            // Decision: rotate to make z approach zero
            assign decision_sign = z_pipe[i][ANGLE_WIDTH-1];
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_pipe[i+1] <= 0;
                    y_pipe[i+1] <= 0;
                    z_pipe[i+1] <= 0;
                    valid_pipe[i+1] <= 0;
                end else if (enable) begin
                    valid_pipe[i+1] <= valid_pipe[i];
                    
                    if (valid_pipe[i]) begin
                        if (decision_sign) begin  // Clockwise rotation
                            x_pipe[i+1] <= x_pipe[i] + y_shifted;
                            y_pipe[i+1] <= y_pipe[i] - x_shifted;
                            z_pipe[i+1] <= z_pipe[i] + atan_lut(i);
                        end else begin  // Counter-clockwise rotation
                            x_pipe[i+1] <= x_pipe[i] - y_shifted;
                            y_pipe[i+1] <= y_pipe[i] + x_shifted;
                            z_pipe[i+1] <= z_pipe[i] - atan_lut(i);
                        end
                    end else begin
                        x_pipe[i+1] <= x_pipe[i];
                        y_pipe[i+1] <= y_pipe[i];
                        z_pipe[i+1] <= z_pipe[i];
                    end
                end
            end
        end
    endgenerate
    
    //==========================================================================
    // Output Assignment
    //==========================================================================
    
    assign x_out = x_pipe[PIPELINE_STAGES];
    assign y_out = y_pipe[PIPELINE_STAGES];
    assign z_out = z_pipe[PIPELINE_STAGES];
    
    //==========================================================================
    // Overflow Detection
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            overflow_flag <= 0;
        end else begin
            // Check for overflow in final stage
            if (valid_pipe[PIPELINE_STAGES]) begin
                overflow_flag <= (x_pipe[PIPELINE_STAGES] == {1'b1, {DATA_WIDTH{1'b0}}}) ||
                                 (y_pipe[PIPELINE_STAGES] == {1'b1, {DATA_WIDTH{1'b0}}});
            end
        end
    end
    
    //==========================================================================
    // Performance Counters
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iteration_counter <= 0;
            throughput_cnt <= 0;
        end else begin
            if (data_valid_in && enable)
                iteration_counter <= iteration_counter + 1;
            
            if (data_valid_out && data_ready_in)
                throughput_cnt <= throughput_cnt + 1;
        end
    end

endmodule

//==============================================================================
// Sine/Cosine Wrapper Module
//==============================================================================

module cordic_sincos #(
    parameter DATA_WIDTH = 18,
    parameter ANGLE_WIDTH = 32,
    parameter PIPELINE_STAGES = 18
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         enable,
    
    input  wire signed [ANGLE_WIDTH-1:0] angle,
    input  wire                         angle_valid,
    output wire                         angle_ready,
    
    output wire signed [DATA_WIDTH:0]   cos_out,
    output wire signed [DATA_WIDTH:0]   sin_out,
    output wire                         result_valid,
    input  wire                         result_ready
);

    // CORDIC gain compensation factor
    localparam signed [DATA_WIDTH-1:0] K_INV = 
        (DATA_WIDTH == 16) ? 16'd19898 :
        (DATA_WIDTH == 18) ? 18'd79593 :
        (DATA_WIDTH == 20) ? 20'd318371 : 16'd19898;
    
    wire overflow;
    wire [15:0] iter_count;
    wire [31:0] throughput;
    
    cordic_advanced #(
        .DATA_WIDTH(DATA_WIDTH),
        .ANGLE_WIDTH(ANGLE_WIDTH),
        .ITERATIONS(PIPELINE_STAGES),
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) cordic_core (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        
        .x_in(K_INV),
        .y_in({DATA_WIDTH{1'b0}}),
        .z_in(angle),
        .data_valid_in(angle_valid),
        .data_ready_out(angle_ready),
        
        .x_out(cos_out),
        .y_out(sin_out),
        .z_out(),
        .data_valid_out(result_valid),
        .data_ready_in(result_ready),
        
        .overflow(overflow),
        .iterations_count(iter_count),
        .throughput_counter(throughput)
    );

endmodule
