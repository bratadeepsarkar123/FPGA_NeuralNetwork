# TASK 2 — Python: Train Model & Export .mem Files
**Agent:** Create the file exactly as specified. Run it. Verify the output.  
**Prereq:** TASK1_SETUP.md must be complete (folders must exist).  
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`

---

## Background (read once, don't question it)

- We train a tiny neural network on the Iris dataset (150 samples, 4 features, 3 classes).
- After training, ALL weights and biases must be converted to **Q8 fixed-point**:
  - Formula: `q = int(round(float_val * 256))`
  - Clamp: `q = max(-32768, min(32767, q))`
  - Stored as **16-bit signed hex** (4 hex digits), two's complement for negatives.
- Files are written one hex value per line, no prefix, no comma.
- Example line in .mem file: `0100` (=256 in decimal = 1.0 in Q8)
- Example negative: `-128` decimal → `FF80` in hex (two's complement 16-bit)

---

## Step 1: Install dependencies

```powershell
pip install scikit-learn tensorflow numpy
```

---

## Step 2: Create the Python script

Create file `c:\Users\brata\Downloads\FPGA_NeuralNetwork\python\train_and_export.py` with EXACTLY this content:

```python
"""
FPGA Neural Network — Training & Weight Export Script
Student: Bratadeep Sarkar, Roll: 240285
Dataset: Iris (4 features, 3 classes)
Architecture: 4 -> 8 (ReLU) -> 3 (Softmax)
Fixed-point: Q8 (multiply by 256, 16-bit signed)
"""

import numpy as np
import os
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import tensorflow as tf
from tensorflow import keras

# ─── 1. REPRODUCIBILITY ────────────────────────────────────────────────────────
np.random.seed(42)
tf.random.set_seed(42)

# ─── 2. LOAD AND PREPROCESS DATA ───────────────────────────────────────────────
iris = load_iris()
X = iris.data.astype(np.float32)   # shape: (150, 4)
y = iris.target                     # 0, 1, or 2

# Normalise inputs (mean=0, std=1) — same scaler used for test export
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

X_train, X_test, y_train, y_test = train_test_split(
    X_scaled, y, test_size=0.2, random_state=42, stratify=y)

