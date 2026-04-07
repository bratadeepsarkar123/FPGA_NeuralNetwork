# TASK 3 — Verilog: The Neuron Module
**Agent:** Create the Verilog source and testbench files EXACTLY as specified. Run the simulation. Verify the output.  
**Prereq:** `iverilog` must be installed. Folders must exist (TASK1).  
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`

---

## Background: The Neuron

A neuron performs: `Output = ReLU( Σ(Input_i × Weight_i) + Bias )`.

This design uses **16-bit signed Q8 fixed-point** numbers:
- **Multiplication:** 16-bit × 16-bit → 32-bit result (Q8 × Q8 = Q16 format).
- **Accumulation:** Stored in a 32-bit signed register.
- **Bias alignment:** Bias is Q8 (16-bit). Products accumulated are Q16 (32-bit). To add bias, shift it left by 8 bits: `bias << 8`.
- **ReLU + truncation:** If final sum is negative → output 0. Otherwise → extract bits `[23:8]` to convert Q16 back to Q8.

**Protocol for feeding inputs (IMPORTANT — read carefully):**

| Cycle | `start` | `last` | What happens |
|-------|---------|--------|-------------|
| First input | 1 | 0 | `acc = product` (clear and load first) |
| Middle inputs | 0 | 0 | `acc = acc + product` |
| Last input | 0 | 1 | `sum = acc + product + (bias<<8)`, apply ReLU, assert `valid` |
| Single input | 1 | 1 | `sum = product + (bias<<8)`, apply ReLU, assert `valid` |

Note: The `last` cycle's product IS included in the sum. This is critical.

---

## Step 1: Create the Neuron Module

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\src\neuron.v` with EXACTLY this content:

```verilog
`timescale 1ns / 1ps
//
// Neuron Module (MAC + ReLU)
// Q8 Fixed-point (16-bit signed)
//
// Protocol:
//   Pulse start=1 on the FIRST input cycle.
//   Pulse last=1 on the LAST input cycle.
//   For a single-input neuron, both start=1 and last=1 on the same cycle.
//   The product on the last cycle IS accumulated.
//
module neuron (
    input  wire        clk,
    input  wire        rst_n,      // active-low reset
    input  wire        start,      // pulse high for 1 cycle to begin
    input  wire [15:0] data_in,    // one input value at a time (Q8 format)
    input  wire [15:0] weight_in,  // matching weight for that input
    input  wire [15:0] bias,       // bias value (Q8 format)
    input  wire        last,       // pulse high on the final input
    output reg  [15:0] out,        // result after ReLU (Q8 format)
    output reg         valid       // high for 1 cycle when output is ready
);

    // Internal 32-bit accumulator (Q16 format after multiply)
    reg signed [31:0] acc;

    // Signed multiplication: Q8 * Q8 = Q16 (32-bit)
    wire signed [31:0] product;
    assign product = $signed(data_in) * $signed(weight_in);

    // Bias shifted to Q16 alignment
    wire signed [31:0] bias_shifted;
    assign bias_shifted = $signed(bias) <<< 8;

    // Final sum for ReLU (computed combinationally for use in the last cycle)
    wire signed [31:0] final_sum_start_last;  // for start+last simultaneous
    wire signed [31:0] final_sum_last;        // for last only (multi-input)
    assign final_sum_start_last = product + bias_shifted;
    assign final_sum_last       = acc + product + bias_shifted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            acc   <= 32'sd0;
            out   <= 16'd0;
            valid <= 1'b0;
        end else if (start && last) begin
            // Single-input neuron: compute everything in one cycle
            if (final_sum_start_last[31]) begin
                out <= 16'd0;                          // ReLU: negative → 0
            end else begin
                out <= final_sum_start_last[23:8];     // Q16 → Q8 truncation
            end
            valid <= 1'b1;
            acc   <= 32'sd0;
        end else if (start) begin
            // First input: clear accumulator, load first product
            acc   <= product;
            valid <= 1'b0;
        end else if (last) begin
            // Last input: accumulate, add bias, apply ReLU
            if (final_sum_last[31]) begin
                out <= 16'd0;                          // ReLU: negative → 0
            end else begin
                out <= final_sum_last[23:8];           // Q16 → Q8 truncation
            end
            valid <= 1'b1;
            acc   <= 32'sd0;
        end else begin
            // Middle inputs: accumulate product
            acc   <= acc + product;
            valid <= 1'b0;
        end
    end

