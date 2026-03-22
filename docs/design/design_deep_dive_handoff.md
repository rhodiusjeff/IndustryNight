# Design Deep Dive — Context Handoff

**Created:** March 2026
**Purpose:** Structured handoff for a future design session to translate direction into implementation
**Prereq:** Read `docs/design/ux_design_direction.md` first

---

## What Has Been Decided

The following design decisions are made and should be treated as constraints, not options:

1. **Dark-first** — `#121212` background. No light mode in v1.
2. **Purple brand** — `#7C3AED` → `#A855F7` spectrum. Purple-to-pink gradient for premium moments.
3. **Two fonts maximum** — One display font (to be selected) + Inter for everything else.
4. **4px spacing grid** — Non-negotiable. All spacing is a multiple of 4.
5. **Semantic color only** — Red = error. Green = success. Never decorative.
6. **Side drawers for CRUD** — Admin never navigates away from a list to create/edit. Context preserved.
7. **Skeleton loading** — No spinners anywhere.

---

## What Still Needs to Be Decided

### 1. Display Font Selection (High Priority)

**Candidates:**
- **Clash Display** — Geometric, high-contrast, feels premium/editorial. Strong at large sizes.
- **Satoshi** — Slightly warmer than Inter, still modern. Works at all sizes, not just display.
- **General Sans** — Clean, versatile, approachable. Less personality than Clash.

**Decision process:**
1. Render IN's event card in each font at 32px and 48px
2. Render a user profile headline in each
3. Render the admin dashboard sidebar section headings
4. Pick the one that feels most like "a creative industry platform you'd trust with your career"

**Resources:**
- Clash Display: https://www.fontshare.com/fonts/clash-display (free)
- Satoshi: https://www.fontshare.com/fonts/satoshi (free)
- General Sans: https://www.fontshare.com/fonts/general-sans (free)
- Fontshare hosts all three; no licensing issues for commercial use

---

### 2. React Framework & Component Library Strategy (High Priority)

**Context:** The Flutter admin app is being migrated to React. The social web experience is being built new.

**Key question:** Build on a component library base (shadcn/ui, Radix UI, Mantine) or fully custom?

**Recommendation to validate:**
- **shadcn/ui + Tailwind** is the current community standard for exactly this type of app. It gives you Radix primitives (accessibility, behavior) with full visual control (no opinionated styles to fight). Linear, Vercel, and most modern SaaS dashboards use this stack or something equivalent.
- The color tokens and spacing scale in `ux_design_direction.md` map directly to Tailwind CSS variables.

**Decision checklist:**
- [ ] Does the React project already have a framework choice? Check with project owner.
- [ ] If starting fresh: `shadcn/ui` + `tailwindcss` + `@radix-ui/themes` base
- [ ] Design tokens → `tailwind.config.js` custom colors and spacing

---

### 3. Admin Navigation Architecture (Medium Priority)

**Context:** Current Flutter admin has a left sidebar with sections: Dashboard, Users, Events, Customers, Products, Moderation, Settings.

**Decisions needed:**
- Fixed 240px sidebar or collapsible (chevron toggle)?
- Top bar for global actions (search, notifications, admin avatar) or integrated into sidebar?
- Command palette (Cmd+K) for power users? Linear-inspired.
- Breadcrumbs on detail pages?

**Recommendation:** Collapsible sidebar (default open, icon-only collapsed state). Top bar for global actions. Cmd+K as a stretch goal for v2.

---

### 4. Social Web Navigation Architecture (Medium Priority)

**Context:** Social app currently has bottom tab navigation (mobile-first). Web experience needs a different primary nav pattern.

**Decisions needed:**
- Top horizontal nav or left sidebar for web?
- Sticky header or scroll-away?
- Mobile web: bottom bar persists or collapses to hamburger?

**Recommendation:** Sticky top nav on web with avatar + search. Mobile web gets bottom bar matching the native app. No hamburger menus.

---

### 5. Motion & Animation Language (Lower Priority, High Impact)

**Context:** IN has an existing celebration overlay for QR connections. Need consistent motion language across the whole product.

**Decisions needed:**
- Transition duration standard (recommendation: 150ms for micro, 200ms for layout, 350ms for page)
- Easing curve (recommendation: `cubic-bezier(0.16, 1, 0.3, 1)` — "spring-like" ease-out)
- Celebration animations: confetti style, particles, or card flip?
- Page transitions: fade, slide, or instant?

