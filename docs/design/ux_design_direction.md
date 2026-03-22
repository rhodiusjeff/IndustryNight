# Industry Night — UX Design Direction

**Version:** 1.0
**Date:** March 2026
**Scope:** Admin App (React migration) + Social Web experience (new)

---

## Overview

This document captures the design research foundation for Industry Night's React-based admin app and social web experience. It synthesizes ~30 platform analyses across three categories: event/nightlife apps, admin dashboards, and creative industry networks.

The core design philosophy: **the platform recedes, the people and events are the experience.** Dark creative aesthetic for social. Calm precision for admin. Social proof everywhere.

---

## Must-Visit Reference URLs

These aren't just inspiration boards — visit them in a browser and feel the interactions.

### Event & Nightlife (Social Experience)

| Platform | URL | What to Study |
|----------|-----|---------------|
| **DICE.fm** | https://dice.fm | Dark mode, imagery-first cards, event detail pages. This is the spiritual ancestor. |
| **Resident Advisor** | https://ra.co | Typography scale, community depth, black bg + red accent. Click into an event. |
| **Partiful** | https://partiful.com | Social proof — the RSVP list IS the marketing. Phone auth flow. |
| **Shotgun** | https://shotgun.live | Purple-on-dark color palette. Friend tracking on event pages. |
| **Sofar Sounds** | https://www.sofarsounds.com | Near-black (#121212) with white 1px borders. Gallery-like intimacy. |
| **Luma** | https://lu.ma | Gradient heroes, backdrop-blur nav, clean event cards. Tech but stylish. |
| **Fever** | https://feverup.com | Spacing discipline and multi-accent color palette. Best-in-class grid. |

### Admin Dashboards

| Platform | URL | What to Study |
|----------|-----|---------------|
| **Linear** | https://linear.app | The gold standard. If you only visit one, this is it. Sidebar, Cmd+K, calm design. |
| **Stripe Dashboard** | https://dashboard.stripe.com | Progressive disclosure on data, semantic color usage, table design. |
| **Vercel** | https://vercel.com/dashboard | Sidebar navigation, project card layouts, status indicators. |
| **Clerk Dashboard** | https://dashboard.clerk.com | User management UI — directly analogous to IN's admin/users section. |
| **Shopify Polaris** | https://polaris.shopify.com | Design system docs. Token naming, component library, spacing scale. |
| **Neon** | https://neon.tech | Modern dark dashboard aesthetic for reference. |

### Creative Industry & Networking

| Platform | URL | What to Study |
|----------|-----|---------------|
| **Read.cv** | https://read.cv | Minimal profile design. Less is more. Let the work speak. |
| **The Dots** | https://the-dots.com | Creative professional networking. Closest analog to IN's social graph. |
| **Polywork** | https://polywork.com | Multihyphenate identity badges (maps to IN's specialty system). |
| **Creatively** | https://creatively.com | Entertainment industry network. Collaboration credits. |
| **Bento.me** | https://bento.me | Bento grid profile layouts. Size encodes importance. |
| **Behance** | https://behance.net | Gallery-first creative feed. How work is showcased. |
| **Dribbble** | https://dribbble.com | Community feed for creative professionals. Discovery patterns. |
| **StyleSeat** | https://www.styleseat.com | Beauty professional profiles — gallery as the primary content. |

---

## Part 1: Event & Nightlife Platform Analysis

### DICE.fm — The Spiritual Ancestor ★★★★★

DICE is what IN's social app should feel like when you grow up.

- **Background:** Pure dark mode, near-black UI that recedes completely
- **Color approach:** Interface is almost monochromatic — the event photography provides all the color. Vivid, full-bleed images on cards. No competing with the content.
- **Typography:** Clean, modern sans-serif. Headlines are large, bold, confident.
- **Layout:** Card grid for discovery, full-bleed hero on detail pages, social graph woven through everything (friends attending, artist following, venue tracking)
- **Social features:** Deepest in the space — Spotify sync, friend tracking on events, ticket transfer, artist/venue follows
- **Key lesson:** The platform disappears. Events and people are the experience.

