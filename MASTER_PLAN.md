# FPGA Neural Network — Master Plan
**Student:** Bratadeep Sarkar | **Roll:** 240285  
**Board:** Basys3 (Artix-7 XC7A35T, 100 MHz clock, W5 pin)  
**GitHub Repo:** https://github.com/electricalengineersiitk/Winter-projects-25-26.git  
**Submission path inside repo:** `NEURAL NETWORKS ON FPGAS/ends_term/project/bratadeepsarkar_240285/`  
**Local workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`  
**Deadline:** 10 April 2025

---

## Agent Task Queue (execute IN ORDER — each depends on the previous)

| # | Agent Doc | What it produces | Blocking? |
|---|-----------|------------------|-----------|
| 1 | `agents/TASK1_SETUP.md` | Folder structure + README.md | YES |
| 2 | `agents/TASK2_PYTHON.md` | `python/train_and_export.py` + all `.mem` files | YES |
| 3 | `agents/TASK3_NEURON.md` | `src/neuron.v` + `sim/tb_neuron.v` + simulation pass | YES |
| 4 | `agents/TASK4_LAYER.md` | `src/layer.v` + `sim/tb_layer.v` + simulation pass | YES |
| 5 | `agents/TASK5_TOPLEVEL.md` | `src/nn_top.v` + `sim/tb_nn_top.v` + `vivado/nn_top.xdc` | YES |
| 6 | `agents/TASK6_VIVADO.md` | Vivado synthesis + bitstream (MANUAL — needs lab PC) | NO |
| 7 | `agents/TASK7_REPORT.md` | `docs/report.pdf` + final README update | NO |

---

## Global Constants (use EXACTLY these everywhere)

```
STUDENT_NAME     = bratadeepsarkar
ROLL_NO          = 240285
FOLDER_NAME      = bratadeepsarkar_240285

NN_ARCH:
  INPUT_SIZE     = 4
  HIDDEN_NEURONS = 8
  OUTPUT_NEURONS = 3
  ACTIVATION_H   = ReLU
  ACTIVATION_O   = Softmax (argmax in hardware)

FIXED_POINT:
  FORMAT         = Q8  (multiply float by 256, round to int)
  WIDTH          = 16 bits signed
  RANGE          = [-32768, 32767]
  TRUNCATE_BITS  = result[23:8]  (for Q8 × Q8 → Q8)

BOARD:
  NAME           = Basys3
  FPGA_PART      = xc7a35tcpg236-1
  CLOCK_PIN      = W5
  CLOCK_PERIOD   = 10.000 ns  (100 MHz)
  RESET_PIN      = U18  (center button, active LOW after inversion)
  START_PIN      = T18  (left button)
  LED_CLASS0     = U16
  LED_CLASS1     = E19
  LED_CLASS2     = U19
  LED_DONE       = V19
  IOSTANDARD     = LVCMOS33

SIMULATION_TOOL  = Icarus Verilog (iverilog + vvp)
```

---

## File Map (final state of workspace)

```
c:\Users\brata\Downloads\FPGA_NeuralNetwork\
├── agents\                    ← agent instruction docs (this repo)
│   ├── TASK1_SETUP.md
│   ├── TASK2_PYTHON.md
│   ├── TASK3_NEURON.md
│   ├── TASK4_LAYER.md
│   ├── TASK5_TOPLEVEL.md
│   ├── TASK6_VIVADO.md
│   └── TASK7_REPORT.md
├── src\
│   ├── neuron.v
│   ├── layer.v
│   └── nn_top.v
├── sim\
│   ├── tb_neuron.v
│   ├── tb_layer.v
│   └── tb_nn_top.v
├── weights\
│   ├── weights_hidden.mem     ← 32 values: 8 neurons × 4 inputs
│   ├── weights_output.mem     ← 24 values: 3 neurons × 8 inputs
│   ├── biases_hidden.mem      ← 8 values
│   ├── biases_output.mem      ← 3 values
│   └── test_data.mem          ← 50 values: 10×(4 inputs + label)
├── python\
│   └── train_and_export.py
├── vivado\
│   └── nn_top.xdc
├── docs\
│   └── report.pdf             ← written by student
├── README.md
└── MASTER_PLAN.md             ← this file
```
