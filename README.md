# ShopEase POS

A modern, feature-rich Point of Sale (POS) system built with Flutter for desktop and mobile platforms. ShopEase combines a sleek Material Design UI with robust business logic to streamline retail operations, inventory management, and financial tracking.

## Overview

ShopEase is a complete POS solution designed for small to medium-sized retail shops. It provides real-time sales processing, comprehensive inventory management, multi-document support (invoices, quotations, proformas), customer relationship management, and detailed reporting — all with offline-first functionality and multi-device synchronization capabilities.

**Current Status:** Frontend complete | Backend API integration pending

---

## Stack & Architecture

### Technology Stack
- **Language:** Dart 3.11+
- **Framework:** Flutter (Desktop & Mobile)
- **State Management:** Riverpod 2.5+ with code generation
- **Database:** SQLite via Drift ORM
- **Routing:** GoRouter 14.1+
- **PDF Generation:** PDF 3.11 + PDFx 2.7
- **Notifications:** flutter_local_notifications 17.2
- **Auth:** Google Sign-In integration ready
- **Data Export:** Excel, CSV support

### Key Dependencies
- `flutter_riverpod` — Reactive state management with dependency injection
- `drift` — Type-safe SQLite ORM with async support
- `go_router` — Declarative routing with deep linking
- `pdf` / `printing` — Document generation and printing
- `fl_chart` — Responsive business analytics charts
- `google_sign_in` / `googleapis` — Cloud backup and sync via Google Drive

### Architecture Overview

```
lib/
├── app/                    Application shell & theme config
├── core/
│   ├── router/              GoRouter configuration & navigation logic
│   ├── theme/                Light/dark theme definitions
│   └── providers/            Global dependency injection & repositories
├── features/
│   ├── auth/                 Login, role-based access control (Admin/Cashier)
│   ├── dashboard/             KPI overview, business metrics, analytics
│   ├── sales/                 Point-of-sale transactions, receipt generation
│   ├── products/              Inventory, SKU management, stock tracking
│   ├── invoices/               Invoice/quotation/proforma generation & management
│   ├── customers/              CRM, customer profiles, balance tracking
│   ├── reports/                Sales summaries, shift reports, financial statements
│   └── settings/                Shop configuration, backup, import/export, sync
├── shared/                  Reusable widgets, splash overlay, common utilities
└── l10n/                    Localization (English, Urdu)
```

**Data Flow:**
1. UI Layer (Screens) → State Management (Riverpod Providers)
2. Application Layer (Services: notifications, recurring invoices, sync)
3. Domain Layer (Business models, use cases)
4. Data Layer (Drift database + repositories, Google Drive sync)

---

## Core Features

### Sales & Invoicing
- **Point-of-Sale Interface** — Fast checkout with product search, quantity entry, and instant receipt printing
- **Multi-Document Support** — Invoices, Quotations, Proformas with customizable templates
- **Receipt Customization** — Bilingual templates (English + Urdu), custom footer text, QR codes
- **Recurring Invoices** — Automated recurring billing with date-based scheduling
- **Overdue Alerts** — Daily notifications for unpaid invoices at 9am

### Inventory & Products
- **Product Management** — SKU, pricing, stock levels, category organization
- **Category System** — Hierarchical product categorization
- **Stock Tracking** — Real-time inventory adjustments, low-stock alerts
- **Bulk Import** — Excel/CSV product import with data validation

### Customer Management
- **Customer Profiles** — Contact info, loyalty points, outstanding balance
- **Loyalty Program** — Point accumulation, redemption with customizable rates
- **Balance Reminders** — SMS/notification templates for customer communication
- **Payment History** — Full transaction audit trail

### Reporting & Analytics
- **Dashboard Metrics** — Daily sales, revenue trends, top products, customer insights
- **Shift Summaries** — Cash reconciliation, shift-wise sales breakdown
- **Financial Reports** — Tax calculations, payment method breakdowns
- **Chart Visualization** — fl_chart integration for trend analysis

### Settings & Administration
- **Shop Configuration** — Name, location, tax rates, currency, branding (logo support)
- **Auto Backup** — Scheduled daily/weekly backups to local storage
- **Google Drive Sync** — Cloud backup via Google Drive API
- **Multi-Device Sync** — Master-slave replication for multi-location shops
- **FBR Integration** — Pakistan FBR tax compliance ready (placeholder for backend)
- **Theme Customization** — Accent color configuration, light/dark mode

### Localization
- **Bilingual Support** — English and Urdu
- **Region-Aware Formatting** — Currency, date, and number formatting per locale
- **RTL Ready** — Urdu right-to-left text rendering with Noto Nastaliq font

---

## Getting Started

