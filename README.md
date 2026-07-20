# GPA Tracker & Grade Calculator

Offline Flutter app for tracking semesters, classes, syllabus grade components,
assignments, GPA, and final grade planning.

## App Setup

- Android package: `com.noorstudy.gpatracker`
- App name: `GPA Tracker & Grade Calculator`
- Storage: local device storage only
- Ads: Android banner ads only

## Release AdMob Values

The current ad structure needs two production values before publishing:

- Android AdMob app ID: `ca-app-pub-4881887086524304~1131831419`
- Android banner ad unit ID: `ca-app-pub-4881887086524304/3963788553`

Set the Android app ID in `android/gradle.properties`:

```properties
ADMOB_APP_ID=ca-app-pub-4881887086524304~1131831419
```

Pass the banner ad unit ID when building:

```bash
flutter build apk --dart-define=ADMOB_ANDROID_BANNER_AD_UNIT_ID=ca-app-pub-4881887086524304/3963788553
```

## Release Signing

For a Play Store upload, keep the upload keystore at
`android/app/upload-keystore.jks` and add `android/key.properties`:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=upload-keystore.jks
```

Release builds require this file and will fail if any signing value is missing.
Do not commit `android/key.properties` or `android/app/upload-keystore.jks`.

## Checks

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk
```

# player-quiz
