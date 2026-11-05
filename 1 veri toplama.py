"""
HARİCİ VERİ SETİ KONTROL VE DOĞRULAMA ARACI
===========================================
Kamera ile manuel fotoğraf çekimi yerine, dışarıdan indirilen (Kaggle, Roboflow, vb.)
Türk İşaret Dili veri setinin klasör yapısını, harf dağılımını ve eksik sınıfları
kontrol eder.
"""

import os
import argparse

EXPECTED_LETTERS = [
    "A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H",
    "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P",
    "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z",
]

VALID_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.bmp', '.webp')

FOLDER_NAME_MAP = {
    "C_": "Ç", "CH": "Ç", "C-": "Ç",
    "G_": "Ğ", "GH": "Ğ", "G-": "Ğ",
    "I_": "İ", "II": "İ", "I-": "İ",
    "O_": "Ö", "OE": "Ö", "O-": "Ö",
    "S_": "Ş", "SH": "Ş", "S-": "Ş",
    "U_": "Ü", "UE": "Ü", "U-": "Ü",
}


def inspect_dataset(data_dir):
    if not os.path.exists(data_dir):
        os.makedirs(data_dir, exist_ok=True)
        print(f"'{data_dir}' klasörü oluşturuldu. Lütfen indirdiğiniz veri setini bu klasöre çıkarın.")
        return

    counts = {}
    for current_root, _, files in os.walk(data_dir):
        imgs = [f for f in files if f.lower().endswith(VALID_EXTENSIONS)]
        if not imgs:
            continue
        raw_label = os.path.basename(current_root).strip().upper()
        if raw_label in ("TRAIN", "TEST", "VAL", "VALID", "VALIDATION", "DATA", "DATASET"):
            continue
        label = FOLDER_NAME_MAP.get(raw_label, raw_label)
        counts[label] = counts.get(label, 0) + len(imgs)

    print("=" * 60)
    print(f"VERİ SETİ ANALİZ RAPORU ({os.path.abspath(data_dir)})")
    print("=" * 60)

    total_images = sum(counts.values())
    if total_images == 0:
        print("Klasörde henüz görüntü bulunamadı!")
        print("İndirdiğiniz veri setini './data/<HARF>/' yapısında yerleştirin.")
        return

    for letter in EXPECTED_LETTERS:
        cnt = counts.get(letter, 0)
        status = "OK" if cnt >= 50 else ("AZ VERİ" if cnt > 0 else "EKSİK")
        print(f"  Harf [{letter}] : {cnt:5d} resim  ({status})")

    extra_classes = set(counts.keys()) - set(EXPECTED_LETTERS)
    if extra_classes:
        print("\nStandart 29 harf dışındaki ek sınıflar:")
        for extra in sorted(extra_classes):
            print(f"  [{extra}] : {counts[extra]} resim")

    missing = [l for l in EXPECTED_LETTERS if counts.get(l, 0) == 0]
    print("=" * 60)
    print(f"Toplam Sınıf Sayısı : {len(counts)}")
    print(f"Toplam Resim Sayısı : {total_images}")
    if missing:
        print(f"Eksik Harfler ({len(missing)}): {', '.join(missing)}")
    else:
        print("29 Türkçe harfin tamamı veri setinde mevcut!")
    print("=" * 60)
    print("Sonraki adım: python \"2 veri işleme1.py\" komutunu çalıştırın.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Harici Veri Seti Kontrol Aracı")
    parser.add_argument("--data-dir", type=str, default="./data", help="Veri seti klasörü")
    args = parser.parse_args()
    inspect_dataset(args.data_dir)
