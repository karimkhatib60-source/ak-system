# AK System

Company management app for AK Design and Construction. Runs on Android phones
and Windows laptops, works fully offline, and syncs between devices through a
free cloud database when online.

**Phase 1** covers clients, projects with stages, team tasks with deadlines,
and deliverables with revisions (R00, R01…) and a client submission log.
Later phases add project money, company accounts, agenda, sales, social media
planning and the growth dashboard.

## How it works

- Each device keeps everything in a local SQLite database, so the app opens
  and works with no internet.
- When online, changes sync to a Supabase database (free tier). If two people
  edit the same item while offline, the most recent edit wins.
- Logins: the first person to create a login is the **owner** and sees
  everything. Later logins join as **architects** and see only the projects
  the owner adds them to.

## One-time cloud setup (about 10 minutes, free)

1. Create a free account at supabase.com and a new project (any region near
   Lebanon, e.g. Frankfurt).
2. In the project, open **SQL Editor**, paste the contents of
   [`supabase/schema.sql`](supabase/schema.sql) and press **Run**.
3. Optional: under **Authentication > Sign In / Providers > Email**, turn off
   "Confirm email" so new logins work immediately.
4. Open **Project Settings > API** and copy the **Project URL** and the
   **publishable (anon) key**.
5. In the app: **Settings > Cloud sync and login > Connect**, paste both, then
   **Create a login**. Do this first on the owner's device.
6. The architect installs the app, connects with the same URL and key, and
   creates their own login. The owner then adds them to projects.

Until step 5, the app works on its own and keeps everything on the device;
the data uploads automatically once you connect.

## Installing

Every push to `main` builds both apps (GitHub > Actions > latest run >
Artifacts). Tagging a commit `v1.0.0` publishes them under Releases.

- **Windows:** download `AK-System-windows.zip`, unzip it to a folder such as
  `C:\AK System`, and run `ak_system.exe`.
- **Android:** download `AK-System-android.apk` on the phone and open it. Allow
  "install unknown apps" for your browser or file manager when asked.

### Android signing key

Updates only install over an earlier version when both are signed with the
same key. Store the key in the repository's **Settings > Secrets and
variables > Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of the `.jks` file |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `ak` |

Keep a copy of the key somewhere safe; losing it means reinstalling the app.

## Development

```
flutter pub get
flutter analyze
flutter test
flutter run -d windows      # or an Android device
```

Code map:

| Path | What |
| --- | --- |
| `lib/data/models.dart` | Records: clients, projects, tasks, deliverables, stages, members |
| `lib/data/db.dart` | Local SQLite tables |
| `lib/data/repository.dart` | All reads and writes the screens use, plus who can see what |
| `lib/sync/` | Offline sync with Supabase and login |
| `lib/ui/` | Screens and widgets |
| `supabase/schema.sql` | Cloud tables and access rules |
| `test/` | Automated checks (data, sync, screens) |
| `test_screens/` | Renders preview screenshots: `flutter test test_screens --update-goldens` |

To add a field: add it to the record in `models.dart`, the column in `db.dart`
and `schema.sql`, then the form. Existing devices need a migration: raise
`_version` in `db.dart` and add the `ALTER TABLE` in an `onUpgrade` handler.
New tables also go in `syncedTables`.
