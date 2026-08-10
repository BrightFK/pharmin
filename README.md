# PharmIn - Pharmacy Inventory & Medicine Expiry Alert System

![PharmIn Banner](assets/icons/logo.png)

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Hive](https://img.shields.io/badge/Hive-2.2.3-FFD700?style=for-the-badge&logo=hive&logoColor=white)](https://docs.hivedb.dev/)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.6.1-30B6B6?style=for-the-badge&logo=riverpod&logoColor=white)](https://riverpod.dev)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Tech Stack](#-tech-stack)
- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [Key Features Explained](#-key-features-explained)
- [Contributing](#-contributing)
---

## 📱 Overview

**PharmIn** is a comprehensive pharmacy inventory management application built with Flutter. It helps pharmacy owners and staff efficiently manage medicines, track stock levels, monitor expiries, process sales, and generate business insights—all with a beautiful, glass-morphism dark blue interface.

> **🎯 Mission**: Simplify pharmacy inventory management with an intuitive, offline-first, and feature-rich mobile application.

---

## ✨ Features

### 🏪 **Inventory Management**
- ✅ Add, edit, and delete medicines with comprehensive details
- ✅ Batch tracking with expiry dates
- ✅ Supplier management
- ✅ Real-time stock level monitoring
- ✅ Low stock alerts with visual indicators

### 💰 **Sales & POS**
- ✅ Complete POS system with cart
- ✅ FEFO (First Expiry First Out) logic
- ✅ Multiple payment methods (Cash, Card, Mobile Money, Insurance, Credit)
- ✅ Professional receipt generation (PDF & Print)
- ✅ Sales transaction history

### 📊 **Analytics & Reports**
- ✅ Stock value analysis
- ✅ Sales trends and patterns
- ✅ Profit margin calculations
- ✅ Transaction timeline
- ✅ CSV report export with preview

### ⚠️ **Alert System**
- ✅ Low stock notifications
- ✅ Expiry alerts (30/60/90 day filters)
- ✅ Push notifications for critical inventory events
- ✅ Morning summary reports

### 🔄 **Inventory Adjustments**
- ✅ Return stock management
- ✅ Stock adjustments (damaged, expired, etc.)
- ✅ Complete audit trail with batch history
- ✅ Transaction logging

### 🎨 **User Experience**
- ✅ Glass-morphism dark blue theme
- ✅ Intuitive navigation
- ✅ Real-time updates
- ✅ Offline-first architecture
- ✅ Pharmacy profile customization

---

## 📸 Screenshots

> **Note**: All screenshots captured on a Samsung Galaxy device.

### Dashboard & Inventory
| Inventory List | Medicine Detail | Add/Edit Medicine |
|:---:|:---:|:---:|
| ![Inventory List](screenshots/Screenshot_20260810_083540.jpg) | ![Medicine Detail](screenshots/Screenshot_20260810_083732.jpg) | ![Add Medicine](screenshots/Screenshot_20260810_083802.jpg) |

| Batch Management | Batch Detail | Batch History |
|:---:|:---:|:---:|
| ![Batch Management](screenshots/Screenshot_20260810_083830.jpg) | ![Batch Detail](screenshots/Screenshot_20260810_083837.jpg) | ![Batch History](screenshots/Screenshot_20260810_084048.jpg) |

### Sales & POS
| Sales Screen | Cart Checkout | Receipt |
|:---:|:---:|:---:|
| ![Sales](screenshots/Screenshot_20260810_083908.jpg) | ![Cart](screenshots/Screenshot_20260810_084016.jpg) | ![Receipt](screenshots/Screenshot_20260810_084027.jpg) |

### Reports & Management
| Stock Report | Transaction History | Export Reports |
|:---:|:---:|:---:|
| ![Stock Report](screenshots/Screenshot_20260810_084041.jpg) | ![Transaction History](screenshots/Screenshot_20260810_084048.jpg) | ![Export Reports](screenshots/Screenshot_20260810_084048.jpg) |

---

## 🛠️ Tech Stack

### Framework & Language
- **Flutter** 3.24+
- **Dart** 3.5+

### State Management
- **Riverpod** 2.6.1

### Local Storage
- **Hive** 2.2.3 (NoSQL database)
- **Hive Flutter** 1.1.0

### UI/UX
- **Custom Glass-morphism** theme
- **Google Fonts** (Material Icons)
- **Font Awesome** 11.0.0

### Utilities
- **UUID** 4.6.0 (Unique ID generation)
- **Intl** 0.20.3 (Date/Time formatting)
- **Share Plus** 13.3.0 (File sharing)
- **PDF** 3.12.0 (Receipt generation)
- **Printing** 5.14.3 (PDF printing)
- **CSV** 8.0.0 (Report export)

### Notifications
- **Flutter Local Notifications** 22.3.0

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.24.0 or higher
- **Dart SDK** 3.5.0 or higher
- **Android Studio** / **VS Code**
- **Android SDK** (for Android development)
- **Xcode** (for iOS development - macOS only)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/pharmin.git
   cd pharmin
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive adapters**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Generate app icons (optional)**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android:**
```bash
flutter build apk --release
# or for bundle
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

---

## 📁 Project Structure

```
pharmin/
├── lib/
│   ├── models/
│   │   ├── medicine.dart
│   │   ├── batch.dart
│   │   ├── supplier.dart
│   │   ├── transaction.dart
│   │   ├── audit_log.dart
│   │   ├── batch_history.dart
│   │   ├── pharmacy_profile.dart
│   │   └── typeid_registry.dart
│   │
│   ├── screens/
│   │   ├── inventory_list_screen.dart
│   │   ├── medicine_detail_screen.dart
│   │   ├── add_edit_medicine_screen.dart
│   │   ├── add_edit_batch_screen.dart
│   │   ├── batch_detail_screen.dart
│   │   ├── sales_screen.dart
│   │   ├── transaction_history_screen.dart
│   │   ├── batch_history_screen.dart
│   │   ├── expiry_alert_screen.dart
│   │   ├── export_reports_screen.dart
│   │   ├── return_adjustment_screen.dart
│   │   ├── pharmacy_profile_screen.dart
│   │   ├── notification_settings_screen.dart
│   │   └── splash_screen.dart
│   │
│   ├── services/
│   │   ├── hive_service.dart
│   │   ├── notification_service.dart
│   │   ├── pharmacy_service.dart
│   │   └── pdf_receipt_generator.dart
│   │
│   ├── providers/
│   │   └── hive_provider.dart
│   │
│   ├── widgets/
│   │   ├── glass_card.dart
│   │   └── delete_confirmation_dialog.dart
│   │
│   ├── utils/
│   │   └── snackbar_utils.dart
│   │
│   ├── main.dart
│   └── secrets.dart
│
├── assets/
│   └── icons/
│       └── logo.png
│
├── android/
├── ios/
├── test/
│
├── pubspec.yaml
├── README.md
└── LICENSE
```

---

## 🎯 Key Features Explained

### 1. Inventory Management
- **Medicine CRUD**: Full create, read, update, delete operations for medicines
- **Batch Tracking**: Each medicine can have multiple batches with unique expiry dates
- **Supplier Management**: Track preferred suppliers for each medicine
- **Stock Alerts**: Automatic low stock warnings with visual indicators

### 2. Sales System
- **FEFO Logic**: Automatically sells from earliest expiry batches first
- **Cart Management**: Add/remove items, adjust quantities
- **Multiple Payment Methods**: Cash, Card, Mobile Money, Insurance, Credit
- **Professional Receipts**: PDF generation with pharmacy branding
- **Transaction History**: Complete audit trail of all sales

### 3. Analytics & Reporting
- **Stock Reports**: Complete inventory CSV export
- **Sales Analytics**: Track trends, best sellers, and revenue
- **Expiry Reports**: Identify medicines expiring soon
- **Low Stock Reports**: Items below reorder level
- **Business Summary**: Key metrics and performance indicators

### 4. Notifications
- **Expiry Alerts**: Automatic notifications for expiring medicines
- **Low Stock Warnings**: Alerts when stock is below reorder level
- **Daily Summary**: Morning report with key metrics
- **Customizable**: Toggle individual alert types

### 5. Pharmacy Profile
- **Custom Branding**: Your pharmacy name, address, phone
- **Receipt Customization**: Personalized footer messages
- **Professional Look**: Consistent branding across receipts and exports

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Contribution Guidelines
- Follow the existing code style
- Write clear commit messages
- Add comments for complex logic
- Update documentation when needed
- Test your changes thoroughly

---

## 🔮 Roadmap

### Phase 1 ✅ (Completed)
- [x] Core inventory management
- [x] Batch tracking
- [x] Sales system
- [x] Transaction history
- [x] Export reports

### Phase 2 🚧 (In Progress)
- [x] Pharmacy profile customization
- [x] Enhanced notifications
- [ ] Barcode/QR scanning
- [ ] Performance optimizations

### Phase 3 📅 (Planned)
- [ ] AI-powered smart search
- [ ] Cloud sync with Supabase
- [ ] Multi-store support
- [ ] Customer management
- [ ] Advanced analytics dashboard

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 👏 Acknowledgments

- **Flutter Community** for the amazing framework
- **Hive** for fast local storage
- **Riverpod** for clean state management
- **All contributors** who help make PharmIn better

---

## ⭐ Show Your Support

If you find PharmIn useful, please give it a star ⭐ on GitHub! Your support helps keep the project active and growing.

---

**Built with ❤️ for the pharmacy community**

---
