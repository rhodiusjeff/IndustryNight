# Industry Night — Social Network Analysis (Product Owner Edition)

**Date:** March 2, 2026
**For:** Product Owner / Founder
**Purpose:** What the IN app's social features do today, what's missing, how sponsors make money from this, and what to build next.

---

## What You'll Learn From This Document

1. What kind of social network IN actually is (and why that matters)
2. What works in the app today vs. what's still placeholder
3. What data we're sitting on that sponsors would pay for
4. What's missing that would keep users coming back between events
5. How sponsors and vendors can generate real revenue through IN
6. What the risks are and how to avoid them
7. What to build next, in what order, and why

---

## 1. What Kind of Social Network Is This?

Industry Night isn't Instagram, LinkedIn, or Meetup. It's something new: an **event-first, verified professional network**.

Here's what makes it different:

| | Industry Night | LinkedIn | Instagram |
|---|---|---|---|
| **How people connect** | Physically scan each other's QR code at an event | Send a digital request to anyone | Follow from anywhere |
| **Trust signal** | "We met in person at this event" | Self-reported job title | None |
| **Who's verified** | People who actually showed up and made connections | Anyone who pays or gets lucky | Blue check = pay |
| **What it's for** | Professional networking for creatives | All professional networking | Content sharing |

### The Verification Ladder

Users earn trust through real actions, not by filling out a form:

1. **Registered** -- Downloaded the app, verified their phone number
2. **Checked In** -- Bought a ticket and entered the activation code at an event
3. **Verified** -- Made their first real connection by scanning someone's QR code

Each level unlocks more features. This creates a reason to attend events and use the app -- not just download it.

### Why This Matters

Every connection in the IN network proves that two creative professionals physically met at one of your events. That's something no other social platform can say. A LinkedIn connection could be two strangers. An Instagram follow is one-directional and meaningless. An IN connection is mutual, verified, and tied to a specific event.

**This is IN's superpower.** It's the thing that makes the network valuable to sponsors and impossible for competitors to copy.

---

## 2. What Works Today vs. What's Placeholder

### Working and Real

These features are fully built, connected to the backend, and functional:

- **QR-based instant connections** -- Scan someone's QR code at an event, you're instantly connected. Both people get a celebration screen. Both automatically become verified members.
- **Connections list** -- See everyone you've connected with. Pull down to refresh. Swipe to remove someone.
- **Real-time connection alerts** -- While your QR code is displayed, the app checks every 4 seconds for incoming connections and shows you when someone scans your code.
- **Profile editing** -- Name, email, bio, specialties -- all saved and synced.
- **Event browsing** -- Upcoming events with images, venue info, dates. Shows your ticket status.
- **Event check-in** -- Scan a QR code or type the 4-digit activation code. Validates your ticket on the server.
- **Ticket display** -- Shows whether you have a ticket and its status (purchased, checked in).

### Placeholder (Looks Real, But Isn't Connected)

These screens exist in the app but show fake/hardcoded data. They need to be wired up to the real backend:

- **Community feed** -- Shows 10 fake posts from fake users. The backend for real posts exists and works, but the app isn't connected to it yet.
- **Create post** -- You can type a post and hit submit, but it doesn't actually go anywhere. Just a fake 1-second delay.
- **Post detail** -- Hardcoded author, content, likes, comments. None of it is real.
- **User search** -- Shows 10 dummy results. The backend search (by name or specialty) works, but the app shows fake data.
- **Other people's profiles** -- Hardcoded stats and info. Not pulling from real data.
- **Perks/Sponsors** -- Hardcoded sponsor list and discount codes. Not connected to the real sponsor data.

### Doesn't Exist At All

These features have no screens, no backend, nothing:

- **Direct messaging** between users
- **Push notifications** (event reminders, "you have a new connection!", etc.)
- **Portfolio / work showcase** on profiles (no way to show your work)
- **"People at this event"** discovery (seeing who else is checked in)
- **Sharing** profiles or events outside the app
- **Hashtags or topics**

