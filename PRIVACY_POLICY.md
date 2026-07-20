# Privacy Policy for CalSync

**Last Updated:** July 20, 2026

Henrique Couto ("I", "me", or "my") built the CalSync app as an open-source application. This service is provided at no cost for the base version, with a premium tier available on Google Play.

This page informs you of my policies regarding the collection, use, and disclosure of personal information when you use my app. **I do not collect, store, or transmit any personal data from your device.**

## Information Collection and Use

- **Calendar Data:** CalSync accesses your calendar events solely to perform the synchronization you configure (copying events from one calendar to another). All reading and writing of calendar data happens **entirely on your device** using Android's built-in calendar provider (`ContentResolver`). The app does not send any calendar data to external servers, nor does it use OAuth or any other authentication method — it simply reads and writes to the calendars already available on your device.

- **Local Storage:** The app may store small amounts of data locally (e.g., sync preferences, filters, and cached calendar lists) using `SharedPreferences` and `SQLite`. This data never leaves your device and is only used to improve your experience and provide offline functionality.

- **Google Play Billing (Google Play version only):** The Google Play version of the app includes a premium subscription option. All payment processing is handled entirely by Google Play Billing. I do not have access to your payment information. The purchase status (active/inactive) is verified locally on your device and through Google Play services. No purchase data is transmitted to me or stored on my servers.

## Third-Party Services

The app does not integrate with any third-party analytics, crash reporting, advertising, or tracking services. It does not use Firebase, Google Analytics, or any similar SDK.

The Google Play version uses the official Google Play Billing library solely for processing subscriptions. This is a required integration for in-app purchases and is subject to Google's privacy policy.

## Permissions

The app requires the following permissions:
- **Calendar:** To read and write calendar events so that the sync functionality works.
- **Foreground Service / Alarm:** To schedule periodic syncs in the background (Android only).

**Note:** The app does **not** require the `INTERNET` permission because all data processing is done locally. It does not authenticate with any service — all calendar access is through the Android system's calendar provider.

## Data Retention

Since all data stays on your device, you can delete it at any time by:
1. Uninstalling the application, or
2. Clearing the app's data in your device's system settings.

## Children's Privacy

This app does not address anyone under the age of 13. I do not knowingly collect personally identifiable information from children.

## Changes to This Privacy Policy

I may update this Privacy Policy from time to time. You are advised to review this page periodically for any changes.

## Contact Me

If you have any questions or suggestions about this Privacy Policy, you can contact me via:
- **GitHub Issues:** [https://github.com/henriquecouto/calendar-sync/issues](https://github.com/henriquecouto/calendar-sync/issues)