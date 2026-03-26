# X2-A1: Admin Ground-Truth Research Inventory

**Produced by:** Track Control Agent  
**Date:** March 26, 2026  
**Status:** Complete — awaiting Jeff review before X2-A2 begins  
**Method:** Systematic code + doc archaeology across all 4 source layers

**Source layers read:**
- Layer 1: `docs/product/master_plan_v2.md` (all sections), `docs/analysis/`
- Layer 2: `packages/admin-app/lib/features/` (all 9 feature dirs), `sidebar.dart`, `routes.dart`
- Layer 3: `packages/api/src/routes/admin.ts` (all 49 endpoints), `webhooks.ts`
- Layer 3b: `/Users/jmsimpson/Documents/GitHub/IndustryNight-runs/B0-claude/packages/react-admin/` (B0 Claude winner worktree)
- Layer 4: All B, C, D, E, A track CODEX prompts

---

## Section 1: Admin Nav Inventory

Every nav item across Flutter sidebar (shipped), master_plan v2 §5.3 (specced), B0 permissions.ts (planned), and B0 Sidebar.tsx (built).

| Nav Item | Flutter Sidebar | master_plan §5.3 | B0 permissions.ts | B0 Sidebar.tsx | Gap |
|----------|----------------|-------------------|-------------------|----------------|-----|
| Dashboard | ✅ top-level | ✅ [all roles] | ✅ [all roles] | ✅ real API | None |
| Event Ops | ❌ missing | ✅ [eventOps, platformAdmin] | ✅ `/event-ops` [eventOps, platformAdmin] | ✅ ComingSoon | Flutter lacks; B2 specced |
| Users | ✅ top-level | ✅ [moderator, platformAdmin] | ✅ `/users` [moderator, platformAdmin] | ✅ ComingSoon | None |
| Events | ✅ top-level | ✅ [eventOps, platformAdmin] | ✅ `/events` [eventOps, platformAdmin] | ✅ ComingSoon | None |
| Tickets | ✅ top-level (REVENUE area) | ❌ not listed as nav item (implied under Events) | ❌ no entry | ❌ no page, no route | **Accidental omission in B0 and §5.3.** B3 specced. Needs product decision: top-level vs. Events sub-section. |
| Images | ✅ top-level (above REVENUE) | ❌ implied under Events | ❌ no entry | ❌ no page, no route | **Accidental omission in B0.** B3 specced under Events. Flutter parity = top-level. |
| Customers | ✅ under REVENUE section | ✅ [platformAdmin] | ✅ `/customers` [platformAdmin] | ✅ ComingSoon | None |
| Products | ✅ under REVENUE section (top-level) | ❌ collapsed under Customers in §5.3 | ❌ no entry | ❌ no page, no route | **Intentional consolidation** per §5.3 (Products accessed from Customer context). B3 specced as /customers/:id with Products sub-panel. Needs Jeff confirmation. |
| Posts | ✅ under MODERATION section | ✅ collapsed under single "Moderation" | — | — | Merged into Moderation in React — intentional per §5.3 |
| Announcements | ✅ under MODERATION section (separate) | ✅ under Moderation as sub-item | — | — | Merged under Moderation in React — intentional per §5.3 |
| Jobs | ❌ missing | ✅ "Jobs Board" [moderator, platformAdmin] | ✅ `/jobs` [moderator, platformAdmin] | ✅ ComingSoon | Flutter lacks; E-track specced |
| Moderation | ❌ (Flutter uses Posts + Announcements) | ✅ [moderator, platformAdmin] | ✅ `/moderation` [moderator, platformAdmin] | ✅ ComingSoon | Intentional consolidation; Flutter stub has 0 API calls |
| Posh Orders | ❌ missing | ✅ "Posh Orders" [eventOps, platformAdmin] | ✅ `/posh-orders` [eventOps, platformAdmin] | ✅ ComingSoon | Flutter lacks; B3 specced; **API endpoint also missing** — see Section 3 |
| Analytics | ❌ missing | ✅ [platformAdmin] | ✅ `/analytics` [platformAdmin] | ✅ ComingSoon | Flutter lacks; D1/D2 specced |
| Markets | ✅ under SETTINGS section | ❌ **not listed in §5.3 Settings** (§5.3 Settings shows: Audit Log, Platform Config, API Key Status only) | ❌ no entry | ❌ no page, no route | **§5.3 staleness.** Markets exists in Flutter + API. B3 specced. React B0 has no markets route. |
| Settings | ✅ under SETTINGS section | ✅ [platformAdmin] | ✅ `/settings` [platformAdmin] | ✅ ComingSoon | None (settings shell); Markets sub-content missing |

