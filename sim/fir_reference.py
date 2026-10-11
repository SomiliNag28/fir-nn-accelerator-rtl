import numpy as np

# same coefficients as your Verilog (must match exactly)
h = np.array([2, 4, 8, 10, 10, 8, 4, 2])

def fir_filter(x, h):
    """Direct convolution, matches direct-form FIR behavior"""
    y = np.convolve(x, h)
    return y[:len(x)]  # truncate to same length for easy comparison

# generate test input: random 8-bit signed samples
np.random.seed(42)
x = np.random.randint(-50, 50, size=20)

y = fir_filter(x, h)

# write test vectors for Verilog testbench to read
with open("sim/test_vectors.txt", "w") as f:
    for xi, yi in zip(x, y):
        f.write(f"{xi} {yi}\n")

print("x =", list(x))
print("y =", list(y))