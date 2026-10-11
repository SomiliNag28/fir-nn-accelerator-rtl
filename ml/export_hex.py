import numpy as np

def to_hex_file(txt_path, hex_path):
    values = np.loadtxt(txt_path, dtype=int)
    with open(hex_path, "w") as f:
        for v in values:
            # convert signed int8 to 2's complement hex
            v_unsigned = v & 0xFF
            f.write(f"{v_unsigned:02x}\n")
    print(f"Wrote {len(values)} values to {hex_path}")

to_hex_file("ml/fc1_weights_int8.txt", "rtl/fc1_weights.hex")
to_hex_file("ml/fc2_weights_int8.txt", "rtl/fc2_weights.hex")