**Nav count summary:**
- Flutter sidebar: 13 items (Dashboard, Users, Events, Tickets, Images, Customers, Products, Posts, Announcements, Markets, Settings + 2 section headers not counted)
- B0 React sidebar (all roles visible, filtered by role): 10 items (Dashboard, Event Ops, Users, Events, Customers, Jobs, Moderation, Posh Orders, Analytics, Settings)
- Items in Flutter only: Tickets (top-level), Images (top-level), Products (top-level), Markets (explicit nav)
- Items in React only (new): Event Ops, Jobs, Posh Orders, Analytics

---

## Section 2: Screen Inventory

Every admin screen across Flutter (shipped), master plan (planned), and B-track prompts (specced).

### Flutter Admin (shipped — `packages/admin-app/lib/features/`)

| Screen | Route | API Wired | Notes |
|--------|-------|-----------|-------|
| AdminLoginScreen | `/login` | ✅ POST /admin/auth/login | Full auth + token storage |
| DashboardScreen | `/` | ✅ GET /admin/dashboard | Stats cards |
| UsersListScreen | `/users` | ✅ GET /admin/users | Search + filter by role/verificationStatus |
| UserDetailScreen | `/users/:id` | ✅ GET /admin/users (id lookup) | Profile + ban/verify/role actions |
| AddUserScreen | `/users/add` | ✅ POST /admin/users | Phone + name + role form |
| EventsListScreen | `/events` | ✅ GET /admin/events | Status filter, hero image, partner count |
| EventFormScreen | `/events/create`, `/events/:id/edit` | ✅ POST + PATCH /admin/events | Unified create/edit |
| EventDetailScreen | `/events/:id` | ✅ getEvent + upload + partner mutations | Images + partners inline |
| EventTicketsScreen | `/events/:id/tickets` | ✅ GET /admin/events/:id/tickets | Per-event ticket list |
| ImageCatalogScreen | `/images` | ✅ GET /admin/images | Grid + multi-select + bulk delete |
| TicketsListScreen | `/tickets` | ✅ GET /admin/tickets | Global ticket list + filter by event |
| CustomersListScreen | `/customers` | ✅ GET /admin/customers | Search + hasProductType filter |
| CustomerFormScreen | `/customers/add`, `/customers/:id/edit` | ✅ POST + PATCH /admin/customers | Unified create/edit |
| CustomerDetailScreen | `/customers/:id` | ✅ getCustomer + contacts + media + products | Full CRM detail |
| DiscountsScreen | `/customers/:id/discounts` | ✅ GET/POST/PATCH/DELETE discounts | Per-customer discounts |
| ProductCatalogScreen | `/products` | ✅ GET /admin/products | Product list + type filter |
| ProductFormScreen | `/products/add`, `/products/:id/edit` | ✅ POST + PATCH /admin/products | Unified create/edit |
| PostsListScreen | `/moderation/posts` | ⚠️ **STUB — 0 API calls** | 100% fake data |
| AnnouncementsScreen | `/moderation/announcements` | ⚠️ **STUB — 0 API calls** | Static UI only |
| MarketsScreen | `/markets` | ✅ GET/POST/PATCH /admin/markets | List + inline create/edit/activate |
| AdminSettingsScreen | `/settings` | ❌ No API calls (static UI) | Stub |

**Flutter total: 21 screens — 18 real API, 2 stubs (moderation), 1 static (settings)**

### React Admin B0 (scaffold — all pages are `<ComingSoon>` except dashboard and auth)

