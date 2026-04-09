`timescale 1ns / 1ps
//
// nn_top — FPGA Neural Network Top-Level (4 → 8 → 3)
// Q8 Fixed-point (16-bit signed)
//
// Loads test inputs from test_data.mem. 
// Uses switches [3:0] to select which of the 10 samples to classify.
//
module nn_top (
    input  wire        clk,
    input  wire        btn_rst,     // active-high reset (physical button)
    input  wire        start,       // pulse to begin inference
    input  wire [3:0]  sw,          // 4 switches to select sample (0-9)
    output reg  [1:0]  predicted_class,  // 0, 1, or 2
    output reg         done         // high for 1 cycle when result is ready
);

    // Internal active-low reset for sub-modules
    wire rst_n = !btn_rst;

    // ══════════════════════════════════════════════════════════════════════
    // FSM States
    // ══════════════════════════════════════════════════════════════════════
    localparam S_IDLE        = 3'd0;
    localparam S_FEED_HIDDEN = 3'd1;
    localparam S_WAIT_HIDDEN = 3'd2;
    localparam S_FEED_OUTPUT = 3'd3;
    localparam S_WAIT_OUTPUT = 3'd4;
    localparam S_CALC_ARGMAX = 3'd5; // New state to break timing path
    localparam S_DONE        = 3'd6;

    reg [2:0] state;
    reg [3:0] cycle_cnt;   
    reg [3:0] sampled_sw;  // snap switches at start
    wire [7:0] base_addr = (sampled_sw * 5); // 5 lines per sample (4 feats + 1 label)

    // ══════════════════════════════════════════════════════════════════════
    // Test Input Memory (loaded from .mem file)
    // ══════════════════════════════════════════════════════════════════════
    // test_data.mem has 50 lines: 10 samples × (4 inputs + 1 label)
    reg [15:0] test_data_mem [0:49];
    initial begin
        $readmemh("test_data.mem", test_data_mem);
    end

    // ══════════════════════════════════════════════════════════════════════
    // Hidden Layer (4 → 8)
    // ══════════════════════════════════════════════════════════════════════
    reg         h_start;
    reg  [15:0] h_data_in;
    reg  [1:0]  h_input_idx;
    reg         h_last;
    wire [127:0] h_out;   // 8 neurons × 16 bits
    wire        h_valid;

    layer #(
        .NUM_NEURONS (8),
        .NUM_INPUTS  (4),
        .WEIGHT_FILE ("weights_hidden.mem"),
        .BIAS_FILE   ("biases_hidden.mem")
    ) hidden_layer (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (h_start),
        .data_in     (h_data_in),
        .input_idx   (h_input_idx),
        .last        (h_last),
        .out_vector  (h_out),
        .valid_layer (h_valid)
    );

    // ══════════════════════════════════════════════════════════════════════
    // Latch hidden outputs
    // ══════════════════════════════════════════════════════════════════════
    reg [15:0] hidden_results [0:7];
    integer k;
    always @(posedge clk) begin
        if (h_valid) begin
            for (k = 0; k < 8; k = k + 1)
                hidden_results[k] <= h_out[k*16 +: 16];
        end
    end

    // ══════════════════════════════════════════════════════════════════════
    // Output Layer (8 → 3)
    // ══════════════════════════════════════════════════════════════════════
    reg [15:0] w_out_mem [0:23];  // 3 neurons × 8 weights
    reg [15:0] b_out_mem [0:2];   // 3 biases

    initial begin
        $readmemh("weights_output.mem", w_out_mem);
        $readmemh("biases_output.mem", b_out_mem);
    end

    reg         o_start;
    reg  [15:0] o_data_in;
    reg  [2:0]  o_input_idx;
    reg         o_last;
    wire [15:0] o_out [0:2];      
    wire [2:0]  o_valid;

    genvar g;
    generate
        for (g = 0; g < 3; g = g + 1) begin : output_neuron
            neuron n (
                .clk       (clk),
                .rst_n     (rst_n),
                .start     (o_start),
                .data_in   (o_data_in),
                .weight_in (w_out_mem[g * 8 + o_input_idx]),
                .bias      (b_out_mem[g]),
                .last      (o_last),
                .out       (o_out[g]),
                .valid     (o_valid[g])
            );
        end
    endgenerate

    wire o_all_valid = o_valid[0];

    // ══════════════════════════════════════════════════════════════════════
    // Main FSM
    // ══════════════════════════════════════════════════════════════════════
    always @(posedge clk or posedge btn_rst) begin
        if (btn_rst) begin
            state          <= S_IDLE;
            cycle_cnt      <= 4'd0;
            sampled_sw     <= 4'd0;
            done           <= 1'b0;
            predicted_class <= 2'd0;
            h_start        <= 1'b0;
            h_data_in      <= 16'd0;
            h_input_idx    <= 2'd0;
            h_last         <= 1'b0;
            o_start        <= 1'b0;
            o_data_in      <= 16'd0;
            o_input_idx    <= 3'd0;
            o_last         <= 1'b0;
        end else begin
            h_start <= 1'b0;
            h_last  <= 1'b0;
            o_start <= 1'b0;
            o_last  <= 1'b0;
            done    <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        sampled_sw  <= sw;
                        state       <= S_FEED_HIDDEN;
                        cycle_cnt   <= 4'd0;
                        // Pre-fetch first input so it's ready when S_FEED_HIDDEN starts
                        h_data_in   <= test_data_mem[sw * 5];
                        h_input_idx <= 2'd0;
                    end
                end

                S_FEED_HIDDEN: begin
                    if (cycle_cnt == 4'd0) h_start <= 1'b1;
                    if (cycle_cnt == 4'd3) h_last  <= 1'b1;
                    
                    // Fetch NEXT input (registered, so arrives next cycle)
                    if (cycle_cnt < 4'd3)
                        h_data_in <= test_data_mem[base_addr + cycle_cnt[1:0] + 1];
                    
                    h_input_idx <= cycle_cnt[1:0];

                    if (cycle_cnt == 4'd3) begin
                        state     <= S_WAIT_HIDDEN;
                        cycle_cnt <= 4'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 4'd1;
                    end
                end

                S_WAIT_HIDDEN: begin
                    if (h_valid) begin
                        state     <= S_FEED_OUTPUT;
                        cycle_cnt <= 4'd0;
                    end
                end

                S_FEED_OUTPUT: begin
                    o_data_in   <= hidden_results[cycle_cnt[2:0]];
                    o_input_idx <= cycle_cnt[2:0];
                    if (cycle_cnt == 4'd0) o_start <= 1'b1;
                    if (cycle_cnt == 4'd7) o_last  <= 1'b1;
                    if (cycle_cnt == 4'd7) begin
                        state     <= S_WAIT_OUTPUT;
                        cycle_cnt <= 4'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 4'd1;
                    end
                end

                S_WAIT_OUTPUT: begin
                    if (o_all_valid) begin
                        state <= S_CALC_ARGMAX;
                    end
                end

                S_CALC_ARGMAX: begin
                    // Timing fix: Register the argmax result in a separate clock cycle
                    if (o_out[0] >= o_out[1] && o_out[0] >= o_out[2])
                        predicted_class <= 2'd0;
                    else if (o_out[1] >= o_out[0] && o_out[1] >= o_out[2])
                        predicted_class <= 2'd1;
                    else
                        predicted_class <= 2'd2;
                    
                    done  <= 1'b1;
                    state <= S_IDLE; // Go back to IDLE to wait for next 'start'
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
