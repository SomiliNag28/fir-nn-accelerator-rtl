import torch
import torch.nn as nn
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

# ---- Load the trained float32 model ----
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

# ---- Load test data ----
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5,), (0.5,))
])
test_data = datasets.MNIST(root="./data", train=False, download=True, transform=transform)
test_loader = DataLoader(test_data, batch_size=1000, shuffle=False)

# ---- Quantization helpers ----
def quantize_tensor(tensor, bits):
    """Symmetric per-tensor quantization to `bits`-bit signed integers."""
    qmax = 2 ** (bits - 1) - 1
    scale = tensor.abs().max() / qmax
    if scale == 0:
        scale = 1e-8
    q = torch.clamp(torch.round(tensor / scale), -qmax - 1, qmax)
    dequantized = q * scale  # simulate fixed-point by dequantizing back
    return dequantized, scale, q

def evaluate_quantized(model, bits):
    """Quantize weights only (simplest first step), run inference, return accuracy."""
    # Save original weights
    orig_fc1_w = model.fc1.weight.data.clone()
    orig_fc2_w = model.fc2.weight.data.clone()

    # Quantize weights
    q_fc1_w, scale1, _ = quantize_tensor(orig_fc1_w, bits)
    q_fc2_w, scale2, _ = quantize_tensor(orig_fc2_w, bits)

    model.fc1.weight.data = q_fc1_w
    model.fc2.weight.data = q_fc2_w

    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in test_loader:
            outputs = model(images)
            _, predicted = torch.max(outputs, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

    accuracy = 100 * correct / total

    # Restore original weights for next test
    model.fc1.weight.data = orig_fc1_w
    model.fc2.weight.data = orig_fc2_w

    return accuracy, scale1.item(), scale2.item()

# ---- Run sweep ----
print(f"{'Bits':<6}{'Accuracy':<12}{'fc1 scale':<14}{'fc2 scale'}")
print("-" * 45)

results = {}
for bits in [16, 8, 6, 4]:
    acc, s1, s2 = evaluate_quantized(model, bits)
    results[bits] = acc
    print(f"{bits:<6}{acc:<12.2f}{s1:<14.6f}{s2:.6f}")

print(f"\nFloat32 baseline (for reference): 93.72%")