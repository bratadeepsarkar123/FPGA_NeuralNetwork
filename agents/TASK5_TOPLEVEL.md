# TASK 5 — Verilog: Top-Level Integration + Constraints
**Agent:** Create the Verilog source and XDC constraints files EXACTLY as specified. Run final simulation.  
**Prereq:** TASK2 (`.mem` files), TASK3 (`neuron.v`), TASK4 (`layer.v`).  
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`

---

## Background: Top-Level Architecture

```
                            ┌─── nn_top ────────────────────────────────────────────┐
                            │                                                        │
 4 test inputs ──►  INPUT   │   HIDDEN LAYER      OUTPUT LAYER     ARGMAX            │
 (from .mem)   ──►  FEEDER  │   (4→8, ReLU)  ──►  (8→3, ReLU) ──► (max of 3) ──► predicted_class
                            │                                                        │
 start ─────────────────────►   FSM controls sequencing                              │
 rst_n ─────────────────────►                                            done ───────►
                            └────────────────────────────────────────────────────────┘
```

**FSM States (5 states):**
1. `IDLE` — wait for `start` pulse
2. `FEED_HIDDEN` — feed 4 inputs to hidden layer (4 clock cycles)
3. `WAIT_HIDDEN` — wait 1 cycle for hidden layer valid
4. `FEED_OUTPUT` — feed 8 hidden outputs to output layer (8 clock cycles)
5. `WAIT_OUTPUT` — wait 1 cycle, latch argmax result, assert `done`

---

## Step 1: Create the Top-Level Module

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\src\nn_top.v` with EXACTLY this content:

