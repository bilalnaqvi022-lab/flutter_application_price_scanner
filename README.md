
# 🔍 PriceLens — Local Market Price Comparison App
> **Scan once. Compare everywhere. Never overpay again.**
> A Flutter mobile app that scans barcodes/QR codes and instantly compares prices across local shops and online marketplaces in Pakistan.

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=flat-square&logo=dart)](https://dart.dev/)
[![SQLite](https://img.shields.io/badge/SQLite-Local%20DB-003B57?style=flat-square&logo=sqlite)](https://www.sqlite.org/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

**Screenshots**
<p align="center">
  <img src="https://github.com/user-attachments/assets/036fb155-bffe-4722-b89b-1449567a5375" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/348cd9a8-95eb-45ab-a649-711dd0b46b26" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/698d53e1-249b-42a8-aa47-c163b6e188ee" width="220" hspace="10"/>
</p>

<br/>

<p align="center">
  <img src="https://github.com/user-attachments/assets/492d460a-b983-4f6d-b0e9-4b0305d395ca" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/9463b2f9-f5b8-4f30-91dd-a74ff97694b5" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/39b587b7-d097-4caa-b893-b5e1f380d2df" width="220" hspace="10"/>
</p>




---

## 📖 Overview

PriceLens lets consumers scan any product barcode or QR code and instantly see price comparisons across local shops and online stores like Daraz and Carrefour. It highlights the cheapest option, tracks scan history, and sends push alerts when prices drop — all designed to help everyday users in Pakistan make smarter purchasing decisions.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📷 **Barcode / QR Scanning** | Scan product codes via device camera for instant lookup |
| 💰 **Live Price Comparison** | Fetch real-time prices from local shop databases and online marketplaces |
| 🏆 **Cheapest Option Alert** | Highlights the best deal and tells you exactly where to buy |
| 🕓 **Scan History** | Saves previously scanned products locally for quick re-reference |
| 🔔 **Price Drop Notifications** | Optional push alerts when a tracked product's price falls |
| 🌐 **Store Links** | Tap to open product pages on Daraz, Carrefour, and more |
| 📊 **Savings Analytics** | Tracks money saved, scans today, and live stores monitored |
| 📤 **Share Comparisons** | Share price results with friends or family via any platform |
| 📴 **Offline Mode** | Graceful handling when no internet connection is detected |
| 🌓 **Polished UI** | Poppins typography, shimmer skeletons, Lottie animations, and smooth transitions |

---

## 📱 Screens

### 🏠 Home
- Hero banner with app branding
- Stat cards — scans today, money saved, live stores tracked
- Quick action grid for fast navigation
- Recent scans list
- Top savings tips section

### 📷 Scanner
- Animated scan viewport with moving laser line
- Corner bracket overlay and grid background
- Loading state with "Fetching prices…" indicator
- Manual barcode entry dialog for typed input

### 📊 Results
- Product header with name and image
- **Best Price** champion banner with savings callout
- Animated price range bar (lowest → highest)
- Ranked store list with online / local badges and ratings
- **Share** and **Set Alert** action buttons

### 🔔 Notifications
- Toggle switches for Price Drops, Weekly Report, and Flash Deals
- Styled notification feed with unread indicators

---

## 🏗️ Project Structure

```
lib/
├── config/
│   └── api_config.dart               # Base URLs, API keys, environment vars
│
├── models/
│   ├── product_model.dart            # Product and barcode data
│   ├── price_result_model.dart       # Store + price comparison result
│   ├── scan_history_model.dart       # Local scan history entry
│   └── notification_model.dart       # Price alert and feed entries
│
├── providers/
│   ├── scanner_provider.dart         # Scan state and barcode handling
│   ├── price_provider.dart           # Price fetch and comparison logic
│   ├── history_provider.dart         # Local scan history management
│   └── notification_provider.dart    # Alert toggle and notification state
│
├── screens/
│   ├── main_screen.dart              # Bottom navigation shell
│   ├── home/
│   │   └── home_screen.dart
│   ├── scanner/
│   │   └── scanner_screen.dart
│   ├── results/
│   │   └── results_screen.dart
│   └── notifications/
│       └── notifications_screen.dart
│
├── services/
│   ├── price_service.dart            # API calls to fetch live store prices
│   ├── database_service.dart         # sqflite operations for scan history
│   └── notification_service.dart     # flutter_local_notifications setup
│
├── widgets/
│   ├── stat_card.dart
│   ├── price_bar.dart                # Animated price range bar
│   ├── store_tile.dart               # Ranked store list item
│   ├── scan_overlay.dart             # Laser line + corner bracket viewport
│   └── shimmer_loader.dart           # Skeleton placeholder while fetching
│
├── theme/
│   └── app_theme.dart                # Colors, typography, Poppins font setup
│
└── main.dart
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>= 3.0.0`
- Dart SDK `>= 3.0.0`
- A physical device or emulator with camera access

### Install & Run

```bash
# 1. Clone the repository
git clone https://github.com/your-username/pricelens.git
cd pricelens

# 2. Install dependencies
flutter pub get

# 3. Run on connected device or emulator
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

---

## 📦 Dependencies

### Core Functionality

| Package | Purpose |
|---------|---------|
| `mobile_scanner` | Barcode and QR code scanning via device camera |
| `http` | REST API calls to fetch live prices from stores |
| `shared_preferences` | Persist lightweight settings and preferences |
| `sqflite` | Local SQLite database for scan history |

### UI & Experience

| Package | Purpose |
|---------|---------|
| `google_fonts` | Poppins font family for polished typography |
| `flutter_animate` | Smooth screen transitions and micro-animations |
| `lottie` | JSON-based animations for loading and success states |
| `shimmer` | Skeleton loading placeholders while prices are fetching |

### App Features

| Package | Purpose |
|---------|---------|
| `provider` | State management across all screens |
| `flutter_local_notifications` | Price drop push alerts |
| `share_plus` | Share product comparisons to any platform |
| `url_launcher` | Open store links (Daraz, Carrefour, etc.) |
| `connectivity_plus` | Detect and handle offline mode gracefully |
| `cached_network_image` | Cache store logos and product images |
| `intl` | Format PKR currency and dates correctly |

---

## ⚙️ Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| ⚡ Performance | Price results appear within **2–5 seconds** |
| ✅ Accuracy | Prices verified via live APIs and shop inputs |
| 👥 Usability | Intuitive interface suitable for all age groups |
| 📈 Scalability | Supports multiple concurrent users and large product databases |
| 🔒 Security | User data encrypted; no personal data shared without consent |
| 🛡️ Reliability | Consistent operation with no unexpected crashes |
| 🔧 Maintainability | APIs and databases updatable as markets change |

---

## 💱 Currency & Localisation

All prices are displayed in **PKR (Pakistani Rupees)** formatted via the `intl` package.
Store integrations include local Pakistani retailers and online marketplaces such as **Daraz** and **Carrefour**.

---

## 🔔 Notification Types

| Alert | Description |
|-------|-------------|
| 📉 Price Drop | Triggered when a tracked product's price falls |
| 📋 Weekly Report | Summary of savings and top deals from the past week |
| ⚡ Flash Deals | Time-limited offers from connected stores |

---

## 🛠️ Troubleshooting

| Issue | Fix |
|-------|-----|
| Camera not working | Grant camera permission in device settings |
| Prices not loading | Check internet connection; verify API keys in `api_config.dart` |
| Scan history missing | Ensure `sqflite` database initialised on first run |
| Notifications not showing | Enable notification permissions in device settings |
| Offline with no feedback | `connectivity_plus` should show an offline banner — check provider setup |
| PKR not formatting | Confirm `intl` locale is initialised in `main.dart` |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