| Screen | Route | Status | Specced In |
|--------|-------|--------|------------|
| LoginPage | `/login` | ✅ real auth (POST /api/admin/auth/login via proxy) | B0 |
| DashboardPage | `/` | ✅ real API (GET /admin/dashboard via useDashboard hook) | B0 |
| EventOpsPage | `/event-ops` | ⚠️ ComingSoon | B2 |
| UsersPage | `/users` | ⚠️ ComingSoon | B3 |
| EventsPage | `/events` | ⚠️ ComingSoon | B3 |
| CustomersPage | `/customers` | ⚠️ ComingSoon | B3 |
| JobsPage | `/jobs` | ⚠️ ComingSoon | E-track |
| ModerationPage | `/moderation` | ⚠️ ComingSoon | B3 (manual), D0 (LLM) |
| PoshOrdersPage | `/posh-orders` | ⚠️ ComingSoon | B3 |
| AnalyticsPage | `/analytics` | ⚠️ ComingSoon | D1/D2 |
| SettingsPage | `/settings` | ⚠️ ComingSoon | B3 |

**React screens NOT yet created (missing routes entirely):**

| Missing Screen | Flutter Equiv | Specced In |
|---------------|---------------|------------|
| Event Detail (`/events/:id`) | EventDetailScreen | B3 |
| Event Create (`/events/create`) | EventFormScreen | B3 |
| Event Edit (`/events/:id/edit`) | EventFormScreen | B3 |
| Event Tickets (`/events/:id/tickets`) | EventTicketsScreen | B3 |
| Image Catalog (`/images`) | ImageCatalogScreen | B3 |
| User Detail (`/users/:id`) | UserDetailScreen | B3 |
| Add User (`/users/add`) | AddUserScreen | B3 |
| Customer Detail (`/customers/:id`) | CustomerDetailScreen | B3 |
| Customer Create (`/customers/add`) | CustomerFormScreen | B3 |
| Customer Edit (`/customers/:id/edit`) | CustomerFormScreen | B3 |
| Customer Discounts (`/customers/:id/discounts`) | DiscountsScreen | B3 |
| Products (standalone or nested) | ProductCatalogScreen | B3 |
| Markets (`/markets`) | MarketsScreen | B3 |
| Admin Users (new) | — | B3 |
| Audit Log (new) | — | B3 |
| Event Ops Detail (`/events/ops/:id`) | — | B2 |

---

## Section 3: API Coverage Map

Every admin API endpoint — which Flutter screens call it, which React screens will call it, which prompts spec it, which are orphaned.

### Endpoints in admin.ts (49 total)

