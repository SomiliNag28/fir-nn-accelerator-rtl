import json
import numpy as np

with open("ml/rtl_test_vectors.json") as f:
    vectors = json.load(f)

for idx, img in enumerate(vectors):
    pixels = np.array(img["image_int8"], dtype=int)
    with open(f"sim/test_image_{idx}.hex", "w") as f:
        for p in pixels:
            f.write(f"{p & 0xFF:02x}\n")

print(f"Exported {len(vectors)} images to sim/test_image_0.hex ... test_image_9.hex")
print("\nExpected predictions (from Python):")
for idx, img in enumerate(vectors):
    print(f"  image {idx}: true={img['true_label']}, python_predicted={img['predicted_label']}")