# TASK 1 — Setup: Folder Structure & README
**Agent:** Execute ALL steps exactly as written. No decisions needed.  
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`  
**Output check:** Run the verification commands at the end — all must pass.

---

## Step 1: Create all required folders

Run this in PowerShell from `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`:

```powershell
New-Item -ItemType Directory -Force -Path src
New-Item -ItemType Directory -Force -Path sim
New-Item -ItemType Directory -Force -Path weights
New-Item -ItemType Directory -Force -Path python
New-Item -ItemType Directory -Force -Path vivado
New-Item -ItemType Directory -Force -Path docs
New-Item -ItemType Directory -Force -Path agents
```

---

## Step 2: Create README.md

Create the file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\README.md` with EXACTLY this content:

```markdown
# Neural Networks on FPGAs — Final Project

**Name:** Bratadeep Sarkar  
**Roll Number:** 240285  
**FPGA Board:** Basys3 (Artix-7 XC7A35T)

---

## Project Description

A 2-layer feedforward neural network implemented in Verilog that classifies
Iris flower inputs into 3 classes (Setosa, Versicolour, Virginica).
Weights are trained in Python (scikit-learn + TensorFlow), quantized to
Q8 fixed-point (16-bit signed), and exported as .mem files loaded by Verilog
using $readmemh. The design is synthesized for the Basys3 FPGA board.

Network architecture: 4 inputs → 8 hidden neurons (ReLU) → 3 output neurons (Softmax/argmax)

---

## How to Run the Python Script

```bash
cd python
pip install scikit-learn tensorflow numpy
python train_and_export.py
```

This generates all `.mem` files in the `weights/` folder.

---

## How to Simulate (Icarus Verilog)

```bash
# Neuron testbench
iverilog -o sim/tb_neuron.vvp sim/tb_neuron.v src/neuron.v
vvp sim/tb_neuron.vvp

# Layer testbench
iverilog -o sim/tb_layer.vvp sim/tb_layer.v src/layer.v src/neuron.v
vvp sim/tb_layer.vvp
```

---

## How to Synthesize in Vivado

1. Open Vivado → Create New RTL Project → select board: Basys3 (xc7a35tcpg236-1)
2. Add sources: all `.v` files from `src/`
3. Add constraints: `vivado/nn_top.xdc`
4. Click Run Synthesis → Run Implementation → Generate Bitstream
5. Open Hardware Manager → Auto Connect → Program Device

---

## Results

| Metric | Value |
|--------|-------|
| LUT Utilisation | _% (fill after synthesis) |
| Worst Negative Slack (WNS) | _ ns (fill after synthesis) |

---

## Verification Results

| Test # | Input Values | Expected Class | FPGA Output |
|--------|-------------|----------------|-------------|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
```

---

## Step 3: Verify

Run this and confirm all folders exist:

```powershell
Get-ChildItem -Directory "c:\Users\brata\Downloads\FPGA_NeuralNetwork\" | Select-Object Name
```

Expected output must include: `src`, `sim`, `weights`, `python`, `vivado`, `docs`, `agents`

Also confirm README exists:
```powershell
Test-Path "c:\Users\brata\Downloads\FPGA_NeuralNetwork\README.md"
```
Must return: `True`

---

## Done ✓ → Proceed to TASK2_PYTHON.md