---

## 3. The Data We're Sitting On

This is where it gets interesting for sponsors. Because of the event-first model, IN captures data that other social platforms simply can't.

### What We Already Have

- **Who our users are professionally** -- Every user picks their creative specialties (hair, makeup, photography, videography, etc.). We know exactly what the community looks like.
- **Who connects with whom** -- We know that photographers connect with MUAs more than any other pairing, for example. That's valuable market intelligence.
- **Who shows up** -- We know exactly who attended each event, not just who bought a ticket. Check-in data is precise.
- **When connections happen** -- We can tell sponsors "most networking happens in the first 90 minutes" which helps them plan activations.
- **Privacy consent** -- Users can opt in/out of analytics and marketing. This is built in from day one, which keeps us compliant and trustworthy.

### What We Could Compute (The Data Exists, We Just Need to Crunch It)

- **Repeat attendance rate** -- "35% of attendees come back to the next event" -- sponsors love retention metrics.
- **Connections per event** -- "Average attendee makes 4.2 connections per event" -- proves engagement.
- **Influence scores** -- "Here are the 10 most connected photographers in NYC" -- identifies brand ambassadors.
- **Specialty growth trends** -- "MUA registrations up 40% this quarter" -- market signal for beauty brands.
- **Cross-specialty affinity** -- "Hair stylists and photographers connect at 3x the rate of other pairings" -- tells niche sponsors exactly where to focus.

### The Key Insight for Sponsors

There's a big difference between telling a sponsor:

> "We had 200 people at the event"

vs.

> "We had 200 people: 45% hair stylists, 25% MUAs, 15% photographers, 15% other. Hair stylists connected with MUAs at 3x the rate of any other pairing. Your brand was seen by 120 hair professionals who are actively networking."

The first one is worth a logo placement. The second one is worth a quarterly data partnership. **We have the raw data for the second version** -- we just need to build the computation and reporting tools.

---

## 4. The Engagement Gap

### The Problem

Here's what the current user journey looks like:

1. Download the app
2. Register with phone number
3. Browse events
4. Buy a ticket
5. Show up at the event
6. Check in with activation code
7. Scan QR codes, make connections
8. **...nothing. The app sits unused until the next event.**

That gap between "made connections" and "next event" is where we lose people. Right now there is literally nothing in the app that gives someone a reason to open it between events. The community feed is fake. There's no messaging. There are no notifications.

### The Solution: Three Pillars

**Feed + Messaging + Notifications** -- these three features together turn IN from "an app I use at events" into "an app I check regularly."

1. **Community Feed** -- A place to post between events. Job opportunities ("Looking for a photographer for a shoot on March 15th"), collaboration requests, event recaps, industry conversations. The backend is built -- we just need to connect the app to it.

