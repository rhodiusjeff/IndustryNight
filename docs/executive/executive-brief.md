# Industry Night -- Executive Brief

**Report Date:** March 2, 2026
**Period:** Project Inception through Week 3
**Branch:** `feature/admin-event-management` (active development)

---

## 1. What Is Industry Night?

Industry Night is an **event-first, proximity-verified social network** for creative professionals (hair stylists, makeup artists, photographers, videographers, models, nail/lash technicians) in NYC to discover networking events and build professional community.

**Two products, one backend:**

| Product | Target User | Platform | Purpose |
|---------|------------|----------|---------|
| **Social App** | Creative professionals | iOS, Android, Web | Attend events, QR networking, community feed |
| **Admin App** | Platform operators | Web, iOS, Android | Manage events, users, tickets, sponsors, moderation |

**Revenue model:** Ticket sales (currently via Posh.vip), sponsor partnerships (3-tier model: logo placement, audience access, data partnerships), and verified-user perks/discounts.

**Key differentiator:** Every connection proves physical co-presence via QR scan at events. This is qualitatively different from any digital-only social network.

---

## 2. Project Timeline

| Date | Milestone |
|------|-----------|
| Feb 4, 2026 | Product requirements finalized (v1.8) |
| Feb 13, 2026 | Initial commit -- project scaffolded |
| Feb 23, 2026 | Infrastructure laydown, domain migration, ops tooling |
| Feb 25, 2026 | PR #1 merged -- foundation complete, admin auth working |
| Mar 1, 2026 | Full stack working: QR connections, tickets, check-in, adversarial review |

**Elapsed:** 18 days from first commit to full-stack working platform.

---

## 3. What Has Been Built

### Backend API (Node.js / Express / TypeScript)
- **11 route modules** covering auth, users, events, connections, posts, sponsors, vendors, discounts, webhooks, admin, and admin-auth
- **4 middleware layers** -- JWT auth, admin auth (token family separation), role-based access, Zod validation
- **3 service integrations** -- Twilio SMS/Verify, AWS SES email, Posh.vip webhooks
- **JWT dual-auth system** -- separate `social` and `admin` token families preventing cross-app token reuse
- **S3 image upload** -- event images with public CDN URLs, hero image system
- **Token auto-refresh** -- 15-minute access tokens with automatic refresh

### Database (PostgreSQL 15 on AWS RDS)
- **22 tables** across 4 migrations
- Core: users, admin_users, events, tickets, posh_orders
- Social: connections, posts, comments, likes
- Business: sponsors, vendors, discounts, event_sponsors
- Media: event_images (up to 5 per event, hero image system)
- Operations: audit log, analytics tables, GDPR export tracking
- CASCADE delete design with audit log preservation (SET NULL)

### Social App (Flutter/Dart -- iOS, Android, Web)
- **19+ screens** across 8 feature modules
- Auth: phone entry, SMS verify with devCode auto-fill, remember-me login
- Events: browsing, detail view, ticket status, activation code entry
- Networking: QR code display, QR scanner, instant connections, celebration overlay, real-time polling notifications
- Community: feed, create post, post detail (UI built, API wiring pending)
- Search: user discovery, profile viewing (UI built, API wiring pending)
- Profile: view, edit, settings
- Perks: sponsor discounts, sponsor detail (UI built, API wiring pending)

### Admin App (Flutter/Dart -- Web, iOS, Android)
- **16+ screens** across 7 feature modules
- Auth: email/password admin login
- Dashboard: stats overview
- Users: list, detail, add user, manage tickets
- Events: full lifecycle with image management, publish gate, sponsor linking
- Sponsors: management + discount management
- Vendors: list + form
- Moderation: posts list, announcements (screens built)

### Shared Package (Flutter/Dart)
- **9 data models** with JSON serialization (auto-generated)
- **7 API clients** -- base HTTP client + auth, users, events, connections, posts, admin, admin-auth
- Utilities: secure storage, validators, formatters, constants

### Infrastructure & Operations
- **AWS EKS cluster** on us-east-1 with auto-scaling (2-10 pods)
- **Kubernetes manifests** -- deployment, service, ingress, secrets, HPA
- **SSL/TLS** via ACM on `api.industrynight.net`
- **ECR** container registry with Docker build pipeline
- **S3** image storage with public-read ACL
- **COOP system** -- infrastructure lifecycle scripts (teardown to ~$3/mo, rebuild from scratch, database backup/restore)
- **CI/CD workflows** -- GitHub Actions for API, mobile, and web

---

## 4. Key Strategic Decisions (from Adversarial Review)