### Prerequisites
- Flutter SDK 3.11+ ([Install Flutter](https://flutter.dev/docs/get-started/install))
- Dart 3.11+
- Android Studio / Xcode (for mobile builds)
- Visual Studio 2019+ or Clang (for Windows builds)

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Abdullahjaved-82/shopease-pos.git
   cd shopease-pos
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Generate localization strings:**
   ```bash
   flutter gen-l10n
   ```

4. **Run the app:**
   ```bash
   # Desktop (Windows/macOS/Linux)
   flutter run -d windows
   flutter run -d macos
   flutter run -d linux

   # Mobile (Android/iOS)
   flutter run -d android
   flutter run -d ios
   ```

### Build for Release

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Android
flutter build apk --release
flutter build aab --release

# iOS
flutter build ios --release
```

---

## Database Schema

ShopEase uses Drift ORM for type-safe SQLite operations. The database includes:

- **Products** — SKU, name, category, price, stock, tax rate
- **Invoices** — Header (customer, date, total) + line items
- **Transactions/Sales** — POS sales records with payment methods
- **Customers** — Profile, balance, loyalty points, expiry tracking
- **Shift Records** — Cash register sessions, opening/closing balances
- **Sync Metadata** — Device ID, master host, last sync timestamp

---

## Authentication & Authorization

**Role-Based Access Control:**
- **Admin** — Full system access (dashboard, settings, reports, all management)
- **Cashier** — Limited to sales, customer lookup, invoice viewing

**Auth Flow:**
1. Login page with credential validation
2. OAuth 2.0 ready (Google Sign-In infrastructure in place)
3. Persistent session via SharedPreferences

---

## Localization & Multi-Language Support

ShopEase ships with bilingual support:
- **English** — Default interface language
- **Urdu** — Complete Urdu translation with custom font (Noto Nastaliq)

Localization files are auto-generated. To add new strings:
1. Edit `lib/l10n/app_en.arb` and `lib/l10n/app_ur.arb`
2. Run `flutter gen-l10n`

---

## Project Structure & Key Files

| File/Directory | Purpose |
|---|---|
| `pubspec.yaml` | Dependencies & project metadata |
| `lib/main.dart` | App entry point & Riverpod initialization |
| `lib/app/app.dart` | Material app config, theme switching, localization |
| `lib/core/router/app_router.dart` | GoRouter configuration & navigation rules |
| `lib/core/theme/app_theme.dart` | Light/dark theme definitions |
| `lib/features/*/` | Feature-specific code (auth, sales, invoices, etc.) |
| `assets/fonts/` | Custom fonts (Urdu font placeholder) |
| `assets/audio/` | Notification & UI sound assets |

---

## State Management & Providers

ShopEase uses Riverpod for reactive state management:

```dart
// Shop settings (auto-loaded on startup)
final shopSettingsControllerProvider = ...

// Invoice notifications (runs periodically)
final invoiceOverdueNotificationServiceProvider = ...

// Multi-device sync service
final automationServiceProvider = ...
```

Key providers are initialized in `lib/app/app.dart` on app startup.

---

## API Integration (Pending)

The frontend is production-ready but awaits backend API integration.

**Endpoints Required:**
- Authentication (login, token refresh, logout)
- Product CRUD + image uploads
- Customer management
- Invoice/quotation management
- Sales transaction recording
- Reports & analytics
- FBR tax submission (Pakistan compliance)
- Google Drive backup/sync

**Current State:** All UI screens & local database workflows are complete. Backend API calls will replace local-only operations.

---

## Performance & Optimization

- **Offline-First** — All operations work without internet; sync when available
- **Lazy Loading** — GoRouter with nested navigation minimizes memory overhead
- **SQLite Efficiency** — Drift generates optimized queries
- **Shimmer Effects** — Smooth loading placeholders in lists
- **Responsive UI** — Adaptive layouts for desktop and mobile

---

## Testing (Recommended)

Add to `dev_dependencies` and implement:
- Unit tests for business logic (`test/`)
- Widget tests for UI components
- Integration tests for critical flows

---

## Deployment

**Desktop (Windows/macOS/Linux)**
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

**Mobile (Android/iOS)**
```bash
flutter build apk --release  # Google Play
flutter build aab --release  # App Bundle
flutter build ios --release  # TestFlight/App Store
```

**Web (Future)**
```bash
flutter build web --release
```

---

## Future Enhancements

- [ ] Backend API integration
- [ ] FBR tax submission automation
- [ ] Multi-location dashboard
- [ ] Advanced inventory forecasting
- [ ] Mobile app with offline sync
- [ ] SMS/WhatsApp notifications
- [ ] Expense tracking & P&L reports
- [ ] Employee management & commissions

---

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is proprietary. All rights reserved.

---

## Support & Contact

- **Author:** [Abdullahjaved-82](https://github.com/Abdullahjaved-82)
- **Repository:** ShopEase POS on GitHub
- **Issues:** Report bugs via GitHub Issues

---

## Acknowledgments

- Flutter & Dart community
- Riverpod for state management
- Drift for database ORM
- GoRouter for declarative routing
- FBR Pakistan for tax compliance guidance

---

## Project Status

- **Version:** 1.0.0
- **Last Updated:** April 2026
- **Frontend Status:** ✅ Complete
- **Backend Status:** ⏳ In Progress
- **Production Ready:** Pending API integration

---

*ShopEase POS — Empowering retail with modern technology.*
