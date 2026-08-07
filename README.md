# VunaFlow

Agricultural loan management platform for AFC (Agricultural Finance Corporation) farmers and staff.

**Stack:** Flutter (client app) · Node.js / Express (API) · PostgreSQL (database)

---

## 1. Project structure

```
vunaflow/
├── backend/                 Node.js + Express + PostgreSQL API
│   ├── config/db.js         PostgreSQL connection pool
│   ├── db/schema.sql        Full schema + seed data (43 real AFC branches, bilingual FAQs, farming advice)
│   ├── db/migrate.js        Runs schema.sql against your database
│   ├── db/seed-admin.js     Creates/updates the first admin login
│   ├── middleware/          JWT auth, role guards, file upload (multer)
│   ├── utils/phone.js       Kenyan phone number validation/normalization
│   ├── routes/              auth, branches, profile, loans, documents,
│   │                        notifications, admin, reports, simulated (chatbot/advice)
│   └── server.js            App entry point
│
└── frontend/vunaflow_app/   Flutter app
    ├── lib/screens/landing_screen.dart      Public marketing landing page
    ├── lib/screens/auth/                    Client login, staff login, register, forgot password
    ├── lib/screens/client/                  Client dashboard, loans, documents, profile, assistant
    ├── lib/screens/staff/                   Staff dashboard, applications, reports, admin
    ├── lib/services/api_service.dart        HTTP client (JWT-aware)
    ├── lib/providers/auth_provider.dart     Session state
    └── lib/theme/app_theme.dart             Brand colors & typography
```

---

## 2. Backend setup (VS Code, Windows)

### Requirements
- Node.js 18+ (`node -v` in a terminal to check)
- PostgreSQL 14+ installed (the Windows installer from postgresql.org also installs **pgAdmin 4**,
  a GUI for browsing your database — useful in step 5 below)

### 2.1 Open the right folder

In VS Code: **File → Open Folder…** and select the top-level `vunaflow` folder (the one containing
both `backend` and `frontend`). This gives you both projects in one workspace with a file explorer
on the left, which is the easiest way to work with a full-stack repo like this.

### 2.2 Run backend commands from `backend/`, not the repo root

This is what caused your error — `package.json` lives inside `backend/`, so npm has to be run from
there. Open a terminal in VS Code (**Terminal → New Terminal**) and run:

```powershell
cd backend
npm install
copy .env.example .env
```

Then open the new `.env` file in VS Code and edit these lines to match your PostgreSQL setup
(the values you chose when installing PostgreSQL). Note the database name — `vunaflow_db` — is
deliberately distinct from any database you may already have called `vunaflow`, so the two never
collide:

```
PGUSER=postgres
PGPASSWORD=your_postgres_password
PGDATABASE=vunaflow_db
JWT_SECRET=any_long_random_string_you_like
```

### 2.3 Create the database

You need to create the `vunaflow_db` database itself before running migrations. Easiest way on
Windows — open **pgAdmin 4** (installed alongside PostgreSQL), connect to your local server,
right-click **Databases → Create → Database…**, name it exactly `vunaflow_db` (matching `.env`),
and save.

Or from the VS Code terminal, if `psql` is on your PATH:

```powershell
psql -U postgres -c "CREATE DATABASE vunaflow_db;"
```

If you have an older `vunaflow` database from a previous project, leave it alone — `vunaflow_db` is
a brand new, completely separate database, so there's no risk of the two clashing or migration
failing because of leftover tables.

### 2.4 Create tables and seed data

Still inside `backend/`:

```powershell
npm run migrate
```

This creates every table and seeds 43 real AFC branches (sourced from AFC's public branch
listings), bilingual (English/Swahili) FAQ content, and farming advice. If you're re-running this
after a previous migration attempt on an older database, drop and recreate `vunaflow_db` first —
the schema has changed (branches reseeded, `market_prices` table removed, `faqs` now has Swahili
columns):

```powershell
psql -U postgres -c "DROP DATABASE IF EXISTS vunaflow_db;"
psql -U postgres -c "CREATE DATABASE vunaflow_db;"
npm run migrate
```

### 2.5 Create your admin login (this is the part I skipped before — sorry!)

Registration in the app always creates a **client** account on purpose, so there's no admin account
until you create one. Run:

```powershell
npm run seed:admin
```

This prints your admin credentials to the terminal:

```
 Email:    admin@afc.co.ke
 Password: Admin@12345
```

Use those on the **Staff Login** screen in the app. Once logged in, use the **Admin** tab to add
real staff accounts with proper passwords, and change or disable your seed admin as needed. The
Admin tab also has a **Branches** section — AFC has 48 branches nationwide and this seed includes
43 of them (sourced from public listings); use **Add Branch** there to add any that are missing.

Want your own email/password instead of the defaults? Pass them as flags:

