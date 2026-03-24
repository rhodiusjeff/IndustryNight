# [Track-B3] React Admin — Admin Parity (All Remaining Screens)

**Track:** B (React Admin)
**Sequence:** 4 of 4 in Track B (final prompt in sequence)
**Prompt ID:** B3
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex
**A/B Test:** No
**Estimated Effort:** Large (may span 2 weeks)
**Dependencies:** B0 (scaffold + design system), B1 (auth + RBAC), B2 (Event Ops screen + image management)

---

## Context

Read these before implementing:

- `CLAUDE.md` — Admin API endpoints table (routes/admin.ts) and Flutter admin app feature list
- `docs/codex/track-B/B0-scaffold-design-system.md` — design system, Tailwind config, component patterns
- `docs/codex/track-B/B1-auth-rbac-permissions.md` — auth middleware, role gating, admin session management (reference for consistency)
- `docs/codex/track-B/B2-event-ops-screen.md` — Event Ops screen + image upload patterns, EventFormScreen structure
- `packages/admin-app/lib/features/` — Flutter admin screens (reference for feature scope, not code to copy)
- `packages/react-admin/components/` — existing shared components from B0 (StatusBadge, DataTable, etc.)

---

## Goal

Build all remaining admin screens in the React admin app, achieving **full feature parity** with the current Flutter admin app. After B3 merges, the React admin app is the primary admin interface — the Flutter admin app is deprecated in favor of React.

This prompt covers 8 major screen groups + 20+ individual screens, unified by consistent component patterns, RBAC enforcement, and end-to-end API integration.

---

## Scope — Build These Screens

### 1. Dashboard — `app/(protected)/page.tsx`

**Current:** Placeholder from B0 (4 stat cards)
**Enhance to:**

- Stat cards: Total Users, Events This Month, Total Connections, Active Customers
- Data from `GET /admin/dashboard`
- Recent activity section (10 most recent audit log entries, OR last 5 events if audit endpoint not built yet)
  - Columns: timestamp, entity (User/Event/Customer), action (created/updated/banned), actor name
  - Link to detail page (e.g., click user → `/users/:id`)
- Charts (two columns):
  - **User Growth** (line chart, 30 days): use recharts or Chart.js; data from daily snapshots
  - **Connection Activity** (bar chart, last 7 days): connections created per day
- Quick action buttons:
  - "Create Event" → `/events/create`
  - "Add User" → `/users/add`
  - "Add Customer" → `/customers/add`
- Dark theme, responsive layout (cards stack on mobile)

---

### 2. Users — `app/(protected)/users/`

#### `page.tsx` — Users List

- **Search + Filters:**
  - Search by name/phone (calls `GET /admin/users?q=searchTerm`)
  - Filter by role: All / user / venueStaff / platformAdmin (calls `GET /admin/users?role=...`)
  - Filter by verificationStatus: All / unverified / pending / verified / rejected (calls `GET /admin/users?verificationStatus=...`)
  - Filters are cumulative (q + role + verificationStatus all in query)

- **Table:**
  - Columns: Avatar (initials fallback), Name, Phone, Role (badge), Verification Status (badge), Joined Date, Actions
  - Sortable by name, joined date (client-side or server-side per endpoint capability)
  - Pagination: show 25 per page, with prev/next/page number buttons
  - No-data state: "No users match your filters"

- **Bulk Actions (at top of table):**
  - Checkbox to select all visible
  - "Ban Selected", "Export as CSV" buttons (CSV export is future — show disabled with tooltip)
  - Selection counter: "2 of 25 selected"

- **Row Actions (per user):**
  - View Profile (icon link → `/users/:id`)
  - Ban/Unban toggle icon (calls `PATCH /admin/users/:id` with `banned: true/false`; shows spinner; updates badge on success)
  - Change Role dropdown (calls `PATCH /admin/users/:id` with new role; shows spinner; updates badge)
  - Verify/Reject dropdown (calls `PATCH /admin/users/:id` with verificationStatus; disabled if already verified)

- **RBAC:** platformAdmin only; moderator + eventOps cannot access (should not appear in sidebar)

---

#### `[id]/page.tsx` — User Detail

- **Profile Card:**
  - Avatar (large), name, phone, email, role badge, verification status badge, joined date, last active
  - Edit button (future — deferred to C4)

- **Specialties Section:**
  - List of specialties selected by user (read-only)
  - "No specialties selected" if empty

- **Posts by This User (collapsible section):**
  - Table or list: post type, content preview (100 chars), likes count, created date
  - Link to full post detail (future — moderation queue handles this)
  - "No posts" empty state

- **Connections (collapsible section):**
  - Counter: "Total: 42 connections"
  - List sample: name, phone, connected date (first 10)
  - "View All Connections" link (future, loads in modal or expanded list)

- **Audit Trail (collapsible section):**
  - Table: timestamp, action (created/updated/banned/verified), changes (old→new value), actor (admin name or system)
  - Filter by action type (dropdown)
  - Descending by timestamp (newest first)
  - Pagination if many entries

- **Action Buttons (bottom of page or sticky footer):**
  - Edit (deferred)
  - Ban/Unban toggle button (with confirmation modal; updates card badge on success)
  - Verify button (if unverified; calls PATCH with status=verified; shows confirm modal)
  - Reject button (if pending; calls PATCH with status=rejected; shows confirm modal)
  - Delete User button (calls DELETE /admin/users/:id after confirmation modal with "type the user's full name to confirm" input; navigates back to list on success)

- **Loading states:** skeleton cards while fetching detail
- **Error states:** "Failed to load user" with retry button; audit trail fetch error doesn't block the page
- **RBAC:** platformAdmin only

---

