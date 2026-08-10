# MARCUS

**Accounting education, from zero to CA Final level.**

MARCUS is a production-quality accounting learning platform that takes a
learner through the entire journey — **Accounting Zero → Basic → Intermediate →
Professional Accountant → Advanced Accounting → CA Final Level** — with real
accounting logic, personalized learning, exam preparation, and an accounting
simulator, not just a quiz app.

> ⚖️ **READ THE LEGAL NOTICE FIRST** — see [Legal & disclaimers](#legal--disclaimers)
> below. MARCUS is an *educational* application. It is **not** affiliated with
> the Institute of Chartered Accountants of India (ICAI), does **not** confer
> any professional qualification, and does **not** provide professional
> accounting, financial, or tax advice.

---

## Table of contents

- [Product vision](#product-vision)
- [The learning journey](#the-learning-journey)
- [Features](#features)
- [How it works (architecture)](#how-it-works-architecture)
- [Content model](#content-model)
- [Project structure](#project-structure)
- [Tech stack](#tech-stack)
- [Getting started](#getting-started)
- [CI & releases (GitHub Actions)](#ci--releases-github-actions)
- [Project status & next steps](#project-status--next-steps)
- [Branding](#branding)
- [Security](#security)
- [Legal & disclaimers](#legal--disclaimers)
- [License](#license)

---

## Product vision

The core learning loop that drives every feature:

```
LEARN → UNDERSTAND → PRACTICE → TEST → ANALYZE → REVISE → MASTER
```

The product continuously identifies **what the learner understands, what they
don't, and what they should study next**, and personalizes the experience
around those answers. It combines:

1. Structured accounting education
2. Interactive practice
3. Exam preparation
4. Accounting problem solving
5. Mistake analysis (mistake intelligence)
6. Personalized learning (adaptive assessment + roadmap)
7. Real-world accounting simulation
8. AI accounting tutor
9. CA Final-level advanced practice

**Design philosophy:** serious and professional — the app must feel like a
real learning platform for accounting students and professionals, not a quiz
app. Clean typography, strong hierarchy, light/dark themes, responsive layouts,
professional progress indicators, no clutter, no childish gamification.

---

## The learning journey

| Level | Name | Focus |
|-------|------|-------|
| 1 | **Accounting Foundation** | Terminology, concepts, accounting equation, debit/credit rules, journal, ledger, trial balance, cash book, bank reconciliation, adjustments, final accounts |
| 2 | **Professional Accounting** | Receivables, payables, inventory, depreciation, accruals/prepayments, provisions, bad debts, payroll, GST & TDS concepts, month-end closing, financial statements, cash flow basics, controls, MIS basics |
| 3 | **Advanced Accounting** | Company accounts, partnership, branch & departmental accounts, consolidated financial statements, business combinations, advanced statements, cash-flow statements, analysis, accounting standards, Ind AS concepts |
| 4 | **CA Final Level** | Advanced financial reporting, Ind AS, complex adjustments, consolidation, business combinations, integrated case studies, exam-style problems, mock examinations |

Each level contains subjects → chapters → topics → lessons (concept,
explanation, example, worked solution, common mistakes) → practice questions
→ mini tests.

### Onboarding & personalization

A new user completes an adaptive **25-question knowledge assessment** covering
eight skill dimensions (foundation, debit/credit, journal, ledger, trial
balance, financial statements, tax/GST awareness, advanced accounting). The
system scores each skill, recommends a starting level (1–4), and builds a
**personalized roadmap**: weak-skill topics are prioritized first, and a strong
learner is never forced back to Level 1. Weak areas then feed the mistake
engine and spaced-repetition revision queue (Day 1 → 3 → 7 → 14 → 30).

---

## Features

- **Personalized onboarding** — assessment → skill analysis → recommended
  level → personalized roadmap.
- **Curriculum engine** — 4 levels, full lesson content with worked examples,
  common mistakes, and practice.
- **Practice engine** — MCQ, numerical, journal entry, fill-in-the-blank, and
  true/false question types with a rich answer experience (why you're
  right/wrong, why alternatives are wrong, common mistakes, related concepts,
  next question).
- **Exam system** — topic, chapter, level, mixed, Professional Accountant, and
  CA Final mock tests with timer, negative marking, question navigation, mark
  for review, submit, results, and performance analysis.
- **Accounting simulator** — journalize real transactions for fictional
  companies. The system runs real double-entry logic: transactions post to the
  ledger, build the trial balance, and flow into the P&L and balance sheet.
  Your entries are checked line-by-line with specific feedback.
- **Mistake intelligence** — every wrong answer is recorded, grouped by skill,
  and converted into revision and easier → medium → difficult → mini-test
  practice.
- **Smart revision** — spaced repetition (Day 1 → 3 → 7 → 14 → 30) with
  performance-adjusted scheduling; repeated mistakes get higher priority.
- **AI accounting tutor** — a provider-abstracted service (`AiTutorService`)
  with a built-in offline coach. Explains concepts at the learner's level,
  prefers hints over answers while solving, and can check journal entries.
  Provider (and API keys) are never hard-coded in the client.
- **Reference library** — accounting rules, journal rules, formulas, ratios,
  financial statement and cash-flow concepts, accounting standards, Ind AS,
  GST accounting, consolidation concepts.
- **Notes & bookmarks** — personal notes, mistake notes, saved lessons and
  questions — all searchable.
- **Global search** — lessons, topics, questions, concepts, standards, journal
  entries, case studies, notes, bookmarks.
- **Professional gamification** — XP, streaks, achievement badges, progress
  levels, and ranks (Accounting Beginner → Bookkeeper → Accountant → Senior
  Accountant → Financial Reporting Specialist → CA Aspirant → CA Final Master).
- **Dashboard** — current level, progress, continue-learning, daily goal,
  streak, questions solved, accuracy, weakest/strongest skills, recommended
  next lesson, revision due, upcoming test, recent performance.
- **Offline-first** — the MVP curriculum ships as bundled data; learner
  progress persists locally and syncs to Supabase when configured.

---

## How it works (architecture)

```
UI (Flutter widgets)
   ↕  Riverpod state
BUSINESS LOGIC (domain engines — pure Dart)
   ↕
DATA (models, repositories, data sources)
   ↕
STORAGE (local, offline-first)  +  BACKEND SERVICES (Supabase / AI — optional)
```

- **Domain layer** (`lib/domain/`) is pure Dart with **no Flutter imports** —
  the accounting engine (journal, ledger, trial balance, P&L, balance sheet,
  simulator checking), assessment engine, roadmap builder, revision engine, and
  gamification are all unit-tested independently of UI.
- **Exact decimal arithmetic** — all financial logic uses the `decimal`
  package; money parsing tolerates Indian formatting (`3,20,000`), currency
  symbols, negatives, and parentheses. No floating-point money.
- **Data-driven content** — the entire curriculum lives in editable JSON under
  `assets/data/` (levels, subjects, chapters, topics, lessons, questions,
  assessment bank, tests, simulations, references) and is loaded lazily per
  level. Content can be updated without touching app code, and a Supabase
  data source can replace the asset source without changing feature code.
- **Abstracted services** — auth, content, sync, and AI are behind interfaces
  (`AuthRepository`, `ContentDataSource`, `SyncEngine`, `AiTutorService`) with
  local implementations for offline development and remote implementations
  (Supabase / HTTP) ready to plug in.

---

## Content model

```
Level (1–4)
 └─ Subject
     └─ Chapter
         └─ Topic
             ├─ Lesson (sections: concept, explanation, example, formula,
             │           worked solution, common mistakes)
             └─ Questions (MCQ / numerical / journal / fill-blank / true-false)
```

Every question carries metadata: topic, chapter, level, difficulty
(⭐ Beginner … ⭐⭐⭐⭐⭐ CA Final), type, answer + accepted variants, explanation,
hint, why-others-are-wrong, common mistake, tags, skills, marks, negative
marks, estimated time.

Content locations:

| Data | File |
|------|------|
| Level metadata, ranks, disclaimer | `assets/data/levels.json` |
| Level 1 curriculum | `assets/data/level_1.json` |
| Level 2 curriculum | `assets/data/level_2.json` |
| Level 3 curriculum | `assets/data/level_3.json` |
| Level 4 curriculum | `assets/data/level_4.json` |
| Assessment bank (25 questions, 8 skills) | `assets/data/assessment.json` |
| Tests (professional, CA Final mock, mixed) | `assets/data/tests.json` |
| Simulator scenarios | `assets/data/simulations.json` |
| Reference library | `assets/data/reference.json` |

The Supabase schema (PostgreSQL, RLS, indexes, constraints) is in
`supabase/migrations/0001_init.sql` — the full entity model (users, profiles,
courses, levels, subjects, chapters, topics, lessons, questions, attempts,
tests, user_progress, user_skills, mistakes, revision_queue, bookmarks, notes,
achievements, streaks, simulations, subscriptions, audit_logs).

---

## Project structure

```
lib/
  core/       config (app name, branding), theme, routing, errors, storage,
              networking, utils
  domain/     pure-Dart engines: accounting, assessment, revision, gamification
  data/       models, datasources, repositories, sync
  features/   auth, onboarding, home, learn, practice, exams, simulator,
              ai_tutor, profile, search, reference
  shared/     design-system widgets (app shell, progress rings, state views,
              answer input, journal editor, stat cards)
assets/data/  curriculum + question content (JSON, editable)
supabase/     schema, migrations, RLS policies
tool/         icon generator, project-local Flutter launcher
test/         unit + widget tests (accounting engine, assessment, revision,
              gamification, repositories, content source, app smoke test)
```

---

## Tech stack

- **Frontend:** Flutter (3.44.9 stable), Riverpod, GoRouter, decimal
- **Backend (optional):** Supabase — PostgreSQL, Auth, Row Level Security,
  edge functions; the app runs fully offline without it
- **AI:** abstraction layer with built-in offline coach; remote provider
  selectable via `--dart-define` (never ship provider secrets in the client)

---

## Getting started

Prerequisites: Flutter SDK 3.44.9 (stable) and — for APK builds — an Android
SDK + JDK 17+.

```bash
flutter pub get
flutter run                # device / emulator
flutter run -d chrome      # web
flutter test               # full test suite
flutter analyze            # static analysis
```

### Build the Android APK

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

The default release build is signed with the debug key, which installs
directly on any Android device. For the Play Store, configure a real signing
key (see `android/app/build.gradle.kts` and the `key.properties` pattern).

### Backend / Supabase

Without configuration the app runs in local demo mode (bundled content, local
auth, local persistence). To enable Supabase, supply at build time — never
commit real keys:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Apply the schema with `supabase db push` (or the SQL file directly), then
toggle on Row Level Security policies from `supabase/migrations/0001_init.sql`.

---

## CI & releases (GitHub Actions)

Two workflows keep the repo self-building:

- **`ci.yml`** — on every push to `main` and every pull request: `flutter
  analyze`, `flutter test`, `flutter build apk --release`, and the APK is
  uploaded as a downloadable workflow artifact.
- **`release.yml`** — when a version tag (`v*`, e.g. `v1.0.0`) is pushed:
  builds the APK, runs tests, and publishes a GitHub **Release** with the APK
  attached, so anyone can download it directly.

```bash
# Tag + release in one shot:
git tag v1.1.0 && git push origin v1.1.0
```

The current latest release is **v1.0.0**:
https://github.com/jiteshoffice1234-star/marcus/releases

---

## Project status & next steps

**Implemented (working end-to-end, 57 tests passing):**

- ✅ Flutter app with modular architecture, theme (light/dark), routing,
  error handling, offline-first local storage
- ✅ Onboarding → 25-question assessment → personalized roadmap
- ✅ 4-level curriculum with lessons + practice questions (60+ questions)
- ✅ Practice player with full answer experience
- ✅ Exam runner (tests, mocks, timer, negative marking, results)
- ✅ Accounting simulator (real journal → ledger → trial balance → statements)
- ✅ Mistake intelligence + spaced-repetition revision
- ✅ AI tutor (offline coach; provider abstraction)
- ✅ Dashboard, profile, notes, bookmarks, achievements, search, reference
- ✅ Supabase schema + migrations + RLS
- ✅ App icon + branding system, responsive web build
- ✅ CI + release workflows, Android release APK

**Planned / next (good starting points for contributors or a future AI agent):**

- 🔲 Wire the Supabase backend (auth, sync engine, hosted content) — the
  abstraction layers exist; the local implementations are active
- 🔲 Admin panel (question/curriculum editor) — schema exists
- 🔲 More curriculum content per level (more questions, lessons, case studies)
- 🔲 Remote AI provider integration (e.g., an HTTP proxy to a hosted model)
- 🔲 Play Store signing key + store listing
- 🔲 Expanded test matrix (widget tests per feature, integration tests)

---

## Branding

- The app name (**MARCUS**) is centralized in `lib/core/config/app_config.dart`;
  platform launcher names live in `android/app/src/main/AndroidManifest.xml`,
  `ios/Runner/Info.plist`, and `web/manifest.json`.
- Original icon assets are generated by `tool/icon_generator.js` into
  `assets/branding/icon/` — no third-party logos or copyrighted assets are
  used anywhere in the app.

---

## Security

- No secrets in client code — backend URLs/keys are build-time
  `--dart-define` values, never committed.
- Supabase service-role keys are server-side only.
- Database Row Level Security is enabled in the schema.
- User input is validated; all money math uses exact decimal arithmetic.
- The app fails gracefully: loading / empty / error / offline states with
  recovery actions on every screen.

---

## Legal & disclaimers

**Please read this section carefully.**

1. **No professional qualification.** MARCUS is an *educational* application.
   It does **not** make anyone a Chartered Accountant (CA) or any other
   professional. Completing this app's content does **not** confer, replace,
   or substitute for any official qualification, certification, license, or
   registration.

2. **Not affiliated with ICAI.** This project is **not** affiliated with,
   endorsed by, or connected to the Institute of Chartered Accountants of
   India (ICAI) or any other examination or regulatory body. "CA", "CA Final",
   and "ICAI" are used only to describe the *level and style* of educational
   content, not any official program. Official ICAI syllabus and qualification
   requirements are separate and must be satisfied through ICAI's own
   processes.

3. **No professional advice.** The content is for learning purposes only and
   is **not** accounting, financial, tax, legal, or investment advice. For
   real business, tax, or financial decisions, consult a qualified
   professional.

4. **No guarantee of results.** MARCUS does not guarantee exam success,
   employment, or professional outcomes of any kind.

5. **Original content.** All curriculum text, questions, examples, and code in
   this repository were written for this project. No copyrighted ICAI
   publications, textbooks, or third-party materials are reproduced.

6. **Trademarks.** All trademarks, service marks, and product names (including
   but not limited to ICAI, Flutter, Supabase, Android) belong to their
   respective owners and are used only for identification/description.
   "MARCUS" is used as this project's name; no claim is made to any trademark
   held by third parties.

7. **Use at your own risk.** The software and content are provided "as is",
   without warranty of any kind, express or implied — see the [License](#license).

---

## License

MIT License — see [LICENSE](LICENSE).

Copyright (c) 2026 jitesh-solanki

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
