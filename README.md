# fittrack_ai

An AI-powered mobile application for calorie, nutrition, hydration, sports events, and community tracking.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Gemini event recommendations

The Events module can request up to three recommendations from Gemini. To enable
it locally:

1. Create a Gemini API key in [Google AI Studio](https://aistudio.google.com/).
2. Copy `env.example.json` to `env.json` and set `GEMINI_API_KEY`.
3. Run the `FitTrack AI` launch configuration in VS Code, or use:

   ```sh
   flutter run --dart-define-from-file=env.json
   ```

`env.json` is ignored by Git. Without a configured key or if the request fails,
Events falls back to recommendations based on the user's interests.

The app sends generic profile preferences and event metadata (including event
titles) to Gemini; it does not send the user's name or ID. Do not put sensitive
information in profile preferences or event titles. Review Google's current data
handling terms for the API plan you use. A key embedded in a mobile app is still
extractable from its binary, so this direct API integration is suitable for
development only. Use a protected server-side proxy before distributing the app
publicly.