endmodule
```

---

## Step 2: Create the Testbench

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\sim\tb_neuron.v` with EXACTLY this content:

```verilog
`timescale 1ns / 1ps

module tb_neuron;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg [15:0] data_in;
    reg [15:0] weight_in;
    reg [15:0] bias;
    reg        last;
    wire [15:0] out;
    wire        valid;

    // Instantiate unit under test
    neuron uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .weight_in(weight_in),
        .bias(bias),
        .last(last),
        .out(out),
        .valid(valid)
    );

    // 100 MHz clock: period = 10 ns
    always #5 clk = ~clk;

    // Task to reset all inputs
    task reset_inputs;
        begin
            start     = 0;
            data_in   = 0;
            weight_in = 0;
            bias      = 0;
            last      = 0;
        end
    endtask

    integer pass_count;
    integer fail_count;

    initial begin
        // Initialise
        clk  = 0;
        rst_n = 0;
        pass_count = 0;
        fail_count = 0;
        reset_inputs;

        // Hold reset for 100 ns
        #100;
        rst_n = 1;
        #20;

        // ================================================================
        // TEST 1: Two-input MAC, bias = 0
        //   1.0 * 1.0 + 0.5 * 2.0 + 0.0 = 2.0
        //   Q8 values: 1.0=0x0100, 0.5=0x0080, 2.0=0x0200
        //   Expected output: 0x0200 (512 decimal = 2.0 in Q8)
        // ================================================================
        $display("--- TEST 1: Two-input MAC (bias=0) ---");

        // Cycle 1: first input (start=1)
        @(posedge clk);
        data_in   = 16'h0100;   // 1.0
        weight_in = 16'h0100;   // 1.0
        bias      = 16'h0000;   // 0.0
        start     = 1;
        last      = 0;

        // Cycle 2: second input (last=1)
        @(posedge clk);
        start     = 0;
        data_in   = 16'h0080;   // 0.5
        weight_in = 16'h0200;   // 2.0
        last      = 1;

        // Cycle 3: deassert last, wait for valid
        @(posedge clk);
        last = 0;

        // Valid appears on the clock edge AFTER last was sampled
        @(posedge clk);
        if (valid !== 1'b1) begin
            $display("  FAIL: valid not asserted");
            fail_count = fail_count + 1;
        end else if (out !== 16'h0200) begin
            $display("  FAIL: out = %0d (0x%04h), expected 512 (0x0200)", out, out);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS: out = %0d (0x%04h)", out, out);
            pass_count = pass_count + 1;
        end
        reset_inputs;

        #20;

        // ================================================================
        // TEST 2: Single-input, negative result → ReLU clips to 0
        //   1.0 * (-1.0) + 0.0 = -1.0 → ReLU → 0
        //   Q8: -1.0 = 0xFF00 (two's complement)
        //   Expected output: 0x0000
        // ================================================================
        $display("--- TEST 2: Single-input ReLU (negative → 0) ---");

        @(posedge clk);
        data_in   = 16'h0100;   // 1.0
        weight_in = 16'hFF00;   // -1.0
        bias      = 16'h0000;
        start     = 1;
        last      = 1;          // single input: start+last same cycle

        @(posedge clk);
        start = 0;
        last  = 0;

        @(posedge clk);
        if (valid !== 1'b1) begin
            $display("  FAIL: valid not asserted");
            fail_count = fail_count + 1;
        end else if (out !== 16'h0000) begin
            $display("  FAIL: out = %0d, expected 0", out);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS: out = %0d", out);
            pass_count = pass_count + 1;
        end
        reset_inputs;

        #20;

        // ================================================================
        // TEST 3: Four-input MAC with bias (matches hidden layer shape)
        //   inputs:  [1.0, 0.5, -0.5, 0.25]
        //   weights: [2.0, 1.0,  1.0, 0.0 ]
        //   bias:    0.5
        //   Expected: 1.0*2.0 + 0.5*1.0 + (-0.5)*1.0 + 0.25*0.0 + 0.5
        //           = 2.0    + 0.5     - 0.5         + 0.0       + 0.5
        //           = 2.5
        //   Q8: 2.5 = 640 = 0x0280
        // ================================================================
        $display("--- TEST 3: Four-input MAC with bias ---");

        // Input 0 (start)
        @(posedge clk);
        data_in   = 16'h0100;   // 1.0
        weight_in = 16'h0200;   // 2.0
        bias      = 16'h0080;   // 0.5
        start     = 1;
        last      = 0;

        // Input 1 (middle)
        @(posedge clk);
        start     = 0;
        data_in   = 16'h0080;   // 0.5
        weight_in = 16'h0100;   // 1.0

        // Input 2 (middle)
        @(posedge clk);
        data_in   = 16'hFF80;   // -0.5 (two's complement)
        weight_in = 16'h0100;   // 1.0

        // Input 3 (last)
        @(posedge clk);
        data_in   = 16'h0040;   // 0.25
        weight_in = 16'h0000;   // 0.0
        last      = 1;

        @(posedge clk);
        last = 0;

        @(posedge clk);
        if (valid !== 1'b1) begin
            $display("  FAIL: valid not asserted");
            fail_count = fail_count + 1;
        end else if (out !== 16'h0280) begin
            $display("  FAIL: out = %0d (0x%04h), expected 640 (0x0280)", out, out);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS: out = %0d (0x%04h)", out, out);
            pass_count = pass_count + 1;
        end

        // ================================================================
        // SUMMARY
        // ================================================================
        #20;
        $display("");
        $display("========================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================");

        if (fail_count > 0)
            $display("  *** SOME TESTS FAILED — FIX neuron.v BEFORE PROCEEDING ***");
        else
            $display("  All tests passed. Proceed to TASK4_LAYER.md");

        $finish;
    end

endmodule
```

---

## Step 3: Run Simulation (Icarus Verilog)

Run these commands from the workspace root `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`:

```powershell
iverilog -o sim/tb_neuron.vvp sim/tb_neuron.v src/neuron.v
vvp sim/tb_neuron.vvp
```

If `iverilog` is not found, install it first:
- Download from https://bleyer.org/icarus/ (Windows installer)
- Or: `choco install iverilog` (if Chocolatey is installed)

---

## Step 4: Verify Output

The console MUST print EXACTLY:
```
--- TEST 1: Two-input MAC (bias=0) ---
  PASS: out = 512 (0x0200)
--- TEST 2: Single-input ReLU (negative → 0) ---
  PASS: out = 0
--- TEST 3: Four-input MAC with bias ---
  PASS: out = 640 (0x0280)

========================================
  RESULTS: 3 PASSED, 0 FAILED
========================================
  All tests passed. Proceed to TASK4_LAYER.md
```

**If ANY test says FAIL:** Do NOT proceed. The neuron module is the most critical component (25 marks). Debug by examining the Q8 math manually:
- Test 1: `(0x0100 × 0x0100) + (0x0080 × 0x0200) = 0x10000 + 0x10000 = 0x20000`. Bits [23:8] = `0x0200`. ✓
- Test 2: `(0x0100 × 0xFF00) = 0xFFFF0000` (negative). ReLU → 0. ✓
- Test 3: Sum of products = `0x20000 + 0x8000 + 0xFFFF8000 + 0x0` = `0x20000`. Plus bias `0x0080 << 8 = 0x8000`. Total = `0x28000`. Bits [23:8] = `0x0280`. ✓

---

## Done ✓ → Proceed to TASK4_LAYER.md
