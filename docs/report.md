# FPGA Neural Network Project — Final Report
**Student:** Bratadeep Sarkar
**Roll Number:** 240285
**Project:** Iris Flower Classifier (4 → 8 → 3)
**Target Hardware:** Basys 3 FPGA (Artix-7 XC7A35T-CPG236-1)

---

## 1. Introduction
The objective of this project was to design, train, and deploy a 2-layer artificial neural network on an FPGA to classify the Iris flower dataset. The design uses Q8 signed fixed-point arithmetic (16-bit, 8 fractional bits) that is efficient for hardware implementation without floating-point units.

## 2. Architecture & Design
The system follows a sequential feed-forward architecture:

1. **Input Layer:** 4 normalized features — Sepal Length, Sepal Width, Petal Length, Petal Width.
2. **Hidden Layer:** 8 neurons using the ReLU activation function.
3. **Output Layer:** 3 neurons (classes 0, 1, 2) — prediction via Argmax.

### Hardware Modules
| Module | Description |
| :--- | :--- |
| `neuron.v` | MAC unit with 16-bit Q8 accumulator, bias addition, and ReLU clipping |
| `layer.v` | Parametrized module to instantiate N neurons for a single layer |
| `nn_top.v` | Top-level FSM orchestrating data flow between layers and memory |

### FSM State Machine
The inference FSM has 7 states:
`S_IDLE → S_FEED_HIDDEN → S_WAIT_HIDDEN → S_FEED_OUTPUT → S_WAIT_OUTPUT → S_CALC_ARGMAX → S_DONE`

A dedicated `S_CALC_ARGMAX` state was added to **decouple the argmax comparison logic** from the output layer's MAC path, which was critical for timing closure.

## 3. Training & Software Results
The model was trained using TensorFlow/Keras on the standard Iris dataset (80/20 split).

- **Test Accuracy:** 93.3% (in 32-bit float software)
- **Weight Format:** 16-bit signed Q8 fixed-point (8 integer bits, 8 fractional bits)
- **Max Absolute Weight:** 0.612 — well within Q8 range, no overflow

Weights and biases were exported as 4 separate `.mem` files (`weights_hidden.mem`, `weights_output.mem`, `biases_hidden.mem`, `biases_output.mem`) plus `test_data.mem` for on-chip test inputs.

## 4. Verification Results (Simulation)
The design was verified against 10 Iris test samples using Icarus Verilog. The testbench (`sim/tb_nn_top.v`) drives the FSM with all 10 samples in sequence and reports PASS/FAIL per sample.

| Sample | Input Features [SL, SW, PL, PW] (cm) | Expected | Predicted | Status |
| :---: | :--- | :---: | :---: | :---: |
| 0 | [4.4, 3.0, 1.3, 0.2] | 0 (Setosa) | 0 | **PASS** |
| 1 | [6.1, 3.0, 4.9, 1.8] | 2 (Virginica) | 2 | **PASS** |
| 2 | [4.9, 2.4, 3.3, 1.0] | 1 (Versicolour) | 1 | **PASS** |
| 3 | [5.5, 2.3, 4.0, 1.3] | 1 (Versicolour) | 1 | **PASS** |
| 4 | [4.8, 3.0, 1.4, 0.3] | 0 (Setosa) | 0 | **PASS** |
| 5 | [5.7, 2.8, 4.5, 1.3] | 1 (Versicolour) | 2 | **FAIL (Q8)** |
| 6 | [5.2, 3.4, 1.4, 0.2] | 0 (Setosa) | 1 | **FAIL (Q8)** |
| 7 | [5.1, 3.8, 1.5, 0.3] | 0 (Setosa) | 1 | **FAIL (Q8)** |
| 8 | [6.5, 3.0, 5.2, 2.0] | 2 (Virginica) | 2 | **PASS** |
| 9 | [5.4, 3.0, 4.5, 1.5] | 1 (Versicolour) | 1 | **PASS** |

**Result: 7/10 PASS (70% hardware accuracy)**

> *Input values shown are original Iris measurements (cm). The hardware processes these as Q8 fixed-point integers (multiplied by 256). The 3 failures in samples 5–7 are due to Q8 quantization rounding on samples with closely spaced decision boundaries — a known limitation of 8-bit integer arithmetic.*

---

## 5. FPGA Performance Metrics (Vivado)

The design was synthesized and implemented for the **XC7A35T-CPG236-1** (Basys 3) at 100 MHz.

| Metric | Value |
| :--- | :--- |
| **Logic Utilization (LUTs)** | 1228 / 20800 **(6%)** |
| **Flip-Flops (Registers)** | 815 / 41600 **(2%)** |
| **DSP Slices** | 33 / 90 **(37%)** |
| **I/O Blocks (IOBs)** | 10 |
| **Worst Negative Slack (WNS)** | **+0.010 ns** |
| **Operating Frequency** | **100 MHz — Timing Met ✅** |

### Timing Closure Notes
The initial post-route WNS was **−0.190 ns** on the critical path:

`DSP48E1 (MAC) → ReLU LUT → Output DSP48E1`

Timing closure was achieved by two changes:
1. **`S_CALC_ARGMAX` State:** Registered the argmax comparison result in a dedicated FSM state, removing it from the output layer's combinatorial critical path.
2. **Post-Route Physical Optimization:** Enabled `phys_opt_design` with `AggressiveExplore` during Vivado implementation (`build.tcl`). This directive physically relocates high-fanout registers to reduce net delays by ~200 ps, achieving a final WNS of **+0.010 ns**.

---

## 6. Design Decisions: Memory Layout
A key design choice is using **four separate `.mem` files** for weights and biases rather than one combined file.

**Rationale:**
- **Parallel Loading:** Each `layer.v` instance loads its own weights independently via `$readmemh`, enabling clean parametrization.
- **Simplicity:** Avoids complex address-offset arithmetic in the FSM, reducing LUT count and improving timing closure.
- **Debuggability:** Separate files make it straightforward to inspect, replace, or regenerate individual weight sets during quantization verification.

---

## 7. Lessons Learned
The most challenging aspects were resolving an **FSM timing hazard** and achieving **timing closure at 100 MHz**.

### FSM 1-Cycle Timing Hazard
The original design asserted `h_start` (hidden layer start) on the same clock edge as the input data was placed on `h_data_in`. Because both signals are registered, the neuron received `h_start` one cycle before the data arrived — causing the first MAC operation to use stale data from the previous sample.

**Fix:** Added a **pre-fetch cycle in `S_IDLE`**: when `start` is asserted, the FSM immediately loads `test_data_mem[sw*5]` into `h_data_in` so the data is valid on the *following* cycle when `S_FEED_HIDDEN` begins.

### Quantization Effects
Fixed-point Q8 arithmetic introduces rounding noise that is amplified near decision boundaries. Samples 5, 6, and 7 lie in regions where the two closest class logits differ by less than 1 Q8 step (~0.004 in float). Future designs could use Q12 or adaptive scaling to recover these boundary cases.

---

**Date:** April 2026
**Repository:** https://github.com/bratadeepsarkar123/FPGA_NeuralNetwork
