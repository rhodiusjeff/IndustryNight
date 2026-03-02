# App Creative Direction – Context Handoff

## The Core Problem

This app is built for creative professionals — hair stylists, makeup artists, photographers, videographers, producers, directors, DJs, designers. These are people who live in visual culture, who judge quality by feel and aesthetics, and who will drop an app in seconds if it looks like a clone of every other event discovery app.

The standard menu-driven, card-grid, bottom-nav app pattern is necessary for structure, but the *content within* those structures needs to break the mold.

## Design Principles

### 1. Visual-First, Always
- The home screen should feel more like scrolling through a curated feed than browsing a database
- Events should lead with striking imagery — venue photos, past event shots, artist work
- Avoid walls of text; let visuals carry the discovery experience
- Think Instagram's discovery tab energy, not Yelp's listing grid

### 2. The App Should Feel Like the Scene
- Dark theme is foundational (already implemented) — this is nightlife, after all
- Motion and transitions matter: smooth page transitions, subtle animations on interactions
- Typography should be bold, modern, and confident — Inter is the base, but headlines may want more personality
- Color pops on dark backgrounds: the indigo primary is a start, but event/venue branding colors could bleed into the UI contextually

### 3. Networking Is the Core Value Prop
- The app isn't just "find events" — it's "find your people at events"
- The QR connect feature should feel instant and satisfying (haptic feedback, connection animation)
- User profiles should showcase work/portfolio, not just a bio card
- The connections list should feel alive — show recent activity, shared events, mutual connections

### 4. Not a Menu App
- The home screen should NOT be a static grid of menu tiles
- Consider a dynamic, scrollable experience that adapts to context:
  - Tonight's events surfaced prominently (time-aware)
  - "People you might know" or "Creatives near you" teasers
  - Community highlights / trending posts
  - Personalized recommendations based on specialty and past check-ins
- The five bottom tabs provide structure, but the home/events tab should be the hero

## Home Screen Concepts to Explore

### Option A: The Timeline
A vertically scrolling feed that mixes content types — upcoming events, community posts, new connections, featured creatives — all in a single stream. Think Twitter/X meets event discovery.

### Option B: The Stage
A bold, full-bleed hero card for tonight's top event, followed by horizontally scrollable sections: "This Week", "Near You", "For [Your Specialty]", "Trending Creatives". More visual, more curated.

### Option C: The Grid
A masonry/pinterest-style grid of event imagery that feels like browsing a mood board. Tapping an image opens the event detail. Specialty filters as horizontal chips above.

### Recommendation
Option B ("The Stage") likely hits the best balance of discoverability, visual impact, and usability. It lets the app feel curated and alive without sacrificing navigation clarity. But this deserves a deeper design conversation.

## What Exists Today

- Dark theme with indigo primary, Inter font — solid foundation
- Bottom navigation: Events, Network, Community, Perks, Profile — five tabs
- GoRouter with auth guards and onboarding redirect — routing works
- Screens are scaffolded but use placeholder content (hardcoded lists, dummy data)
- No animations, no custom transitions, no dynamic content yet

## What's Needed Next (Post-Auth)

1. **Home screen design decision** — pick a direction from above (or a new one) and build it
2. **Event card component** — the workhorse widget; needs to be visually compelling
3. **Real API integration** — replace placeholder data with actual API calls
4. **Animations and polish** — page transitions, loading states (shimmer is already a dependency), pull-to-refresh
5. **Profile/portfolio screen** — this is where creatives show their work; needs to shine
6. **Push notifications** — event reminders, connection requests, community activity

## Open Questions

- Should the app support user-uploaded cover photos for events, or are venue/admin-provided images the only source?
- How much personalization can we drive from specialties alone vs. requiring explicit "interests" selection?
- Should the community feed be global, local (city-based), or event-scoped?
- What's the visual language for verified vs. unverified users? Badge only, or does the profile treatment differ?
