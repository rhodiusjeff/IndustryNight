# Industry Night - Implementation Plan

**Version:** 1.0
**Date:** February 4, 2026
**Status:** Draft

---

## Overview

This document outlines the implementation plan for the Industry Night platform, consisting of three main components:

1. **Backend API** - Node.js REST API (shared by all clients)
2. **Mobile App** - Flutter (iOS first, then Android)
3. **Web Admin App** - Admin dashboard (Flutter Web or separate framework)

---

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        EXTERNAL SERVICES                        │
├─────────────────────────────────────────────────────────────────┤
│  Posh.vip (Webhooks)  │  Twilio/SNS (SMS)  │  Stripe (Phase 2) │
└───────────┬───────────┴─────────┬──────────┴─────────┬─────────┘
            │                     │                    │
            ▼                     ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND API (Node.js)                      │
│                         AWS EKS / K8s                           │
├─────────────────────────────────────────────────────────────────┤
│  Auth  │  Users  │  Events  │  Connections  │  Posts  │  Admin  │
└─────────────────────────────────────────────────────────────────┘
            │                     │
            ▼                     ▼
┌─────────────────────┐   ┌─────────────────────┐
│    MOBILE APP       │   │   WEB ADMIN APP     │
│    (Flutter)        │   │   (Flutter Web)     │
├─────────────────────┤   ├─────────────────────┤
│ • User onboarding   │   │ • User management   │
│ • Event browsing    │   │ • Event management  │
│ • QR networking     │   │ • Sponsor/Vendor    │
│ • Community Board   │   │ • Content moderation│
│ • Profile mgmt      │   │ • Analytics         │
│ • Connections       │   │ • Announcements     │
└─────────────────────┘   └─────────────────────┘
```

---

## Phase Breakdown

### Phase 1A: Foundation (Backend + Auth)
**Goal:** Core infrastructure and authentication working

**Backend:**
- [x] AWS EKS cluster setup
- [x] Node.js API scaffold (Express or Fastify)
- [x] Database setup (PostgreSQL on RDS)
- [x] JWT authentication implementation
- [x] SMS verification flow (Twilio or SNS)
- [x] Posh webhook endpoint (receive + validate)
- [x] User CRUD operations
- [x] Basic logging and monitoring

**Deliverable:** Users can be created via Posh webhook or admin, and can authenticate via SMS

---

### Phase 1B: Core Mobile App
**Goal:** Users can log in, set up profile, browse events

**Mobile Screens:**
- [x] Splash / Loading
- [x] Phone Entry (login)
- [x] SMS Code Verification
- [ ] "Not Registered" screen (link to Posh)
- [x] Profile Setup (name, bio, specialty, socials, photo)
- [x] Home (events list)
- [x] Event Detail (basic - no social features yet)
- [x] Profile View (own profile)
- [x] Settings

**Backend Additions:**
- [x] Event CRUD endpoints
- [x] Profile update endpoints
- [x] Specialty list endpoint

**Deliverable:** Registered users can log in and set up profiles. Events are visible.

---

### Phase 1C: Verification & QR Networking
**Goal:** Full verification flow and connection-making at events

**Mobile Screens:**
- [x] Activation Code Entry
- [x] My QR Code display
- [x] QR Scanner
- [x] Connection Success modal
- [x] My Connections list
- [x] Connection Profile View

**Backend Additions:**
- [x] Activation code validation endpoint
- [x] Event check-in endpoint
- [x] Connection creation endpoint
- [x] Connections list endpoint
- [x] User verification status updates

**Deliverable:** Users can check in at events, scan QR codes, make connections, become verified

---

### Phase 1D: Event Social Features
**Goal:** Who's Going / Who's Here functionality

**Mobile Screens:**
- [ ] Event Detail (enhanced with social features)
  - Who's Going tab (connections with tickets)
  - Who's Here tab (connections checked in)
- [ ] Event Check-in prompt/flow

**Backend Additions:**
- [ ] Event attendees endpoint (filtered by connections)
- [ ] Check-in status queries

**Deliverable:** Checked-in users can see which connections are at the event

---

### Phase 1E: Community Board
**Goal:** Verified users can post and view community content

**Mobile Screens:**
- [x] Community Board feed
- [x] Create Post screen
- [x] Post Detail view
- [ ] "Verify to access" gate (for unverified users)

**Backend Additions:**
- [x] Post CRUD endpoints
- [x] Post feed endpoint (with pagination)
- [x] Announcement flag support

**Deliverable:** Verified users can view and create posts

---

### Phase 1F: Creative Search
**Goal:** Users can find other creatives by specialty

**Mobile Screens:**
- [x] Search screen
- [x] Filter by specialty
- [x] Search results list
- [x] Profile view (other users)

**Backend Additions:**
- [x] User search endpoint (with filters)
- [x] Public profile endpoint

**Deliverable:** Users can search and discover other creatives

---

### Phase 2A: Web Admin - Foundation
**Goal:** Basic admin dashboard functional

**Web Screens:**
- [x] Admin Login
- [x] Dashboard (overview stats)
- [x] User List (search, filter, view)
- [x] User Detail (view profile, verification status, ban)
- [x] Add User (manual entry)

**Backend Additions:**
- [x] Admin-only endpoints (role-based access)
- [x] User management endpoints (list, search, ban)
- [x] Basic analytics queries

**Deliverable:** Admins can view and manage users

---

### Phase 2B: Web Admin - Event Management
**Goal:** Full event management capability

**Web Screens:**
- [x] Event List
- [x] Create Event
  - Basic info (title, description, venue, date/time)
  - Activation code generation
  - Code validity window
- [ ] Edit Event
- [x] Event Detail
  - Attendee list (who has tickets)
  - Check-in list (who entered code)
  - Connection activity
- [ ] Duplicate Event (for recurring)

**Backend Additions:**
- [x] Admin event endpoints
- [x] Activation code management
- [ ] Event analytics endpoints

**Deliverable:** Admins can create and manage events with activation codes

---

### Phase 2C: Web Admin - Sponsor Management
**Goal:** Full sponsor and discount management

**Web Screens:**
- [x] Sponsor List (by tier: title, app, event)
- [x] Create/Edit Sponsor
  - Name, logo, description
  - Tier assignment
  - Social links
- [ ] Sponsor Detail
  - Associated events
  - Discount codes
- [x] Discount Management
  - Create discount code
  - Set expiration
  - View redemption stats (future)

**Mobile Additions:**
- [x] Perks/Discounts screen (verified users)
- [x] Sponsor detail view

**Backend Additions:**
- [x] Sponsor CRUD endpoints
- [x] Discount CRUD endpoints
- [ ] Event-sponsor association

**Deliverable:** Admins can manage sponsors and discounts. Users see perks.

---

### Phase 2D: Web Admin - Vendor Management
**Goal:** Event vendor management

**Web Screens:**
- [x] Vendor List
- [x] Create/Edit Vendor
  - Name, logo, description
  - What they offer
- [ ] Assign Vendors to Events

**Mobile Additions:**
- [ ] Vendors section on Event Detail

**Backend Additions:**
- [x] Vendor CRUD endpoints
- [ ] Event-vendor association

**Deliverable:** Admins can manage vendors per event

---

### Phase 2E: Web Admin - Content Moderation
**Goal:** Community board moderation tools

**Web Screens:**
- [x] Post List (with filters: reported, recent, by user)
- [ ] Post Detail (view, delete)
- [x] User ban management
- [x] Announcement creation

**Backend Additions:**
- [ ] Report post endpoint
- [x] Admin post deletion
- [x] Announcement creation endpoint

**Deliverable:** Admins can moderate community content

---

### Phase 3: Advanced Features (Future)
- [ ] In-app ticket purchase (Stripe)
- [ ] Push notifications
- [ ] Analytics dashboard
- [ ] Posh API sync (automatic event import)
- [ ] Android release

---

## Mobile App Screen Inventory

### Authentication Flow
| Screen | Access | Description |
|--------|--------|-------------|
| Splash | All | App loading / logo |
| Phone Entry | All | Enter phone number |
| SMS Verification | All | Enter SMS code |
| Not Registered | All | "Buy ticket at posh.vip" message |
| Profile Setup | Registered+ | First-time profile creation |

### Main App (Tab Bar)
| Screen | Access | Description |
|--------|--------|-------------|
| Home / Events | Registered+ | List of upcoming events |
| Community Board | Verified | Feed of posts |
| Search | Registered+ | Find creatives |
| Connections | Checked-in+ | List of your connections |
| Profile | Registered+ | Your profile + settings |

### Event Screens
| Screen | Access | Description |
|--------|--------|-------------|
| Event List | Registered+ | Browse all events |
| Event Detail | Registered+ | Event info, venue, time |
| Event Detail (Social) | Checked-in | Who's Going, Who's Here |
| Activation Code Entry | Registered+ | Enter 4-digit event code |

### QR Networking
| Screen | Access | Description |
|--------|--------|-------------|
| My QR Code | Checked-in | Display your QR for scanning |
| QR Scanner | Checked-in | Scan another user's QR |
| Connection Success | Checked-in | Confirmation modal |

### Community Board
| Screen | Access | Description |
|--------|--------|-------------|
| Feed | Verified | All posts + announcements |
| Create Post | Verified | New post form |
| Post Detail | Verified | Single post view |

### Profiles & Search
| Screen | Access | Description |
|--------|--------|-------------|
| My Profile | Registered+ | View/edit your profile |
| User Profile | Registered+ | View another user's profile |
| Search | Registered+ | Search by name/specialty |
| Search Results | Registered+ | Filtered list of users |

### Settings & Misc
| Screen | Access | Description |
|--------|--------|-------------|
| Settings | Registered+ | App preferences |
| Perks | Verified | Sponsor discounts |
| Sponsor Detail | Verified | Individual sponsor info |

**Total Mobile Screens: ~25**

---

## Web Admin App Screen Inventory

### Authentication
| Screen | Description |
|--------|-------------|
| Admin Login | Email/password or SSO |
| Forgot Password | Password reset |

### Dashboard
| Screen | Description |
|--------|-------------|
| Dashboard | Key metrics, recent activity |

### User Management
| Screen | Description |
|--------|-------------|
| User List | Searchable, filterable table |
| User Detail | Full profile, status, actions |
| Add User | Manual user creation form |
| Banned Users | List of banned accounts |

### Event Management
| Screen | Description |
|--------|-------------|
| Event List | All events (draft, published, completed) |
| Create Event | Full event form with code generation |
| Edit Event | Modify existing event |
| Event Detail | Attendees, check-ins, stats |
| Event Analytics | Views, check-ins, connections made |

### Sponsor Management
| Screen | Description |
|--------|-------------|
| Sponsor List | All sponsors by tier |
| Create/Edit Sponsor | Sponsor form |
| Sponsor Detail | Events, discounts, stats |
| Discount List | All active discount codes |
| Create/Edit Discount | Discount form |

### Vendor Management
| Screen | Description |
|--------|-------------|
| Vendor List | All vendors |
| Create/Edit Vendor | Vendor form |
| Assign to Event | Link vendors to events |

### Content Moderation
| Screen | Description |
|--------|-------------|
| Post List | All posts with moderation tools |
| Post Detail | View + delete |
| Create Announcement | Admin announcement form |
| Reports | Reported content queue |

### Settings
| Screen | Description |
|--------|-------------|
| Admin Settings | Platform configuration |
| Admin Users | Manage admin accounts |
| Audit Log | Action history |

**Total Web Admin Screens: ~25**

---

## Backend API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/request-code` | Send SMS verification code |
| POST | `/auth/verify-code` | Verify SMS code, return JWT |
| POST | `/auth/refresh` | Refresh JWT token |
| POST | `/webhooks/posh` | Receive Posh ticket webhook |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/me` | Get current user profile |
| PUT | `/users/me` | Update current user profile |
| GET | `/users/:id` | Get user by ID (public profile) |
| GET | `/users/search` | Search users (with filters) |
| POST | `/users` | Create user (admin only) |
| PUT | `/users/:id/ban` | Ban user (admin only) |

### Events
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/events` | List events |
| GET | `/events/:id` | Get event detail |
| POST | `/events` | Create event (admin only) |
| PUT | `/events/:id` | Update event (admin only) |
| DELETE | `/events/:id` | Delete event (admin only) |
| POST | `/events/:id/checkin` | Check in with activation code |
| GET | `/events/:id/attendees` | Get attendees (connections only) |

