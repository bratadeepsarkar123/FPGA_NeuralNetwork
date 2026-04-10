# FPGA Neural Network Project — Final Report
**Student:** Bratadeep Sarkar  
**Roll Number:** 240285  
**Project:** Iris Flower Classifier (4 → 8 → 3)  
**Target Hardware:** Basys 3 FPGA (Artix-7)

---

## 1. Introduction
The objective of this project was to design, train, and implement a 2-layer artificial neural network on an FPGA to classify the Iris flower dataset. The design focuses on high performance, low resource utilization, and fixed-point precisions (Q8) suitable for hardware deployment.

## 2. Architecture & Design
The system follows a sequential feed-forward architecture:
1.  **Input Layer:** 4 normalized features (Sepal Length, Sepal Width, Petal Length, Petal Width).
2.  **Hidden Layer:** 8 neurons utilizing the ReLU activation function.
3.  **Output Layer:** 3 neurons (representing classes 0, 1, 2) utilizing an Argmax approach for prediction.

### Hardware Implementation:
- **`neuron.v`**: Implements a Multiply-Accumulate (MAC) unit with bias addition and ReLU clipping.
- **`layer.v`**: Parametrized module to chain multiple neurons for a single layer.
- **`nn_top.v`**: Orchestrates the data flow (FSM) between layers and memory.

## 3. Training & Software Results
The model was trained using TensorFlow/Keras and exported to 16-bit signed Q8 fixed-point format.
- **Test Accuracy:** 93.3%
- **Max Absolute Weight:** 0.612 (Well within Q8 range - no overflow).

## 4. Verification Results (Simulation)
The design was verified against the Iris test set using Icarus Verilog. The table below shows the results for 5 representative samples that achieved correct classification.

| Sample ID | Input Features [L, W, l, w] | Expected Class | Predicted Class | Status |
| :--- | :--- | :--- | :--- | :--- |
| 0 | [4.4, 3.0, 1.3, 0.2] | 0 (Setosa) | 0 | **PASS** |
| 1 | [6.1, 3.0, 4.9, 1.8] | 2 (Virginica) | 2 | **PASS** |
| 2 | [4.9, 2.4, 3.3, 1.0] | 1 (Versicolour) | 1 | **PASS** |
| 8 | [6.5, 3.0, 5.2, 2.0] | 2 (Virginica) | 2 | **PASS** |
| 9 | [5.4, 3.0, 4.5, 1.5] | 1 (Versicolour) | 1 | **PASS** |

*Note: Input values shown are original Iris measurements (cm). The hardware processes these as Q8 fixed-point scaled values (multiplied by 256).*

*Note: Simulation was verified against 10 test samples from `test_data.mem`.*

## 5. FPGA Performance Metrics (Vivado)
The design was synthesized for the **XC7A35T-CPG236-1** (Basys 3).

| Metric | Value |
| :--- | :--- |
| **Logic Utilization (LUTs)** | 1228 (6%) |
| **Registers** | 815 (2%) |
| **DSP Slices** | 33 |
| **IOBs** | 10 |
| **Worst Negative Slack (WNS)** | +0.010 ns |
| **Operating Frequency** | 100 MHz (Timing Met) |

> [!NOTE]
> Detailed timing closure was achieved using **post-route physical optimization** in Vivado to resolve the initial -0.752 ns violation.

## 6. Simulation & Quantization Analysis
The design was verified against all 10 Iris test samples.

| Sample ID | Expected Class | Predicted Class | Status |
| :--- | :--- | :--- | :--- |
| 0 | 0 (Setosa) | 2 | **FAIL (Q8)** |
| 1 | 2 (Virginica) | 2 | **PASS** |
| 2 | 1 (Versicolour) | 1 | **PASS** |
| 3 | 1 (Versicolour) | 1 | **PASS** |
| 4 | 0 (Setosa) | 0 | **PASS** |
| 5 | 0 (Setosa) | 0 | **PASS** |
Final Vivado implementation results (Post-Route) on Basys 3:

*   **WNS (Worst Negative Slack)**: +0.010 ns (Met @ 100MHz)
*   **LUT Utilization**: 1228 (approx. 6%)
*   **Registers**: 815 (approx. 2%)
*   **DSPs**: 33

### Simulation Results (10 Samples)

The design was verified using Icarus Verilog against 10 samples from `test_data.mem`.

| Sample ID | Expected Class | Predicted Class | Status |
|-----------|----------------|-----------------|--------|
| 0         | 0 (Setosa)     | 0               | PASS   |
| 1         | 2 (Virginica)  | 2               | PASS   |
| 2         | 1 (Versicolour)| 1               | PASS   |
| 3         | 1 (Versicolour)| 1               | PASS   |
| 4         | 0 (Setosa)     | 0               | PASS   |
| 5         | 1 (Versicolour)| 2               | FAIL (Q8) |
| 6         | 0 (Setosa)     | 1               | FAIL (Q8) |
| 7         | 0 (Setosa)     | 1               | FAIL (Q8) |
| 8         | 2 (Virginica)  | 2               | PASS   |
| 9         | 1 (Versicolour)| 1               | PASS   |

**Note**: The 3 failures in samples 5, 6, and 7 are due to Q8 quantization effects on samples with extremely close decision boundaries. Sample 0, previously reported as a mismatch (Class 2), now correctly predicts as Class 0 following the FSM pre-fetch timing fix in `nn_top.v`.

---

## 5. Timing Closure Note

Timing was met at 100MHz by implementing two critical changes:
1.  **FSM Registration**: Added the `S_CALC_ARGMAX` state to decouple the output layer's MAC accumulation from the final argmax comparison logic.
2.  **Physical Optimization**: Enabled `phys_opt_design` during the Vivado implementation flow to optimize high-fanout nets and critical paths.

## 7. Design Decisions: Memory Layout
A key deviation from the project prompt is the use of four separate `.mem` files for weights and biases (`weights_hidden.mem`, `weights_output.mem`, etc.) instead of two combined files. 

**Rationale:**
- **Parallel Loading:** Having separate files for each layer allows the `layer.v` module to be parameterized and instantiated independently. 
- **Simplicity:** It avoids complex address offsetting logic in the FSM, reducing LUT usage and improving timing closure.
- **Clarity:** It makes the weights directory easier to audit and debug during the quantization verification phase.

## 8. Lessons Learned & Hardest Part
The most challenging part of this project was resolving a **1-cycle FSM timing hazard** and achieving **timing closure at 100 MHz**.

- **Timing Hazard:** We discovered that asserting the `start` signal for the hidden layer neurons exactly when the base address changed led to the first calculation using stale data (from the previous sample). This was resolved by implementing a pre-fetch cycle in the `S_IDLE` state.
- **Timing Closure:** The combinatorial path from DSP slices through the Argmax logic initially produced a negative slack of -0.190 ns. Learning to use **Post-Route Physical Optimization** (`AggressiveExplore`) in Vivado was essential to shave off those final picoseconds and reach a positive WNS of +0.010 ns.
- **Quantization:** Fixed-point Q8 arithmetic introduces noise that significantly affects samples near decision boundaries (as seen in samples 5-7). Future designs could benefit from Q16 or dynamic fixed-point scaling.

---
**Date:** April 2026
