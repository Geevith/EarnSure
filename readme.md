# 🚀 EarnSure Platform

EarnSure is a **B2B2C Parametric Insurance platform** designed specifically for **Food Delivery Riders**, featuring **Edge-AI anti-spoofing** and **automated claim processing**.

This repository is a **monorepo** containing the complete EarnSure stack:

- **FastAPI backend**
- **Next.js admin dashboard**
- **Flutter mobile application**

---

# 📂 Repository Structure

```bash
/app                # Python/FastAPI Backend (Dockerized)
/earnsure-admin     # Next.js Web Admin Dashboard
/earnsure_app       # Flutter Mobile App for Riders
docker-compose.yml  # Orchestrates backend, Celery workers, PostgreSQL
```

---

# 🛠️ Prerequisites

Before you begin, ensure you have the following installed:

1. **Docker Desktop** (running in background)
2. **Flutter SDK**
3. **Node.js & npm**
4. **Git**

---

# 🚦 Step-by-Step Local Setup

## 1️⃣ Clone & Configure Environment

```bash
git clone https://github.com/YOUR_USERNAME/earnsure_app.git
cd earnsure_app

# Create local environment file
cp .env.example .env
```

Update the `.env` file with the required **API keys** or **database credentials**.

---

## 2️⃣ Start Backend (Docker)

```bash
docker-compose up --build -d
```

### Backend Services
- **API Docs:** `http://localhost:8000/docs`
- **PostgreSQL:** `localhost:5432`

---

## 3️⃣ Start Admin Dashboard (Next.js)

```bash
cd earnsure-admin
npm install
npm run dev
```

### Admin Dashboard
- **URL:** `http://localhost:3000`

---

## 4️⃣ Start Rider App (Flutter)

```bash
cd earnsure_app
flutter pub get
```

### ▶️ Run on Chrome (Fast UI Testing)

```bash
flutter run -d chrome
```

### 📱 Run on Android Emulator (Sensor Testing)

```bash
flutter run
```

---

# 🤝 Contributing

- Create a new branch for your changes
- Test against the local Docker environment
- Open a Pull Request once validated

---

# 🚀 Push to GitHub

```bash
git add .
git commit -m "Initial commit: EarnSure monorepo MVP"
git branch -M main
git remote add origin https://github.com/YourUsername/earnsure_app.git
git push -u origin main
```

---

# 📌 Tech Stack

- **Backend:** FastAPI, Celery, PostgreSQL, Docker
- **Admin Dashboard:** Next.js
- **Mobile App:** Flutter
- **Infrastructure:** Docker Compose

---

# 🌟 Key Features

- Parametric insurance for riders
- Edge-AI anti-spoofing
- Automated claim processing
- Admin analytics dashboard
- Rider mobile app
- Real-time risk & payout workflows