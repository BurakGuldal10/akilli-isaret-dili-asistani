import pickle
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import numpy as np

data_dict = pickle.load(open("data.pickle", "rb"))

# El sayılarını kontrol et
hand_counts = data_dict.get("hand_counts", [1] * len(data_dict["data"]))

# Tek el verileri (42 özellik)
single_hand_data = []
single_hand_labels = []

# İki el verileri (84 özellik)
two_hand_data = []
two_hand_labels = []

SINGLE_HAND_FEATURES = 42  # 21 landmark * 2 koordinat
TWO_HAND_FEATURES = 84     # 42 * 2 el

for d, l, h in zip(data_dict["data"], data_dict["labels"], hand_counts):
    try:
        arr = np.array(d).flatten()
        if h == 1 and len(arr) == SINGLE_HAND_FEATURES:
            single_hand_data.append(arr)
            single_hand_labels.append(l)
        elif h == 2 and len(arr) == TWO_HAND_FEATURES:
            two_hand_data.append(arr)
            two_hand_labels.append(l)
    except Exception:
        pass

print("=" * 50)
print("MODEL EĞİTİMİ")
print("=" * 50)
print(f"Tek el veri sayısı: {len(single_hand_data)}")
print(f"İki el veri sayısı: {len(two_hand_data)}")
print("=" * 50)

models = {}

# İyileştirilmiş model parametreleri
def create_model():
    return RandomForestClassifier(
        n_estimators=200,        # 100 yerine 200 ağaç
        max_depth=30,            # Derinlik sınırı
        min_samples_split=5,     # Minimum bölünme örneği
        min_samples_leaf=2,      # Yaprakta minimum örnek
        random_state=42,
        n_jobs=-1                # Tüm CPU çekirdeklerini kullan
    )

# Tek el modeli eğit
if len(single_hand_data) > 0:
    print("\n[TEK EL MODELİ]")
    data_single = np.asarray(single_hand_data)
    labels_single = np.asarray(single_hand_labels)
    
    unique_labels = np.unique(labels_single)
    print(f"Sınıf sayısı: {len(unique_labels)}")
    
    if len(unique_labels) > 1:
        xtrain, xtest, ytrain, ytest = train_test_split(
            data_single, labels_single, test_size=0.2, shuffle=True, stratify=labels_single
        )
        
        model_single = create_model()
        print("Model eğitiliyor...")
        model_single.fit(xtrain, ytrain)
        
        y_pred = model_single.predict(xtest)
        score = accuracy_score(y_pred, ytest)
        print(f"Başarı: {score * 100:.2f}%")
        
        # En düşük performanslı sınıfları göster
        print("\nSınıf bazlı performans (düşükten yükseğe):")
        from collections import Counter
        correct = Counter()
        total = Counter()
        for true, pred in zip(ytest, y_pred):
            total[true] += 1
            if true == pred:
                correct[true] += 1
        
        class_acc = {k: correct[k]/total[k]*100 for k in total}
        sorted_acc = sorted(class_acc.items(), key=lambda x: x[1])
        for label, acc in sorted_acc[:5]:  # En düşük 5 sınıf
            print(f"  {label}: {acc:.1f}%")
        
        models["single_hand"] = model_single
    else:
        print("Tek el için yeterli sınıf yok!")

# İki el modeli eğit
if len(two_hand_data) > 0:
    print("\n[İKİ EL MODELİ]")
    data_two = np.asarray(two_hand_data)
    labels_two = np.asarray(two_hand_labels)
    
    unique_labels, counts = np.unique(labels_two, return_counts=True)
    print(f"Sınıf dağılımı: {dict(zip(unique_labels, counts))}")
    
    # En az 2 örneği olan sınıfları filtrele
    valid_labels = unique_labels[counts >= 2]
    
    if len(valid_labels) >= 2:
        mask = np.isin(labels_two, valid_labels)
        data_two_filtered = data_two[mask]
        labels_two_filtered = labels_two[mask]
        
        xtrain, xtest, ytrain, ytest = train_test_split(
            data_two_filtered, labels_two_filtered, test_size=0.2, shuffle=True
        )
        
        model_two = create_model()
        print("Model eğitiliyor...")
        model_two.fit(xtrain, ytrain)
        
        y_pred = model_two.predict(xtest)
        score = accuracy_score(y_pred, ytest)
        print(f"Başarı: {score * 100:.2f}%")
        
        models["two_hand"] = model_two
    else:
        print("İki el için yeterli sınıf yok!")

# Modelleri kaydet
print("\n" + "=" * 50)
f = open("model.p", "wb")
pickle.dump({"models": models}, f)
f.close()

print(f"Kaydedilen modeller: {list(models.keys())}")
print("Modeller başarıyla kaydedildi!")
print("=" * 50)