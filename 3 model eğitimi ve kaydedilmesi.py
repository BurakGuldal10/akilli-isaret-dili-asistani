import pickle
from collections import Counter
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import numpy as np

data_dict = pickle.load(open("data.pickle", "rb"))

hand_counts = data_dict.get("hand_counts", [1] * len(data_dict["data"]))
is_normalized = data_dict.get("normalized", False)

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
        arr = np.array(d, dtype=np.float32).flatten()
        if h == 1 and len(arr) == SINGLE_HAND_FEATURES:
            single_hand_data.append(arr)
            single_hand_labels.append(l)
        elif h == 2 and len(arr) == TWO_HAND_FEATURES:
            two_hand_data.append(arr)
            two_hand_labels.append(l)
    except Exception:
        pass

print("=" * 50)
print("HARİCİ VERİ SETİ İLE MODEL EĞİTİMİ")
print("=" * 50)
print(f"Tek el veri sayısı : {len(single_hand_data)}")
print(f"İki el veri sayısı : {len(two_hand_data)}")
print(f"Ölçek normalizasyonu: {'Aktif ([0, 1])' if is_normalized else 'Eski tip'}")
print("=" * 50)

models = {}


def create_model():
    """
    Harici veri setlerindeki sınıf dengesizliklerini (farklı resim sayılarını)
    dengelemek için class_weight='balanced' kullanılır.
    """
    return RandomForestClassifier(
        n_estimators=150,
        max_depth=25,
        min_samples_split=5,
        min_samples_leaf=2,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )


# Tek el modeli eğit
if len(single_hand_data) > 0:
    print("\n[TEK EL MODELİ]")
    data_single = np.asarray(single_hand_data, dtype=np.float32)
    labels_single = np.asarray(single_hand_labels)

    unique_labels, counts = np.unique(labels_single, return_counts=True)
    valid_labels = unique_labels[counts >= 2]
    print(f"Sınıf sayısı: {len(valid_labels)}")

    if len(valid_labels) > 1:
        mask = np.isin(labels_single, valid_labels)
        data_single = data_single[mask]
        labels_single = labels_single[mask]

        xtrain, xtest, ytrain, ytest = train_test_split(
            data_single, labels_single, test_size=0.2, shuffle=True, stratify=labels_single, random_state=42
        )

        model_single = create_model()
        print("Model eğitiliyor...")
        model_single.fit(xtrain, ytrain)

        y_pred = model_single.predict(xtest)
        score = accuracy_score(ytest, y_pred)
        print(f"Başarı: {score * 100:.2f}%")

        print("\nSınıf bazlı performans (en düşük 5 sınıf):")
        correct = Counter()
        total = Counter()
        for true, pred in zip(ytest, y_pred):
            total[true] += 1
            if true == pred:
                correct[true] += 1

        class_acc = {k: correct[k] / total[k] * 100 for k in total}
        sorted_acc = sorted(class_acc.items(), key=lambda x: x[1])
        for label, acc in sorted_acc[:5]:
            print(f"  {label}: {acc:.1f}%")

        models["single_hand"] = model_single
    else:
        print("Tek el için yeterli sınıf yok!")

# İki el modeli eğit
if len(two_hand_data) > 0:
    print("\n[İKİ EL MODELİ]")
    data_two = np.asarray(two_hand_data, dtype=np.float32)
    labels_two = np.asarray(two_hand_labels)

    unique_labels, counts = np.unique(labels_two, return_counts=True)
    print(f"Sınıf dağılımı: {dict(zip(unique_labels, counts))}")

    valid_labels = unique_labels[counts >= 2]

    if len(valid_labels) >= 2:
        mask = np.isin(labels_two, valid_labels)
        data_two_filtered = data_two[mask]
        labels_two_filtered = labels_two[mask]

        xtrain, xtest, ytrain, ytest = train_test_split(
            data_two_filtered, labels_two_filtered, test_size=0.2, shuffle=True, stratify=labels_two_filtered, random_state=42
        )

        model_two = create_model()
        print("Model eğitiliyor...")
        model_two.fit(xtrain, ytrain)

        y_pred = model_two.predict(xtest)
        score = accuracy_score(ytest, y_pred)
        print(f"Başarı: {score * 100:.2f}%")

        models["two_hand"] = model_two
    else:
        print("İki el için yeterli sınıf yok!")

# Modelleri kaydet
print("\n" + "=" * 50)
with open("model.p", "wb") as f:
    pickle.dump({"models": models, "normalized": is_normalized}, f)

print(f"Kaydedilen modeller: {list(models.keys())}")
print("Modeller başarıyla 'model.p' dosyasına kaydedildi!")
print("=" * 50)
