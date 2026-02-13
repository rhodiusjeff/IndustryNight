# Industry Night API

REST API backend for Industry Night applications.

## Tech Stack

- Node.js 20+
- TypeScript
- Express.js
- PostgreSQL
- JWT Authentication
- AWS SDK (S3, SES, Secrets Manager)
- Twilio (SMS)

## Getting Started

### Prerequisites

- Node.js 20+
- PostgreSQL database
- AWS credentials (for S3, SES, Secrets Manager)
- Twilio account (for SMS)

### Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Create `.env` file:
   ```bash
   cp .env.example .env
   ```

3. Configure environment variables in `.env`

4. Run database migrations:
   ```bash
   cd ../database && ./scripts/migrate.sh
   ```

5. Start development server:
   ```bash
   npm run dev
   ```

## Project Structure

```
src/
├── index.ts              # Entry point
├── config/
│   ├── database.ts       # Database connection
│   ├── auth.ts           # JWT configuration
│   └── env.ts            # Environment validation
├── routes/
│   ├── auth.ts           # Authentication routes
│   ├── users.ts          # User management
│   ├── events.ts         # Event routes
│   ├── connections.ts    # Networking routes
│   ├── posts.ts          # Community posts
│   ├── sponsors.ts       # Sponsor management
│   ├── vendors.ts        # Vendor management
│   ├── discounts.ts      # Discount/perks
│   ├── webhooks.ts       # Posh webhooks
│   └── admin.ts          # Admin routes
├── middleware/
│   ├── auth.ts           # JWT verification
│   ├── admin.ts          # Admin role check
│   └── validation.ts     # Request validation
├── services/
│   ├── sms.ts            # Twilio SMS
│   ├── email.ts          # AWS SES
│   └── posh.ts           # Posh integration
├── models/
│   └── *.ts              # Database models
└── utils/
    ├── jwt.ts            # JWT utilities
    └── errors.ts         # Error handling
```

## API Endpoints

### Authentication
- `POST /auth/request-code` - Request SMS verification code
- `POST /auth/verify-code` - Verify code and get tokens
- `POST /auth/refresh` - Refresh access token
- `POST /auth/logout` - Logout
- `GET /auth/me` - Get current user

### Users
- `GET /users` - Search users
- `GET /users/:id` - Get user by ID
- `PATCH /users/me` - Update profile
- `POST /users/me/photo` - Upload profile photo
- `POST /users/me/verification` - Submit verification
- `GET /users/me/qr` - Get QR code data

### Events
- `GET /events` - List events
- `GET /events/:id` - Get event details
- `GET /events/:id/tickets` - Get user tickets
- `POST /events/:id/checkin` - Check in to event

### Connections
- `GET /connections` - List connections
- `GET /connections/pending` - Pending requests
- `POST /connections` - Create connection
- `POST /connections/:id/accept` - Accept request
- `POST /connections/:id/decline` - Decline request
- `DELETE /connections/:id` - Remove connection

### Posts
- `GET /posts` - Get feed
- `GET /posts/:id` - Get post
- `POST /posts` - Create post
- `PATCH /posts/:id` - Update post
- `DELETE /posts/:id` - Delete post
- `POST /posts/:id/like` - Like post
- `DELETE /posts/:id/like` - Unlike post
- `GET /posts/:id/comments` - Get comments
- `POST /posts/:id/comments` - Add comment

### Admin (requires admin role)
- `GET /admin/dashboard` - Dashboard stats
- `GET /admin/users` - List all users
- `PATCH /admin/users/:id` - Update user
- `POST /admin/users` - Add user
- `GET /admin/events` - List all events
- `POST /admin/events` - Create event
- `PATCH /admin/events/:id` - Update event
- `GET /admin/sponsors` - List sponsors
- `POST /admin/sponsors` - Create sponsor
- `PATCH /admin/sponsors/:id` - Update sponsor
- `GET /admin/vendors` - List vendors
- `POST /admin/vendors` - Create vendor

## Testing

```bash
# Run all tests
npm test

# Watch mode
npm run test:watch
```

## Docker

```bash
# Build image
docker build -t industrynight-api .

# Run container
docker run -p 3000:3000 --env-file .env industrynight-api
```
