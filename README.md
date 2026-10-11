# Fixed-Point FIR Filter and Quantized Neural Network Inference Accelerator

RTL design, verification, and synthesis of two FIR filter architectures, extended into a hardware-aware quantization study and RTL implementation of a small neural network inference accelerator — all verified against independent Python reference models and carried through to logic synthesis.

Full write-up: [`project_report.pdf`](./project_report.pdf)

---

## Overview

This project is in two linked parts.

**Part 1 — FIR Filter.** An 8-tap fixed-point FIR low-pass filter is implemented in two RTL architectures — direct-form (fully parallel) and resource-shared (serial, single reused multiplier) — and compared after logic synthesis on gate count, flip-flop count, and throughput.

**Part 2 — NN Accelerator.** A small fully-connected network (784→32→10) is trained on MNIST in PyTorch, quantized to fixed-point at multiple bit-widths (16/8/6/4-bit), and the 8-bit version is re-implemented as synthesizable RTL built from the same multiply-accumulate (MAC) core used in the FIR filter's serial design.

Both designs are verified with self-checking testbenches against Python golden models, and both are synthesized with the open-source Yosys toolchain for real gate-level resource numbers.

---

## Results summary

### FIR filter — direct-form vs. serial

| Metric | Direct-form | Serial |
|---|---|---|
| Total cells | 926 | 880 |
| Flip-flops | 64 | 105 |
| AND gates | 409 | 341 |
| XOR gates | 261 | 203 |
| Throughput | 1 sample / cycle | 1 sample / 8 cycles |

Both pass all tests in their self-checking testbenches against a NumPy golden reference.

### Quantization sweep (weights + activations)

| Bit-width | Accuracy | Drop from FP32 baseline (93.72%) |
|---|---|---|
| 16-bit | 93.72% | 0.00 pts |
| 8-bit  | 93.63% | 0.09 pts |
| 6-bit  | 93.42% | 0.30 pts |
| 4-bit  | 88.97% | 4.75 pts |

8-bit was selected for RTL implementation — accuracy within 0.1 points of full precision at half the bit-width of 16-bit.

### Accelerator — RTL vs. Python, on 10 real MNIST test images

**9/10 correct.** The single mismatch is the same image the Python 8-bit quantized model also misclassifies — the RTL output is faithful to the quantized model it was derived from, not introducing independent hardware errors.

### Accelerator synthesis

| Metric | Count |
|---|---|
| Total cells | 102,435 |
| Multiplexers | 90,934 (~89%) |
| Flip-flops | ~7,050 |

Resource usage is dominated by multiplexers, not arithmetic — a direct result of addressing a large (25,088-entry) weight memory without inferred block RAM. See the report for the full discussion.

---

## Repository structure

```
.
├── rtl/              RTL source (Verilog)
│   ├── fir_direct.v          8-tap FIR, direct-form (parallel) architecture
│   ├── fir_serial.v          8-tap FIR, resource-shared (serial) architecture
│   ├── mac_layer.v            Parameterized multiply-accumulate layer (reused for both NN layers)
│   ├── accelerator_top.v      Top-level NN accelerator (chains two mac_layer instances)
│   ├── fc1_weights.hex        Trained, quantized int8 weights — layer 1
│   └── fc2_weights.hex        Trained, quantized int8 weights — layer 2
│
├── tb/               Testbenches
│   ├── fir_direct_check_tb.v     Self-checking testbench, direct-form FIR
│   ├── fir_serial_check_tb.v     Self-checking testbench, serial FIR
│   └── accelerator_tb.v          Self-checking testbench, NN accelerator
│
├── sim/              Simulation data and golden reference outputs
│   ├── fir_reference.py          Python golden model for the FIR filter
│   ├── test_vectors.txt          Input/expected-output pairs for FIR testbenches
│   └── test_image_*.hex          Quantized MNIST test images for the accelerator
│
├── syn/              Synthesis scripts (Yosys) and reports
│   ├── synth_direct.ys
│   ├── synth_serial.ys
│   └── synth_accelerator.ys
│
├── ml/               Model training, quantization, and RTL data export (Python)
│   ├── train_mlp.py              Trains the baseline float32 MLP on MNIST
│   ├── quantize.py               Weight-only quantization sweep
│   ├── quantize_full.py          Weight + activation quantization sweep
│   ├── export_for_rtl.py         Integer-only reference forward pass + test vectors
│   ├── export_hex.py             Converts weights to .hex for $readmemh
│   ├── export_test_image.py      Exports a single test image to .hex
│   ├── export_all_test_images.py Exports all test images to .hex
│   └── calibrate_shift.py        Finds the correct inter-layer rescale shift amount
│
├── project_report.pdf    Full written report
└── README.md              This file
```

---

## Tools used

All open-source, no paid licenses required.

| Purpose | Tool |
|---|---|
| Simulation | [Icarus Verilog](http://iverilog.icarus.com/) |
| Waveform viewing | [GTKWave](https://gtkwave.sourceforge.net/) |
| Synthesis | [Yosys](https://yosyshq.net/yosys/) |
| Model training / quantization | PyTorch, NumPy |

---

## Reproducing the results

```bash
# FIR filter — simulate and verify
iverilog -o sim/fir_direct_sim rtl/fir_direct.v tb/fir_direct_check_tb.v
vvp sim/fir_direct_sim

iverilog -o sim/fir_serial_sim rtl/fir_serial.v tb/fir_serial_check_tb.v
vvp sim/fir_serial_sim

# NN accelerator — train, quantize, export, simulate
python ml/train_mlp.py
python ml/quantize_full.py
python ml/export_for_rtl.py
python ml/export_hex.py
python ml/export_all_test_images.py

iverilog -o sim/accel_sim rtl/mac_layer.v rtl/accelerator_top.v tb/accelerator_tb.v
vvp sim/accel_sim

# Synthesis (requires Yosys on PATH)
yosys syn/synth_direct.ys
yosys syn/synth_serial.ys
yosys syn/synth_accelerator.ys
```

---

## Key findings

- **Resource-sharing's area benefit is scale-dependent.** At only 8 taps / 8-bit precision, the serial FIR's control overhead (counter, accumulator, busy flag) nearly offsets the savings from removing seven multipliers — flip-flop count actually increased. The benefit would be expected to grow with wider data or more taps.
- **Quantization has a clear "cliff," not a gradual slope.** Accuracy is nearly unaffected down to 8-bit, still reasonable at 6-bit, and drops sharply at 4-bit — informing the choice of 8-bit for hardware implementation.
- **Different workloads expose different hardware bottlenecks.** The FIR filter's cost is arithmetic-bound; the NN accelerator's cost (as synthesized here, without block-RAM inference) is memory-addressing-bound, despite using the same underlying MAC primitive.

## Limitations

- Generic (non-vendor-specific) synthesis only — no block RAM inference, no place-and-route, no Fmax numbers.
- Inter-layer rescaling in the accelerator uses a single calibrated shift constant rather than a derived per-layer fixed-point multiply.
- Per-tensor (not per-channel) quantization.