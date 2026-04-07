# TASK 4 — Verilog: The Layer Module
**Agent:** Create the Verilog source and testbench files EXACTLY as specified. Run the simulation. Verify the output.  
**Prereq:** TASK2_PYTHON.md (`.mem` files must exist) AND TASK3_NEURON.md (`neuron.v` must exist).  
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`

---

## Background: The Hidden Layer

- 8 neurons process the **same 4 inputs in parallel**.
- Each neuron has its **own 4 weights** and **own bias**, loaded from `.mem` files.
- The layer module contains a **small FSM** (input counter) that feeds the 4 inputs sequentially.
- Weight memory layout in `weights_hidden.mem` (32 values total):
  - Lines 0–3: Neuron 0's 4 weights (for inputs 0, 1, 2, 3)
  - Lines 4–7: Neuron 1's 4 weights
  - Lines 8–11: Neuron 2's 4 weights
  - ...
  - Lines 28–31: Neuron 7's 4 weights
- Bias memory layout in `biases_hidden.mem` (8 values): one per neuron.

---

## Step 1: Create the Layer Module

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\src\layer.v` with EXACTLY this content:

```verilog
`timescale 1ns / 1ps
//
// Hidden Layer — 8 Neurons in Parallel
// Loads weights/biases from .mem files via $readmemh.
//
// Interface:
//   Pulse start=1 for 1 cycle. Then feed data_in for 4 consecutive cycles
//   (input_idx 0, 1, 2, 3). Assert last=1 on the 4th cycle (input_idx=3).
//   When valid_layer goes high, all 8 neuron outputs are ready in out_vector.
//
module layer #(
    parameter NUM_NEURONS  = 8,
    parameter NUM_INPUTS   = 4,
    parameter WEIGHT_FILE  = "weights/weights_hidden.mem",
    parameter BIAS_FILE    = "weights/biases_hidden.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,       // pulse to trigger (same as neuron start)
    input  wire [15:0] data_in,     // one input value per cycle
    input  wire [1:0]  input_idx,   // which input (0..3) is being fed
    input  wire        last,        // pulse on final input (input_idx == 3)
    output wire [127:0] out_vector, // 8 neurons × 16 bits = 128 bits
    output wire        valid_layer  // high for 1 cycle when all outputs ready
);

    // ── Weight & Bias Memory ──────────────────────────────────────────────
    // Weight layout: neuron_i weights at indices [i*NUM_INPUTS .. i*NUM_INPUTS+3]
    reg [15:0] weights_mem [0:NUM_NEURONS*NUM_INPUTS-1];  // 32 values
    reg [15:0] biases_mem  [0:NUM_NEURONS-1];             // 8 values

    initial begin
        $readmemh(WEIGHT_FILE, weights_mem);
        $readmemh(BIAS_FILE, biases_mem);
    end

    // ── Instantiate 8 Neurons ─────────────────────────────────────────────
    // Each neuron gets the same data_in, start, last signals.
    // Each neuron gets its own weight (looked up by neuron index + input_idx).
    wire [7:0] neuron_valid;  // valid signal from each neuron

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_inst
            neuron n (
                .clk       (clk),
                .rst_n     (rst_n),
                .start     (start),
                .data_in   (data_in),
                .weight_in (weights_mem[i * NUM_INPUTS + input_idx]),
                .bias      (biases_mem[i]),
                .last      (last),
                .out       (out_vector[i*16 +: 16]),
                .valid     (neuron_valid[i])
            );
        end
    endgenerate

    // All neurons run the same number of cycles, so they all finish together.
    // Use neuron 0's valid as the layer valid (AND with others for safety).
    assign valid_layer = neuron_valid[0];

endmodule
```

---

## Step 2: Create the Testbench

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\sim\tb_layer.v` with EXACTLY this content:

```verilog
`timescale 1ns / 1ps