### Connections
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/connections` | List my connections |
| POST | `/connections` | Create connection (QR scan) |
| GET | `/connections/:id` | Get connection detail |

### Posts (Community Board)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/posts` | List posts (paginated) |
| GET | `/posts/:id` | Get single post |
| POST | `/posts` | Create post |
| DELETE | `/posts/:id` | Delete post (author or admin) |
| POST | `/posts/:id/report` | Report post |

### Sponsors
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/sponsors` | List sponsors |
| GET | `/sponsors/:id` | Get sponsor detail |
| POST | `/sponsors` | Create sponsor (admin) |
| PUT | `/sponsors/:id` | Update sponsor (admin) |
| DELETE | `/sponsors/:id` | Delete sponsor (admin) |

### Discounts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/discounts` | List active discounts (verified users) |
| GET | `/discounts/:id` | Get discount detail |
| POST | `/discounts` | Create discount (admin) |
| PUT | `/discounts/:id` | Update discount (admin) |
| DELETE | `/discounts/:id` | Delete discount (admin) |

### Vendors
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/vendors` | List vendors |
| GET | `/vendors/:id` | Get vendor detail |
| POST | `/vendors` | Create vendor (admin) |
| PUT | `/vendors/:id` | Update vendor (admin) |
| DELETE | `/vendors/:id` | Delete vendor (admin) |

### Admin
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/stats` | Dashboard statistics |
| GET | `/admin/users` | List all users (admin) |
| GET | `/admin/posts` | List all posts (admin) |
| GET | `/admin/audit-log` | Audit log entries |

