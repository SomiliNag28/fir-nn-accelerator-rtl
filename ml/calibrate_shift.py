import json
import numpy as np

with open("ml/rtl_test_vectors.json") as f:
    vectors = json.load(f)

# Load weights (same ones used in RTL)
w1 = np.loadtxt("ml/fc1_weights_int8.txt", dtype=int).reshape(32, 784)
w2 = np.loadtxt("ml/fc2_weights_int8.txt", dtype=int).reshape(10, 32)

def rtl_forward_sim(image_int, shift_amt):
    """Exactly mirrors what accelerator_top.v computes, including the shift+saturate."""
    # Layer 1: raw integer MAC
    h1_raw = w1 @ image_int  # [32]
    # ReLU
    h1_raw = np.maximum(h1_raw, 0)
    # Shift + saturate to int8 (same as RTL)
    h1_shifted = h1_raw >> shift_amt
    h1_int8 = np.clip(h1_shifted, -128, 127)

    # Layer 2: raw integer MAC (no rescale on final logits, same as RTL)
    out_raw = w2 @ h1_int8
    return out_raw

print(f"{'Shift':<8}{'Correct/10'}")
print("-" * 20)

best_shift = None
best_score = -1

for shift_amt in range(0, 16):
    correct = 0
    for img in vectors:
        image_int = np.array(img["image_int8"], dtype=int)
        logits = rtl_forward_sim(image_int, shift_amt)
        predicted = int(np.argmax(logits))
        if predicted == img["predicted_label"]:  # compare against Python's OWN int8 model, not ground truth
            correct += 1
    print(f"{shift_amt:<8}{correct}")
    if correct > best_score:
        best_score = correct
        best_shift = shift_amt

print(f"\nBest shift amount: {best_shift} (matches Python int8 model on {best_score}/10 images)")