# ─── 3. BUILD AND TRAIN MODEL ──────────────────────────────────────────────────
model = keras.Sequential([
    keras.layers.Dense(8, activation='relu', input_shape=(4,),
                        kernel_initializer='glorot_uniform', name='hidden'),
    keras.layers.Dense(3, activation='softmax', name='output')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

model.fit(X_train, y_train,
          epochs=200, batch_size=32,
          validation_split=0.1,
          verbose=0)

# ─── 4. EVALUATE ───────────────────────────────────────────────────────────────
loss, acc = model.evaluate(X_test, y_test, verbose=0)
print(f"Test accuracy: {acc*100:.1f}%  (must be > 90% to proceed)")
assert acc > 0.90, f"Accuracy too low: {acc}. Re-run to get different seed."

# ─── 5. EXTRACT WEIGHTS ────────────────────────────────────────────────────────
hidden_layer = model.get_layer('hidden')
output_layer = model.get_layer('output')

W_hidden = hidden_layer.get_weights()[0]   # shape: (4, 8)
b_hidden  = hidden_layer.get_weights()[1]  # shape: (8,)
W_output  = output_layer.get_weights()[0]  # shape: (8, 3)
b_output  = output_layer.get_weights()[1]  # shape: (3,)

print(f"\nWeight shapes:")
print(f"  W_hidden:  {W_hidden.shape}  (4 inputs × 8 neurons)")
print(f"  b_hidden:  {b_hidden.shape}")
print(f"  W_output:  {W_output.shape}  (8 inputs × 3 neurons)")
print(f"  b_output:  {b_output.shape}")

# ─── 6. QUANTISE TO Q8 ─────────────────────────────────────────────────────────
def to_q8(val):
    """Convert float to 16-bit signed Q8 integer."""
    q = int(round(float(val) * 256))
    q = max(-32768, min(32767, q))
    return q

def to_hex16(val):
    """Convert integer to 4-char uppercase hex (two's complement for negatives)."""
    q = to_q8(val)
    if q < 0:
        q = q + 65536  # two's complement 16-bit
    return f"{q:04X}"

# ─── 7. WRITE .mem FILES ───────────────────────────────────────────────────────
weights_dir = os.path.join(os.path.dirname(__file__), '..', 'weights')
os.makedirs(weights_dir, exist_ok=True)

# weights_hidden.mem: 32 values
# Layout: neuron 0 weights (inputs 0,1,2,3), neuron 1 weights, ..., neuron 7
# W_hidden shape is (4, 8) so W_hidden[:,n] = weights for neuron n
with open(os.path.join(weights_dir, 'weights_hidden.mem'), 'w') as f:
    for neuron in range(8):
        for inp in range(4):
            f.write(to_hex16(W_hidden[inp, neuron]) + '\n')
print(f"Wrote weights_hidden.mem — {8*4} values")

# weights_output.mem: 24 values
# W_output shape is (8, 3), W_output[:,n] = weights for output neuron n
with open(os.path.join(weights_dir, 'weights_output.mem'), 'w') as f:
    for neuron in range(3):
        for inp in range(8):
            f.write(to_hex16(W_output[inp, neuron]) + '\n')
print(f"Wrote weights_output.mem — {3*8} values")

# biases_hidden.mem: 8 values
with open(os.path.join(weights_dir, 'biases_hidden.mem'), 'w') as f:
    for n in range(8):
        f.write(to_hex16(b_hidden[n]) + '\n')
print(f"Wrote biases_hidden.mem — 8 values")

# biases_output.mem: 3 values
with open(os.path.join(weights_dir, 'biases_output.mem'), 'w') as f:
    for n in range(3):
        f.write(to_hex16(b_output[n]) + '\n')
print(f"Wrote biases_output.mem — 3 values")

# test_data.mem: 10 test samples
# Format per sample: 4 input lines then 1 label line = 5 lines per sample
# Inputs are Q8 quantised scaled values; label is raw integer (0,1,2)
# Pick first 10 from X_test (already scaled)
with open(os.path.join(weights_dir, 'test_data.mem'), 'w') as f:
    for i in range(10):
        for feat in range(4):
            f.write(to_hex16(X_test[i, feat]) + '\n')
        f.write(f"{y_test[i]:04X}" + '\n')  # label as hex
print(f"Wrote test_data.mem — 10 samples × 5 lines = 50 lines")

# ─── 8. SANITY CHECK ───────────────────────────────────────────────────────────
print("\n--- Sanity check: first 5 test predictions ---")
preds = np.argmax(model.predict(X_test[:5], verbose=0), axis=1)
for i in range(5):
    status = "OK" if preds[i] == y_test[i] else "MISMATCH"
    print(f"  Sample {i}: expected={y_test[i]}, predicted={preds[i]}  {status}")

print("\n--- Q8 range check ---")
all_weights = np.concatenate([W_hidden.flatten(), W_output.flatten(),
                               b_hidden.flatten(), b_output.flatten()])
max_abs = np.max(np.abs(all_weights))
print(f"  Max absolute float weight: {max_abs:.4f}")
print(f"  Max Q8 value: {to_q8(max_abs)} (must be < 32767)")
if to_q8(max_abs) < 32767:
    print("  Q8 range OK — no overflow")
else:
    print("  WARNING: Q8 overflow! Some weights clipped.")

print("\nAll .mem files written successfully. Proceed to TASK3_NEURON.md")
```

---

## Step 3: Run the script

```powershell
cd c:\Users\brata\Downloads\FPGA_NeuralNetwork
python python/train_and_export.py
```

---

## Step 4: Verify output

**Expected terminal output (approximate):**
```
Test accuracy: 9X.X%  (must be > 90% to proceed)
Wrote weights_hidden.mem — 32 values
Wrote weights_output.mem — 24 values
Wrote biases_hidden.mem — 8 values
Wrote biases_output.mem — 3 values
Wrote test_data.mem — 10 samples × 5 lines = 50 lines
--- Sanity check: first 5 test predictions ---
  Sample 0: expected=X, predicted=X  OK
  ...
Q8 range OK — no overflow
All .mem files written successfully.
```

**File check:**
```powershell
Get-ChildItem c:\Users\brata\Downloads\FPGA_NeuralNetwork\weights\
(Get-Content c:\Users\brata\Downloads\FPGA_NeuralNetwork\weights\weights_hidden.mem).Count
```
`weights_hidden.mem` must have exactly **32 lines**.  
`weights_output.mem` must have exactly **24 lines**.  
`biases_hidden.mem` must have exactly **8 lines**.  
`biases_output.mem` must have exactly **3 lines**.  
`test_data.mem` must have exactly **50 lines**.

**Each line must be exactly 4 uppercase hex characters, e.g.: `017E`, `FF80`, `0000`**

---

## If it fails

- "No module named sklearn" → run `pip install scikit-learn`
- "No module named tensorflow" → run `pip install tensorflow`
- Accuracy < 90% → run script again (random seed may vary slightly)
- Overflow warning → weights are too large; add `W_hidden / 2` rescaling (ask planner)

---

## Done ✓ → Proceed to TASK3_NEURON.md