### Resident Advisor (ra.co) — Community Depth ★★★★★

Proves a niche creative community can sustain deep engagement for 20+ years.

- **Background:** True black (#000)
- **Accent:** Red (#FF4848) — bold, editorial, unapologetic
- **Typography:** Brutalist display fonts (AlternateGothicPro) at up to 120px. Aggressive hierarchy. Makes a statement.
- **Community layers:** Events → editorial content → DJ charts → venue profiles → artist profiles → reviews. Not just a ticket shop.
- **Key lesson:** Editorial content and community features justify the platform beyond transactional event discovery. IN's community feed is this layer.

### Partiful — Social Proof Mastery ★★★★★

Best UX for making events feel social and alive before they happen.

- **Auth:** Phone-based (validates IN's approach)
- **Standout:** The RSVP list IS the marketing. You see exactly who's going. Friends attending = FOMO = conversion.
- **Pre-event comments:** People talking before the event builds anticipation
- **Typography:** Custom "Partiful Display" typeface — distinctive brand identity
- **Key lesson:** Show the people, not just the event. Social proof belongs on every event card.

### Shotgun — Color Reference ★★★★

- **Color:** Purple/black/white with gradients — most directly relevant palette for IN
- **Community:** Friend tracking, ambassador rewards, music service sync
- **Purple-on-dark reads:** Premium without being corporate. Creative without being chaotic.
- **Key lesson:** This is IN's closest color reference. Deep purple + near-black + white text.

### Sofar Sounds — Intimate Aesthetic ★★★★

- **Background:** Near-black (#121212) — not pure black, more sophisticated
- **Borders:** Distinctive white 1px borders on all containers — creates gallery-like separation
- **Fonts:** Geist + Inter pairing
- **Key lesson:** #121212 background + 1px `rgba(255,255,255,0.08)` borders = premium feel without harsh contrast.

### Luma — Modern Web Events ★★★★

- **Hero treatment:** Dramatic multi-color gradients (cyan → purple → orange) — striking hero sections
- **Navigation:** Backdrop-blur nav bar — glassmorphism done right
- **Layout:** Asymmetric, confident, tech-forward
- **Weakness:** Reads "YC startup" more than "creative nightlife." Needs tuning for IN's audience.
- **Key lesson:** Gradient heroes and backdrop-blur are premium signals. Use for event hero images.

### Fever — Spacing Discipline ★★★

- **Spacing:** Best-in-class 8px grid system, ruthlessly consistent
- **Color:** Navy/teal dark mode with multi-accent palette (blue, pink, gold, green)
- **Weakness:** Algorithm-driven and impersonal. Feels like you're shopping, not discovering.
- **Key lesson:** Disciplined spacing makes everything feel polished. 8px grid minimum.

### Posh.vip — The Low Bar ⚠️

**What's broken:**
- Three conflicting typefaces (Inconsolata + Cormorant + Inter) — no visual hierarchy
- Workflows are "overdesigned yet under-functioning" — beautiful surfaces, frustrating flows
- Zero social features — no community, no profiles, no networking
- Inconsistent visual language across screens

**Key lesson:** Looking sleek is not enough. IN needs functional social mechanics that Posh completely lacks.

### Eventbrite — Corporate Anti-Pattern ⚠️

- Light-only, warm brown/earth tones, corporate-professional
- Great information architecture but zero personality
- **Key lesson:** Don't build "Eventbrite with dark mode." The personality must come through in every interaction.

---

## Part 2: Admin Dashboard Analysis

### Linear — The Gold Standard ★★★★★

Study this obsessively. Every pixel is intentional.

- **Color system:** LCH color space, 3-input theme (base, accent, contrast). Warm grays, not cool grays.
- **Sidebar:** Dimmed/muted when not active — recedes to let the content workspace dominate
- **Navigation:** Cmd+K command palette — every action is reachable without a mouse
- **Philosophy:** "Calm design" — no decoration exists without purpose
- **Transitions:** 150-200ms, eased. Fast enough to feel snappy, slow enough to feel smooth.
- **Spacing:** 4px grid, religiously consistent
- **Application to IN admin:** Sidebar hierarchy → Platform → Events / Customers / Users / Products → Detail views. Every table, form, and drawer follows Linear's density and spacing.

### Stripe Dashboard — Data Excellence ★★★★★

The model for making complex financial/operational data approachable.

- **Progressive disclosure:** Show summary, click to expand detail. Never overwhelm.
- **Semantic color:** Red ONLY for things needing immediate action. Green ONLY for confirmed success. Never decorative.
- **Spacing:** 2/4/8/16/24/32/48px scale
- **Performance:** Cards render under 100ms — data loading feels instant
- **Application to IN admin:** Customer detail pages, event revenue summaries, ticket stats should follow Stripe's card → expand → detail pattern.

### Shopify Polaris — Design System Bible ★★★★★

The most concrete, well-documented design token system for admin apps.

- **Tokens:** Full semantic naming (`--p-color-bg-surface`, `--p-space-400`, etc.)
- **Typography:** Inter, 1.2x major third scale
- **Spacing:** 4px base: `0 / 2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64 / 96 / 128`
- **Components:** 60+ production-ready with accessibility baked in
- **Application to IN admin:** When building the React component library, use Polaris as the structural reference for token naming and component API design. Don't fork it — reference the patterns.

### Clerk Dashboard — User Management Reference ★★★★

Directly analogous to IN's admin/users section.

- **OKLCH color space** with 11 shade variants per color — gives smooth gradations for hover/active states
- **State completeness:** Loading skeleton, error state, empty state with personality — every screen, every time
- **Application to IN admin:** The user list, user detail, and verification workflow screens should directly reference Clerk's UX patterns.

### Cross-Platform Admin Consensus Patterns

These patterns appear across Linear, Stripe, Shopify, Vercel, Notion, and Clerk:

| Pattern | What All the Best Do |
|---------|---------------------|
| **Sidebar** | Left, ~220-240px, collapsible, dimmed inactive items |
| **Color** | Warm grays, max 2-3 accent colors, semantic-only red/green |
| **Typography** | Inter (or Inter Display for headings), 1.2x type scale |
| **Spacing** | 4px base unit, consistent throughout |
| **Tables** | Inline edit for simple fields, side drawer for complex. Bulk select toolbar. |
| **Badges** | Rounded pills, 10-15% opacity backgrounds, semantic colors only |
| **CRUD** | Side drawers preserve context. Toast confirmation after every action. Skeleton loading. |
| **Empty states** | Personality, not just "No items found" |
| **Transitions** | 150-200ms ease — not so fast it's jarring, not so slow it feels broken |

---

## Part 3: Creative Industry & Networking Platform Analysis

### The Dots — Creative Professional Networking ★★★★★

The closest existing analog to IN's social professional layer.

- **Work-first profiles:** Portfolio cards are the lead content, not bio text
- **Skills as tags:** Multidisciplinary identity represented as badges, not a single role field
- **"Positivity algorithm":** Surfaces diverse creative talent rather than just high-engagement accounts
- **Collaboration-centric:** Projects show all contributors, not just the lead
- **Application to IN:** Feed algorithm should prioritize diverse creatives. Tag collaborators at events.

### Creatively — Entertainment Industry Network ★★★★★

The most direct competitor to what IN's social professional network aspires to be.

- **Target audience:** Exactly IN's audience — photographers, stylists, MUAs, directors, producers
- **Collaboration credits:** Tag everyone who worked on a project. Credits expand all tagged users' networks organically.
- **Gallery-first:** Portfolio grid is the profile. Work is the identity.
- **Application to IN:** Post-event, attendees should be able to tag who they worked with. "I shot with @photographer at last night's event." Both profiles grow.

### Polywork — Multihyphenate Identity ★★★★

- **Core insight:** Creative professionals are "multihyphenate" — they don't have one job title
- **Display:** Multiple professional identities as modular badges, stacked beside the name
- **Application to IN:** A hair stylist who also photographs should display both specialties as equal-weight badges. IN's specialty system should be visually prominent, not buried in a profile form.

### Read.cv — Minimal Professional Profiles ★★★★

- **Core lesson:** Clean, minimal profiles with strong typography can be MORE impactful than feature-heavy ones
- **Design:** Near-white background, one carefully chosen accent, typography does all the work
- **Application to IN social web:** Profile pages should be restraint-first. One profile photo. Name large. Specialties as badges. Work gallery below. Bio short.

### Bento.me — The Bento Grid Trend ★★★★

- **Layout:** Modular card grids where card size encodes importance
- **Data:** Eye-tracking shows users spend 2.6× longer on larger cards
- **Trend:** 67% of top product sites use bento-style layouts in 2025-2026
- **Application to IN:** Profile pages and event details should use bento grids — hero image big, secondary content smaller cards surrounding.

### StyleSeat / Fresha — Beauty Industry Standards ★★★★

- **IN's beauty industry users already use these platforms** — they set expectations
- **Gallery-first:** Portfolio images are the primary profile content, not an afterthought section
- **Booking-adjacent:** Clean, minimal friction flows for the service transaction
- **Application to IN:** Don't make beauty professionals feel their profile is less capable than their StyleSeat page. Gallery display must be first-class.

### Blinq / Popl — QR Networking Validation ★★★★

- **Core lesson:** At noisy events, connection exchange must be ONE action with immediate visual confirmation
- **Celebration:** Instant animations on successful connection
- **Application to IN:** IN's existing celebration overlay is well-aligned with the industry standard. Keep it. Refine the animation timing (200ms target).

---

## Part 4: 2025-2026 Design Trends

| Trend | How It Applies to IN |
|-------|---------------------|
| **Soft dark mode** (#121212-#1b1b1b) | Near-black is premium; pure black is harsh. Use #121212 for backgrounds. |
| **Glassmorphism on dark** | Frosted glass for event cards, connection overlays, hero sections. Sparingly. |
| **Bento grid layouts** | Profile pages, event details, dashboard overview. Size = importance. |
| **Micro-interactions** | 200ms transitions, celebration overlays, card hover states. These make the difference. |
| **Gradient accents** | Purple-to-pink or purple-to-blue as accents, not backgrounds. |
| **Display + system font pairing** | One expressive display font + Inter for body. Two fonts maximum. |
| **Semantic color only** | Red = error. Green = success. Never decorative. |
| **Skeleton loading** | Content-shaped loading states everywhere. No spinners. |

---

## Part 5: IN Design System Recommendations

### Color Tokens

```css
/* Backgrounds */
--bg-primary:    #121212;          /* Main canvas — soft dark, not pure black */
--bg-surface:    #1E1E1E;          /* Cards, panels, sidebar */
--bg-elevated:   #2A2A2A;          /* Modals, dropdowns, hover */

/* Borders */
--border:        rgba(255,255,255,0.08);   /* Subtle — Sofar Sounds-inspired */
--border-strong: rgba(255,255,255,0.16);  /* Active/focused states */

/* Text */
--text-primary:    #F5F5F5;        /* Near-white, not pure white */
--text-secondary:  #A0A0A0;        /* Labels, timestamps, metadata */
--text-tertiary:   #606060;        /* Placeholder, disabled */

/* Brand Accents */
--accent-primary:  #7C3AED;        /* Deep purple — brand primary */
--accent-light:    #A855F7;        /* Light purple — hover, gradients */
--accent-energy:   #FF3D8E;        /* Neon pink — live, notifications, celebration */
--accent-cool:     #1B9CFC;        /* Electric blue — links, info, secondary CTA */
--accent-gold:     #F1C40F;        /* Gold — verification badges, achievements */

/* Gradients */
--gradient-brand:  linear-gradient(135deg, #7C3AED, #FF3D8E);
--gradient-cool:   linear-gradient(135deg, #7C3AED, #1B9CFC);

/* Semantic */
--success:  #10B981;
--warning:  #F59E0B;
--error:    #EF4444;
```

### Typography Scale

| Role | Font | Size | Weight | Line Height |
|------|------|------|--------|-------------|
| Display / Hero | Clash Display or Satoshi | 40-48px | 700 | 1.1 |
| H1 | Inter Display | 34px | 600 | 1.2 |
| H2 | Inter Display | 28px | 600 | 1.25 |
| H3 | Inter | 24px | 600 | 1.3 |
| H4 | Inter | 20px | 600 | 1.35 |
| Body Large | Inter | 16px | 400 | 1.6 |
| Body | Inter | 14px | 400 | 1.6 |
| Label | Inter | 13px | 500 | 1.4 |
| Caption | Inter | 12px | 400 | 1.4 |
| Mono | JetBrains Mono | 13px | 400 | 1.5 |

**Font evaluation priority:** Clash Display > Satoshi > General Sans. Render IN event cards and hero text in each before deciding.

### Spacing Scale

4px base unit — `0 / 2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64 / 96`

### Top Exemplar Per Surface

| Surface | Primary Reference | Secondary | Key Pattern |
|---------|-----------------|-----------|-------------|
| **Admin — Dashboard** | Linear | Stripe | Calm sidebar, card stats, data density |
| **Admin — Events** | Shopify Admin | Notion | CRUD drawers, image management, status gates |
| **Admin — Customers/CRM** | Stripe | HubSpot | Progressive disclosure, tabbed detail, relationship cards |
| **Admin — Users** | Clerk | Linear | User list table, status badges, ban/verify actions |
| **Social Web — Event Discovery** | DICE.fm | Resident Advisor | Dark cards, imagery-first, friend presence |
| **Social Web — Event Detail** | Partiful | Luma | Social proof (who's going), gradient hero, pre-event engagement |
| **Social Web — Profile** | Read.cv | The Dots | Minimal, work gallery, specialty badges |
| **Social Web — Community Feed** | Behance | Dribbble | Gallery grid, creative work, collaboration credits |
| **Social Web — Networking** | Blinq/Popl | Polywork | QR celebration, connection card, modular identity |
| **Social Web — Perks** | Fever | Shotgun | Sponsor discovery cards, redemption tracking |

---

## Part 6: Anti-Patterns to Avoid

1. **Posh's font soup** — One display font + Inter for body. Two fonts, full stop.
2. **Eventbrite's corporate blandness** — This is a creative industry app. The design itself must feel creative.
3. **Feature-heavy profiles** — Read.cv proves restraint is more powerful than completeness. Show work, not fields.
4. **Light-only mode** — Dark mode is table stakes for nightlife/creative audiences. Build dark-first.
5. **Generic admin templates** — The admin app should feel as intentional as Linear. Not Bootstrap.
6. **Gratuitous glassmorphism** — Reserve for 1-2 key surfaces: event hero, connection overlay. Nowhere else.
7. **Pure black (#000000) backgrounds** — Near-black (#121212) is warmer and more sophisticated.
8. **Decorative use of semantic colors** — Red is only for errors. Green is only for success. Period.
9. **Spinners** — Skeleton loading states only. Content-shaped placeholders.
10. **Navigating away for CRUD** — Admin CRUD uses side drawers that preserve list context.

---

## IN's Unique Design Position

No competitor combines all of these in a single platform:

1. **Dark creative aesthetic** (DICE/RA sensibility) + **real-time QR networking** (Blinq/Popl flow)
2. **Community feed** (Behance creative showcase) + **business integration** (sponsor perks, vendor space)
3. **Multihyphenate professional identity** (Polywork specialty system) + **full event lifecycle** (discovery → check-in → networking → post-event community)
4. **Admin CRM** (Linear-quality dashboard) that directly powers the social experience

This combination is IN's defensible design territory.
