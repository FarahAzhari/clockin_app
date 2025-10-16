# ⏱️ Clock-In App: Attendance Tracking System

ClockIn is an attendance application that allows users to check in or check out efficiently. It includes features such as location-based check-ins within a specified radius, attendance reports, and leave request submissions. The project consists of a Flutter mobile app and an API backend.

---

## ✨ Project Overview

This project serves as a Final Project for the **Mobile Programming (Flutter)** course, demonstrating proficiency in:

- Application architecture
- State management
- Integrating with a backend API
- Geolocation-based features (restricting check-ins based on location)
- Implementation of full **C.R.U.D.** (Create, Read, Update, Delete) feature set

The core functionality is a **Attendance Tracking System**, allowing authorized users to log their presence and view historical attendance reports.

---

## 🔑 Application Features and Page Structure

| No. | Page / Feature           | Assignment Category | Description                                                                 |
|-----|--------------------------|---------------------|-----------------------------------------------------------------------------|
| 1   | **Login Screen**         | Authentication      | The entry point for existing users to sign into the application.            |
| 2   | **Register Screen**      | Authentication      | The interface for new users to create an account.                           |
| 3   | **Attendance List**      | CRUD - Read         | Main dashboard showing a list of all historical attendance records.         |
| 4   | **Add Attendance**       | CRUD - Create       | A form to submit a new attendance/clock-in record (date and time included). |
| 5   | **Individual Report**    | Info / Report       | Displays a detailed attendance report/history for a specific user.          |
| 6   | **Profile / Role Screen**| Info / Profile      | Shows current user's information and role (e.g., Admin/Employee).           |
| 7   | **Edit/Update Record**   | CRUD - Update       | Flow to modify an existing attendance record.                               |
| 8   | **Delete Record**        | CRUD - Delete       | Delete attendance entries from the attendance list.                         |

---

## 🛠️ Technology Stack and Dependencies

This project is developed using **Flutter** and **Dart**, with a data-centric architecture. Below are key dependencies and their purposes:

| Category            | Dependency (Assumed)      | Purpose                                                        |
|---------------------|---------------------------|----------------------------------------------------------------|
| Framework           | Flutter, Dart             | Primary development environment                                |
| State Management    | Provider                  | Manage app-wide state and auth logic                           |
| Geolocation         | geolocator                | Restrict check-ins to users within a specific location         |
| Caching / Prefs     | shared_preferences        | Store session/login status and simple user preferences         |
| API / HTTP          | http                      | Manage server-based auth or data sync if implemented           |

---

### 🖥️ Project Screenshots
https://github.com/user-attachments/assets/e8ebe1ed-48b9-4f4d-bc9d-95c7b5fe83ba

---

## 🚀 Installation and Setup

To run this project locally, follow these steps:

### 1. Clone the Repository

```bash
git clone https://github.com/FarahAzhari/clockin_app
cd clockin_app
```

### 2. Get Dependencies

Make sure you have Flutter SDK installed, then run:

```bash
flutter pub get
```

### 3. Run the Application

Connect a device or start an emulator, then run:

```bash
flutter run
```

© 2025 Farah Azhari




