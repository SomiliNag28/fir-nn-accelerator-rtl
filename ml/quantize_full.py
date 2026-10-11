import torch
import torch.nn as nn
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

transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5,), (0.5,))
])
test_data = datasets.MNIST(root="./data", train=False, download=True, transform=transform)
test_loader = DataLoader(test_data, batch_size=1000, shuffle=False)

def quantize_tensor(tensor, bits):
    """Symmetric per-tensor quantization to `bits`-bit signed integers."""
    qmax = 2 ** (bits - 1) - 1
    scale = tensor.abs().max() / qmax
    if scale == 0:
        scale = 1e-8
    q = torch.clamp(torch.round(tensor / scale), -qmax - 1, qmax)
    dequantized = q * scale
    return dequantized, scale.item()

def quantized_forward(model, x, bits):
    """Manual forward pass with weights AND activations quantized at every step."""
    x = x.view(x.size(0), -1)

    # Quantize input image itself (it's the first "activation")
    x, _ = quantize_tensor(x, bits)

    # Layer 1: quantized weights, quantized input -> linear -> quantize output
    w1, scale_w1 = quantize_tensor(model.fc1.weight.data, bits)
    b1 = model.fc1.bias.data  # keep bias at higher precision (standard practice)
    h1 = torch.nn.functional.linear(x, w1, b1)
    h1 = torch.relu(h1)
    h1, scale_a1 = quantize_tensor(h1, bits)

    # Layer 2: same pattern
    w2, scale_w2 = quantize_tensor(model.fc2.weight.data, bits)
    b2 = model.fc2.bias.data
    out = torch.nn.functional.linear(h1, w2, b2)
    # final output not quantized further; it's just used for argmax classification

    return out, (scale_w1, scale_a1, scale_w2)

def evaluate_full_quantized(model, bits):
    correct = 0
    total = 0
    scales = None
    with torch.no_grad():
        for images, labels in test_loader:
            outputs, scales = quantized_forward(model, images, bits)
            _, predicted = torch.max(outputs, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
    accuracy = 100 * correct / total
    return accuracy, scales

print(f"{'Bits':<6}{'Accuracy':<12}{'scale_w1':<14}{'scale_a1':<14}{'scale_w2'}")
print("-" * 60)

results = {}
for bits in [16, 8, 6, 4]:
    acc, (sw1, sa1, sw2) = evaluate_full_quantized(model, bits)
    results[bits] = acc
    print(f"{bits:<6}{acc:<12.2f}{sw1:<14.6f}{sa1:<14.6f}{sw2:.6f}")

print(f"\nFloat32 baseline (for reference): 93.72%")

# save scales for the 8-bit case — you'll likely pick this as your RTL target
import json
_, scales_8bit = evaluate_full_quantized(model, 8)
with open("ml/scales_8bit.json", "w") as f:
    json.dump({"scale_w1": scales_8bit[0], "scale_a1": scales_8bit[1], "scale_w2": scales_8bit[2]}, f, indent=2)
print("\nSaved 8-bit scales to ml/scales_8bit.json")