# keys/

Local, git-ignored secrets. Everything here except this README is ignored by git.
Never commit these files.

- `service-account.json`: Firebase service account JSON, used only for the Supabase
  `FIREBASE_SERVICE_ACCOUNT` secret (`supabase secrets set`).
- `webhook-secret.txt`: the Database Webhook secret (`WEBHOOK_SECRET`).

The build never reads anything in this folder. Firebase app configs are not kept
here: `google-services.json` goes in `android/app/` and `GoogleService-Info.plist`
goes in `ios/Runner/` (added through Xcode). Both locations are git-ignored; share
the files privately with teammates.