module tb_layer;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [15:0] data_in;
    reg  [1:0]  input_idx;
    reg         last;
    wire [127:0] out_vector;
    wire        valid_layer;

    // Instantiate UUT
    layer uut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .data_in     (data_in),
        .input_idx   (input_idx),
        .last        (last),
        .out_vector  (out_vector),
        .valid_layer (valid_layer)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Init
        clk       = 0;
        rst_n     = 0;
        start     = 0;
        data_in   = 0;
        input_idx = 0;
        last      = 0;

        // Reset
        #100;
        rst_n = 1;
        #20;

        $display("============================================");
        $display(" Layer Testbench (8 neurons, 4 inputs)");
        $display(" Weights from: weights/weights_hidden.mem");
        $display(" Biases from:  weights/biases_hidden.mem");
        $display("============================================");
        $display("");

        // Feed 4 inputs: [1.0, 0.5, 0.625, 0.125] in Q8
        // Q8 values: 1.0=0x0100, 0.5=0x0080, 0.625=0x00A0, 0.125=0x0020
        $display("Feeding inputs: [1.0, 0.5, 0.625, 0.125]");
        $display("");

        // Input 0 (start)
        @(posedge clk);
        data_in   = 16'h0100;   // 1.0
        input_idx = 2'd0;
        start     = 1;
        last      = 0;

        // Input 1 (middle)
        @(posedge clk);
        start     = 0;
        data_in   = 16'h0080;   // 0.5
        input_idx = 2'd1;

        // Input 2 (middle)
        @(posedge clk);
        data_in   = 16'h00A0;   // 0.625
        input_idx = 2'd2;

        // Input 3 (last)
        @(posedge clk);
        data_in   = 16'h0020;   // 0.125
        input_idx = 2'd3;
        last      = 1;

        @(posedge clk);
        last = 0;
        data_in = 0;

        // Wait for valid
        wait(valid_layer);
        @(posedge clk); // let output settle

        $display("--- Layer Outputs (Q8 hex) ---");
        for (i = 0; i < 8; i = i + 1) begin
            $display("  Neuron %0d: 0x%04h  (decimal: %0d)",
                     i,
                     out_vector[i*16 +: 16],
                     out_vector[i*16 +: 16]);
        end
        $display("");
        $display("Verify: each output should be >= 0 (ReLU enforces this).");
        $display("Values depend on trained weights in .mem files.");
        $display("");
        $display("Layer test DONE.");

        #100;
        $finish;
    end

endmodule
```

---

## Step 3: Verify prereqs exist

Before compiling, confirm the `.mem` files were generated by Task 2:

```powershell
Test-Path "c:\Users\brata\Downloads\FPGA_NeuralNetwork\weights\weights_hidden.mem"
Test-Path "c:\Users\brata\Downloads\FPGA_NeuralNetwork\weights\biases_hidden.mem"
```

Both must return `True`. If not, go back and run TASK2_PYTHON.md first.

---

## Step 4: Run Simulation (Icarus Verilog)

```powershell
iverilog -o sim/tb_layer.vvp sim/tb_layer.v src/layer.v src/neuron.v
vvp sim/tb_layer.vvp
```

---

## Step 5: Verify Output

The console should print something like:
```
============================================
 Layer Testbench (8 neurons, 4 inputs)
 Weights from: weights/weights_hidden.mem
 Biases from:  weights/biases_hidden.mem
============================================

Feeding inputs: [1.0, 0.5, 0.625, 0.125]

--- Layer Outputs (Q8 hex) ---
  Neuron 0: 0xXXXX  (decimal: XXXX)
  Neuron 1: 0xXXXX  (decimal: XXXX)
  ...
  Neuron 7: 0xXXXX  (decimal: XXXX)

Verify: each output should be >= 0 (ReLU enforces this).
Values depend on trained weights in .mem files.

Layer test DONE.
```

**What to check:**
- All 8 neurons produce output (no hangs).
- No output is negative (ReLU should prevent this — all values ≥ 0).
- Some outputs might be 0 (ReLU killed them) and that's normal.
- If the simulation hangs, double-check that `neuron.v` correctly handles the `last` signal.

---

## Done ✓ → Proceed to TASK5_TOPLEVEL.md