```verilog
`timescale 1ns / 1ps
//
// nn_top — FPGA Neural Network Top-Level (4 → 8 → 3)
// Q8 Fixed-point (16-bit signed)
//
// Loads test inputs from test_data.mem, feeds them through hidden + output
// layers, and produces a 2-bit predicted class via argmax.
//
module nn_top (
    input  wire        clk,
    input  wire        rst_n,       // active-low reset
    input  wire        start,       // pulse to begin inference
    output reg  [1:0]  predicted_class,  // 0, 1, or 2
    output reg         done         // high for 1 cycle when result is ready
);

    // ══════════════════════════════════════════════════════════════════════
    // FSM States
    // ══════════════════════════════════════════════════════════════════════
    localparam S_IDLE        = 3'd0;
    localparam S_FEED_HIDDEN = 3'd1;
    localparam S_WAIT_HIDDEN = 3'd2;
    localparam S_FEED_OUTPUT = 3'd3;
    localparam S_WAIT_OUTPUT = 3'd4;
    localparam S_DONE        = 3'd5;

    reg [2:0] state;
    reg [3:0] cycle_cnt;   // counts input cycles (max 8 for output layer)

    // ══════════════════════════════════════════════════════════════════════
    // Test Input Memory (loaded from .mem file)
    // ══════════════════════════════════════════════════════════════════════
    // test_data.mem has 50 lines: 10 samples × (4 inputs + 1 label)
    // We use the first sample (lines 0–3) as the default test input.
    reg [15:0] test_inputs [0:3];
    initial begin
        test_inputs[0] = 16'h0000;
        test_inputs[1] = 16'h0000;
        test_inputs[2] = 16'h0000;
        test_inputs[3] = 16'h0000;
        $readmemh("weights/test_data.mem", test_inputs, 0, 3);
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
        .WEIGHT_FILE ("weights/weights_hidden.mem"),
        .BIAS_FILE   ("weights/biases_hidden.mem")
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
    // Latch hidden outputs (needed to feed output layer sequentially)
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
    // Uses 3 separate neurons (NOT a full "layer" module, since the
    // layer module is parameterised for 4 inputs / 8 neurons).
    // ══════════════════════════════════════════════════════════════════════
    reg [15:0] w_out_mem [0:23];  // 3 neurons × 8 weights
    reg [15:0] b_out_mem [0:2];   // 3 biases

    initial begin
        $readmemh("weights/weights_output.mem", w_out_mem);
        $readmemh("weights/biases_output.mem", b_out_mem);
    end

    reg         o_start;
    reg  [15:0] o_data_in;
    reg  [15:0] o_weight [0:2];   // current weight for each of the 3 neurons
    reg         o_last;
    wire [15:0] o_out [0:2];      // output of each of the 3 neurons
    wire [2:0]  o_valid;

    genvar g;
    generate
        for (g = 0; g < 3; g = g + 1) begin : output_neuron
            neuron n (
                .clk       (clk),
                .rst_n     (rst_n),
                .start     (o_start),
                .data_in   (o_data_in),
                .weight_in (w_out_mem[g * 8 + cycle_cnt[2:0]]),
                .bias      (b_out_mem[g]),
                .last      (o_last),
                .out       (o_out[g]),
                .valid     (o_valid[g])
            );
        end
    endgenerate

    wire o_all_valid = o_valid[0];  // all 3 finish together

    // ══════════════════════════════════════════════════════════════════════
    // Main FSM
    // ══════════════════════════════════════════════════════════════════════
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            cycle_cnt      <= 4'd0;
            done           <= 1'b0;
            predicted_class <= 2'd0;
            h_start        <= 1'b0;
            h_data_in      <= 16'd0;
            h_input_idx    <= 2'd0;
            h_last         <= 1'b0;
            o_start        <= 1'b0;
            o_data_in      <= 16'd0;
            o_last         <= 1'b0;
        end else begin
            // Default: deassert pulses
            h_start <= 1'b0;
            h_last  <= 1'b0;
            o_start <= 1'b0;
            o_last  <= 1'b0;
            done    <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (start) begin
                        state     <= S_FEED_HIDDEN;
                        cycle_cnt <= 4'd0;
                    end
                end

                S_FEED_HIDDEN: begin
                    // Feed test_inputs[0..3] to hidden layer over 4 cycles
                    h_data_in   <= test_inputs[cycle_cnt[1:0]];
                    h_input_idx <= cycle_cnt[1:0];

                    if (cycle_cnt == 4'd0)
                        h_start <= 1'b1;   // first input

                    if (cycle_cnt == 4'd3)
                        h_last <= 1'b1;    // last input

                    if (cycle_cnt == 4'd3) begin
                        state     <= S_WAIT_HIDDEN;
                        cycle_cnt <= 4'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 4'd1;
                    end
                end

                S_WAIT_HIDDEN: begin
                    // Wait for hidden layer to produce valid outputs
                    if (h_valid) begin
                        state     <= S_FEED_OUTPUT;
                        cycle_cnt <= 4'd0;
                    end
                end

                S_FEED_OUTPUT: begin
                    // Feed hidden_results[0..7] to output neurons over 8 cycles
                    o_data_in <= hidden_results[cycle_cnt[2:0]];

                    if (cycle_cnt == 4'd0)
                        o_start <= 1'b1;   // first input

                    if (cycle_cnt == 4'd7)
                        o_last <= 1'b1;    // last input

                    if (cycle_cnt == 4'd7) begin
                        state     <= S_WAIT_OUTPUT;
                        cycle_cnt <= 4'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 4'd1;
                    end
                end

                S_WAIT_OUTPUT: begin
                    if (o_all_valid) begin
                        // Argmax: find which of the 3 outputs is largest
                        if (o_out[0] >= o_out[1] && o_out[0] >= o_out[2])
                            predicted_class <= 2'd0;
                        else if (o_out[1] >= o_out[0] && o_out[1] >= o_out[2])
                            predicted_class <= 2'd1;
                        else
                            predicted_class <= 2'd2;

                        done  <= 1'b1;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    // Stay here until next start pulse
                    if (start)
                        state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
```

---

## Step 2: Create the Top-Level Testbench

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\sim\tb_nn_top.v` with EXACTLY this content:

```verilog
`timescale 1ns / 1ps

module tb_nn_top;

    reg        clk;
    reg        rst_n;
    reg        start;
    wire [1:0] predicted_class;
    wire       done;

    nn_top uut (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .predicted_class (predicted_class),
        .done            (done)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        start = 0;

        #100;
        rst_n = 1;
        #20;

        $display("========================================");
        $display(" nn_top Integration Test");
        $display(" Test input: first sample from test_data.mem");
        $display("========================================");
        $display("");

        // Pulse start
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for done (timeout after 500 cycles)
        repeat (500) begin
            @(posedge clk);
            if (done) disable repeat_block;
        end : repeat_block

        if (done) begin
            $display("Inference COMPLETE.");
            $display("  Predicted class: %0d", predicted_class);
            $display("  (Compare with expected label from test_data.mem line 5)");
        end else begin
            $display("TIMEOUT: done never asserted after 500 cycles.");
            $display("  Check FSM logic in nn_top.v");
        end

        $display("");
        $display("========================================");
        #100;
        $finish;
    end

endmodule
```

---

## Step 3: Create the Basys3 XDC Constraints File

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\vivado\nn_top.xdc` with EXACTLY this content:

```tcl
## XDC Constraints — Basys3 (XC7A35T-CPG236-1)
## For nn_top module

## ─── Clock (100 MHz) ──────────────────────────────────────────────────────────
set_property PACKAGE_PIN W5 [get_ports clk]
    set_property IOSTANDARD LVCMOS33 [get_ports clk]
    create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ─── Buttons ──────────────────────────────────────────────────────────────────
## Center button = reset (active-low externally, directly wired to rst_n)
set_property PACKAGE_PIN U18 [get_ports rst_n]
    set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## Left button = start inference
set_property PACKAGE_PIN W19 [get_ports start]
    set_property IOSTANDARD LVCMOS33 [get_ports start]

## ─── LEDs (predicted class + done) ────────────────────────────────────────────
## LED 0 = predicted_class[0]
set_property PACKAGE_PIN U16 [get_ports {predicted_class[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {predicted_class[0]}]

## LED 1 = predicted_class[1]
set_property PACKAGE_PIN E19 [get_ports {predicted_class[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {predicted_class[1]}]

## LED 15 = done (rightmost LED, easy to spot)
set_property PACKAGE_PIN L1 [get_ports done]
    set_property IOSTANDARD LVCMOS33 [get_ports done]
```

---

## Step 4: Run Integration Simulation

```powershell
iverilog -o sim/tb_nn_top.vvp sim/tb_nn_top.v src/nn_top.v src/layer.v src/neuron.v
vvp sim/tb_nn_top.vvp
```

---

## Step 5: Verify

Expected console output:
```
========================================
 nn_top Integration Test
 Test input: first sample from test_data.mem
========================================

Inference COMPLETE.
  Predicted class: X
  (Compare with expected label from test_data.mem line 5)

========================================
```

If it prints `TIMEOUT`, the FSM is stuck — check state transitions in `nn_top.v`.

The predicted class (0, 1, or 2) should match the expected label from `test_data.mem` line 5 (the 5th line, which is the label for the first test sample).

---

## Done ✓ → Proceed to TASK6_VIVADO.md