---

## Dependencies & Build Order

```
Phase 1A: Backend Foundation
    │
    ├── Phase 1B: Core Mobile App
    │       │
    │       ├── Phase 1C: Verification & QR
    │       │       │
    │       │       ├── Phase 1D: Event Social
    │       │       │
    │       │       └── Phase 1E: Community Board
    │       │               │
    │       │               └── Phase 1F: Creative Search
    │       │
    │       └── Phase 2A: Web Admin Foundation
    │               │
    │               ├── Phase 2B: Event Management
    │               │
    │               ├── Phase 2C: Sponsor Management
    │               │
    │               ├── Phase 2D: Vendor Management
    │               │
    │               └── Phase 2E: Content Moderation
    │
    └── Phase 3: Advanced Features
```

**Critical Path:** 1A → 1B → 1C → 1D/1E (parallel) → 1F

**Web Admin can begin after 1B** (needs auth + users working)

---

## Technical Decisions Needed

- [x] Database: PostgreSQL (RDS) vs DynamoDB vs Aurora
- [x] SMS Provider: Twilio vs AWS SNS
- [x] Image Storage: S3 + CloudFront
- [x] API Framework: Express vs Fastify vs NestJS
- [x] Web Admin Framework: Flutter Web vs React vs Vue
- [x] CI/CD: GitHub Actions vs AWS CodePipeline

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-04 | Initial implementation plan |