#### `add/page.tsx` — Add User Form

- **Form Fields:**
  - Phone (required, normalized to +1-XXX-XXX-XXXX on blur)
  - Name (required)
  - Email (optional)
  - Role (dropdown: user, venueStaff, platformAdmin; default: user)

- **Submit:**
  - Button: "Create User"
  - Calls `POST /admin/users` with { phone, name, email, role }
  - On success: navigate to `/users/:id` (newly created user detail)
  - On error: show inline error message (red text or error box)

- **Validation:**
  - Phone: required, must be valid format (use shared validator)
  - Name: required, 2-100 chars
  - Role: required

- **RBAC:** platformAdmin only

---

### 3. Events — `app/(protected)/events/`

#### `page.tsx` — Events List

- **Filters:**
  - Status filter: All / Draft / Published / Cancelled / Completed
  - Search by name (calls `GET /admin/events?q=...`)
  - Date range (optional, future — show as "coming soon")

- **Table:**
  - Columns: Event Name, Venue, Start Date, Status (badge, color-coded), Image Count (badge), Partner Count (badge), Actions
  - Sortable by name, start date
  - Pagination: 15 per page

- **Row Actions:**
  - View Detail (icon link → `/events/:id`)
  - Edit (icon link → `/events/:id/edit`)
  - Delete (icon, only if status=draft; calls DELETE /admin/events/:id after confirmation; removes from list)

- **Create Button:**
  - Top-right: "Create Event" button → `/events/create`

- **RBAC:** platformAdmin + eventOps can read; eventOps cannot delete or edit (show delete as disabled with tooltip "Event Ops can only view")

---

#### `create/page.tsx` — Create Event Form