**Resources:**
- Framer Motion (React) — standard for production animation in this stack
- `motion.dev` (Motion One) — lighter alternative

---

## Screens to Prototype First

Priority order for the initial design sprint:

### Sprint 1 — Foundation
1. **Color + typography style guide** — Render all tokens as a living style sheet
2. **Admin sidebar + shell** — The chrome everything lives inside
3. **Event list screen (admin)** — Table with status badges, hero thumbnails, action column

### Sprint 2 — Social Hero Screens
4. **Event discovery screen (social web)** — Card grid, search/filter, dark mode
5. **Event detail page (social web)** — Gradient hero, social proof (who's going), partner logos
6. **User profile (social web)** — Gallery-first, specialty badges, minimal bio

### Sprint 3 — Admin CRUD Depth
7. **Event detail (admin)** — Two-column layout, image management, partner management
8. **Customer detail (admin)** — CRM-style tabbed layout: overview, products, discounts, redemptions
9. **User detail (admin)** — Status badges, verification actions, connection history

---

## File Inventory

All relevant design files live in `docs/design/`:

| File | Purpose |
|------|---------|
| `ux_design_direction.md` | Full research report — ~30 platform analyses, design system recommendations, reference URLs |
| `design_deep_dive_handoff.md` | This file — structured handoff for implementation sprint |
| `Industry Night - UI Design Brief.pdf` | 2-page executive summary for stakeholders |

---

## Implementation Checklist (for when the React project starts)

```
Phase 0 — Design Tokens
[ ] Choose display font (Clash Display / Satoshi / General Sans)
[ ] Implement color tokens as CSS custom properties or Tailwind config
[ ] Set up 4px spacing scale in Tailwind
[ ] Set up typography scale (display, h1-h4, body, label, caption)

Phase 1 — Component Library Core
[ ] Button (primary, secondary, ghost, destructive — each with loading state)
[ ] Badge / Pill (semantic colors, with dot indicator variant)
[ ] Card (surface, elevated, with hover state)
[ ] Avatar (with fallback initials, online indicator variant)
[ ] Input / Textarea / Select (dark mode styled)
[ ] Table (with sort headers, row hover, bulk select, skeleton loading)
[ ] Side Drawer (right-side, 480px, with overlay)
[ ] Toast notifications (success, error, info — bottom-right stack)
[ ] Skeleton loading (text line, card, avatar variants)
[ ] Empty state (with icon, headline, subtext, optional CTA)

Phase 2 — Admin Layout
[ ] App shell (sidebar + top bar + content area)
[ ] Sidebar (with section groups, active state, collapsed/expanded)
[ ] Breadcrumb component
[ ] Page header (title + primary action button)

Phase 3 — Social Layout
[ ] App shell (sticky top nav + bottom mobile bar)
[ ] Event card (image, title, date, venue, attendee preview)
[ ] Profile card (avatar, name, specialties, connection count)
[ ] Community post card (author, content, gallery preview, like/comment)
[ ] Connection celebration overlay (QR success animation)
```

---

## Open Questions (for project owner)

1. **Single React repo or separate (admin + social web)?** Separate Next.js apps sharing a component library is the recommended pattern. Allows independent deployment and separate Tailwind configs.

2. **SSR requirement?** Next.js for both. Social web benefits from SSR for event detail pages (SEO, social previews). Admin can be pure SPA but Next.js handles both cleanly.

3. **Design tool?** Figma is standard. Figma's variable system maps directly to CSS custom properties — set up the token library in Figma before writing any component code.

4. **Dark-only or dark-default with light toggle?** Recommendation: dark-only for v1. Add light mode in v2 when there's real user demand. Light mode is a significant maintenance burden.

5. **Authentication flow for social web?** Phone + OTP works on mobile. For web: same flow (phone → OTP via SMS) is fine and IN already has the backend. Email magic link is the alternative if SMS friction is a concern on desktop.

---

## Key People / Context

- **Design research:** Completed March 2026. No Figma files yet — this doc + `ux_design_direction.md` are the source of truth.
- **Current Flutter apps:** Social app (iOS/Android) and Admin app (Flutter web) are live. React migration is additive — Flutter apps stay in production during React build.
- **Backend:** Node.js/Express API is React-ready. All endpoints documented in `CLAUDE.md` under "Admin API endpoints" and "Routes."

---

## Quick Reference: The ONE-SENTENCE Design Pitch

> Industry Night looks like DICE.fm decided to build LinkedIn for creative professionals, and Linear built the back office.
