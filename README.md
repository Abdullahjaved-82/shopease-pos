# ShopEase POS

A modern, feature-rich Point of Sale (POS) system built with Flutter for desktop and mobile platforms. ShopEase combines a sleek Material Design UI with robust business logic to streamline retail operations, inventory management, and financial tracking.

## Overview

ShopEase is a complete POS solution designed for small to medium-sized retail shops. It provides real-time sales processing, comprehensive inventory management, multi-document support (invoices, quotations, proformas), customer relationship management, and detailed reporting—all with offline-first functionality and multi-device synchronization capabilities.

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
