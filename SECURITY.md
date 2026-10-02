# Security notes

## Implemented controls

- Firestore is deny-by-default. Verified users can access only their own data.
- Product configuration and sensor telemetry are separate capabilities.
- Each ESP32 receives a unique Firebase Auth identity and can update only the
  weight and timestamp fields for its owner.
- Re-provisioning rotates both the password and a rule-enforced key version, so
  old device tokens lose Firestore access immediately.
- BLE identity reads and writes require Secure Connections with MITM protection,
  exact service/characteristic UUIDs are checked, and re-provisioning requires
  the physical BOOT/pairing button at startup.
- Pairing uses a random 128-bit device identifier stored in NVS; it does not
  expose the ESP32 MAC address and is not remotely guessable.
- User-controlled strings, numbers, categories, and document IDs are bounded in
  both the client and Firestore rules.
- Production Android traffic is HTTPS-only and app-data backup is disabled.
- Authentication and data errors shown to users do not expose backend details.

## Deployment and credential rotation

The previously committed firmware contained the shared credential
`esp32@auth.com`. Removing it from the current source does not revoke the live
account or erase it from Git history.

Roll out this security migration in this order:

1. Deploy `createUserProfile`, `ensureUserProfile`, `provisionDevice`, and
   `cleanupUserDevices` from `functions/` using the Node.js 22 runtime.
2. Release the updated app and have existing users verify their email addresses.
3. Flash the updated firmware and provision each device through the app.
4. Deploy `firestore.rules`.
5. Disable or delete the old `esp32@auth.com` Firebase Authentication account
   and rotate any reused password immediately.
6. If this repository was shared, rewrite the leaked password from Git history
   with an approved history-rewrite process and invalidate existing clones.
7. Restrict every Firebase API key by API and by Android package/SHA, iOS bundle
   ID, or web origin in Google Cloud Console.
8. For production hardware, enable ESP32 Secure Boot v2, flash encryption, and
   encrypted NVS. The Firebase device credential must not remain extractable
   from unencrypted flash.
9. Enable Firebase Authentication email-enumeration protection and a server-side
   password policy; client-side validation alone is not an authorization control.

Never commit service-account keys, `.env` files, firmware secret headers, or
Firebase runtime configuration. Relevant patterns are included in `.gitignore`.

## Verification

From `functions/`:

```bash
npm ci
npm run lint
npm audit
```

Firestore rule tests are in `functions/test/firestore.rules.test.js`. They need
Java and the Firebase Emulator Suite:

```bash
firebase emulators:exec --only firestore "npm run test:rules"
```

Run the Flutter checks where the Flutter SDK is installed:

```bash
flutter analyze
flutter test
```