- **Form Fields:**
  - Event Name (required, 1-200 chars)
  - Start Time (datetime picker, required)
  - End Time (datetime picker, required; must be > start time)
  - Venue Name (required, text field)
  - Venue Address (required, text field)
  - Description (optional, textarea, 0-1000 chars)
  - Capacity (optional, number, min 1)
  - Posh Event ID (optional, alphanumeric; required to publish, but doesn't block creation)

- **Form Behavior:**
  - Save button: "Create Event"
  - On success: navigate to `/events/:id` (newly created event detail)
  - On error: show inline error (e.g., "Failed to create event: [error message]")
  - Unsaved changes warning (optional, nice-to-have): "You have unsaved changes" if user tries to navigate away

- **Validation (client + server):**
  - All required fields present
  - End time > start time
  - Posh Event ID: if provided, must be unique (server will validate)

- **RBAC:** platformAdmin + eventOps can create

---

#### `[id]/page.tsx` — Event Detail

**This is the most complex screen.** Two-column layout (left: event info + partners, right: images + activation code).

- **Left Column — Event Info:**
  - Event name, venue name, venue address, description
  - Start/End time
  - Capacity
  - Status badge (draft/published/cancelled/completed), color-coded
  - Posh Event ID (if set)
  - Created date, last updated date

  - **Edit Button:**
    - Opens inline edit mode for each field (click label → becomes input → save/cancel)
    - OR opens a modal with the same form as create/edit
    - Calls `PATCH /admin/events/:id` on save

  - **Status Transition Buttons (only show allowed transitions):**
    - If status=draft:
      - **Publish button:** validates publish gate (posh_event_id + venue_name + at least 1 image); calls `PATCH /admin/events/:id` with status=published; shows spinner; on error shows modal with reason (e.g., "Missing Posh Event ID")
      - **Cancel button:** calls `PATCH /admin/events/:id` with status=cancelled; shows confirm modal
    - If status=published:
      - **Cancel button:** calls `PATCH /admin/events/:id` with status=cancelled; shows confirm modal
      - **Complete button:** calls `PATCH /admin/events/:id` with status=completed; shows confirm modal
    - If status=cancelled or completed:
      - No transition buttons (read-only)

- **Right Column — Image Management:**
  - **Upload Section:**
    - Drag-and-drop zone with icon (or file picker button)
    - Accepts image files (jpeg, png, webp, max 10MB)
    - Shows upload progress (% bar) and spinner
    - Max 5 images per event; show "Maximum 5 images reached" if at limit
    - On successful upload, image appears in gallery immediately
    - On error: show inline error message (red text)

  - **Image Gallery (grid, 3 columns):**
    - Thumbnail (4:3 aspect, cover)
    - Star icon overlay (top-left): click to set as hero; only one star visible at a time
    - Delete icon overlay (bottom-right): click to delete; shows confirm modal with image preview
    - Sort order badge (if not hero): shows sort_order value
    - Hover effect: slight zoom or opacity change

  - **Image Preview Modal (click thumbnail to open):**
    - Full-size image
    - Metadata: upload date, sort order, URL (copyable)
    - Actions: Set Hero (if not hero), Delete (with confirm)
    - Close button or click-outside to close

  - **Activation Code Section:**
    - Large monospace display: "XXXX-XXXX-XXXX" (format from API)
    - Copy button (copies to clipboard, shows "Copied!" tooltip briefly)
    - Regenerate button (future — shows as disabled for now)

- **Loading states:** skeleton cards while fetching event detail
- **Error states:** "Failed to load event" with retry button
- **RBAC:** platformAdmin + eventOps can view; only platformAdmin can edit or upload images (eventOps sees edit/upload as disabled)

---

#### `[id]/edit/page.tsx` — Edit Event Form

- Same form as create, but:
  - Pre-populated with current event data
  - Fetches data from `GET /admin/events/:id` on mount
  - Submit button: "Save Event"
  - On success: navigate back to `/events/:id` (show a toast "Event updated")
  - Disable editing if status != draft (show message: "Cannot edit published/cancelled/completed events"; form is read-only)

- **RBAC:** platformAdmin only

---

### 4. Image Catalog — `app/(protected)/images/page.tsx`

- **Filters:**
  - Filter by Event (dropdown: All Events, then each event name)
  - Search by event name (if dropdown filtering not enough)

- **Grid Layout:**
  - Responsive grid (4 columns on desktop, 2 on tablet, 1 on mobile)
  - Each image tile:
    - Thumbnail (4:3 aspect, cover)
    - Event name (small text below)
    - Upload date (small text)
    - LLM-generated tags (if available; small chips, e.g., "portrait", "outdoor")
    - Checkbox (top-left) for multi-select

  - Hover effects: slight zoom, show delete icon overlay (trash icon, bottom-right)

- **Bulk Actions (at top):**
  - "Select All" checkbox
  - "Archive Selected" button (archive = soft delete; calls `DELETE /admin/images/:imageId` for each; removes from grid)
  - "Download Selected" button (future, disabled)
  - Selection counter

- **Click Image:**
  - Opens preview modal:
    - Full-size image
    - Metadata: event name, upload date, URL (copyable), sort order
    - Tags (editable? future)
    - Archive button (soft delete)
    - Close button

- **Pagination or Infinite Scroll:**
  - Show 20 images per load

- **Empty state:**
  - "No images yet" if event selected but has no images
  - "No events have images" if no images across all events

- **Loading state:** skeleton grid while fetching

- **RBAC:** platformAdmin + eventOps can view; only platformAdmin can delete

---

### 5. Customers — `app/(protected)/customers/`

#### `page.tsx` — Customers List

- **Filters:**
  - Search by name (calls `GET /admin/customers?q=...`)
  - Filter by product type: All / sponsorship / vendor_space / data_product (calls `GET /admin/customers?hasProductType=...`)

- **Table:**
  - Columns: Logo (small square image or fallback circle with initials), Name, Product Types (badges, e.g., "sponsorship, vendor_space"), Active Products Count, Actions
  - Sortable by name, product count

- **Row Actions:**
  - View Detail → `/customers/:id`
  - Edit → `/customers/:id/edit`
  - Delete (icon; shows confirm modal; calls `DELETE /admin/customers/:id`; cascades to products + discounts)

- **Create Button:**
  - Top-right: "Add Customer" → `/customers/add`

- **RBAC:** platformAdmin only

---

#### `[id]/page.tsx` — Customer Detail (Tabbed Layout)

- **Header:**
  - Logo (large square, or initials fallback)
  - Name, company description (if any)
  - Edit button → `/customers/:id/edit`

- **Tab 1: Overview**
  - Logo, name, email, phone, website (if any)
  - Billing contact name/email
  - Mailing address
  - Notes (read-only text, or editable field if inline edit enabled)
  - Edit button (opens form modal or navigates to edit page)

- **Tab 2: Products (Customer Purchases)**
  - Table: Product Name, Type (badge), Quantity, Start Date, End Date, Status (badge: active/expired/cancelled/pending), Actions
  - Row actions: View, Edit (inline or modal), Delete
  - Add button: "Add Product Purchase" → opens modal with product selector + quantity + date fields
  - Edit modal:
    - Product (read-only dropdown or selector)
    - Quantity, start date, end date (editable)
    - Status (dropdown)
    - Save/Cancel buttons
    - Calls `PATCH /admin/customers/:id/products/:cpId`
  - Delete: calls `DELETE /admin/customers/:id/products/:cpId` after confirm

- **Tab 3: Discounts**
  - Table: Discount Name, Perks (text preview), Redemption Count, Created Date, Status, Actions
  - Row actions: Edit, Delete
  - Create button: "New Discount" → opens form modal
  - Form (create/edit):
    - Name (required)
    - Description/Perks (textarea, e.g., "Free haircut on first visit")
    - Redemption Limit (optional, number)
    - Expiration Date (optional, date picker)
    - Is Active (toggle)
    - Save/Cancel buttons
    - Calls `POST /admin/customers/:id/discounts` or `PATCH /admin/customers/:id/discounts/:did`
  - Delete: calls `DELETE /admin/customers/:id/discounts/:did` after confirm

- **Tab 4: Redemptions (Analytics)**
  - **Summary Cards:**
    - Total Redemptions (all-time)
    - Unique Users (who redeemed at least one discount)
    - Redemption Rate (redeemed / issued, if available)

  - **Breakdown by Discount (table or stacked bar chart):**
    - Discount name, total redemptions, unique users, redemption date range
    - Click to filter redemptions below to this discount (optional)

  - **Recent Redemptions (table):**
    - Columns: User Name, Discount Name, Redemption Method (self_reported, code_entry, qr_scan), Date
    - Sortable by date (newest first)
    - Pagination: 10 per page
    - Filter by discount (dropdown, affects the table below)

- **RBAC:** platformAdmin only

---

#### `add/page.tsx` — Create Customer Form

- **Form Fields:**
  - Logo (optional, file upload with preview; square aspect)
  - Name (required)
  - Email (optional)
  - Phone (optional)
  - Website (optional, URL)
  - Billing Contact Name (optional)
  - Billing Contact Email (optional)
  - Mailing Address (optional, textarea)
  - Company Description (optional, textarea)

- **Submit:**
  - Button: "Create Customer"
  - Calls `POST /admin/customers` with form data (multipart if logo included)
  - On success: navigate to `/customers/:id`
  - On error: show inline error

- **RBAC:** platformAdmin only

---

#### `[id]/edit/page.tsx` — Edit Customer Form

- Same form as create, pre-populated from `GET /admin/customers/:id`
- Submit button: "Save Customer"
- On success: navigate back to `/customers/:id`
- RBAC: platformAdmin only

---

### 6. Products — `app/(protected)/products/page.tsx`

- **Table:**
  - Columns: Product Name, Type (badge: sponsorship/vendor_space/data_product), Price (if numeric), Is Standard (checkmark or badge), Description Preview, Active Customers Using This, Actions
  - Sortable by name, type, price
  - Pagination: 20 per page

- **Filters:**
  - Filter by Type (dropdown)
  - Is Standard (toggle)
  - Search by name

- **Row Actions:**
  - Edit (icon, opens inline modal)
  - Delete (icon, disabled if any customer_products reference it; shows error modal explaining RESTRICT constraint)

- **Create Button:**
  - Top-right: "New Product" → opens create modal

- **Create/Edit Modal:**
  - Name (required)
  - Type (dropdown: sponsorship, vendor_space, data_product; required)
  - Price (optional, number)
  - Is Standard (toggle: if true, this product is a platform-wide offering; if false, custom/one-off)
  - Description (optional, textarea, 0-500 chars)
  - Save/Cancel buttons
  - Create modal: calls `POST /admin/products`
  - Edit modal: calls `PATCH /admin/products/:id`
  - On success: modal closes, list updates
  - On error: shows error message in modal

- **Delete Action:**
  - Icon with trash symbol
  - On click: shows modal "Cannot delete: X customers are using this product. Remove their purchases first." (if RESTRICT error from API)
  - Or: shows confirm modal if deletion is allowed

- **RBAC:** platformAdmin only

---

### 7. Moderation — `app/(protected)/moderation/`

#### `posts/page.tsx` — Posts Moderation Queue

- **Filters:**
  - Filter by Report Status: All Posts / Reported Posts Only
  - Filter by Post Type: All / general / collaboration / job / announcement

- **Table (or Card List for better UX):**
  - Columns/Fields:
    - Author (name + avatar)
    - Post Type (badge)
    - Content Preview (first 150 chars; ellipsis if longer)
    - Report Count (badge, red if > 0)
    - Report Reasons Summary (comma-separated list of unique reasons, e.g., "inappropriate, spam")
    - Created Date
    - Actions

  - Sortable by date, report count
  - Pagination: 10 per page

- **Row Actions:**
  - **Approve** (eye icon or button): removes from report queue; calls internal action or `PATCH /admin/posts/:id` with status=approved or report_count=0 (depends on API design)
  - **Delete Post** (trash icon): soft-deletes the post; calls `DELETE /admin/posts/:id`; shows confirm modal with preview
  - **Ban Author** (ban icon): bans the user; calls `PATCH /admin/users/:id` with banned=true; shows confirm modal

- **Click Post Content:**
  - Opens preview modal:
    - Full post content
    - Author (name, avatar, link to user detail)
    - Post type, created date
    - Engagement stats (likes, comments count)
    - Report details (if reported):
      - List of report reasons
      - Report timestamps
      - (Optional: reporter names if not anonymous; depends on schema)
    - Actions: Approve, Delete, Ban Author

- **Bulk Actions (if many):**
  - Checkboxes for multi-select
  - "Delete Selected Posts" button
  - "Ban Authors of Selected Posts" button

- **Empty state:**
  - "No reported posts" if filtered to reported-only
  - "No posts" if no posts match filters

- **Loading state:** skeleton cards while fetching

- **RBAC:** platformAdmin + moderator can access; other roles cannot

---

#### `announcements/page.tsx` — Create Platform Announcements

**Note:** This is a "create only" screen. An announcement is a post created by the platform (system) and appears in the community feed as the "official voice."

- **Form:**
  - Title (optional, text field)
  - Content (required, textarea or rich text editor; 1-5000 chars)
  - Post Type: always "announcement" (hidden field)
  - Media (optional, file upload for images; future, show as disabled)

- **Submit:**
  - Button: "Post Announcement"
  - Calls `POST /admin/posts` with { content, type: 'announcement', title? }
  - On success: shows confirm modal "Announcement posted to community feed"; clears form
  - On error: shows error message

- **Preview:**
  - Live preview of how it will appear in the community feed (below the form, read-only)
  - Author shown as "Industry Night" or "Platform"
  - Timestamp: "just now"

- **Recent Announcements (below form):**
  - List of last 5 announcements posted by platform
  - Read-only
  - Each item: content preview, timestamp, action buttons (Edit — future, Delete)
  - Delete calls `DELETE /admin/posts/:id` after confirm

- **RBAC:** platformAdmin + moderator can create; other roles cannot

---

### 8. Settings — `app/(protected)/settings/page.tsx`

(Deferred to prompt C4 — Build Admin Settings)
For now, show placeholder: "Settings — Coming Soon"

---

## Shared Components — Build or Enhance

### Existing (from B0)
- `StatusBadge` — event status, user role, verification status, product type, customer product status
- `AvatarWithFallback` — image with initials fallback
- `ConfirmModal` — generic confirm dialog with optional "type to confirm" input
- `DataTable` — sortable/filterable table with pagination
- `EmptyState` — generic empty state (icon + message + optional action button)
- `ComingSoon` — placeholder for unimplemented screens

### New — Build These

#### `DateTimeRangePicker`
- Renders two datetime pickers (start + end)
- Validates end > start
- Used in event create/edit form

#### `InlineEdit`
- Click-to-edit field: label, value, edit button
- On click, shows input field with save/cancel buttons
- Used in customer detail tabs or event detail

#### `ImageUploadZone`
- Drag-and-drop area with file picker fallback
- Shows upload progress (%)
- Preview of uploaded file
- Used in event detail, customer form (logo), announcement form (future)

#### `ConfirmDeleteModal`
- Enhanced confirm modal for destructive actions
- Shows "type entity name to confirm" input for high-risk deletes (users, events)
- Used across all CRUD screens

#### `TabsComponent`
- Renders tab bar + tab content
- Used in customer detail (4 tabs), event ops screen (if not already built in B2)

#### `StatsCard`
- Enhance from B0: support loading skeleton, error state, optional icon
- Used in dashboard

#### `ToastNotification`
- Toast/snackbar for success messages (e.g., "Event saved", "User banned")
- Show auto-dismiss (3-5 seconds) or manual close
- Position: top-right or bottom-right
- Used throughout all screens on success actions

---

## Acceptance Criteria

- **[ ] All 15+ screens listed above render without errors**
- **[ ] Dashboard stats are real data from `GET /admin/dashboard`; charts render (even if hardcoded data for now)**
- **[ ] User list: search, role filter, verification filter, bulk actions all work correctly**
- **[ ] User detail: ban/unban action calls endpoint and updates badge; delete shows "type name to confirm" input**
- **[ ] Event create → detail → navigation flow works end-to-end**
- **[ ] Event publish button: disabled until posh_event_id + venue_name + at least 1 image (validates publish gate from B2)**
- **[ ] Event status transitions (draft→published, published→completed) show appropriate buttons per status**
- **[ ] Image upload in event detail: drag-drop + file picker both work; uploaded image appears in gallery with hero toggle**
- **[ ] Image delete from event detail: shows preview modal and removes from gallery**
- **[ ] Customer detail tabs: all 4 tabs load and display correct data**
- **[ ] Add product to customer: modal opens, product selector works, purchase record created**
- **[ ] Create/edit discount: form submits correctly, shows in discount list**
- **[ ] Redemption analytics: summary cards + breakdown table render correctly**
- **[ ] Moderation queue: reported posts appear; delete post removes from list; approved post disappears from queue**
- **[ ] Create announcement: form submits, post appears in recent announcements list below**
- **[ ] All screens respect RBAC:**
  - eventOps: cannot access users, customers, products, moderation, analytics, settings
  - moderator: cannot access events (write), customers, products, analytics, settings; can read users; can access moderation
  - platformAdmin: full access
- **[ ] All list screens have loading states (skeleton loaders) and error states (with retry)**
- **[ ] All CRUD forms show spinner on submit and disable submit button**
- **[ ] All delete actions show confirm modal with action description**
- **[ ] Toast notifications appear for success actions (e.g., "Event created", "User banned")**
- **[ ] Pagination works on all table screens**
- **[ ] Responsive design: all screens work on mobile (sidebar collapses, tables scroll horizontally if needed)**
- **[ ] No TypeScript strict mode errors (`npm run type-check`)**
- **[ ] No console errors or warnings during basic navigation**
- **[ ] All new components have JSDoc comments**
- **[ ] (Optional) Storybook stories added for new components (nice-to-have; can defer to C5)**

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platform admin, I create an event, upload images, set Posh ID, add partners, and publish — entirely in React admin | E2E flow |
| Platform Admin | As a platform admin, I manage users: search, filter, ban/unban, change role, verify, and delete | User management |
| Platform Admin | As a platform admin, I manage customers, their product purchases, and their discounts + redemption analytics | Customer CRM |
| Moderator | As a moderator, I see only Dashboard, Users (read), and Moderation in my sidebar and cannot access other sections | Role gate + sidebar filtering |
| Moderator | As a moderator, I review reported posts in the moderation queue, approve or delete them, and ban spammers | Content moderation |
| Event Ops | As event ops, I create events and upload images, but cannot delete events or access user/customer management | Limited role |
| Any Admin | As any admin, navigation is fast and all screens load data from the API without errors | Performance + stability |
| Any Admin | As any admin, I see consistent visual language, button placement, and error handling across all screens | Design consistency |

---

## Technical Spec

### File Structure (New Files)

```
packages/react-admin/app/(protected)/
├── page.tsx                                    # Enhanced Dashboard (B0 → B3)
├── users/
│   ├── page.tsx                                # Users List
│   ├── [id]/
│   │   └── page.tsx                            # User Detail
│   └── add/
│       └── page.tsx                            # Add User Form
├── events/
│   ├── page.tsx                                # Events List
│   ├── create/
│   │   └── page.tsx                            # Create Event Form
│   ├── [id]/
│   │   ├── page.tsx                            # Event Detail
│   │   └── edit/
│   │       └── page.tsx                        # Edit Event Form
├── images/
│   └── page.tsx                                # Image Catalog
├── customers/
│   ├── page.tsx                                # Customers List
│   ├── add/
│   │   └── page.tsx                            # Create Customer Form
│   ├── [id]/
│   │   ├── page.tsx                            # Customer Detail (tabbed)
│   │   └── edit/
│   │       └── page.tsx                        # Edit Customer Form
├── products/
│   └── page.tsx                                # Products Catalog
├── moderation/
│   ├── posts/
│   │   └── page.tsx                            # Posts Moderation Queue
│   └── announcements/
│       └── page.tsx                            # Create Announcements
└── settings/
    └── page.tsx                                # Settings (placeholder → C4)

packages/react-admin/components/
├── ui/
│   ├── tabs.tsx                                # NEW: Tab component (radix/shadcn)
│   ├── input.tsx                               # Enhanced for date/time (if needed)
├── dashboard/
│   └── StatCard.tsx                            # Enhanced: skeleton + error states
├── forms/
│   ├── DateTimeRangePicker.tsx                 # NEW
│   ├── ImageUploadZone.tsx                     # NEW
│   ├── InlineEdit.tsx                          # NEW (optional)
├── modals/
│   ├── ConfirmDeleteModal.tsx                  # NEW
│   ├── PreviewImageModal.tsx                   # NEW
│   ├── PreviewPostModal.tsx                    # NEW
│   ├── AddProductModal.tsx                     # NEW
│   ├── EditDiscountModal.tsx                   # NEW
│   └── EditProductModal.tsx                    # NEW
├── tables/
│   ├── UsersTable.tsx                          # NEW (or use generic DataTable)
│   ├── EventsTable.tsx                         # NEW
│   ├── CustomersTable.tsx                      # NEW
│   ├── ProductsTable.tsx                       # NEW
│   ├── PostsTable.tsx                          # NEW
├── layout/
│   └── (existing Sidebar, Topbar, AppShell — no changes from B0)
├── common/
│   ├── EmptyState.tsx                          # Existing
│   ├── ComingSoon.tsx                          # Existing
│   ├── SkeletonCard.tsx                        # Existing
│   ├── ToastNotification.tsx                   # NEW
│   └── StatusBadge.tsx                         # Enhanced: add more status types
└── shared/
    ├── AvatarWithFallback.tsx                  # Existing
    └── ConfirmModal.tsx                        # Existing

packages/react-admin/lib/
├── api/
│   ├── client.ts                               # Existing
│   ├── admin.ts                                # NEW: AdminApi client with all endpoints
├── hooks/
│   ├── useAuth.ts                              # Existing
│   ├── useDashboard.ts                         # Existing
│   ├── useUsers.ts                             # NEW: fetch users, search, filter, pagination
│   ├── useUserDetail.ts                        # NEW: fetch single user + audit trail
│   ├── useEvents.ts                            # NEW: fetch events, filter
│   ├── useEventDetail.ts                       # NEW: fetch event with images + partners
│   ├── useCustomers.ts                         # NEW: fetch customers, filter
│   ├── useCustomerDetail.ts                    # NEW: fetch customer with products/discounts/redemptions
│   ├── useProducts.ts                          # NEW: fetch products
│   ├── usePosts.ts                             # NEW: fetch posts for moderation queue
│   ├── useRedirectIfUnauthorized.ts            # NEW: check permission for current route; redirect if denied
│   └── useToast.ts                             # NEW: show/hide toast notifications
├── validation/
│   ├── phone.ts                                # Existing, from shared
│   ├── event.ts                                # NEW: validate event form
│   ├── customer.ts                             # NEW: validate customer form
│   └── discount.ts                             # NEW: validate discount form
└── services/
    └── api-admin.ts                            # NEW: high-level service wrapping AdminApi (optional, can put logic in hooks)

packages/react-admin/types/
├── admin.ts                                    # Enhanced: add User, Event, Customer, Product, Post types
└── api.ts                                      # Enhanced: add response types for all endpoints
```

### AdminApi Client

Create `lib/api/admin.ts` wrapping all admin endpoints:

```typescript
// lib/api/admin.ts
import { ApiClient } from './client'

export class AdminApi {
  constructor(private client: ApiClient) {}

  // Dashboard
  getDashboard() { return this.client.get('/admin/dashboard') }

  // Users
  getUsers(params?: { q?: string; role?: string; verificationStatus?: string; limit?: number; offset?: number }) {
    return this.client.get('/admin/users', { params })
  }
  getUserDetail(id: string) { return this.client.get(`/admin/users/${id}`) }
  createUser(data: { phone: string; name: string; email?: string; role?: string }) {
    return this.client.post('/admin/users', data)
  }
  updateUser(id: string, data: Partial<{ role: string; banned: boolean; verificationStatus: string }>) {
    return this.client.patch(`/admin/users/${id}`, data)
  }
  deleteUser(id: string) { return this.client.delete(`/admin/users/${id}`) }

  // Events
  getEvents(params?: { q?: string; status?: string; limit?: number; offset?: number }) {
    return this.client.get('/admin/events', { params })
  }
  getEventDetail(id: string) { return this.client.get(`/admin/events/${id}`) }
  createEvent(data: any) { return this.client.post('/admin/events', data) }
  updateEvent(id: string, data: any) { return this.client.patch(`/admin/events/${id}`, data) }
  deleteEvent(id: string) { return this.client.delete(`/admin/events/${id}`) }

  // Event Images
  uploadEventImage(eventId: string, file: File) {
    const formData = new FormData()
    formData.append('image', file)
    return this.client.post(`/admin/events/${eventId}/images`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
  }
  setHeroImage(eventId: string, imageId: string) {
    return this.client.patch(`/admin/events/${eventId}/images/${imageId}/hero`, {})
  }
  deleteEventImage(eventId: string, imageId: string) {
    return this.client.delete(`/admin/events/${eventId}/images/${imageId}`)
  }

  // Image Catalog
  getImages(params?: { eventId?: string; limit?: number; offset?: number }) {
    return this.client.get('/admin/images', { params })
  }
  deleteImage(imageId: string) { return this.client.delete(`/admin/images/${imageId}`) }

  // Event Partners
  addEventPartner(eventId: string, data: { customerId: string; productId: string }) {
    return this.client.post(`/admin/events/${eventId}/partners`, data)
  }
  removeEventPartner(eventId: string, cpId: string) {
    return this.client.delete(`/admin/events/${eventId}/partners/${cpId}`)
  }

  // Customers
  getCustomers(params?: { q?: string; hasProductType?: string; limit?: number; offset?: number }) {
    return this.client.get('/admin/customers', { params })
  }
  getCustomerDetail(id: string) { return this.client.get(`/admin/customers/${id}`) }
  createCustomer(data: any) { return this.client.post('/admin/customers', data) }
  updateCustomer(id: string, data: any) { return this.client.patch(`/admin/customers/${id}`, data) }
  deleteCustomer(id: string) { return this.client.delete(`/admin/customers/${id}`) }

  // Customer Products
  getCustomerProducts(customerId: string) {
    return this.client.get(`/admin/customers/${customerId}/products`)
  }
  addCustomerProduct(customerId: string, data: { productId: string; quantity?: number; startDate?: string; endDate?: string }) {
    return this.client.post(`/admin/customers/${customerId}/products`, data)
  }
  updateCustomerProduct(customerId: string, cpId: string, data: any) {
    return this.client.patch(`/admin/customers/${customerId}/products/${cpId}`, data)
  }
  deleteCustomerProduct(customerId: string, cpId: string) {
    return this.client.delete(`/admin/customers/${customerId}/products/${cpId}`)
  }

  // Customer Discounts
  getCustomerDiscounts(customerId: string) {
    return this.client.get(`/admin/customers/${customerId}/discounts`)
  }
  createCustomerDiscount(customerId: string, data: any) {
    return this.client.post(`/admin/customers/${customerId}/discounts`, data)
  }
  updateCustomerDiscount(customerId: string, discountId: string, data: any) {
    return this.client.patch(`/admin/customers/${customerId}/discounts/${discountId}`, data)
  }
  deleteCustomerDiscount(customerId: string, discountId: string) {
    return this.client.delete(`/admin/customers/${customerId}/discounts/${discountId}`)
  }

  // Customer Redemptions
  getCustomerRedemptions(customerId: string) {
    return this.client.get(`/admin/customers/${customerId}/redemptions`)
  }

  // Products
  getProducts(params?: { type?: string; isStandard?: boolean; limit?: number; offset?: number }) {
    return this.client.get('/admin/products', { params })
  }
  createProduct(data: any) { return this.client.post('/admin/products', data) }
  updateProduct(id: string, data: any) { return this.client.patch(`/admin/products/${id}`, data) }
  deleteProduct(id: string) { return this.client.delete(`/admin/products/${id}`) }

  // Posts
  getPosts(params?: { reported?: boolean; type?: string; limit?: number; offset?: number }) {
    return this.client.get('/admin/posts', { params })
  }
  deletePost(id: string) { return this.client.delete(`/admin/posts/${id}`) }
  createPost(data: { content: string; type: string; title?: string }) {
    return this.client.post('/admin/posts', data)
  }
}
```

### React Query Hooks Pattern

Example hook for users list:

```typescript
// hooks/useUsers.ts
import { useQuery } from '@tanstack/react-query'
import { useAdminApi } from './useAdminApi'

export interface UseUsersOptions {
  q?: string
  role?: string
  verificationStatus?: string
  limit?: number
  offset?: number
}

export function useUsers(options?: UseUsersOptions) {
  const api = useAdminApi()
  return useQuery({
    queryKey: ['users', options],
    queryFn: () => api.getUsers(options),
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

export function useUserDetail(userId: string) {
  const api = useAdminApi()
  return useQuery({
    queryKey: ['users', userId],
    queryFn: () => api.getUserDetail(userId),
    enabled: !!userId,
  })
}
```

### Auth Check Hook (RBAC Redirect)

```typescript
// hooks/useRedirectIfUnauthorized.ts
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from './useAuth'
import { canAccess } from '@/lib/permissions'

export function useRedirectIfUnauthorized(requiredPath: string) {
  const router = useRouter()
  const { admin } = useAuth()

  useEffect(() => {
    if (admin && !canAccess(admin.role, requiredPath)) {
      router.push('/') // Redirect to dashboard
    }
  }, [admin, requiredPath, router])
}
```

---

## Test Suite

### Unit Tests (Vitest)

Focus on critical logic:

```typescript
// __tests__/components/StatusBadge.test.tsx
import { render, screen } from '@testing-library/react'
import StatusBadge from '@/components/common/StatusBadge'

describe('StatusBadge', () => {
  it('renders draft status with correct color', () => {
    render(<StatusBadge status="draft" />)
    expect(screen.getByText('Draft')).toHaveClass('bg-gray-600')
  })

  it('renders published status with correct color', () => {
    render(<StatusBadge status="published" />)
    expect(screen.getByText('Published')).toHaveClass('bg-green-600')
  })
})

// __tests__/lib/validation.test.ts
import { validateEvent } from '@/lib/validation/event'

describe('validateEvent', () => {
  it('requires event name', () => {
    const errors = validateEvent({ name: '', startTime: new Date(), endTime: new Date() })
    expect(errors.name).toBeDefined()
  })

  it('requires endTime > startTime', () => {
    const now = new Date()
    const past = new Date(now.getTime() - 1000)
    const errors = validateEvent({ name: 'Event', startTime: now, endTime: past })
    expect(errors.endTime).toBeDefined()
  })
})
```

### End-to-End Tests (Playwright)

Extend from B0:

```typescript
// e2e/users.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Users Management', () => {
  test.beforeEach(async ({ page }) => {
    // Login as platformAdmin
    await page.goto('http://localhost:3630/login')
    await page.fill('[name=email]', process.env.TEST_ADMIN_EMAIL!)
    await page.fill('[name=password]', process.env.TEST_ADMIN_PASSWORD!)
    await page.click('button[type=submit]')
    await page.waitForURL('http://localhost:3630/')
  })

  test('search and filter users', async ({ page }) => {
    await page.goto('http://localhost:3630/users')
    await page.fill('[placeholder="Search users"]', 'john')
    await page.click('button:has-text("Search")')
    await expect(page.locator('text=John')).toBeVisible()
  })

  test('ban and unban user', async ({ page }) => {
    await page.goto('http://localhost:3630/users')
    await page.click('button:has-text("View")') // View first user
    await page.waitForURL(/\/users\/\w+/)
    const banBtn = page.locator('button:has-text("Ban")')
    await banBtn.click()
    await expect(page.locator('text=Banned')).toBeVisible()
  })

  test('delete user requires confirmation', async ({ page }) => {
    await page.goto('http://localhost:3630/users')
    await page.click('button:has-text("View")')
    await page.waitForURL(/\/users\/\w+/)
    await page.click('button:has-text("Delete")')
    const modal = page.locator('[role=dialog]')
    await expect(modal.locator('text=type the user')).toBeVisible()
  })
})

// e2e/events.spec.ts
test('create event and publish with publish gate validation', async ({ page }) => {
  // Logged in as platformAdmin
  await page.goto('http://localhost:3630/events/create')
  await page.fill('[placeholder="Event Name"]', 'Networking Night')
  // ... fill other fields ...
  await page.click('button:has-text("Create Event")')
  await page.waitForURL(/\/events\/\w+/)

  // Try to publish without Posh ID
  const publishBtn = page.locator('button:has-text("Publish")')
  // Button should be disabled (or show error on click)
  expect(publishBtn).toBeDisabled()

  // Fill Posh ID, upload image
  // ... (fill form, upload) ...
  // Now publish should be enabled
  expect(publishBtn).toBeEnabled()
})

// e2e/moderation.spec.ts
test('delete post from moderation queue', async ({ page }) => {
  await page.goto('http://localhost:3630/moderation/posts')
  await page.click('[data-testid="reported-badge"]')
  const deleteBtn = page.locator('button[data-testid="delete-post"]').first()
  await deleteBtn.click()
  const modal = page.locator('[role=dialog]')
  await expect(modal.locator('text=Delete this post')).toBeVisible()
  await modal.click('button:has-text("Delete")')
  await expect(deleteBtn).not.toBeVisible()
})
```

---

## Definition of Done

- [ ] All 15+ screens and 20+ sub-screens build without TypeScript errors
- [ ] All screens load data from API correctly and display it
- [ ] RBAC is enforced: eventOps/moderator cannot access restricted screens (redirect to dashboard or show error)
- [ ] All forms validate on client and server; show inline errors
- [ ] All delete actions show confirmation modal with action description; some require "type to confirm"
- [ ] All success actions show toast notification (e.g., "Event created")
- [ ] All list screens have pagination, search, and filters working correctly
- [ ] All image upload screens (event detail, customer form) support drag-drop + file picker
- [ ] Event publish button is disabled until publish gate requirements met (posh_event_id + venue + image)
- [ ] Dashboard charts render (even if with sample data)
- [ ] Customer detail tabs all load correct data from API
- [ ] Moderation queue filters work; approve/delete/ban actions remove post from queue
- [ ] Create announcement form submits and shows in recent list below
- [ ] All new components have JSDoc comments and TypeScript types
- [ ] Unit tests pass: `npm test` in `packages/react-admin/`
- [ ] E2E tests pass: key user flows (create event, ban user, delete post, etc.) work end-to-end
- [ ] Responsive design: all screens work on mobile (sidebar collapses, tables scroll, forms stack)
- [ ] No console errors or warnings during navigation
- [ ] No strict mode TypeScript errors: `npm run type-check`
- [ ] All code is committed to `feature/B3-admin-parity` branch
- [ ] Completion Report and Interrogative Session filled in (below)

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/B3-admin-parity-[claude|gpt]`
**Model used:** —
**Date completed:** —
**Total implementation time:** —

### What I implemented exactly as specced
-

### What I deviated from the spec and why
-

### What I deferred or left incomplete (with reasoning)
-

### Technical debt introduced
-

### Performance notes
- Dashboard load time with real data:
- Largest table (users/events) pagination performance:
- Image upload handling (single vs. bulk):

### Known issues / blockers for production
-

### Structural notes for post-B3 work (deprecation of Flutter admin)
-

---

## Interrogative Session

**Q1: Are the dashboard charts performant with real data? Should we add pagination/date range filtering?**
> Jeff:

**Q2: The event publish gate (posh_event_id + venue + image) — does the UX make it obvious to users why publish is disabled? Should we add explanatory text/tooltip?**
> Jeff:

**Q3: For the moderation queue, should we prioritize reported posts (sort by report count)? Or should we add a "Recently reported" filter?**
> Jeff:

**Q4: Customer redemption analytics — should we add export (CSV) for this data? Useful for business reporting?**
> Jeff:

**Q5: Any screens that feel redundant or over-engineered? Or missing critical workflows?**
> Jeff:

---

## Deprecation Note

**Track B completion:** After B3 merges to `integration` and passes adversarial review:

The React admin app (`packages/react-admin/`) becomes the primary admin interface. The Flutter admin app (`packages/admin-app`) is deprecated and should be:

1. **Marked as archived** in `README.md` with a note: "Superseded by React admin (packages/react-admin). Kept for reference only."
2. **Excluded from CI/CD:** Remove from `.github/workflows/` or mark jobs as skipped
3. **No longer deployed:** Existing deployment (`deploy-admin.sh`) can remain for rollback, but new deployments only run React admin

**Confirm with Jeff before deprecating** — ensure all stakeholders are aware and no integrations depend on Flutter admin.

---

## Related Prompts

- **A0** — Social App (Flutter) — parallel track, independent
- **C0** — Shared Services (Auth, API, Database validation) — parallel track
- **C1** — Missing Backend Endpoints — may need to wire new endpoints discovered during B3 implementation
- **C4** — Admin Settings Screen — deferred, builds on B3 foundation
- **Review** — Adversarial panel review before merging B3 to `integration`

---
