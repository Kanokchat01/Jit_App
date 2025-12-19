# 🧠 JidDee – Mental Health Assessment App (Flutter + Firebase)

JidDee เป็นแอปประเมินสุขภาพจิต พัฒนาโดยใช้ **Flutter** และ **Firebase**  
ออกแบบมาเพื่อรองรับผู้ใช้งานหลายบทบาท (Patient / Clinician / Admin)  
โดยมีฟีเจอร์หลักคือ **PHQ-9 Mental Health Assessment** และ Dashboard สำหรับผู้ดูแล

---

## ✨ Features (ปัจจุบัน)
- 🔐 Firebase Authentication (Email / Password)
- 👤 Role-based App (Patient / Clinician / Admin)
- 📝 PHQ-9 Mental Health Assessment
- 🎯 Risk Classification (Green / Yellow / Red)
- 📊 Dashboard สำหรับ Clinician/Admin
- ☁️ Firebase Firestore Database
- ⚙️ FlutterFire (รองรับ Android / iOS / Web / Windows)

---

## 🧩 Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend / Auth / DB:** Firebase
  - Firebase Authentication
  - Cloud Firestore
- **Tools:** FlutterFire CLI, Firebase CLI, GitHub

---

## 📁 Project Structure
lib/
├── main.dart
├── firebase_options.dart (generated, not tracked)
├── gates/ # AuthGate / RoleGate
├── models/ # Data models (User, PHQ9)
├── services/ # Firestore services
├── shells/ # Patient / Dashboard shell
├── screens/แก
│ ├── auth/ # Login
│ ├── patient/ # Patient UI (Home, PHQ-9)
│ └── dashboard/ # Clinician/Admin UI

yaml
คัดลอกโค้ด

---

## 🚀 Getting Started (For New Contributors)

### 1️⃣ Clone Repository
```bash
git clone https://github.com/<your-repo>/flutter-jiddee.git
cd flutter-jiddee
2️⃣ Install Dependencies
bash
คัดลอกโค้ด
flutter pub get
🔥 Firebase Setup (สำคัญมาก)
❗ ไฟล์ Firebase ไม่ได้ถูก push ขึ้น repo เพื่อความปลอดภัย
ทุกคนต้องตั้ง Firebase ของตัวเอง

3️⃣ Install Firebase Tools
bash
คัดลอกโค้ด
npm install -g firebase-tools
dart pub global activate flutterfire_cli
Login Firebase:

bash
คัดลอกโค้ด
firebase login
4️⃣ Configure Firebase for this Project
bash
คัดลอกโค้ด
flutterfire configure
เลือก:

Firebase project ของคุณ

Platforms: Android (และอื่น ๆ ถ้าต้องการ)

หลังจากนี้จะได้ไฟล์:

bash
คัดลอกโค้ด
lib/firebase_options.dart
android/app/google-services.json
▶️ Run the App
bash
คัดลอกโค้ด
flutter run
👥 User Roles
Role	Description
patient	ผู้ใช้ทั่วไป ทำแบบประเมิน
clinician	ดู Dashboard ผู้ป่วย
admin	จัดการระบบ

ค่า role ถูกเก็บใน Firestore:

bash
คัดลอกโค้ด
users/{uid}/role
ตัวอย่าง:

json
คัดลอกโค้ด
role: "clinician"
📝 PHQ-9 Risk Logic (MVP)
0–4 → Green

5–14 → Yellow

15+ → Red

ถ้าข้อ 9 > 0 → Red (Self-harm risk)

🧑‍💻 Development Workflow (แนะนำ)
bash
คัดลอกโค้ด
git checkout -b feature/your-feature-name
# code...
git add .
git commit -m "Add new feature"
git push origin feature/your-feature-name
ใช้ Pull Request ในการ merge

🔒 Security Notes
❌ ห้าม commit:

firebase_options.dart

google-services.json

ใช้ .gitignore ที่เตรียมไว้แล้ว

🛣️ Roadmap (งานที่ยังทำต่อได้)
 UI/UX improvement

 PHQ-9 History & Graph

 TMHI-55 Assessment

 Appointment System

 Notification (Firebase Cloud Messaging)

 Emotion Recognition (Vision / AI)

🤝 Contributors
Initial Developer: (your name)

Team Members: (add names here)

📄 License
This project is for educational and research purposes.

yaml
คัดลอกโค้ด

---

## ✅ สิ่งที่ผมแนะนำให้คุณทำต่อทันที
1. สร้างไฟล์ `README.md`
2. วางเนื้อหานี้ทั้งหมด
3. Commit + Push
```bash
git add README.md
git commit -m "Add project README"
git push


hhhhh