"""
==============================================================================
İŞARET DİLİ TANÍMA API SUNUCUSU
==============================================================================
Bu dosya, Flask-SocketIO kullanarak gerçek zamanlı işaret dili tanıma 
sunucusu oluşturur. Mobil uygulamadan gelen kamera görüntülerini alır,
MediaPipe ile el tespiti yapar ve eğitilmiş model ile tahmin üretir.

Özellikler:
- WebSocket üzerinden gerçek zamanlı iletişim
- MediaPipe ile el landmark tespiti
- Tek el ve iki el modeli desteği
- Mobil cihazdan veri toplama modu

Kullanım:
    python api_socket.py

Sunucu varsayılan olarak 0.0.0.0:5000 adresinde çalışır.
==============================================================================
"""

# ======================== KÜTÜPHANE İMPORTLARI ========================
import pickle          # Model dosyasını yüklemek için
import cv2             # Görüntü işleme (OpenCV)
import mediapipe as mp # El tespiti için Google MediaPipe
import numpy as np     # Sayısal işlemler için
import base64          # Görüntü verisini decode etmek için
import os              # Dosya/klasör işlemleri
from datetime import datetime  # Zaman damgası oluşturmak için
from flask import Flask        # Web sunucusu framework
from flask_socketio import SocketIO, emit  # WebSocket desteği

# ======================== FLASK UYGULAMASI ========================
# Flask uygulaması oluştur
app = Flask(__name__)

# SocketIO'yu CORS (Cross-Origin) desteği ile başlat
# cors_allowed_origins='*' tüm kaynaklardan bağlantıya izin verir
socketio = SocketIO(app, cors_allowed_origins='*')

# ======================== MODEL YÜKLEME ========================
# Eğitilmiş modeli pickle dosyasından yükle
# model.p dosyası 3 model eğitimi ve kaydedilmesi.py tarafından oluşturulur
model_dict = pickle.load(open('./model.p', 'rb'))

# Model yapısını kontrol et ve uygun modeli al
# Yeni format: {'models': {'single_hand': model1, 'two_hand': model2}}
# Eski format: {'model': model}
if 'models' in model_dict:
    models = model_dict['models']
    model_single = models.get('single_hand')  # Tek el modeli
    model_two = models.get('two_hand')        # İki el modeli
else:
    # Geriye uyumluluk için eski format desteği
    model_single = model_dict.get('model')
    model_two = None

# Model yükleme durumunu konsola yazdır
print(f"Tek el modeli: {'Yüklendi' if model_single else 'Yok'}")
print(f"İki el modeli: {'Yüklendi' if model_two else 'Yok'}")

# ======================== MEDİAPIPE AYARLARI ========================
# MediaPipe el tespiti modülünü başlat
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=True,   # True: Her frame bağımsız işlenir (mobil için daha iyi)
                              # False: Video akışı optimizasyonu (tracking kullanır)
    min_detection_confidence=0.4,  # El tespit güvenlik eşiği (0.0-1.0)
                                   # Düşük değer = daha kolay tespit, daha fazla yanlış pozitif
    min_tracking_confidence=0.4,   # El takip güvenlik eşiği
    max_num_hands=2                # Maksimum tespit edilecek el sayısı
)

# ======================== ETİKET SÖZLÜĞÜ ========================
# Model çıktısını (sayı) harfe dönüştürmek için sözlük
# Türk İşaret Dili alfabesi (29 harf)
labels_dict = {
    0: 'A', 1: 'B', 2: 'C', 3: 'Ç', 4: 'D', 5: 'E', 
    6: 'F', 7: 'G', 8: 'Ğ', 9: 'H', 10: 'I', 11: 'İ', 
    12: 'J', 13: 'K', 14: 'L', 15: 'M', 16: 'N', 17: 'O', 
    18: 'Ö', 19: 'P', 20: 'R', 21: 'S', 22: 'Ş', 23: 'T', 
    24: 'U', 25: 'Ü', 26: 'V', 27: 'Y', 28: 'Z'
}

# ======================== VERİ TOPLAMA AYARLARI ========================
# Mobil cihazdan toplanan görüntülerin kaydedileceği klasör
MOBILE_DATA_DIR = './mobile_data'
os.makedirs(MOBILE_DATA_DIR, exist_ok=True)  # Klasör yoksa oluştur

# Veri toplama modu değişkenleri (global)
collecting_data = False    # Veri toplama aktif mi?
current_letter = None      # Hangi harf için veri toplanıyor?
collected_count = 0        # Toplanan görüntü sayısı

# ======================== SOCKET OLAY İŞLEYİCİLERİ ========================

@socketio.on('connect')
def handle_connect():
    """
    Mobil cihaz bağlandığında tetiklenir.
    Bağlantı durumunu konsola yazdırır.
    """
    print('📱 Mobil cihaz bağlandı!')

@socketio.on('disconnect')
def handle_disconnect():
    """
    Mobil cihaz bağlantısı kesildiğinde tetiklenir.
    """
    print('📴 Mobil cihaz ayrıldı')

@socketio.on('start_collection')
def handle_start_collection(data):
    """
    Veri toplama modunu başlatır.
    
    Args:
        data (dict): {'letter': 'A'} formatında harf bilgisi
    
    İşleyiş:
    1. Hangi harf için veri toplanacağını belirle
    2. O harf için klasör oluştur
    3. Sayacı sıfırla
    4. Mobil uygulamaya 'started' durumu gönder
    """
    global collecting_data, current_letter, collected_count
    
    # Hangi harf için veri toplanacak
    current_letter = data.get('letter', 'A')
    collecting_data = True
    collected_count = 0
    
    # Harf için klasör oluştur (örn: ./mobile_data/A/)
    letter_dir = os.path.join(MOBILE_DATA_DIR, current_letter)
    os.makedirs(letter_dir, exist_ok=True)
    
    print(f"📸 Veri toplama başladı: {current_letter}")
    
    # Mobil uygulamaya durum bildir
    emit('collection_status', {'status': 'started', 'letter': current_letter})

