import pickle
import time
import cv2
import mediapipe as mp
import numpy as np

# Modelleri yükle
model_dict = pickle.load(open('./model.p', 'rb'))
is_normalized = model_dict.get('normalized', False)

if 'models' in model_dict:
    models = model_dict['models']
    model_single = models.get('single_hand')
    model_two = models.get('two_hand')
else:
    model_single = model_dict.get('model')
    model_two = None

print(f"Tek el modeli: {'Yüklendi' if model_single else 'Yok'}")
print(f"İki el modeli: {'Yüklendi' if model_two else 'Yok'}")
print(f"Ölçek normalizasyonu: {'Aktif' if is_normalized else 'Eski tip'}")

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

cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

print("Kamera başlatılıyor (lütfen bekleyin)...")
time.sleep(2)
for _ in range(60):
    cap.read()
print("Kamera hazır!")

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

hands = mp_hands.Hands(static_image_mode=True, min_detection_confidence=0.3, max_num_hands=2)

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

        for hand_landmarks in results.multi_hand_landmarks:
            mp_drawing.draw_landmarks(
                frame,
                hand_landmarks,
                mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style(),
            )

        data_aux = []
        x_ = []
        y_ = []

        for hand_landmarks in results.multi_hand_landmarks:
            for lm in hand_landmarks.landmark:
                x_.append(lm.x)
                y_.append(lm.y)

        min_x, max_x = min(x_), max(x_)
        min_y, max_y = min(y_), max(y_)
        width = (max_x - min_x) if (is_normalized and (max_x - min_x) > 1e-6) else 1.0
        height = (max_y - min_y) if (is_normalized and (max_y - min_y) > 1e-6) else 1.0

        for x, y in zip(x_, y_):
            data_aux.append((x - min_x) / width)
            data_aux.append((y - min_y) / height)

        x1 = int(min_x * W) - 10
        y1 = int(min_y * H) - 10
        x2 = int(max_x * W) + 10
        y2 = int(max_y * H) + 10

        try:
            active_model = model_single if num_hands == 1 else (model_two if num_hands == 2 else None)
            hand_text = f"({num_hands} el)" if active_model is not None else f"({num_hands} el - model yok)"

            if active_model is not None:
                prediction = active_model.predict([np.asarray(data_aux, dtype=np.float32)])
                if isinstance(prediction[0], (str, np.str_)):
                    predicted_character = str(prediction[0])
                else:
                    predicted_character = labels_dict.get(int(prediction[0]), '?')

                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 4)
                cv2.putText(
                    frame,
                    f"{predicted_character} {hand_text}",
                    (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1.3,
                    (0, 255, 0),
                    3,
                    cv2.LINE_AA,
                )
            else:
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 255), 4)
                cv2.putText(
                    frame,
                    hand_text,
                    (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1.0,
                    (0, 0, 255),
                    2,
                    cv2.LINE_AA,
                )
        except Exception as e:
            print(f"Tahmin hatası: {e}")

    cv2.putText(
        frame,
        "Cikis: 'q' tusuna bas",
        (10, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )

    cv2.imshow('frame', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
