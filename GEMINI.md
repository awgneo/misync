# App Summary

I just a Xiaomi MiBand 10 Pro NFC Chinese Edition, in America. I have tried the Mi Fitness app, and the Notify for Xiaomi app. They are both missing features. I am thinking of developing my own Android app called MiSync that is pretty hands off. The Chinese edition allows for NFC access and custom cards, but only when I have the Chinese version of the Mi Fitness app set to the Chinese region. This is all currently working perfectly, and hooks up to the Notify app, which doesn't support cards at all. So we need to maintain NFC access while developing this app. Notify works perfectly as well, but it has many limitations and is super buggy. Let m know if you need the APKs for either of these apps.

# App Requirements

- Sync all health data, workout and sleep data to Google Health connect
- Sync notifications with filtering from Android to the watch (just app selection for now)
- Sync DND status from Android to the watch and vice versa
- Sync alarms from Android to the watch and vice versa
- Allow my phone to find the watch and vice versa
- Generate NFC cards and manage them (for a Ultraloq NFC bolt door lock) (CANCELLED)
- Ability to install custom watch faces (Notify for Xiaomi supports this)
- Setup quick replies for message notifications (Mi Fitness supports this)
- Installs a MiSync app automatically that is a set up customizable actionsbuttons for launching things on the phone (Automate, Tasker, etc)
- Using the latests and greatest 2026 android development UI frameworks (flutter is fine/preferred)

# Features

## Sections
- Notifications
  - Apps
  - Quick Replies
  - Alarms
  - Do not Disturb
- Faces
- Health
  - Workouts
  - Metrics
  - Sleep
- Cards
- Actions

## Other
- A quick tile should be created to ring the watch
- The watch should automatically wire up ring phone to app
- Music controls, camera controls, all the normal MiBand apps should just work
- The app should run in the background and keep the BT connection alive

## Pairing
- We will use the Notify method of extracting the pairing code from the Mi Fitness device logs during startup

# Other Information
- Are the MiBand APIs publically available for interacting with HyperOS and all features?
- Notify installs a HyperOS app to intercept notifications, bypassing the built-in notification system
  - I am trying to avoid this method and just allow for the setting of the quick replies, which Mi Fitness supports
- I do want to inject our own HyperOS app as well, but just for the actions (app)
  - Is there any easy way to launch this actions app?
  - Notify allows you to press and hold the watch face and tap it again to somehow launch their injected app
  - Surely there is a better way? Swiping right on the watch face to bring up widgets could work, if we could somehow inject a widget? Some other action we could hook into?

# Resources
- [Notify Vela JS Developers Guide](https://mibandnotify.com/xiaomi-mi-band/notify-xms-app-instructions.php)
- [Xiaomi Vela JS Developers Guide](https://iot.mi.com/vela/quickapp/en/guide/)