| Endpoint | Flutter | React B0 | Specced In | Status |
|----------|---------|----------|------------|--------|
| `GET /admin/dashboard` | DashboardScreen | ✅ real | B3 (enhance) | ✅ Covered |
| `GET /admin/markets` | MarketsScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/markets` | MarketsScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/markets/:id` | MarketsScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/users` | UsersListScreen | ❌ stub | B3 | ✅ API exists, React not built |
| `PATCH /admin/users/:id` | UserDetailScreen | ❌ stub | B3 | ✅ API exists, React not built |
| `POST /admin/users` | AddUserScreen | ❌ stub | B3 | ✅ API exists, React not built |
| `GET /admin/events` | EventsListScreen | ❌ stub | B3 | ✅ API exists, React not built |
| `GET /admin/events/:id` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/events` | EventFormScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/events/:id` | EventFormScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/events/:id` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/events/:id/images` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/events/:id/images/:imageId/hero` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/events/:id/images/:imageId` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/events/:id/partners` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/events/:id/partners/:cpId` | EventDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/tickets` | TicketsListScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/events/:id/tickets` | EventTicketsScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/events/:id/tickets` | (event detail) | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/events/:id/tickets/:ticketId` | TicketsListScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/events/:id/tickets/:ticketId/refund` | TicketsListScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/images` | ImageCatalogScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/images/:imageId` | ImageCatalogScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/customers` | CustomersListScreen | ❌ stub | B3 | ✅ API exists, React not built |
| `GET /admin/customers/:id` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built (includes media list embedded) |
| `POST /admin/customers` | CustomerFormScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/customers/:id` | CustomerFormScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/customers/:id` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/customers/:id/contacts` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/customers/:id/contacts` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/customers/:id/contacts/:contactId` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/customers/:id/contacts/:contactId` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/customers/:id/media` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/customers/:id/media/:mediaId` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/products` | ProductCatalogScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/products` | ProductFormScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/products/:id` | ProductFormScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/products/:id` | ProductCatalogScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/customers/:id/products` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/customers/:id/products` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/customers/:id/products/:cpId` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/customers/:id/products/:cpId` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/customers/:id/discounts` | DiscountsScreen | ❌ | B3 | ✅ API exists, React not built |
| `POST /admin/customers/:id/discounts` | DiscountsScreen | ❌ | B3 | ✅ API exists, React not built |
| `PATCH /admin/customers/:id/discounts/:discountId` | DiscountsScreen | ❌ | B3 | ✅ API exists, React not built |
| `DELETE /admin/customers/:id/discounts/:discountId` | DiscountsScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/customers/:id/redemptions` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |
| `GET /admin/discounts/:id/redemptions` | CustomerDetailScreen | ❌ | B3 | ✅ API exists, React not built |

**No orphaned endpoints** — every existing admin API endpoint is covered by either Flutter or B3 spec.

### API Gaps (specced in prompts but NOT yet in backend)

| Missing Endpoint | Needed By | Specced In | Notes |
|-----------------|-----------|------------|-------|
| `GET /admin/posh-orders` | Posh Orders page | B3 | **posh_orders table exists; no read endpoint at all** — biggest gap |
| `GET /admin/audit-log` | Admin Audit Log screen | B3 | audit_log table exists; no admin read endpoint |
| `GET /admin/admin-users` + CRUD | Admin Users screen | B3 | admin_users table exists; no admin CRUD endpoint |
| `GET /admin/events/:id/checkins/stream` (SSE) | Event Ops screen | B2, C1 | New endpoint — real-time check-in stream |
| `PATCH /admin/events/:id/tickets/:ticketId/wristband` | Event Ops screen | B2, C1 | New endpoint — wristband confirmation |
| `POST /users/me/photo` | Social app profile photo | A-track | Social app gap, not admin |

### `GET /admin/customers/:id/media` — CLARIFICATION NEEDED
CLAUDE.md lists this as a separate endpoint. **It does NOT exist as a standalone route** in admin.ts. Media records are embedded in the response of `GET /admin/customers/:id`. CLAUDE.md table is incorrect on this point — see Section 6.

---

## Section 4: Workflow Inventory

Every end-to-end admin workflow — current coverage status.

| Workflow | Flutter | React B0 | React Specced | API Complete |
|----------|---------|----------|---------------|--------------|
| Admin Login + Session Restore | ✅ | ✅ | B1 (RBAC + roles) | ✅ |
| Event Lifecycle (create → publish) | ✅ | ⚠️ stub | B3 | ✅ |
| Event Image Management (upload + hero) | ✅ | ❌ | B3 | ✅ |
| Event Partner Management | ✅ | ❌ | B3 | ✅ |
| Event Status Transitions (draft→published→completed) | ✅ | ❌ | B3 | ✅ (publish gate enforced) |
| Event Check-In Night (live stream + wristbands) | ❌ | ⚠️ stub | B2 | ❌ (SSE + wristband endpoints missing) |
| User Management (list/search/detail/ban/verify) | ✅ | ⚠️ stub | B3 | ✅ |
| Add User | ✅ | ❌ | B3 | ✅ |
| Customer CRM (create/edit/detail) | ✅ | ⚠️ stub | B3 | ✅ |
| Customer Contacts CRUD | ✅ | ❌ | B3 | ✅ |
| Customer Media Upload | ✅ | ❌ | B3 | ✅ (POST + DELETE only; GET embedded in customer detail) |
| Customer Products (purchase tracking) | ✅ | ❌ | B3 | ✅ |
| Customer Discounts CRUD | ✅ | ❌ | B3 | ✅ |
| Discount Redemption Analytics | ✅ | ❌ | B3 | ✅ |
| Product Catalog Management | ✅ | ❌ | B3 | ✅ |
| Ticket Management (global + per-event) | ✅ | ❌ | B3 | ✅ |
| Ticket Refund | ✅ | ❌ | B3 | ✅ |
| Image Catalog (all images, bulk delete) | ✅ | ❌ | B3 | ✅ |
| Markets Management (create/edit/activate) | ✅ | ❌ | B3 | ✅ |
| Post Moderation (review + delete) | ⚠️ stub | ⚠️ stub | B3 (manual), D0 (LLM) | ❌ (moderation_status columns not added yet — Phase 0 schema) |
| Announcements Create/Manage | ⚠️ stub | ⚠️ stub | B3 | ❌ (no announcements endpoint exists) |
| Posh Orders View + Reconciliation | ❌ | ⚠️ stub | B3 | ❌ (no read endpoint exists) |
| Audit Log View | ❌ | ❌ | B3 | ❌ (no read endpoint; audit_log table exists) |
| Admin Users CRUD | ❌ | ❌ | B3 | ❌ (no /admin/admin-users endpoint) |
| RBAC Role-Gated Navigation | ❌ (no roles in Flutter) | ✅ permissions.ts | B1 | ❌ (moderator/eventOps enum values not in schema yet — C0 required) |
| Analytics Dashboard (influence, event reports) | ❌ | ⚠️ stub | D1/D2 | ❌ (no analytics endpoints beyond dashboard stats) |
| LLM Moderation Pipeline | ❌ | ❌ | D0 | ❌ |
| Jobs Board Admin | ❌ | ⚠️ stub | E-track | ❌ (jobs table doesn't exist yet) |
| Platform Config Management | ❌ | ❌ | B3/C4 | ❌ (platform_config table not created yet — C0 required) |

---

## Section 5: Intentional Divergence Candidates

Places where React admin spec diverges from Flutter. Flagged as intentional or accidental.

| Divergence | Flutter | React (B0/spec) | Verdict | Notes |
|------------|---------|-----------------|---------|-------|
| **Tickets nav placement** | Top-level nav item | Not in B0 nav at all; B3 specs it under Events | ⚠️ **Accidental omission** — B0 built nav from NAV_PERMISSIONS which doesn't include a tickets route. B3 scope adds ticket screens but the nav item was never added to B0's Sidebar.tsx or permissions.ts. Product decision needed: top-level or under Events sub-nav. |
| **Images nav placement** | Top-level nav item (`/images`) | Not in B0 nav; B3 specs image catalog under Events context | ⚠️ **Accidental omission** — same as Tickets. Needs product decision. |
| **Products nav placement** | Top-level under REVENUE section | Collapsed under Customers per §5.3 | ✅ **Intentional per master_plan §5.3.** Products are always contextual to a customer. No standalone products nav item needed. Confirm with Jeff. |
| **Markets nav placement** | Explicit nav item under SETTINGS | §5.3 Settings section omits Markets entirely | ⚠️ **Ambiguous** — §5.3 looks like a staleness omission (see Section 6). B3 explicitly specs a Markets screen at `/markets`. Need product decision: standalone nav item or under Settings sub-page? |
| **Moderation split** | Posts + Announcements = 2 separate nav items | Single "Moderation" nav item | ✅ **Intentional consolidation** per §5.3. Cleaner UX. |
| **Event Ops (new)** | Not built | New primary nav item [eventOps, platformAdmin] | ✅ **Intentional new** feature. B2 specced. No Flutter equiv expected. |
| **Jobs (new)** | Not built | New nav item [moderator, platformAdmin] | ✅ **Intentional new** feature. E-track specced. |
| **Posh Orders (new)** | Not built | New nav item [eventOps, platformAdmin] | ✅ **Intentional new** feature. B3 specced. Blocked by missing API. |
| **Analytics (new)** | Not built | New nav item [platformAdmin] | ✅ **Intentional new** feature. D1/D2 specced. |
| **Admin Users management** | Not built | B3 specced as new screen | ✅ **Intentional new** feature. Explicit gap in Flutter (missing from §3.2). |
| **Audit Log viewer** | Not built | B3 specced as new screen | ✅ **Intentional new** feature. Explicit gap in Flutter. |
| **eventOps nav item count** | N/A | permissions.ts: eventOps sees `/`, `/event-ops`, `/events`, `/posh-orders` = 4 items | ✅ **Consistent** — permissions.ts and §5.3 both agree. B0 claude-completion.md flagged this as a deviation (2 vs 4) but the actual code is correct. Non-issue. |

---

## Section 6: Doc Staleness Flags

Documents in `docs/` that appear outdated relative to current implementation — candidates for archiving or correction in X2-C.

| Doc | Stale Section | What's Wrong | Suggested Action |
|----|--------------|--------------|-----------------|
| `docs/product/master_plan_v2.md` §5.3 | Settings nav block | Lists: "Audit Log, Platform Config, API Key Status" — **Markets is missing** despite being a fully implemented feature in Flutter and specced in B3 | Correct §5.3 or note it as a product decision (is Markets under Settings or standalone?) |
| `docs/product/master_plan_v2.md` §3.2 | Admin App Gaps table | References "Sponsor/vendor" workflow with `PATCH /admin/sponsors/:id` and `PATCH /admin/vendors/:id` as missing. **These routes were replaced by the unified Customer model.** No sponsors/vendors tables exist. | Update §3.2 to reference Customer model; remove stale sponsor/vendor endpoint references |
| `docs/product/master_plan_v2.md` §3.3 | Backend API Gaps | Lists `PATCH /admin/sponsors/:id`, `PATCH /admin/vendors/:id`, `GET/POST /admin/sponsors/:id/discounts` as missing. **These architecturally no longer exist — superseded by customers model.** | Remove these rows; replace with still-valid gaps (posh-orders read, audit-log read, admin-users CRUD) |
| `CLAUDE.md` Admin API table | `/admin/customers/:id/media` row | Lists `GET /admin/customers/:id/media` as a standalone endpoint. **It does not exist.** Media is embedded in `GET /admin/customers/:id` response. | Remove the GET row; note that media list is returned in customer detail |
| `docs/analysis/implementation_audit.md` | Entire document | Written before the customer unification (uses sponsor/vendor terminology throughout); predates tickets API, contacts API, media API, markets API additions | Archive to `docs/archive/`; superseded by master_plan_v2.md §1 and §3 |
| `docs/product/implementation_plan.md` | All | Pre-dates master_plan_v2.md; earlier schema of the same information. master_plan_v2 is now the authoritative planning doc. | Archive to `docs/archive/`; or confirm superseded status with Jeff |
| All B, C, D, E, A track prompt specs | `## Completion Report` sections | 20+ prompt spec files contain empty `## Completion Report` sections that should not be in spec files (per updated protocol; agents write completions to `log/` dir) | Remove these sections in X2-C cleanup pass |
| `docs/codex/track-B/B1-auth-rbac-permissions.md` | Context section | States "B0 scaffold: `packages/react-admin/` with empty auth shell but no real token management" — post-B0 execution, B0 claude winner has real auth in worktree. Not "in the main repo" but the statement is pre-execution context | Minor — spec was written before B0 execution, describing the start state. Acceptable as-is; no action needed unless confusing to agents. |

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Flutter admin screens | 21 (18 real API, 2 stubs, 1 static) |
| React admin pages (B0) | 11 (2 real, 9 ComingSoon) |
| React admin sub-routes missing entirely | 16 |
| Admin API endpoints implemented | 49 |
| Admin API gaps (specced, not built) | 6 |
| API orphans (built, no UI coverage) | 0 |
| Intentional divergences | 9 |
| Accidental divergences (product decision needed) | 3 (Tickets nav, Images nav, Markets nav) |
| Doc staleness flags | 7 |

## Product Decisions Required (for Jeff review)

Before X2-A2 can produce the Master Plan v3, three nav decisions need Jeff's input:

1. **Tickets nav item** — Top-level nav item (Flutter parity) OR nested under Events as a sub-section only? B3 spec currently implies sub-section but B0 nav omits it entirely.

2. **Images nav item** — Top-level `/images` (Flutter parity) OR accessible only from event detail / no standalone nav? B3 spec implies event context, but Flutter users are accustomed to the global image catalog as a first-class screen.

3. **Markets nav item** — Standalone nav item (probably under Settings) OR sub-page within Settings page? Currently missing from both B0 nav and §5.3.

All other divergences are either clearly intentional (Jobs, Posh Orders, Analytics, Event Ops, Product placement) or clearly accidental with an obvious fix (removing stale sponsor/vendor references).
