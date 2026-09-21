# DeenMate

DeenMate is a Flutter-based Islamic companion app built as a Software Development Project (SDP2). It brings together a range of everyday Islamic tools into a single mobile and web experience.

## Features

- **Prayer Times** — Accurate daily salat times with location support and notification reminders
- **Qibla Compass** — Real-time direction to the Kaaba
- **Quran Reader** — Full Quran with translation and reading tracker
- **Dhikr & Tasbih** — Digital counter for daily remembrance
- **Islamic Calendar** — Hijri dates and upcoming Islamic events
- **Zakat Calculator** — Calculate obligatory charity on savings, gold, silver, and trade goods
- **Qurbani & Aqiqah Planner** — Group-based animal sacrifice planner with shared expense tracking, participant management, and settlement calculations
- **Halal Scanner** — Scan product barcodes or images to check ingredient halal status using AI
- **Islamic AI Assistant** — Multi-model AI chat (Gemini, Groq, OpenRouter, Cerebras) for Islamic Q&A
- **Daily Guidance** — AI-generated morning Islamic reminder
- **Emergency SOS** — Group location sharing and SOS alerts for trusted contacts
- **Hajj & Umrah Guide** — Step-by-step ritual walkthroughs
- **Inheritance Calculator** — Faraid distribution according to Islamic law

## Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions)
- **AI:** Firebase AI Logic (Gemini), Groq, OpenRouter, Cerebras
- **Platforms:** Android, iOS, Web

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project connected via `firebase_options.dart`

### Setup

1. Clone the repo and install dependencies:
   ```bash
   flutter pub get
   ```

2. Create a `.env` file in the project root with your API keys:
   ```
   GEMINI_API_KEY=your_key_here
   GROQ_API_KEY=your_key_here
   OPENROUTER_API_KEY=your_key_here
   CEREBRAS_API_KEY=your_key_here
   ```
   > The `.env` file is gitignored. Never commit API keys to source control.

3. Deploy Firestore security rules:
   ```bash
   firebase login
   firebase use deenmate-be588
   firebase deploy --only firestore:rules
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### Building for Release

Use `--dart-define` to pass API keys at build time instead of bundling `.env`:

```bash
flutter build apk --release \
  --dart-define=GEMINI_API_KEY=your_key \
  --dart-define=GROQ_API_KEY=your_key \
  --dart-define=OPENROUTER_API_KEY=your_key \
  --dart-define=CEREBRAS_API_KEY=your_key
```

## Project Structure

```
lib/
  screens/       # All UI screens
  services/      # Business logic and API integrations
  widgets/       # Reusable UI components
  l10n/          # Localization files
assets/
  images/        # App images and icons
  videos/        # Tutorial videos
functions/       # Firebase Cloud Functions
firestore.rules  # Firestore security rules
```

## Team

Developed by the DeenMate team as part of SDP2 at United International University.
