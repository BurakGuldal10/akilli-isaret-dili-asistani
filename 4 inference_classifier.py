import pickle
import time
import cv2
import mediapipe as mp
import numpy as np

# Modelleri yükle
model_dict = pickle.load(open('./model.p', 'rb'))

# Yeni format kontrolü
if 'models' in model_dict:
    models = model_dict['models']
    model_single = models.get('single_hand')
    model_two = models.get('two_hand')
else:
    # Eski format - geriye uyumluluk
    model_single = model_dict.get('model')
    model_two = None

print(f"Tek el modeli: {'Yüklendi' if model_single else 'Yok'}")
print(f"İki el modeli: {'Yüklendi' if model_two else 'Yok'}")

# Farklı backend'leri dene
print("Kamera aranıyor...")
cap = None
for backend in [cv2.CAP_MSMF, cv2.CAP_DSHOW, cv2.CAP_ANY]:
    cap = cv2.VideoCapture(0, backend)
    if cap.isOpened():
        ret, test_frame = cap.read()
        if ret and test_frame is not None:
            print(f"Kamera bulundu! Backend: {backend}")
            break
    cap.release()

if cap is None or not cap.isOpened():
    print("HATA: Kamera açılamadı!")
    exit()

# Kamera ayarları
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

# Kamera ısınma süresi
print("Kamera başlatılıyor (lütfen bekleyin)...")
time.sleep(2)
for _ in range(60):
    cap.read()
print("Kamera hazır!")

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

hands = mp_hands.Hands(static_image_mode=True, min_detection_confidence=0.3, max_num_hands=2)

# Tüm Türkçe harfler için etiket sözlüğü
labels_dict = {
    0: 'A', 1: 'B', 2: 'C', 3: 'Ç', 4: 'D', 5: 'E', 
    6: 'F', 7: 'G', 8: 'Ğ', 9: 'H', 10: 'I', 11: 'İ', 
    12: 'J', 13: 'K', 14: 'L', 15: 'M', 16: 'N', 17: 'O', 
    18: 'Ö', 19: 'P', 20: 'R', 21: 'S', 22: 'Ş', 23: 'T', 
    24: 'U', 25: 'Ü', 26: 'V', 27: 'Y', 28: 'Z'
}

while True:
    ret, frame = cap.read()
    
    if not ret or frame is None:
        print("UYARI: Frame alınamadı, tekrar deneniyor...")
        continue

    H, W, _ = frame.shape
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    results = hands.process(frame_rgb)
    
    if results.multi_hand_landmarks:
        num_hands = len(results.multi_hand_landmarks)
        
        # Tüm elleri çiz
        for hand_landmarks in results.multi_hand_landmarks:
            mp_drawing.draw_landmarks(
                frame,
                hand_landmarks,
                mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style())

        # Veri hazırla
        data_aux = []
        x_ = []
        y_ = []
        
        for hand_landmarks in results.multi_hand_landmarks:
            for i in range(len(hand_landmarks.landmark)):
                x = hand_landmarks.landmark[i].x
                y = hand_landmarks.landmark[i].y
                x_.append(x)
                y_.append(y)

        for hand_landmarks in results.multi_hand_landmarks:
            for i in range(len(hand_landmarks.landmark)):
                x = hand_landmarks.landmark[i].x
                y = hand_landmarks.landmark[i].y
                data_aux.append(x - min(x_))
                data_aux.append(y - min(y_))

        # Bounding box hesapla
        x1 = int(min(x_) * W) - 10
        y1 = int(min(y_) * H) - 10
        x2 = int(max(x_) * W) + 10
        y2 = int(max(y_) * H) + 10

        try:
            # El sayısına göre doğru modeli seç
            if num_hands == 1 and model_single is not None:
                prediction = model_single.predict([np.asarray(data_aux)])
                hand_text = "(1 el)"
            elif num_hands == 2 and model_two is not None:
                prediction = model_two.predict([np.asarray(data_aux)])
                hand_text = "(2 el)"
            elif num_hands == 1 and model_single is None:
                prediction = None
                hand_text = "(1 el - model yok)"
            elif num_hands == 2 and model_two is None:
                prediction = None
                hand_text = "(2 el - model yok)"
            else:
                prediction = None
                hand_text = ""

            if prediction is not None:
                if isinstance(prediction[0], (str, np.str_)):
                    predicted_character = str(prediction[0])
                else:
                    predicted_character = labels_dict.get(int(prediction[0]), '?')

                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 4)
                cv2.putText(frame, f"{predicted_character} {hand_text}", (x1, y1 - 10), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1.3, (0, 255, 0), 3, cv2.LINE_AA)
            else:
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 255), 4)
                cv2.putText(frame, hand_text, (x1, y1 - 10), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 2, cv2.LINE_AA)
                
        except Exception as e:
            print(f"Tahmin hatası: {e}")

    # El sayısını ekranda göster
    cv2.putText(frame, "Cikis: 'q' tusuna bas", (10, 30), 
               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2, cv2.LINE_AA)

    cv2.imshow('frame', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
