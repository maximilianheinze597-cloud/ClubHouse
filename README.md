# CLUBHOUSE – SV Hausgemachter Salat

Mobile-first React + TypeScript app for the SVHS club hub and **CLUBHOUSE: ULTIMATE TEAM**.

## What is in the repository
- Responsive dark-green interface: dashboard, squad, matches, news, profile/auth, Ultimate Team, album and objectives.
- Original SVHS-styled card visuals with Bronze/Silber/Gold/Ultimate/Legendär rarity tiers.
- Optional Supabase email/password sign-up, sign-in, sign-out and password-reset flow.
- Demo mode persists local preview state on the same browser/device and clearly labels local-only results.
- Supabase schema migrations for profiles/roles, club roster and fixtures, card catalog/inventory, album, objectives, points ledger, packs, squads, AI opponents, trades and audit history.
- Server-side atomic pack opening with idempotency, versioned odds snapshots and guarantee support.
- Server-side AI match simulation and duplicate-card upgrade RPCs.
- Server-side card-only trade creation/acceptance RPCs.
- Seed data for fictional game-only cards, sample pack odds, AI opponents and objectives.
- PWA manifest, original SVG icon and offline shell service worker.
- GitHub Actions CI plus GitHub Pages deployment workflow.

## Run locally
Requires Node.js 20.19+ or 22.12+.

```bash
npm install
npm run dev
npm test
npm run build
```

A lockfile is not committed yet, so `npm install` creates one locally. The CI workflow installs dependencies and runs the tests/build on each push and pull request.

## Demo mode vs. connected mode
Without `.env.local`, the app runs in local preview mode. Preview cards, packs, Club Points and match results are stored only in that browser; they are not server-verified and do not sync between users.

To enable accounts and server-backed game actions, configure Supabase below. The UI then uses Supabase Auth, loads the user's balance/inventory, and calls the Edge Function/RPCs for pack openings, match rewards and card upgrades. Trading RPCs exist in the database, but a complete trade-management screen and end-to-end verification are still outstanding. Admin CRUD, real push delivery, image upload validation, attendance/polls, complete standings/statistics and comprehensive end-to-end tests are also not yet finished. This is an implemented core, not a claim that every item in the full specification is production-ready.

No real player photos, verified match results or official third-party game assets are bundled. Starter card names and ratings in the game catalog are fictional/game-only. Obtain appropriate consent and usage rights before adding real photos, especially for minors.

## Supabase setup
1. Create a Supabase project.
2. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (or the project's publishable key). Never expose a service-role key through a `VITE_` variable.
3. Install the Supabase CLI, link the project and review/apply the migrations in order:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```
4. Run `supabase/seed.sql` in the SQL editor after migrations. It creates fictional game characters, Starter/Gold packs, sample AI opponents and objectives. Each rarity configured with a nonzero probability needs at least one available card.
5. Deploy the Edge Function:
   ```bash
   supabase functions deploy open-pack
   ```
6. In Supabase Auth, configure the site's URL and allowed redirect URLs. For GitHub Pages, include `https://maximilianheinze597-cloud.github.io/ClubHouse/` if Pages is enabled.
7. Register an account through the Profile screen. New accounts receive the player role and the initial virtual Club Points balance. No real-money purchase or cash-out exists.

### Secure first admin
New users are always assigned the player role. To grant the first admin, verify the account UUID in Supabase Auth, then run this manually in the trusted Supabase SQL editor:

```sql
insert into public.user_roles(user_id, role, granted_by)
values ('YOUR_AUTH_USER_UUID', 'admin', 'YOUR_AUTH_USER_UUID');
```

Do not expose role assignment to public clients. Review migrations on a test project before production use. GitHub Pages hosts only the static frontend; Supabase supplies authentication, data and trusted game actions.

## GitHub Pages
The workflow at `.github/workflows/pages.yml` builds, tests and deploys the static frontend when pushed to `main`. In repository settings, enable Pages with **GitHub Actions** as the build/deployment source if it is not already enabled. The app can be used in demo mode without Supabase; real accounts and server-backed actions require the Supabase configuration above.

## Testing status
The domain tests cover team rating calculations and pack-probability boundaries. GitHub Actions is configured to run tests and a production build. SQL migrations and real Supabase behavior still require applying them to a test Supabase project and exercising authenticated concurrent requests; do not treat a successful frontend build alone as proof of backend security.
