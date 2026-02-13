# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Industry Night is a mobile app + companion website for discovering, promoting, and managing industry night events (hair stylists, makeup artists, photographers, videographers, producers, directors - creative workers). The mobile app serves operational users making connections; the website handles administrative functions.

## Tech Stack

- **Frontend:** Flutter (shared codebase for mobile app and web)
- **Backend:** RESTful API with JWT token authentication
- **Database:** TBD
- **Authentication:** Phone number verification via SMS link/code (passwordless)

## Project Structure

```
docs/           # Project memory and documentation (source of truth)
```

## Architecture Decisions

- **Phone-based identity:** Users authenticate via SMS code/link sent to their phone number - no passwords
- **Dual-platform Flutter:** Single Flutter codebase targets both mobile (iOS first, then Android) and web admin interface
- **Role separation:** Mobile app for end users (browse, save, check-in); Web for venue admins and platform operators

## Key Domain Concepts

- **Industry Night:** Events offering perks/discounts to verified industry workers
- **Verification:** Optional proof of industry employment (paystub, POS screenshot, employer email)
- **Check-in:** Users redeem perks at venues via in-app button or venue code
- **Roles:** User, Venue Admin, Venue Staff, Platform Admin

## Documentation

The `docs/` directory is the project memory. Key documents:
- `industry_night_app_developer_context_handoff.md` - Full product requirements and MVP scope