| Question | Decision | Rationale |
|----------|----------|-----------|
| Invite-only or open registration? | **Open registration** | Events list is marketing funnel; verification ladder is the real gate |
| Posh webhook creates users? | **No -- auto-link by phone** | Users create own accounts; Posh orders reconciled on registration |
| Verification feature gating? | **Yes -- backend required** | `requireVerified` middleware gates community board, perks |
| Who's Going / Who's Here? | **Build behind feature flag** | Product owner decides visibility |
| Server-side connection validation? | **Defer** | Low risk at current scale; client-side gate sufficient |
| Activation code time window? | **Event lifecycle IS the gate** | No `code_valid_start/end` columns needed |
| Market area filtering? | **Add to events + users** | `market_area` enum; default to user's home market |
| Sponsor/vendor/perks model? | **Deferred to product owner** | Current CRUD adequate for MVP |

---

## 5. MVP Scorecard

**33 requirements items:** 13 done / 5 partial-adequate / 5 not done / 2 deferred (feature flag) / 2 deferred (product owner) / 2 retired / 4 not done (tracked)

**~55% done or adequate, ~85% resolved or tracked**

30 GitHub issues created for tracking all remaining work.

### Key Remaining Gaps

| # | Item | Priority |
|---|------|----------|
| #18 | Wire community feed to API | P0 -- highest retention impact |
| New | Push notifications | P0 -- no way to pull users back between events |
| #14 | Verification-based feature gating | P1 -- gates community + perks |
| #12-13 | Posh phone normalization + auto-link | P1 -- walk-in ticket flow |
| New | Discount redemption tracking | P1 -- enables Tier 2 sponsor revenue |
| New | Connection-only DMs | P1 -- biggest functional gap |
| #20 | Pre-MVP security review | Required before launch |

---

## 6. Sponsor Revenue Strategy (3-Tier Model)

| Tier | Offering | Price Range | Status |
|------|----------|-------------|--------|
| **1** | Logo placement on event pages | $500-2K/event | Working today |
| **2** | Verified audience access + redemption tracking | $2-5K/event | Requires verification gating + redemption tracking |
| **3** | Ongoing audience intelligence & data partnership | $5-20K/quarter | Requires analytics computation + reporting |

**Key insight:** IN's data asset is that every connection proves physical co-presence. Combined with specialty data, this enables audience intelligence that commands 5-10x premium over generic event sponsorship.

**Most important missing piece:** Discount redemption tracking. Without it, we can't prove sponsor ROI.

---

## 7. What's Next

### Phase A: Engagement (make the app worth opening between events)
1. Wire community feed (#18)
2. Push notifications (new)
3. Verification gating (#14)

### Phase B: Professional Utility
4. Connection-only DMs
5. Profile portfolios
6. Creative search UI

### Phase C: Sponsor Revenue Engine
7. Redemption tracking
8. Analytics computation
9. Sponsor reports

### Phase D: Growth
10. Market area expansion
11. Mutual connections
12. External sharing

---

## 8. Known Technical Debt

| Item | Impact | Priority |
|------|--------|----------|
| SQL injection in posts.ts | Security vulnerability | High (pre-launch) |
| No API tests (Jest configured but empty) | Risk of regressions | High |
| Post author data shape mismatch | Blocks feed wiring | High (pre-feed) |
| Token refresh 500 error | Users logged out after 15 min | Fixed |
| No DB connectivity check in /health | Silent failures | Medium |
| No pre-deploy migration runner in CI/CD | Manual step | Medium |

---

## 9. AWS Cost Profile

| State | Monthly Cost | Description |
|-------|-------------|-------------|
| **Full running** | ~$160/mo | EKS cluster + RDS + networking |
| **Hibernated** (COOP teardown) | ~$3/mo | S3 backups + Route53 only |

COOP scripts enable full teardown and rebuild, preserving all data via `pg_dump` backups.

---

## Appendix: How to Regenerate This Brief

### Markdown version
This document lives at `docs/executive/executive-brief.md`. Update sections manually.

### Slide deck versions
```bash
# Set up environment (first time only)
python3 -m venv /tmp/pptx-env && /tmp/pptx-env/bin/python -m ensurepip --upgrade
/tmp/pptx-env/bin/pip install python-pptx

# Generate Executive Brief (14 slides, detailed)
/tmp/pptx-env/bin/python scripts/generate-exec-brief.py

# Generate Executive Summary (5 slides, non-technical)
/tmp/pptx-env/bin/python scripts/generate-exec-summary.py
```

### PDF versions
```bash
pandoc docs/analysis/social_network_analysis.md \
  -o "docs/executive/Social Network Analysis - Industry Night.pdf" \
  --pdf-engine=xelatex --toc --toc-depth=3 \
  -V geometry:"margin=1in" -V fontsize=11pt \
  -V mainfont="Helvetica Neue" -V monofont="Menlo" \
  -V colorlinks=true -V linkcolor=NavyBlue -V urlcolor=NavyBlue \
  -H docs/.pdf-header.tex
```

**Suggested cadence:** Weekly, at end of each development sprint.
