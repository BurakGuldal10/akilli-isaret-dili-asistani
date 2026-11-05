# 📖 İŞARET DİLİ TANIMA PROJESİ

## 📋 Proje Özeti

Bu proje, Türk İşaret Dili alfabesini (29 harf) gerçek zamanlı olarak tanıyan bir makine öğrenmesi uygulamasıdır. Proje iki ana bileşenden oluşur:

1. **Python Backend**: Veri toplama, model eğitimi ve API sunucusu
2. **Flutter Mobil Uygulama**: Kullanıcı arayüzü ve kamera entegrasyonu

---

## 🔄 İş Akışı Diyagramı

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           İŞARET DİLİ TANIMA PROJESİ                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
    ┌─────────────────────────────────┼─────────────────────────────────────┐
    │                                 │                                     │
    ▼                                 ▼                                     ▼
┌─────────┐    ┌─────────┐    ┌─────────────┐    ┌─────────┐    ┌──────────────┐
│1. Veri  │───▶│2. Veri  │───▶│3. Model     │───▶│4. Test  │    │ 5. Mobil     │
│ Toplama │    │ İşleme  │    │   Eğitimi   │    │(PC'de)  │    │  Uygulama    │
└─────────┘    └─────────┘    └─────────────┘    └─────────┘    └──────────────┘
    │               │               │                                │
    ▼               ▼               ▼                                ▼
 ./data/        data.pickle      model.p                      api_socket.py
 (resimler)    (özellikler)     (model)                        (sunucu)
```

---

## 📂 PYTHON DOSYALARI

### 1️⃣ `1 veri toplama.py` - Veri Toplama

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Kameradan el işareti görüntüleri toplamak |
| **Girdi** | Bilgisayar kamerası |
| **Çıktı** | `./data/A/`, `./data/B/`, ... klasörlerinde `.jpg` dosyaları |

**Kontroller:**
- `q`: Veri toplamaya başla
- `s`: Harfi atla
- `n` veya `SPACE`: Sonraki harfe geç
- `ESC`: Programdan çık

**Özellikler:**
- Her harf için 300 resim toplar
- Türkçe alfabe desteği: 29 harf (A-Z + Ç, Ğ, İ, Ö, Ş, Ü)
- Mevcut resim sayısını gösterir
- Farklı açılardan görüntü toplamayı teşvik eder

---

### 2️⃣ `2 veri işleme1.py` - Veri İşleme

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Toplanan resimleri model için işlemek |
| **Girdi** | `./data/` klasöründeki resimler |
| **Çıktı** | `data.pickle` dosyası |

**İşleyiş:**
1. Her resimde MediaPipe ile eli tespit et
2. 21 landmark noktasının (x, y) koordinatlarını çıkar
3. Koordinatları normalize et (pozisyondan bağımsız hale getir)
4. Veri artırma uygula (yatay aynalama)
5. Tüm veriyi pickle dosyasına kaydet

**Teknik Detaylar:**
- Her el için: 21 nokta × 2 koordinat = **42 özellik**
- İki el için: 42 × 2 = **84 özellik**
- Veri artırma ile örnek sayısı 2 katına çıkar

---

### 3️⃣ `3 model eğitimi ve kaydedilmesi.py` - Model Eğitimi

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Makine öğrenmesi modeli eğitmek |
| **Girdi** | `data.pickle` |
| **Çıktı** | `model.p` |
| **Algoritma** | Random Forest Classifier |

**Model Parametreleri:**
- `n_estimators`: 200 ağaç
- `max_depth`: 30 (derinlik sınırı)
- `min_samples_split`: 5
- `min_samples_leaf`: 2
- `test_size`: %20

**Eğitilen Modeller:**
- **Tek el modeli** (`single_hand`): 42 özellik → 29 sınıf (harf)
- **İki el modeli** (`two_hand`): 84 özellik → 29 sınıf

**Başarı Oranı:** ~%99+

---

### 4️⃣ `4 inference_classifier.py` - PC'de Test

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Modeli bilgisayar kamerasıyla test etmek |
| **Girdi** | Bilgisayar kamerası + `model.p` |
| **Çıktı** | Ekranda gerçek zamanlı tahmin |

**Çalışma Prensibi:**
1. Kamera açılır ve ısınma süresi beklenir
2. Her frame'de el tespit edilir
3. El landmark'ları çıkarılır
4. Model ile tahmin yapılır
5. Sonuç ekranda gösterilir
6. `q` tuşu ile çıkılır

**Görsel Çıktı:**
- Yeşil kutu: El tespit edildi ve tahmin başarılı
- Kırmızı kutu: El tespit edildi ama model mevcut değil
- El sayısı ve tahmin edilen harf ekranda gösterilir

---

### 5️⃣ `api_socket.py` - Mobil Sunucu

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Mobil uygulama için API sunucusu |
| **Framework** | Flask + Flask-SocketIO |
| **Port** | 5000 |
| **Protokol** | WebSocket (Socket.IO) |

**Socket Olayları:**

| Olay | Yön | Açıklama |
|------|-----|----------|
| `connect` | ← | Mobil cihaz bağlandı |
| `disconnect` | ← | Mobil cihaz ayrıldı |
| `frame_data` | ← | Görüntü verisi geldi |
| `prediction_result` | → | Tahmin sonucu |
| `start_collection` | ← | Veri toplama başlat |
| `stop_collection` | ← | Veri toplama durdur |
| `collection_status` | → | Veri toplama durumu |

**Veri Toplama Modu:**
- Mobil uygulamadan yeni harfler için veri toplanabilir
- Görüntüler `./mobile_data/{HARF}/` klasörüne kaydedilir

---

## 📱 MOBİL UYGULAMA DOSYALARI

### 📄 `lib/main.dart` - Ana Sayfa

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Harf seçim ekranı |
| **Widget** | `HomeScreen` |
| **İçerik** | 3 sütunlu grid halinde 29 harf butonu |

**İşleyiş:**
- Uygulama başlatıldığında bu ekran gösterilir
- Kullanıcı öğrenmek istediği harfe tıklar
- Seçilen harf `RecognitionScreen`'e parametre olarak gönderilir

---

### 📄 `lib/recognition_screen.dart` - Tanıma Ekranı

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Kamera ile işaret tanıma |
| **Widget** | `RecognitionScreen` (StatefulWidget) |

**Özellikler:**
- Ön kamera önizlemesi (tam ekran)
- Sunucu bağlantı durumu göstergesi
- Tahmin sonucu gösterimi (doğru/yanlış)
- Hedef harf göstergesi
- Veri toplama modu

**Frame İşleme:**
- YUV420 → RGB dönüşümü
- Görüntü yeniden boyutlandırma (240×180 px)
- JPEG sıkıştırma (%60 kalite)
- Her 10 frame'de bir gönderim

**Durum Renkleri:**
- 🔵 Mavi: Bağlı, bekleniyor
- 🟢 Yeşil: Doğru işaret
- 🔴 Kırmızı: Yanlış işaret
- 🟠 Turuncu: El algılanamıyor
- 🟣 Mor: Veri toplama modu

---

### 📄 `lib/socket_service.dart` - Socket Servisi

| Özellik | Açıklama |
|---------|----------|
| **Amaç** | Sunucu iletişimini yönetmek |
| **Kütüphane** | `socket_io_client` |

**Stream'ler:**
- `connectionStream`: Bağlantı durumu (bool)
- `predictionStream`: Tahmin sonuçları (String)
- `collectionStream`: Veri toplama durumu (Map)

**Metodlar:**
- `connect(url)`: Sunucuya bağlan
- `sendFrame(bytes)`: Görüntü gönder
- `startCollection(letter)`: Veri toplamayı başlat
- `stopCollection()`: Veri toplamayı durdur
- `dispose()`: Bağlantıyı kapat

---

## 📁 VERİ DOSYALARI

| Dosya/Klasör | İçerik | Boyut |
|--------------|--------|-------|
| `./data/` | Ham resimler (harflere göre klasörlenmiş) | ~8700 resim |
| `data.pickle` | İşlenmiş özellik vektörleri | ~4.5 MB |
| `model.p` | Eğitilmiş Random Forest modeli | ~25 MB |
| `./mobile_data/` | Mobil uygulamadan toplanan veriler | Değişken |
| `labels.txt` | Sınıf etiketleri | 87 byte |

---

## 🔧 KULLANIM KILAVUZU

### Gereksinimler

**Python:**
```bash
pip install opencv-python mediapipe numpy scikit-learn flask flask-socketio
```

**Flutter:**
```bash
flutter pub get
```

### Çalıştırma Sırası

```bash
# 1. Veri toplama (isteğe bağlı - yeni veri eklemek için)
python "1 veri toplama.py"

# 2. Veri işleme
python "2 veri işleme1.py"

# 3. Model eğitimi
python "3 model eğitimi ve kaydedilmesi.py"

# 4. PC'de test (isteğe bağlı)
python "4 inference_classifier.py"

# 5. Mobil için sunucu başlat
python api_socket.py

# 6. Flutter uygulamasını çalıştır (yeni terminal)
cd mobil_uygulama
flutter run
```

### Mobil Uygulama Ayarları

`recognition_screen.dart` dosyasında sunucu IP adresini güncelleyin:

```dart
static const String serverUrl = 'http://BILGISAYAR_IP:5000';
```

IP adresini bulmak için:
- **Windows:** `ipconfig` komutu
- **Mac/Linux:** `ifconfig` komutu

---

## 🏗️ TEKNİK MİMARİ

```
┌─────────────────────────────────────────────────────────────────┐
│                         MOBİL UYGULAMA                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   Kamera    │───▶│  YUV→RGB   │───▶│ JPEG Sıkıştırma     │  │
│  │  (Flutter)  │    │  Dönüşüm   │    │ (240×180, %60)      │  │
│  └─────────────┘    └─────────────┘    └──────────┬──────────┘  │
│                                                   │              │
│                                        ┌──────────▼──────────┐  │
│                                        │  Socket.IO Client   │  │
│                                        │   (Base64 Encode)   │  │
│                                        └──────────┬──────────┘  │
└───────────────────────────────────────────────────┼─────────────┘
                                                    │
                                          WebSocket │
                                                    │
┌───────────────────────────────────────────────────┼─────────────┐
│                        PYTHON SUNUCU              │              │
│                                        ┌──────────▼──────────┐  │
│                                        │  Socket.IO Server   │  │
│                                        │  (Base64 Decode)    │  │
│                                        └──────────┬──────────┘  │
│                                                   │              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────▼───────────┐  │
│  │   Model     │◀───│  Özellik    │◀───│    MediaPipe       │  │
│  │  (Predict)  │    │  Çıkarma    │    │   El Tespiti       │  │
│  └──────┬──────┘    └─────────────┘    └─────────────────────┘  │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   Sonuç     │───▶ {'char': 'A'} ───▶ Mobil Uygulamaya       │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 NOTLAR

- Modelin doğruluğu, eğitim verisinin kalitesine bağlıdır
- İyi aydınlatma el tespitini kolaylaştırır
- Farklı açılardan veri toplamak modeli güçlendirir
- Mobil ve PC aynı Wi-Fi ağında olmalıdır

---

## 👨‍💻 GELİŞTİRİCİ

Bu proje, Türk İşaret Dili eğitimi için geliştirilmiştir.

---

*Son güncelleme: 25 Aralık 2025*
