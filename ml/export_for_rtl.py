import torch
import torch.nn as nn
import numpy as np
import json
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

class TinyMLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(28*28, 32)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(32, 10)
    def forward(self, x):
        x = x.view(x.size(0), -1)
        x = self.relu(self.fc1(x))
        x = self.fc2(x)
        return x

model = TinyMLP()
model.load_state_dict(torch.load("ml/tiny_mlp_fp32.pth"))
model.eval()

BITS = 8
QMAX = 2 ** (BITS - 1) - 1  # 127 for 8-bit

def quantize_to_int(tensor, bits=BITS):
    """Returns INTEGER values (not dequantized) plus the scale used."""
    qmax = 2 ** (bits - 1) - 1
    scale = tensor.abs().max() / qmax
    if scale == 0:
        scale = 1e-8
    q_int = torch.clamp(torch.round(tensor / scale), -qmax - 1, qmax).to(torch.int32)
    return q_int, scale.item()

# ---- Quantize weights to integers ----
w1_int, scale_w1 = quantize_to_int(model.fc1.weight.data)   # shape [32, 784]
b1 = model.fc1.bias.data.numpy()                             # keep float bias for now
w2_int, scale_w2 = quantize_to_int(model.fc2.weight.data)   # shape [10, 32]
b2 = model.fc2.bias.data.numpy()

print(f"fc1 weight int range: [{w1_int.min()}, {w1_int.max()}]  scale={scale_w1:.6f}")
print(f"fc2 weight int range: [{w2_int.min()}, {w2_int.max()}]  scale={scale_w2:.6f}")

# ---- Save weights as flat text files (easy for Verilog $readmemh/$fscanf) ----
np.savetxt("ml/fc1_weights_int8.txt", w1_int.numpy().flatten(), fmt="%d")
np.savetxt("ml/fc2_weights_int8.txt", w2_int.numpy().flatten(), fmt="%d")

# ---- Integer-only forward pass (mimics EXACTLY what hardware computes) ----
def integer_forward(image_flat_int, w1_int, b1, scale_w1, w2_int, b2, scale_w2, act_bits=BITS):
    """
    image_flat_int: already-quantized int8 input (784,)
    Returns: integer logits (10,) — same math hardware would do
    """
    qmax_act = 2 ** (act_bits - 1) - 1

    # Layer 1: integer MAC, then rescale/requantize to int8 activation
    h1_raw = w1_int.numpy() @ image_flat_int   # pure integer matmul: [32,784]x[784] -> [32]
    h1_float = h1_raw * scale_w1 + b1           # apply scale + bias (still needs one float mul here —
                                                  # in real hardware this becomes a fixed-point multiply,
                                                  # a detail you'll note as a simplification in RTL)
    h1_float = np.maximum(h1_float, 0)          # ReLU
    scale_a1 = np.abs(h1_float).max() / qmax_act if np.abs(h1_float).max() > 0 else 1e-8
    h1_int = np.clip(np.round(h1_float / scale_a1), -qmax_act-1, qmax_act).astype(np.int32)

    # Layer 2: integer MAC again
    out_raw = w2_int.numpy() @ h1_int
    out_float = out_raw * scale_w2 * scale_a1 + b2
    return out_float  # final logits, used only for argmax — no need to quantize further

# ---- Quantize a handful of test images and export as test vectors ----
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5,), (0.5,))
])
test_data = datasets.MNIST(root="./data", train=False, download=True, transform=transform)

NUM_TEST_IMAGES = 10
test_vectors = []

for i in range(NUM_TEST_IMAGES):
    image, label = test_data[i]
    image_flat = image.view(-1)
    image_int, scale_img = quantize_to_int(image_flat)
    image_int_np = image_int.numpy()

    logits = integer_forward(image_int_np, w1_int, b1, scale_w1, w2_int, b2, scale_w2)
    predicted = int(np.argmax(logits))

    test_vectors.append({
        "index": i,
        "true_label": int(label),
        "predicted_label": predicted,
        "image_int8": image_int_np.tolist(),
        "logits": logits.tolist()
    })
    print(f"Image {i}: true={label}, predicted={predicted}, match={label==predicted}")

with open("ml/rtl_test_vectors.json", "w") as f:
    json.dump(test_vectors, f, indent=2)

print(f"\nSaved {NUM_TEST_IMAGES} test vectors to ml/rtl_test_vectors.json")
print("Saved weight files: ml/fc1_weights_int8.txt, ml/fc2_weights_int8.txt")