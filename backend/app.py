"""
==============================================================================
İŞARET DİLİ TANIMA API SUNUCUSU (backend/app.py)
==============================================================================
Flask-SocketIO kullanarak gerçek zamanlı Türk İşaret Dili (TİD) tanıma sunucusu.
Mobil ve Web uygulamalarından gelen kamera görüntülerini alır, MediaPipe ile el
tespiti yapar ve eğitilmiş model ile tahmin üretir.

Çalıştırma:
    python backend/app.py
==============================================================================
"""

import os
import pickle
import base64
import cv2
import mediapipe as mp
import numpy as np
from flask import Flask
from flask_socketio import SocketIO, emit

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins='*')

# ======================== MODEL YÜKLEME ========================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MODEL_PATHS = [
    os.path.join(BASE_DIR, 'models', 'model.p'),
    os.path.join(os.path.dirname(BASE_DIR), 'model.p'),
]

model_path = next((p for p in DEFAULT_MODEL_PATHS if os.path.exists(p)), None)
if model_path is None:
    raise FileNotFoundError(
        "Eğitilmiş model dosyası bulunamadı! Lütfen 'backend/models/model.p' dosyasını oluşturun."
    )

model_dict = pickle.load(open(model_path, 'rb'))
is_normalized = model_dict.get('normalized', False)

if 'models' in model_dict:
    models = model_dict['models']
    model_single = models.get('single_hand')
    model_two = models.get('two_hand')
else:
    model_single = model_dict.get('model')
    model_two = None

print(f"Model dosyası       : {model_path}")
print(f"Tek el modeli       : {'Yüklendi' if model_single else 'Yok'}")
print(f"İki el modeli       : {'Yüklendi' if model_two else 'Yok'}")
print(f"Ölçek normalizasyonu: {'Aktif ([0, 1])' if is_normalized else 'Eski tip'}")

CONFIDENCE_THRESHOLD = 0.45

# ======================== MEDİAPIPE AYARLARI ========================
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=True,
    min_detection_confidence=0.4,
    min_tracking_confidence=0.4,
    max_num_hands=2,
)

# ======================== ETİKET SÖZLÜĞÜ ========================
labels_dict = {
    0: 'A', 1: 'B', 2: 'C', 3: 'Ç', 4: 'D', 5: 'E',
    6: 'F', 7: 'G', 8: 'Ğ', 9: 'H', 10: 'I', 11: 'İ',
    12: 'J', 13: 'K', 14: 'L', 15: 'M', 16: 'N', 17: 'O',
    18: 'Ö', 19: 'P', 20: 'R', 21: 'S', 22: 'Ş', 23: 'T',
    24: 'U', 25: 'Ü', 26: 'V', 27: 'Y', 28: 'Z'
}


@app.route('/health')
def health_check():
    return {
        'status': 'ok',
        'single_hand_model': model_single is not None,
        'two_hand_model': model_two is not None,
        'normalized': is_normalized,
    }


@socketio.on('connect')
def handle_connect():
    print('📱 İstemci bağlandı!')


@socketio.on('disconnect')
def handle_disconnect():
    print('📴 İstemci ayrıldı')


@socketio.on('frame_data')
def handle_frame(data):
    """Mobil veya Web uygulamasından gelen her kamera karesini işler ve tahmin döndürür."""
    try:
        image_data = data.get('image')
        if not image_data:
            emit('prediction_result', {'char': '...'})
            return

        if ',' in image_data:
            image_data = image_data.split(',', 1)[1]

        decoded_data = base64.b64decode(image_data)
        np_data = np.frombuffer(decoded_data, np.uint8)
        img = cv2.imdecode(np_data, cv2.IMREAD_COLOR)

        if img is None:
            emit('prediction_result', {'char': '...'})
            return

        data_aux = []
        x_ = []
        y_ = []

        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        results = hands.process(img_rgb)

        response_text = "..."
        confidence = 0.0

        if results.multi_hand_landmarks:
            num_hands = len(results.multi_hand_landmarks)

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

            try:
                active_model = model_single if num_hands == 1 else (model_two if num_hands == 2 else None)

                if active_model is not None:
                    features = [np.asarray(data_aux, dtype=np.float32)]
                    if hasattr(active_model, "predict_proba"):
                        probs = active_model.predict_proba(features)[0]
                        max_idx = int(np.argmax(probs))
                        confidence = float(probs[max_idx])
                        if confidence >= CONFIDENCE_THRESHOLD:
                            raw_pred = active_model.classes_[max_idx]
                        else:
                            raw_pred = None
                    else:
                        raw_pred = active_model.predict(features)[0]
                        confidence = 1.0

                    if raw_pred is not None:
                        if isinstance(raw_pred, (str, np.str_)):
                            response_text = str(raw_pred)
                        else:
                            response_text = labels_dict.get(int(raw_pred), '?')

            except Exception as e:
                print(f"❌ Tahmin hatası: {e}")

        emit('prediction_result', {'char': response_text, 'confidence': round(confidence, 2)})

    except Exception as e:
        print(f"Frame işleme hatası: {e}")
        emit('prediction_result', {'char': '...'})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print("=" * 50)
    print("🚀 İşaret Dili Tanıma API Sunucusu")
    print("=" * 50)
    print(f"📡 Sunucu adresi: http://0.0.0.0:{port}")
    print("=" * 50)
    socketio.run(app, host='0.0.0.0', port=port, debug=False)