```powershell
npm run seed:admin -- --email=you@afc.co.ke --password=YourStrongPassword1 --name="Your Name" --phone=0712345678
```

### 2.6 Start the API

```powershell
npm run dev
```

The API runs on `http://localhost:4000`. Visit that URL (or `http://localhost:4000/health`) in a
browser to confirm it's running.

---

## 3. Viewing the PostgreSQL database (seeing your actual user/loan data)

Once you've registered a test client or logged in as staff through the app, here's exactly how to
see that data land in the database:

**Option A — pgAdmin 4 (GUI, installed with PostgreSQL on Windows)**
Open pgAdmin → expand **Servers → PostgreSQL → Databases → vunaflow_db → Schemas → public → Tables**.
Right-click a table (e.g. `users`) → **View/Edit Data → All Rows**. If you don't see your latest
test data, right-click **Tables** → **Refresh** first — pgAdmin doesn't auto-refresh.

**Option B — a VS Code extension**
Install the **PostgreSQL** extension by Chris Kolkman (`cweijan.vscode-postgresql-client2`) or the
official **PostgreSQL** extension from the Extensions panel (`Ctrl+Shift+X`, search "PostgreSQL").
Add a connection with your `.env` credentials and browse tables directly inside VS Code.

**Option C — psql in the terminal**
```powershell
psql -U postgres -d vunaflow_db

\dt                                          -- list all tables

SELECT id, full_name, email, role, is_active FROM users;
SELECT * FROM farmer_profiles;
SELECT id, client_id, amount_requested, status, created_at FROM loan_applications;
SELECT * FROM loan_status_history ORDER BY created_at DESC;
SELECT * FROM documents;
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 10;
SELECT name, county, phone FROM branches ORDER BY name;

\q                                            -- quit
```

Every action in the app writes here in real time: registering a client adds a row to `users` and
`farmer_profiles`; submitting a loan adds a row to `loan_applications` plus a `submitted` entry in
`loan_status_history`; a staff member changing a loan's status adds another `loan_status_history`
row and a new row in `notifications` for the client.

---

## 4. Flutter app setup

### Requirements
- Flutter SDK 3.3+

### Steps

```bash
cd frontend/vunaflow_app
flutter pub get
```

Point the app at your backend. By default it targets `http://localhost:4000`, which works for
web/desktop or an iOS simulator. Override it per-platform with `--dart-define`:

```bash
# Android emulator (maps to host machine's localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000

# Physical device on the same Wi-Fi network
flutter run --dart-define=API_BASE_URL=http://<your-machine-LAN-IP>:4000

# Web / desktop / iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:4000
```

---

## 5. Troubleshooting: branch dropdown empty / branches not loading

This almost always means `npm run migrate` didn't fully succeed — usually because it ran against a
database that already had conflicting objects in it (e.g. an old `branches` table with different
columns from a previous project). Since `.env.example` now points at a fresh, dedicated
`vunaflow_db` (see section 2.3 above) instead of a generically-named `vunaflow`, re-create the
database with that exact name and re-run the migration:

```powershell
psql -U postgres -c "DROP DATABASE IF EXISTS vunaflow_db;"
psql -U postgres -c "CREATE DATABASE vunaflow_db;"
cd backend
npm run migrate
```

Watch the terminal output closely — it should end with
`✅ Database schema created and seeded successfully.` If you see a red `❌ Migration failed` message
instead, copy the error text; it'll tell you exactly what clashed. Then confirm branches actually
exist by checking in pgAdmin or running:

```powershell
psql -U postgres -d vunaflow_db -c "SELECT count(*) FROM branches;"
```

You should see 43 AFC branches listed (AFC's own site cites 48 nationwide — add any remaining ones
yourself from the Admin tab's **Branches** section once you're logged in as admin). If that query
works but the app still shows nothing, the problem is on the connectivity side — see the login
troubleshooting notes above (backend running, correct `API_BASE_URL` for your platform).

---

## 6. Feature checklist

**Authentication** — registration (with confirm-password, an 8-character minimum, and two security
questions chosen from a fixed list), login, and password reset via those two security questions
(no email/SMS delivery required — this build has no provider for that, so identity is verified by
matching the two answers instead of sending a code). Separate client vs staff portals are enforced
both client-side (separate login screens) and server-side (the `portal` field in `/api/auth/login`
rejects mismatched roles). Phone numbers are validated and normalized to Kenyan format (`+254...`)
whether entered as `07...`, `01...`, or `+254...`. Duplicate emails and phone numbers are rejected
both in the app and at the database level (`UNIQUE` constraints), so no two accounts can share one.

**Client dashboard** — welcome banner, loan summary cards, recent applications with status pills,
notification bell with unread badge, logout available from every screen.

