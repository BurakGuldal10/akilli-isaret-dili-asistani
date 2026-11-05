# 🤟 Akıllı İşaret Dili Asistanı (TİD Eğitim & Tanıma Platformu)

Türk İşaret Dili (TİD) alfabesindeki **29 harfi** gerçek zamanlı olarak tanıyan, kullanıcıların pratik yaparak harfleri öğrenmesini sağlayan **Python (Flask-SocketIO + MediaPipe + Scikit-Learn)** ve **Flutter (Mobil & Web)** tabanlı eğitim platformu.

---

## 🏗️ Proje Mimarisi

Proje; **Sunucu (`backend/`)**, **Model Eğitim Hattı (`ml_training/`)** ve **Katmanlı Flutter İstemcisi (`mobil_uygulama/`)** olmak üzere 3 ana modüle ayrılmıştır:

```text
akilli-isaret-dili-asistani/
├── backend/                          # Gerçek Zamanlı WebSocket API Sunucusu
│   ├── app.py                        # Flask-SocketIO + MediaPipe + Model tahmin sunucusu
│   ├── requirements.txt              # Sunucu Python bağımlılıkları
│   └── models/                       # Eğitilmiş model (model.p) ve etiketler (labels.txt)
│
├── ml_training/                      # Harici Veri Seti İşleme ve Model Eğitim Hattı
│   ├── 1_inspect_dataset.py          # Veri seti klasör ve sınıf dağılımı doğrulama aracı
│   ├── 2_process_dataset.py          # MediaPipe landmark çıkarımı, [0, 1] ölçekleme ve augmentation
│   ├── 3_train_model.py              # Tek el (42) ve çift el (84) Random Forest model eğitimi
│   ├── 4_test_webcam.py              # Bilgisayar kamerası ile gerçek zamanlı model testi
│   └── requirements.txt              # Eğitim ortamı bağımlılıkları
│
├── mobil_uygulama/                   # Flutter Mobil (Android/iOS) & Web Uygulaması
│   └── lib/
│       ├── main.dart                 # Uygulama başlangıç noktası
│       ├── core/
│       │   └── app_theme.dart        # Renk paleti, karanlık tema ve stil sabitleri
│       ├── models/
│       │   └── letter_info.dart      # 29 harf için TİD yapılış rehberi ve el sayısı modeli
│       ├── providers/
│       │   └── app_state.dart        # Öğrenme ilerlemesi, skor ve sunucu ayarları durumu
│       ├── services/
│       │   ├── socket_service.dart   # Socket.IO WebSocket iletişim servisi
│       │   └── image_converter.dart  # Arka plan Isolate YUV420 -> JPEG dönüştürücü
│       ├── screens/
│       │   ├── main_navigation_screen.dart # 4 sekmeli alt menü çerçevesi
│       │   ├── home_screen.dart      # Harf öğrenme, filtreleme ve ilerleme ekranı
│       │   ├── recognition_screen.dart # Kamera ile gerçek zamanlı harf pratiği
│       │   └── settings_screen.dart  # Sunucu bağlantı ayarları ve istatistik ekranı
│       └── widgets/
│           ├── letter_card.dart      # Harf kartı bileşeni
│           ├── letter_guide_sheet.dart # Harf nasıl yapılır bilgi penceresi (BottomSheet)
│           └── stat_card.dart        # İstatistik bilgi kartı
│
└── docs/                             # Proje geliştirme yol haritası ve teknik raporlar
    └── Proje_Gelistirme_Yol_Haritasi_ve_Rapor.pdf
```

---

## 🚀 Hızlı Başlangıç

### 1️⃣ Model Eğitimi (`ml_training/`)
İndirdiğiniz Türk İşaret Dili veri setini `./data/<HARF>/` klasörüne yerleştirdikten sonra:

```bash
# 1. Veri setini kontrol et
python ml_training/1_inspect_dataset.py

# 2. Görüntülerden ölçekten bağımsız [0, 1] el koordinatlarını çıkar
python ml_training/2_process_dataset.py

# 3. Modeli eğit ve backend/models/model.p olarak kaydet
python ml_training/3_train_model.py
```

### 2️⃣ API Sunucusunu Başlatma (`backend/`)

```bash
pip install -r backend/requirements.txt
python backend/app.py
```
Sunucu varsayılan olarak `http://0.0.0.0:5000` adresinde çalışır. Sağlık kontrolü için `http://localhost:5000/health` adresini ziyaret edebilirsiniz.

### 3️⃣ Mobil & Web Uygulamasını Çalıştırma (`mobil_uygulama/`)

```bash
cd mobil_uygulama
flutter pub get
flutter run
```
Uygulama içindeki **Ayarlar** sekmesinden veya kamera ekranının sağ üst köşesindeki bağlantı ikonundan sunucu IP adresinizi (`http://192.168.1.x:5000`) anında güncelleyebilirsiniz.
