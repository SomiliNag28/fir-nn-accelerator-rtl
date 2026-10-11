import json
import numpy as np

with open("ml/rtl_test_vectors.json") as f:
    vectors = json.load(f)

# Export image 0 (change index to test others)
IMAGE_INDEX = 0
img = vectors[IMAGE_INDEX]
pixels = np.array(img["image_int8"], dtype=int)

with open("sim/test_image_0.hex", "w") as f:
    for p in pixels:
        p_unsigned = p & 0xFF
        f.write(f"{p_unsigned:02x}\n")

print(f"Exported image {IMAGE_INDEX}: true_label={img['true_label']}, "
      f"python_predicted={img['predicted_label']}")
print(f"Expected logits (from Python): {img['logits']}")
print("Saved to sim/test_image_0.hex")