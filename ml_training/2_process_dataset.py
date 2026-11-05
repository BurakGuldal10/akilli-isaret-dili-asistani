"""
VERİ SETİ İŞLEME VE ÖZNİTELİK ÇIKARIMI (ml_training/2_process_dataset.py)
=========================================================================
Harici veri setindeki görüntülerden MediaPipe ile el koordinatlarını çıkarır,
ölçekten bağımsız [0, 1] aralığına normalize eder ve veri artırma (augmentation)
uygulayarak data.pickle dosyasına kaydeder.
"""

import os
import pickle
import argparse
import numpy as np
import mediapipe as mp
import cv2

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DATA_DIR = os.path.join(PROJECT_ROOT, "data")
DEFAULT_OUTPUT = os.path.join(PROJECT_ROOT, "data.pickle")

VALID_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.bmp', '.webp')

FOLDER_NAME_MAP = {
    "C_": "Ç", "CH": "Ç", "C-": "Ç",
    "G_": "Ğ", "GH": "Ğ", "G-": "Ğ",
    "I_": "İ", "II": "İ", "I-": "İ",
    "O_": "Ö", "OE": "Ö", "O-": "Ö",
    "S_": "Ş", "SH": "Ş", "S-": "Ş",
    "U_": "Ü", "UE": "Ü", "U-": "Ü",
}


def read_image_unicode(filepath):
    """Windows'ta Türkçe karakterli dosya yollarını güvenle okur."""
    try:
        stream = np.fromfile(filepath, dtype=np.uint8)
        return cv2.imdecode(stream, cv2.IMREAD_COLOR)
    except Exception:
        return None


def normalize_landmarks(x_, y_):
    """El koordinatlarını [0.0, 1.0] aralığına ölçekten bağımsız olarak normalize eder."""
    min_x, max_x = min(x_), max(x_)
    min_y, max_y = min(y_), max(y_)
    width = (max_x - min_x) if (max_x - min_x) > 1e-6 else 1e-6
    height = (max_y - min_y) if (max_y - min_y) > 1e-6 else 1e-6

    data_aux = []
    for x, y in zip(x_, y_):
        data_aux.append((x - min_x) / width)
        data_aux.append((y - min_y) / height)
    return data_aux


def rotate_landmarks(data_aux, angle_deg):
    """Normalize edilmiş [0, 1] landmark noktalarını merkez (0.5, 0.5) etrafında döndürür."""
    rad = np.radians(angle_deg)
    cos_a, sin_a = np.cos(rad), np.sin(rad)
    rotated = []
    for i in range(0, len(data_aux), 2):
        dx = data_aux[i] - 0.5
        dy = data_aux[i + 1] - 0.5
        rx = dx * cos_a - dy * sin_a + 0.5
        ry = dx * sin_a + dy * cos_a + 0.5
        rotated.append(float(np.clip(rx, 0.0, 1.0)))
        rotated.append(float(np.clip(ry, 0.0, 1.0)))
    return rotated


def augment_landmarks(data_aux):
    """Orijinal, yatay aynalanmış ve -10/+10 derece döndürülmüş varyasyonlar üretir."""
    augmented_data = [data_aux.copy()]

    mirrored = []
    for i in range(0, len(data_aux), 2):
        mirrored.append(1.0 - data_aux[i])
        mirrored.append(data_aux[i + 1])
    augmented_data.append(mirrored)

    for angle in (-10, 10):
        augmented_data.append(rotate_landmarks(data_aux, angle))

    return augmented_data


def discover_class_images(root_dir):
    class_files = {}
    if not os.path.exists(root_dir):
        return class_files

    for current_root, _, files in os.walk(root_dir):
        image_files = [
            os.path.join(current_root, f)
            for f in files
            if f.lower().endswith(VALID_EXTENSIONS)
        ]
        if not image_files:
            continue

        raw_label = os.path.basename(current_root).strip().upper()
        if raw_label in ("TRAIN", "TEST", "VAL", "VALID", "VALIDATION", "DATA", "DATASET"):
            continue

        label = FOLDER_NAME_MAP.get(raw_label, raw_label)
        class_files.setdefault(label, []).extend(image_files)

    return class_files


def main():
    parser = argparse.ArgumentParser(description="Harici İşaret Dili Veri Seti İşleme Aracı")
    parser.add_argument("--data-dir", type=str, default=DEFAULT_DATA_DIR)
    parser.add_argument("--output", type=str, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=True,
        min_detection_confidence=0.3,
        max_num_hands=2,
    )

    print("=" * 60)
    print(f"HARİCİ VERİ SETİ İŞLEME BAŞLATILIYOR ({args.data_dir})")
    print("=" * 60)

    class_images = discover_class_images(args.data_dir)
    if not class_images:
        print(f"HATA: '{args.data_dir}' içinde işlenecek resim bulunamadı!")
        return

    data = []
    labels = []
    hand_counts = []
    skipped = 0
    processed = 0

    for label in sorted(class_images.keys()):
        img_paths = class_images[label]
        class_count = 0

        for img_path in img_paths:
            img = read_image_unicode(img_path)
            if img is None:
                skipped += 1
                continue

            img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            result = hands.process(img_rgb)

            if not result.multi_hand_landmarks:
                skipped += 1
                continue

            num_hands = len(result.multi_hand_landmarks)
            x_ = []
            y_ = []

            for hand_landmarks in result.multi_hand_landmarks:
                for lm in hand_landmarks.landmark:
                    x_.append(lm.x)
                    y_.append(lm.y)

            data_aux = normalize_landmarks(x_, y_)
            augmented_samples = augment_landmarks(data_aux)

            for aug_data in augmented_samples:
                data.append(aug_data)
                labels.append(label)
                hand_counts.append(num_hands)

            class_count += len(augmented_samples)
            processed += 1

        print(f"  [{label}] Harfi: {len(img_paths)} ham resim -> {class_count} eğitim örneği")

    print("=" * 60)
    print(f"Toplam başarılı işlenen resim : {processed}")
    print(f"El algılanamayan/atlanan resim: {skipped}")
    print(f"Toplam üretilen eğitim verisi : {len(data)} (Augmentation dahil)")

    with open(args.output, "wb") as f:
        pickle.dump(
            {
                "data": data,
                "labels": labels,
                "hand_counts": hand_counts,
                "normalized": True,
            },
            f,
        )
    print(f"\nVeriler başarıyla '{args.output}' dosyasına kaydedildi!")


if __name__ == "__main__":
    main()