2. **Messaging** -- After you scan someone's QR code at an event, you should be able to message them in the app. Right now, people exchange Instagram handles or phone numbers instead. **Every conversation that moves to Instagram is a user who doesn't need IN anymore.** Connection-only messaging (you can only message people you've physically met) is a natural spam filter.

3. **Push Notifications** -- The app has no way to pull you back. We need: "You have a new connection!", "New event in NYC next week", "Your connection Sarah posted in the community", "New perk from [Sponsor]."

### Why This Matters

Sponsors and partners care about one number: **how often people actually open the app**. An event-only app means people open it once a month on event night. With a working feed and messaging, people might open it several times a week.

The difference between those two numbers is the difference between:
- "We sponsor events" (one-time, transactional, low value)
- "We have an ongoing relationship with your audience" (recurring partnership, high value)

### Getting the Feed Started

Empty communities die. When the community feed goes live, we need to seed it:
- Admin announcements (event recaps, upcoming event teasers, community milestones)
- Post-event prompts ("How was Industry Night? Share your experience!")
- Sample collaboration requests to model the behavior
- Connection prompts ("Say hi to Sarah in the community feed")

---

## 5. How Sponsors and Vendors Make Money Through IN

### Three Levels of Sponsor Revenue

#### Level 1: Logo Placement ($500--2,000 per event)
"Your logo on the event page, visible to all attendees."

**This works today.** Sponsors are linked to events and their logos appear on event detail screens.

**The limitation:** This is the lowest-value tier. Every event platform offers this. It's a commodity.

#### Level 2: Audience Access ($2,000--5,000 per event)
"Your discount codes delivered to 200 verified hair professionals who attended your sponsored event."

**This is where the real money starts.** It requires:
- Verification gating (so "verified professionals" means something real)
- Working perks screen (connected to real sponsor data, not fake)
- **Redemption tracking** (knowing whether discount codes were actually used)

**This is the single highest-value investment we can make** -- it moves sponsors from "we put our logo somewhere" to "we reached verified professionals in our target demographic."

#### Level 3: Data Partnership ($5,000--20,000 per quarter)
"Monthly audience intelligence report: growth trends, specialty demographics, engagement patterns, top influencers in your target market."

**This is recurring revenue** -- sponsors pay quarterly for ongoing insights, not per-event. It requires building the analytics tools to compute and present the data we already capture.

### The Most Important Missing Piece: Redemption Tracking

Right now, a sponsor gives us discount codes, we show them to users, and **nobody knows if anyone used them.** Not us, not the sponsor.

That's a massive gap. Even simple self-reported tracking ("Tap 'I Used This' when you redeem this code") would let us tell sponsors: "42 users redeemed your 20% off code."

**That's conversion data.** That's what turns a $500 logo placement into a $5,000 quarterly partnership. Sponsors don't pay for impressions -- they pay for proof that their money did something.

### The Marketing Consent Channel

Sponsors will eventually ask: "Can we email your attendees?"

The answer should always be: **"No, but we can deliver your discounts and content to users who opted in."**

This is called a **managed channel** -- IN controls the relationship between sponsor and user. The sponsor never gets email addresses or phone numbers. This:
- Protects user trust (sponsors don't get personal info)
- Lets IN charge for access (we're the gatekeeper)
- Prevents sponsor fatigue (we control how often users see sponsor content)
- Maintains our position as the platform (the sponsor needs us)

Giving sponsors direct access to user contact info would be a mistake -- it eliminates our role and our revenue.

---

## 6. Risks to Watch

### Product Risks

| Risk | What It Means | How We Avoid It |
|---|---|---|
| **Connection decay** | People connect at events then never interact again. The connections go stale. | Build messaging and feed so connections stay active between events |
| **Empty community feed** | Nobody posts because nobody posts. Chicken-and-egg problem. | Seed the feed with admin announcements, post-event prompts, and collaboration request templates |
| **Event dependency** | If events are monthly, the app is only relevant 2 days a month | Feed + messaging + notifications create between-event value |
| **Users leave for Instagram** | People connect on IN, then move conversations to Instagram DMs | In-app messaging keeps conversations here. Portfolio feature removes the need to visit Instagram for work samples |
| **Over-promising to sponsors** | Saying "we have 500 users" when only 50 are active | Focus on verified users and event attendance as honest metrics. Never inflate numbers. |

### Perception Risks

| Risk | What It Means | How We Avoid It |
|---|---|---|
| **"Selling user data" feeling** | Users may feel uncomfortable if they think we're sharing their info with sponsors | We share anonymized, aggregated insights -- never individual data. Messaging: "We share audience trends with sponsors to bring you better perks." |
| **Low analytics opt-in** | If too few users agree to analytics, the data isn't meaningful | Clear explanation during signup about why it helps them (better perks, better events). Not a dark pattern -- genuine value exchange. |

---

## 7. What to Build Next (In Order)

### Phase A: Make the App Worth Opening Between Events
1. **Wire the community feed** -- Connect the placeholder to the real backend. This is the single most impactful thing we can build.
2. **Push notifications** -- Give the app a way to pull users back (new connections, new events, new posts).
3. **Verification gating** -- Lock community access behind "attend an event + make a connection." This drives event attendance.

### Phase B: Build Professional Utility
4. **Connection-only messaging** -- Let people continue conversations after events without leaving the app.
5. **Profile portfolios** -- Let creatives showcase their work (3-6 featured images).
6. **Creative search** -- Connect the real search backend to the app so people can find collaborators by specialty.

### Phase C: Build the Sponsor Revenue Engine
7. **Redemption tracking** -- Know whether discount codes get used. This is what sponsors will pay for.
8. **Analytics computation** -- Crunch the data we already have into influence scores, event performance, demographic trends.
9. **Sponsor reports** -- Package the data into something we can show (or sell to) sponsors.
10. **Wire perks screen** -- Connect real sponsor/discount data to the app.

### Phase D: Network Growth
11. **Mutual connections** -- "You and Sarah have 12 connections in common" -- builds social proof.
12. **People at This Event** -- See who else is checked in. Digital equivalent of looking around the room.
13. **External sharing** -- Share your IN profile or an event link outside the app. Viral growth.
14. **Structured collaboration board** -- "Looking for MUA for shoot on 3/15" with structured fields.

### Why This Order?

Phase A keeps users in the app. Without it, everything else is pointless -- you can't monetize an app nobody opens.

Phase B gives users professional reasons to stay. This is what makes IN more than "just another events app."

Phase C builds the revenue engine. By this point, we have active users, engagement data, and proof points for sponsors.

Phase D creates network effects -- each new user makes the platform more valuable for everyone else.

---

## 8. Key Concepts (Quick Reference)

| Term | What It Means for IN |
|---|---|
| **Audience Intelligence** | Knowing who our users are in detail -- not just "200 attendees" but "120 hair professionals who actively network." Worth 5-10x more to sponsors than raw headcounts. |
| **DAU/MAU** | How often people open the app (daily active / monthly active). Event-only apps: very low. With feed + messaging: much higher. Higher = more valuable to sponsors. |
| **Managed Channel** | We control how sponsors reach our users. Sponsors never get email addresses -- they go through us. This is our revenue moat. |
| **Conversion Data** | Proof that a sponsor's investment worked. "42 people used your discount code" vs. "we showed your code to 200 people." The first is worth dramatically more. |
| **Affinity Data** | Knowledge about who connects with whom. "Photographers connect with MUAs at 3x the rate of other pairings." Tells niche sponsors exactly where to focus. |
| **Network Effects** | Each new creative who joins makes the platform more valuable for everyone. This is IN's long-term moat -- the connection data can't be copied. |
| **Cold Start Problem** | An empty feed has no posts, which means nobody posts, which means the feed stays empty. Solution: seed it with admin content and prompt users to post. |
| **Verified Co-Presence** | IN's unique data: proof that two professionals physically met at an event. No other social platform has this. |
| **Feature Gating** | Locking features behind real-world actions. "Attend an event to unlock the community board" drives attendance and engagement. |
| **Redemption Tracking** | Knowing if discount codes actually get used. The #1 most important thing for proving sponsor ROI. |

---

## Related Documents

- **Social Network Analysis (Technical)** -- `docs/analysis/social_network_analysis.md` -- Full technical version with file references, code details, and implementation specifics
- **Adversarial Review** -- `docs/analysis/adversarial_review.md` -- Detailed requirements-vs-reality audit with decisions
- **Implementation Plan** -- `docs/product/implementation_plan.md` -- Development roadmap
- **Executive Brief** -- `docs/executive/Industry Night - Executive Brief.pptx` -- Slide deck overview
- **Executive Summary** -- `docs/executive/Industry Night - Executive Summary.pptx` -- Non-technical slide deck
