# TradeStart production foundation (not activated)

The current `index.html` remains a **fictional-data demo**. Do NOT enter applicant personal information. The production schema and security policies are staged in `supabase/migrations/001_tradestart_foundation.sql`.

## Design

- **Admin:** controls manually entered participant records, deactivation, published shifts, confirmed assignments and recorded training.
- **Participant:** authenticated, approved and eligible; sees open shifts, their own profile, their own responses and assignment history.
- **Public:** no access to participant or shift records.
- **One opening by default:** `ts_shifts.openings default 1`; managers can explicitly post more.
- **Fair rotation:** manager approves respondents with fewest completed shifts, with manual safety/qualification review. Rotation is a later server-side feature and is **not** yet enforced by SQL.
- **Notifications:** pending. No emails or text messages are sent.

## Activation checklist

1. Create a dedicated Supabase project under AHI control, with MFA on administrators.
2. Review `001_tradestart_foundation.sql` and run it in the SQL editor, using a **new empty project**. No script has been executed against any live database.
3. Create AHI administrator in Supabase Authentication, copy its Auth user UUID, then insert the UUID into `public.ts_admins` using the SQL editor. Never put this UUID alongside sensitive records in GitHub.
4. Verify RLS denials for unauthenticated users and for unrelated authenticated users, and permitted admin/participant operations. Run an RLS test suite before go-live.
5. Implement separate authenticated admin and participant interfaces, passwordless sign-in or approved login, invitations, audit logging, and server-side validation for shift capacity/rotation.
6. Add transactional email/text alerts using a protected server function and opt-in preferences; no messaging keys in the frontend.
7. Have Arizona payroll, workers-compensation, employment and youth-work restrictions reviewed before real assignments.

## Security boundaries

GitHub Pages is a static host. Supabase publishable keys may appear client-side **only with thoroughly tested RLS**; secret keys must remain server-side. Do not use client-side hiding as authorization. Avoid full street addresses in public shift listings. Never collect SSNs, banking details or I-9 documents in this app; use a compliant payroll/onboarding service.

This is **foundation code**, not a deployed production employment platform.
