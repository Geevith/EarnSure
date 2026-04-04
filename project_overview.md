
# EarnSure
**Your earnings. Assured !**

###  [Watch our 2-Minute Project Brief Video Here](https://youtu.be/nM_pFawiAp8)

---

##  1. Executive Summary
**EarnSure** is a B2B2C embedded parametric insurance platform protecting food delivery riders' income during peak earning disruptions. Using hexagonal geospatial grids (Uber H3), Edge-AI physics-based anti-spoofing, and Dual-Key Consensus triggers,We enable instant payouts through a risk-aware model designed to optimize loss ratios and support strong, sustainable margins.

---

##  2. Problem Statement (Hackathon Persona: Food Delivery)
**1.2M riders lose ₹5-8K/week** from 20-30 minute disruptions during **Peak Hours** (Lunch 12-3 PM, Dinner 7-11 PM) due to:
1. Monsoon flooding (>25mm/hr)
2. Heatwaves (>45°C)
3. Traffic gridlock/civic barricades
4. Platform dispatch outages (Webhook 5xx status >45min)

 **The Crisis Addressed**: Telegram syndicates are currently spoofing GPS from fraud farms, draining liquidity pools. EarnSure's architecture renders this physically impossible.

---

##  3. Solution Overview (Persona Scenario & Workflow)
EarnSure is a B2B2C Embedded Engine running natively inside Swiggy/Zomato rider apps.

> **The Seamless Workflow:**
> Rider opens the app → Sees “Insurance Active: ₹98/week” → Monsoon impacts mapped zone → Edge AI validates event conditions → Dual-key consensus initiates → Payout is processed .

---

##  4. Core Mandatory Features 

### 4.1 AI-Powered Risk Assessment 
**Dynamic Weekly Premium Engine**:
```python
premium = base_rate + (disruption_prob * zone_risk * historical_claims_factor)
# Example: Chennai rider, high monsoon forecast → ₹98/week
```
* **ML Model**: XGBoost trained on 7-day weather forecasts + rider history.
* **Streak Discount**: 15% discount applied after 4 consecutive weeks to prevent adverse selection.

### 4.2 Intelligent Fraud Detection 
**Edge-AI Zero-Trust Fusion**: Validates physical hardware states directly on the device before processing any location-based claims to prevent GPS spoofing.

### 4.3 Parametric Automation (The Triggers) 
**Multi-Node Oracle Triggers**:
* **Primary Key**: Weather API (>25mm/hr OR >45°C)
* **Secondary Key**: Social Sentinel NLP (Scrapes local RSS to confirm localized disruption)
* **Action**: Dual-Key Consensus → Instant Razorpay Smart-Contract Payout

### 4.4 Integration Capabilities 
| API Type | Source Provider | Hackathon Cost |
| :--- | :--- | :--- |
| **Weather** | Visual Crossing (Free Tier) | ₹0 |
| **Traffic** | TomTom (Free Tier) | ₹0 |
| **Events** | NewsAPI RSS fallback (PredictHQ trial) | ₹0 |
| **Platform** | Simulated Zomato Webhook (Dispatch 5xx) | ₹0 |
| **Payments** | RazorpayX Sandbox | ₹0 |

---

## 5. System Architecture & Tech Stack 

### 5.1 Zone-Based Pub/Sub (Scales to 10M Riders)
* **The Grid**: India mapped into 50K H3 hexagons (2km radius).
* **The Engine**: Async API polling (Celery/Redis) evaluates triggers per hex, not per user.
* **The Execution**: Hex Trigger → Pub/Sub Broadcast → All active riders inside the hex receive instantaneous payouts.

### 5.2 Tech Stack & Web vs. Mobile Justification
**Web vs. Mobile Justification:** We chose a **Mobile-first architecture (Flutter)** because gig workers operate 100% on the road via smartphones. A cross-platform framework like Flutter allows us to deploy high-performance, sensor-heavy native apps for both Android and iOS from a single Dart codebase. A web-based platform is fundamentally incompatible with a delivery rider's requirement for real-time background location tracking and hardware sensor access.

* **Frontend (Rider App)**: Flutter (Embedded SDK via `tflite_flutter` and `sensors_plus`)
* **Frontend (Corporate)**: Next.js + Tailwind (Admin/ESG Web Dashboard)
* **Backend (High Concurrency)**: FastAPI (Microservices) | Celery + Redis (Async Polling) | PostgreSQL/PostGIS (H3 native queries)
* **AI/ML**: TensorFlow Lite (Edge fraud detection) | scikit-learn XGBoost (Pricing) | Hugging Face Transformers (Social NLP)
* **Infra (Serverless Scale)**: AWS Lambda + EventBridge | Cloud Run | Firebase Hosting

### 5.3 Development Plan & MVP Demo Flow (3 Minutes)
1. **Onboarding (30s)**: Identity verification.
2. **AI Risk Profiling**: System outputs "Risk 7.2/10 → ₹98/week."
3. **Policy Creation**: Rider buys weekly policy via mock UPI.
4. **The Trigger (LIVE)**: Admin toggles "Chennai Monsoon Hex." Flutter Edge AI verifies physics  → Payout is processed .
5. **Analytics**: Dashboard updates showing 92% automation and 38% loss ratio.

---

## 6. Adversarial Defense & Anti-Spoofing (Crisis Solution)

### 6.1 The Differentiation: Physics Can't Lie
GPS coordinates are spoofable; hardware physics are not.
* **Telegram Spoofer**: Exhibits dead flat sensors (0Hz vibration), unnaturally perfect GPS locks, and AC charging states (100% battery + wall outlet).

### 6.2 The Data: Syndicate Fingerprinting
* **Millisecond Claim Clustering**: >50 claims firing within a 3-second window flags a coordinated script.
* **Cellular Tower Triangulation**: Cross-referencing GPS coordinates against actual connected Cell Tower IDs.
* **WiFi BSSID Overlap**: Identifying 50 phones pinging the exact same router MAC address (fraud farms).
* **AC Power Signature**: Flagging devices charging via wall outlets while supposedly "stranded" in a flood.
* **Duplicate Claim Prevention**: Device fingerprinting and strict timestamp validation ensure a rider cannot submit multiple disruption claims for the same localized weather event across different embedded apps (preventing double-dipping).

### 6.3 UX Balance: Trust Score Workflow
* **High Trust Rider + Physics Match**: Auto-Approve (98% of cases).
* **Low Trust + Flat Sensors**: Soft Flag. Rider receives prompt: *"Verify Environment: Complete 1 delivery post-weather for instant unlock."* Honest riders get paid; fraud farms are blocked.

---

**Strict Controls:**
* **Dynamic Payout Cap**: Parametric payout mathematically capped to never exceed 80% of the rider's historical hourly rate to neutralize moral hazard.
* **Strict Coverage Scope**: EarnSure exclusively covers Loss of Income. In strict adherence to platform constraints, coverage for health, life, accidents, and vehicle repairs is explicitly excluded from this architecture.