**Farmer profile** — personal details (including a proper Date of Birth picker) + farm information,
editable, with National ID validated to 7–8 digits and farming advice tied to the farmer's primary
crop. A complete profile (National ID, Date of Birth, Farm Size, Primary Crop) is required before a
loan application can be started — enforced both in the app (redirects to Edit Profile if incomplete)
and on the server (rejects the submission otherwise).

**Loan application** — form with client & server-side validation (amount ≥ KSh 100,000), an AFC
branch selector, a rule-based eligibility checker shown inline, and an illustrative repayment
schedule chart (principal vs interest per month, using a disclosed indicative rate) so a farmer can
see roughly what repaying the loan will look like before submitting. The server hard-blocks
submission if the applicant is under 18 (calculated from their profile's date of birth). On success,
the app shows: *"Your loan application has been submitted. Please visit any AFC branch for proper
document verification."*

**Document upload** — ID, title deed, collateral documents; files stored on disk with paths recorded
in PostgreSQL; per-document delete.

**Loan tracking** — six-stage status pipeline (Submitted → Under Review → Documents Verified →
Approved / Rejected → Disbursed) with a full audit trail (`loan_status_history`) shown as a timeline.

**Staff dashboard** — view all applications, search by client name/email, filter by status, open any
application to review documents and change its status (writes to the audit trail and notifies the
client automatically). Logout available from every tab.

**Reports** — total/pending/approved/rejected/disbursed loan counts, total clients.

**Analytics** — applications by month (bar chart), approved vs rejected (pie chart), loan amount
statistics, applications by branch — built with `fl_chart`.

**Notifications** — stored in PostgreSQL per user, created automatically on registration, submission,
and every status change; mark-as-read support.

**Branch selection** — `branches` table seeded with 43 real, sourced AFC branches across all six
regions (Head Office + Central Rift, Coast, Eastern, Mount Kenya, North Rift, Nyanza Western); chosen
explicitly when applying for a loan, and optionally as a home branch at registration/profile edit.
Admins can add any of AFC's remaining branches from the Admin tab.

**Admin / user management** — add staff, disable/enable staff, assign staff↔admin roles, manage the
AFC branch list.

**Simulated features** (no external paid APIs required):
- **Eligibility checker** — rule-based: farm size ≥ 2 acres, amount ≤ KSh 1,000,000, has collateral,
  age ≥ 18 → "Likely eligible" or "May require further review". This is informational; the server
  separately hard-enforces the 18+ rule at submission time regardless of this indication.
- **Smart Assistant (chatbot)** — bilingual (English/Swahili, toggle in the Assistant screen) FAQ
  matching against a `faqs` table, plus greeting recognition ("hi", "hello", "habari", "mambo", etc.)
  so the assistant responds naturally to a simple hello instead of only matching FAQ keywords.
- **Farming advice** — predefined tips per crop, shown on the farmer's profile.

Weather updates and market prices were removed from this build at the client's request — the
backend routes and UI sections for both have been taken out entirely (not just hidden).

---

## 7. Landing page

Shown to everyone before login, matching the requested structure: nav bar (with EN/SW language
toggle, Client Login, Staff Login), hero section, "What VunaFlow Does", "How It Works" steps,
feature cards, benefits (farmers vs staff), About AFC, FAQ accordion, contact info, and footer.
After choosing a portal and logging in, users land on the Client Dashboard or Staff Dashboard —
never both.

---

## 8. Improvements made beyond the original spec

- **Portal-enforced login** — the backend rejects a client login attempt on the staff portal and vice
  versa, rather than relying on the frontend alone.
- **Full audit trail** for every loan status change (`loan_status_history`), not just the current
  status — this powers both the client's tracking timeline and the staff review screen, and gives you
  a real "who changed what, when" record for compliance.
- **Automatic notifications** fire on registration, loan submission, and every status change, so
  "Notifications" isn't a separate manual step for staff — it's built into the loan workflow.
- **Eligibility checker** is exposed as its own endpoint (`GET /api/loans/eligibility-check`) so the
  client can check before submitting, and the result is also stored against the application for staff
  to see during review.
- **Search + filter combine** on the staff applications list (status chips and a text search work
  together, with pagination support already in the API for when your dataset grows).
- **Role-based route guards** on every sensitive endpoint (`authenticate` + `authorize`), not just
  hidden UI — disabling a staff account immediately blocks their API access, not just their app view.
- **Staff can actually open uploaded documents**, not just see a filename — tapping a document on
  the staff review screen (or the client's own upload screen) opens the file in a new tab/external
  viewer for real verification, not just a list of names.
- **Profile-completeness and age gates are enforced server-side**, not just hidden in the UI — even
  a modified or scripted client can't bypass the "complete your profile first" or "must be 18+" rules,
  since `POST /api/loans` re-checks both independently of what the app already validated.
- **Kenyan phone numbers are normalized, not just validated** — whatever format a user types
  (`07...`, `01...`, `+254...`), it's stored consistently as `+254...` everywhere, so staff records
  don't end up with three different formats for the same number.
