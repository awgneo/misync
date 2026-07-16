---
description: Further develop the MiSync App
---

MiSync is an android app to sync Android OS with only Xiaomi HyperOS watches, like the MiBand 10 Pro. It prioritizes minimal UI and quiet syncing features to Android, attemping to be an app you open rarely and use other apps, like Google Fit and others to actually see the data synced. The app is the sync all and a library of QuickApps that work along with it and are deployed to the watch.

Please review all of the following:

1. The development guide in DEVELOPMENT.md
2. The QuickApp guide in .docs/xiaomi_vela_quickapp
  - All subdirectories and files in guides
  - All subdirectories and files in components
  - All subdirectories and files in features
3. The flutter source code in lib/** (100% of all subdirectories and files)
4. A sampling of the native kotlin source code in android/app/src/main/kotlin/**
  - MainActivity.kt
  - base/**
  - A sampling of modules (notifications, media, health)
5. The messages QuickApp in apps/messages (100% of all subdirectories and files)
6. The shared QuickApp library in apps/shared