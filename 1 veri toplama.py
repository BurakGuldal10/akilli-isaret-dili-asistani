import os
import cv2

DATA_DIR = "./data"

# Türkçe harfler dahil tüm sınıf isimleri (29 harf)
class_names = [
    "A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H", "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P", "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"
]

# Daha fazla veri topla - 300 resim
data_size = 300

if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

cap = cv2.VideoCapture(0)

# Kamera ayarları
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

print("=" * 50)
print("VERİ TOPLAMA PROGRAMI")
print("=" * 50)
print(f"Toplam {len(class_names)} harf için veri toplanacak.")
print(f"Her harf için {data_size} resim toplanacak.")
print("=" * 50)
print("\nKontroller:")
print("  'n' veya SPACE = Sonraki harfe geç")
print("  'q' = Veri toplamaya başla")
print("  's' = Harfi atla")
print("  ESC = Programdan çık")
print("=" * 50)

for idx, class_name in enumerate(class_names):
    class_dir = os.path.join(DATA_DIR, class_name)
    if not os.path.exists(class_dir):
        os.makedirs(class_dir)
    
    # Mevcut resim sayısını kontrol et
    existing_images = len([f for f in os.listdir(class_dir) if f.endswith('.jpg')])
    
    print(f"\n[{idx + 1}/{len(class_names)}] '{class_name}' harfi - Mevcut: {existing_images} resim")
    
    # Harfi göster ve tuşa basılmasını bekle
    while True:
        _, frame = cap.read()
        
        # Harf bilgisi
        cv2.putText(frame, f"HARF: {class_name}", (200, 200), cv2.FONT_HERSHEY_SIMPLEX, 3, (0, 255, 0), 5)
        cv2.putText(frame, f"[{idx + 1}/{len(class_names)}]", (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        cv2.putText(frame, f"Mevcut: {existing_images} resim", (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
        cv2.putText(frame, "SPACE/n: Sonraki | q: Topla | s: Atla | ESC: Cik", (30, 450), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
        
        cv2.imshow("frame", frame)
        
        key = cv2.waitKey(25) & 0xFF
        
        if key == ord("n") or key == ord(" "):  # Sonraki harfe geç
            print(f"  '{class_name}' atlandı (sonraki harfe geçildi)")
            break
        elif key == ord("q"):  # Veri topla
            print(f"  '{class_name}' için veri toplama başlıyor...")
            
            counter = existing_images
            target = data_size
            
            while counter < target:
                _, frame = cap.read()
                
                progress = f"{class_name}: {counter}/{target}"
                cv2.putText(frame, progress, (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                cv2.putText(frame, "Farkli acilardan gosterin!", (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                
                cv2.imshow("frame", frame)
                cv2.waitKey(25)
                cv2.imwrite(os.path.join(class_dir, f"{counter}.jpg"), frame)
                counter += 1
            
            print(f"  '{class_name}' tamamlandı: {counter} resim")
            break
            
        elif key == ord("s"):  # Atla
            print(f"  '{class_name}' atlandı.")
            break
            
        elif key == 27:  # ESC - Programdan çık
            print("\nProgram sonlandırıldı.")
            cap.release()
            cv2.destroyAllWindows()
            exit()

cap.release()
cv2.destroyAllWindows()
print("\nVeri toplama tamamlandı!")
