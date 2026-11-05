import os
import pickle
import numpy as np

try:
    import mediapipe as mp
    import cv2
except ImportError as e:
    print(f"Hata: {e}")
    exit()

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
mp_drawing_style = mp.solutions.drawing_styles

hands = mp_hands.Hands(static_image_mode=True, min_detection_confidence=0.3, max_num_hands=2)

DATA_DIR = "./data"

data = []
labels = []
hand_counts = []

def augment_landmarks(x_, y_, data_aux):
    """Landmark verilerini augment et - yatay aynalama"""
    augmented_data = []
    
    # Orijinal veri
    augmented_data.append(data_aux.copy())
    
    # Yatay aynalama (x koordinatlarını ters çevir)
    mirrored = []
    min_x = min(x_)
    max_x = max(x_)
    min_y = min(y_)
    
    for i in range(0, len(data_aux), 2):
        # x koordinatını aynala
        orig_x = data_aux[i]
        mirrored_x = (max_x - min_x) - orig_x
        mirrored.append(mirrored_x)
        mirrored.append(data_aux[i + 1])  # y aynı kalır
    
    augmented_data.append(mirrored)
    
    return augmented_data

print("Veri işleme başlatılıyor...")
print("=" * 50)

skipped = 0
processed = 0

for dir_ in os.listdir(DATA_DIR):
    dir_path = os.path.join(DATA_DIR, dir_)
    if not os.path.isdir(dir_path):
        continue
        
    class_count = 0
    for img_path in os.listdir(dir_path):
        if not img_path.endswith('.jpg'):
            continue
            
        img = cv2.imread(os.path.join(dir_path, img_path))
        if img is None:
            skipped += 1
            continue
            
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        result = hands.process(img_rgb)

        if result.multi_hand_landmarks:
            num_hands = len(result.multi_hand_landmarks)
            
            x_ = []
            y_ = []
            data_aux = []
            
            # Tüm ellerin landmark'larını topla
            for hand_landmarks in result.multi_hand_landmarks:
                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x
                    y = hand_landmarks.landmark[i].y
                    x_.append(x)
                    y_.append(y)
            
            # Normalize edilmiş koordinatları hesapla
            for hand_landmarks in result.multi_hand_landmarks:
                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x
                    y = hand_landmarks.landmark[i].y
                    data_aux.append(x - min(x_))
                    data_aux.append(y - min(y_))

            # Veri artırma uygula
            augmented_samples = augment_landmarks(x_, y_, data_aux)
            
            for aug_data in augmented_samples:
                data.append(aug_data)
                labels.append(dir_)
                hand_counts.append(num_hands)
            
            class_count += len(augmented_samples)
            processed += 1
    
    print(f"  {dir_}: {class_count} örnek (augmented)")

print("=" * 50)
print(f"Toplam işlenen resim: {processed}")
print(f"Atlanan resim: {skipped}")
print(f"Toplam veri sayısı: {len(data)} (augmented)")
print(f"Tek el verileri: {hand_counts.count(1)}")
print(f"İki el verileri: {hand_counts.count(2)}")

f = open("data.pickle", "wb")
pickle.dump({"data": data, "labels": labels, "hand_counts": hand_counts}, f)
f.close()
print("\nVeriler başarıyla kaydedildi!")
