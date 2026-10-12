# CLUBHOUSE – SV Hausgemachter Salat

Mobile-first React + TypeScript prototype for the SVHS club dashboard and CLUBHOUSE: ULTIMATE TEAM.

## Included
- Responsive dark-green UI for Home, squad, matches, news, profile, Ultimate Team, album and tasks.
- Card models with Bronze/Silber/Gold/Ultimate/Legendär rarities, attributes, pack-shop presentation and local reveal UI.
- Demo match simulation and virtual Club Points, explicitly labelled as local preview.
- Supabase schema foundation with RLS for profiles, roles, players, seasons, matches, news, calendar, card inventory, points ledger, packs, squads, AI opponents and trades.
- Server-side pack-opening RPC migration and authenticated Edge Function wrapper.
- Unit tests for rating calculations and probability boundaries.

## Run locally
Requires Node.js 20.19+ or 22.12+.

```bash
npm install
npm run dev
npm run test
npm run build
```

## Honest implementation status
The UI currently uses in-memory demo state. The local pack-opening animation, CP changes and match simulation are **not yet connected to the Supabase backend** and are not secure for real accounts. Do not treat demo values or outcomes as persistent, server-verified data. The SQL/Edge Function is a foundation for secure pack opening, but requires review, seed data and deployment before activation.

The broader production scope still needs real auth screens and frontend integration, secure server functions for trading/upgrades/match rewards, full admin CRUD, image upload validation, push delivery, polls, transfer history, standings, and end-to-end tests. The database migration is a starting point and must be reviewed on a test Supabase project before production.

No verified match results, official logos or player photographs are bundled. Sample card ratings are game-only values. Get consent and appropriate rights before uploading any real player photos, particularly for minors.

## Supabase

A sample seed script is provided at `supabase/seed.sql` for fictional game characters and the Starter/Gold pack odds. Review it before applying; the Ultimate pack intentionally remains inactive until its server-side guarantee rule is implemented. A GitHub Actions workflow runs the dependency install, tests and build on pushes/PRs.

1. Create a Supabase project and install the Supabase CLI.
2. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. Never expose a service-role key.
3. Link the project and review/apply migrations: `supabase link --project-ref YOUR_REF`, then `supabase db push`.
4. Seed available card definitions, pack definitions and probability versions before activating packs. Each rarity shown in a pack needs an available card and weights must sum to 100%.
5. Deploy the Edge Function: `supabase functions deploy open-pack`.
6. Connect the frontend to Supabase Auth and call the Edge Function with the authenticated session and a new UUID idempotency key per intentional purchase.

New accounts receive only the player role. To grant the first admin, verify the account UUID in Supabase Auth and run this manually in the trusted SQL editor:

```sql
insert into public.user_roles(user_id, role, granted_by)
values ('YOUR_AUTH_USER_UUID', 'admin', 'YOUR_AUTH_USER_UUID');
```

Never expose admin-role changes through the public frontend. GitHub Pages can host the static UI but cannot run the backend by itself.

## Dependencies / lockfile
The project manifest is included. A package lockfile could not be generated in this build environment because the npm registry was unreachable; generate it on a network-enabled machine with `npm install` before using `npm ci` in CI. Build and automated tests could not be executed here because dependencies were not installed.