@socketio.on('stop_collection')
def handle_stop_collection():
    """
    Veri toplama modunu durdurur.
    Toplanan görüntü sayısını mobil uygulamaya bildirir.
    """
    global collecting_data, current_letter, collected_count
    
    collecting_data = False
    print(f"✅ Veri toplama tamamlandı: {current_letter} - {collected_count} görüntü")
    
    # Mobil uygulamaya sonucu bildir
    emit('collection_status', {'status': 'stopped', 'count': collected_count})
    
    # Değişkenleri sıfırla
    current_letter = None
    collected_count = 0

@socketio.on('frame_data')
def handle_frame(data):
    """
    Mobil uygulamadan gelen her kamera frame'ini işler.
    
    Args:
        data (dict): {'image': 'base64_encoded_jpeg'} formatında görüntü
    
    İşleyiş:
    1. Base64 formatındaki görüntüyü decode et
    2. JPEG'den OpenCV formatına çevir
    3. Veri toplama modundaysa görüntüyü kaydet
    4. Tahmin modundaysa:
       a. MediaPipe ile el tespiti yap
       b. El landmark'larını çıkar
       c. Modele gönder ve tahmin al
       d. Sonucu mobil uygulamaya gönder
    """
    global collected_count
    
    try:
        # ===== GÖRÜNTÜ DECODE =====
        # Base64 string'i byte dizisine çevir
        image_data = data['image']
        decoded_data = base64.b64decode(image_data)
        
        # Byte dizisini numpy array'e çevir
        np_data = np.frombuffer(decoded_data, np.uint8)
        
        # JPEG'i OpenCV BGR formatına decode et
        img = cv2.imdecode(np_data, cv2.IMREAD_COLOR)

        # Görüntü decode edilemezse
        if img is None:
            emit('prediction_result', {'char': '...'})
            return

        # ===== VERİ TOPLAMA MODU =====
        if collecting_data and current_letter:
            # Görüntüyü ilgili klasöre kaydet
            letter_dir = os.path.join(MOBILE_DATA_DIR, current_letter)
            
            # Benzersiz dosya adı oluştur (tarih + mikrosaniye)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            filename = f"{current_letter}_{timestamp}.jpg"
            filepath = os.path.join(letter_dir, filename)
            
            # Görüntüyü kaydet
            cv2.imwrite(filepath, img)
            collected_count += 1
            
            print(f"💾 Kaydedildi: {filename} (Toplam: {collected_count})")
            
            # Mobil uygulamaya kaydetme durumunu bildir
            emit('collection_status', {'status': 'saved', 'count': collected_count})
            return

       
        data_aux = []  
        y_ = []        

        # BGR'den RGB'ye çevir (MediaPipe RGB bekler)
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # MediaPipe ile el tespiti yap
        results = hands.process(img_rgb)

        # Varsayılan yanıt (el bulunamadı)
        response_text = "..."

        if results.multi_hand_landmarks:
            # Tespit edilen el sayısı
            num_hands = len(results.multi_hand_landmarks)
            
            
            for hand_landmarks in results.multi_hand_landmarks:
                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x  # 0-1 arası normalize x
                    y = hand_landmarks.landmark[i].y  # 0-1 arası normalize y
                    x_.append(x)
                    y_.append(y)

           
            for hand_landmarks in results.multi_hand_landmarks:
                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x
                    y = hand_landmarks.landmark[i].y
                    # Her koordinattan minimum değeri çıkar
                    data_aux.append(x - min(x_))
                    data_aux.append(y - min(y_))

            # ===== MODEL TAHMİNİ =====
            try:
                # El sayısına göre uygun modeli seç
                if num_hands == 1 and model_single is not None:
                    # Tek el modeli ile tahmin
                    prediction = model_single.predict([np.asarray(data_aux)])
                elif num_hands == 2 and model_two is not None:
                    # İki el modeli ile tahmin
                    prediction = model_two.predict([np.asarray(data_aux)])
                else:
                    prediction = None

                # Tahmin sonucunu işle
                if prediction is not None:
                    # Model doğrudan string döndürüyorsa
                    if isinstance(prediction[0], (str, np.str_)):
                        response_text = str(prediction[0])
                    else:
                        # Model sayı döndürüyorsa sözlükten harfi al
                        response_text = labels_dict.get(int(prediction[0]), '?')
                        
            except Exception as e:
                print(f"❌ Tahmin hatası: {e}")
        
        # Sonucu mobil uygulamaya gönder
        emit('prediction_result', {'char': response_text})

    except Exception as e:
        print(f"Frame işleme hatası: {e}")
        emit('prediction_result', {'char': '...'})

# ======================== ANA PROGRAM ========================
if __name__ == '__main__':
    # Başlangıç bilgilerini yazdır
    print("="*50)
    print("🚀 İşaret Dili API Sunucusu (Veri Toplama Destekli)")
    print("="*50)
    print("📡 Sunucu adresi: http://0.0.0.0:5000")
    print("💡 Mobil uygulamada bu bilgisayarın IP adresini kullanın")
    print(f"📁 Mobil veri klasörü: {os.path.abspath(MOBILE_DATA_DIR)}")
    print("="*50)
    
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)