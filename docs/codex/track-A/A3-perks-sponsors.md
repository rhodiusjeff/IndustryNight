# [Track-A3] Perks + Sponsor Display + Redemption

**Track:** A (Social App Completion)
**Sequence:** 4 of 4 in Track A
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← equally strong; Dart + TypeScript state management and widget testing fit both models well
**A/B Test:** No
**Estimated Effort:** Small (4-6 hours)
**Dependencies:** A2 (user search / profile — establishes UI navigation patterns)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — full project reference, especially the Perks / Sponsors architecture section
- `docs/product/requirements.md` — customer/sponsor business model and discount tier system
- `packages/api/src/routes/discounts.ts` — social-facing endpoints: GET /discounts, POST /discounts/:id/redeem
- `packages/api/src/routes/sponsors.ts` — GET /sponsors (active customers with sponsorship products)
- `packages/shared/lib/models/discount.dart` — Discount model (customerId, customerName, customerLogo, expiresAt)
- `packages/shared/lib/models/customer.dart` — Customer model (name, description, logoUrl, website, socialLinks)
- `packages/shared/lib/models/discount_redemption.dart` — DiscountRedemption model (userId, discountId, redeemedAt)
- `packages/shared/lib/api/perks_api.dart` — PerksApi client (verify it exists and is complete)
- `packages/social-app/lib/features/perks/` — existing screens (if any)

> **Flutter Widget Test Gotcha:** `FakeAppState.initialize()` MUST be a no-op override in all widget tests. Without this, `SecureStorage` throws `MissingPluginException` in test context. See `EXECUTION_CONTEXT.md` §1 and the reference test at `packages/social-app/test/features/settings/settings_screen_test.dart`.

---

## Goal

Wire the Perks screens to the real PerksApi. Users can browse active sponsor/customer perks, view perk details, and tap "I Used This" to record a self-reported redemption. This completes Track A — the full social app retention feature loop is now functional: auth → onboarding → events → QR networking → community feed → search → **perks** ✓

---

## Acceptance Criteria

**Perks Screen (browsing all available perks)**
- [ ] On init: calls `perksApi.getDiscounts()` to load all active discounts
- [ ] Displays list grouped by sponsor (sponsor card header followed by discount cards) OR flat list sorted by sponsor name — whichever is cleaner given API response shape
- [ ] Discount card shows: title, description (truncated to ~100 chars), "Valid until {date}" if expiry set
- [ ] "Redeem" button on each discount card navigates to sponsor_detail_screen
- [ ] Pull-to-refresh: reloads list from API (shows loading spinner, no error toast on success)
- [ ] Empty state when no discounts: "No perks available right now — check back after the next event"
- [ ] Loading state: circular progress indicator while fetching
- [ ] Error state: snackbar "Could not load perks. Try again." with retry button
- [ ] Screen handles AppState appBar / bottom nav properly (no navigation breaks)

**Sponsor Detail Screen (viewing sponsor + their discounts + redeeming)**
- [ ] Takes discountId OR customerId as route param; loads discount + customer detail
- [ ] Header: sponsor logo (hero image, centered, 120x120px), sponsor name, description (2-3 lines, light grey text)
- [ ] List of all active discounts from this sponsor
- [ ] Each discount card: title, full description, "Valid until {date}", "I Used This" button
- [ ] "I Used This" button UX:
  - [ ] Initial state: purple/active color, enabled
  - [ ] Tap: shows confirm dialog "Did you use this perk at {Sponsor Name}?" with Yes/Cancel buttons
  - [ ] On Yes: calls `perksApi.redeemDiscount(discountId)`, shows loading spinner on button
  - [ ] On success: button changes to "✓ Used on {date}" (greyed, disabled), success toast "Perk redeemed!"
  - [ ] Already redeemed (loaded from getMyRedemptions on init): button pre-renders as "✓ Used on {date}" (greyed, disabled)
  - [ ] API error (409 duplicate, 500, etc.): snackbar "Could not record redemption. Try again." — button remains active
  - [ ] Network error: snackbar with retry — button remains active
- [ ] Sponsor's social links / website (if present): tappable links that open in browser
- [ ] Back button or nav pop returns to perks_screen with list unchanged
- [ ] Page handles scroll for long descriptions and many discounts

**PerksApi Completeness (packages/shared/lib/api/perks_api.dart)**
- [ ] `getSponsors()` → `List<Customer>` — calls `GET /sponsors`, returns active customers with sponsorship products
- [ ] `getDiscounts()` → `List<Discount>` — calls `GET /discounts`, includes customerName, customerLogo
- [ ] `redeemDiscount(String discountId)` → `DiscountRedemption` — calls `POST /discounts/:id/redeem`
- [ ] `getMyRedemptions()` → `List<DiscountRedemption>` — if endpoint exists; otherwise skip (UI will derive from discount list on screen init)
- [ ] All methods handle auth token (inherited from ApiClient base)
- [ ] Error responses parsed correctly (non-2xx status codes throw / return null gracefully)

**Redemption State Tracking (AppState or screen-local)**
- [ ] After calling `redeemDiscount()`, store redeemed discountId in local set (or AppState) to immediately reflect state without reload
- [ ] On sponsor_detail_screen init: call `getMyRedemptions()` to load previously redeemed discounts
- [ ] Button pre-renders correctly based on this state (no second API call if user taps "I Used This" twice)
- [ ] Duplicate redemption attempt (user taps button after already used): button is disabled, no second API call goes out

**Navigation**
- [ ] Bottom nav "Perks" tab → `/perks` route → perks_screen
- [ ] Perks screen card tap → `/discounts/:discountId` or `/sponsors/:customerId` (whichever makes sense)
- [ ] GoRouter routes exist: `/perks`, `/sponsors/:id` (or `/discounts/:id`)
- [ ] Back button / pop returns to previous screen correctly
- [ ] Deep link support (optional but nice-to-have for future testing)

**State & Caching (optional but recommended)**
- [ ] Perks list cached locally; pull-to-refresh forces fresh fetch
- [ ] Last-fetched-at timestamp so UI can show "Last updated X min ago"
- [ ] If API unavailable on init, show cached list with "Last updated X min ago" badge

**UI Polish (all screens)**
- [ ] All screens render sponsor logos with proper fallback (avatar initial if no URL)
- [ ] Date formatting: "Valid until Jan 15, 2026" (use package:intl formatters)
- [ ] Discount expiry shows in red if within 7 days, grey otherwise
- [ ] No hardcoded colors; all from Theme.of(context).colorScheme
- [ ] Touch targets >= 48dp (WCAG compliance)
- [ ] Text contrast ratios meet WCAG AA
- [ ] "I Used This" button loading state: button disabled, shows spinner inside
- [ ] No visual lag when button transitions to "✓ Used"

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Creative professional | As a user who attended an event, I browse the Perks tab and see exclusive discounts from sponsors | Retention: keep users engaged post-event |
| User (using perk) | As a user who used a discount at a sponsor's studio, I tap "I Used This" — the platform records it and the button locks so I can't accidentally redeem twice | Self-reported redemption = proof of audience access (Tier 2 revenue) |
| Returning user | As a user returning after a week, I open the Perks tab and already-redeemed perks show "✓ Used" so I know what I've already claimed | Smooth UX: no confusion about redemption history |
| User offline | As a user on spotty wifi, I open the Perks tab and see the last cached perks rather than a white screen | Graceful degradation |
| Sponsor (via analytics) | As a sponsor, I see in the dashboard that 47 users claimed my perk, and 12 have marked "I Used This" | Redemption conversion data (populated from discount_redemptions table) |

---

## Technical Spec

### 1. Directory Structure & Files to Create/Modify

**New files:**
```
packages/social-app/lib/features/perks/
  screens/
    perks_screen.dart             # Browse all active perks (grouped or flat)
    sponsor_detail_screen.dart    # View sponsor + their discounts + redeem
  widgets/
    discount_card.dart            # Reusable discount card component
    sponsor_header.dart           # Sponsor logo + name + description
  perks_screen_test.dart          # Widget tests
  sponsor_detail_screen_test.dart # Widget tests
```

**Modified files:**
```
packages/shared/lib/api/perks_api.dart     # Complete/verify PerksApi
packages/social-app/lib/config/routes.dart # Add /perks, /sponsors/:id routes
packages/social-app/lib/providers/app_state.dart # Optional: add redemption cache
packages/social-app/lib/main.dart          # Verify perks nav tab wired (if not already)
```

### 2. PerksApi (packages/shared/lib/api/perks_api.dart)

**Verify or create PerksApi with these methods:**

```dart
import 'package:shared/models/customer.dart';
import 'package:shared/models/discount.dart';
import 'package:shared/models/discount_redemption.dart';

class PerksApi {
  final ApiClient client;

  PerksApi(this.client);

  /// Fetch all active sponsors (customers with sponsorship products).
  /// Calls GET /sponsors
  Future<List<Customer>> getSponsors() async {
    try {
      final response = await client.get('/sponsors');
      return (response as List)
          .map((json) => Customer.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all active discounts (includes customerName, customerLogo).
  /// Calls GET /discounts
  Future<List<Discount>> getDiscounts() async {
    try {
      final response = await client.get('/discounts');
      return (response as List)
          .map((json) => Discount.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Record a self-reported redemption ("I Used This").
  /// Calls POST /discounts/:id/redeem
  Future<DiscountRedemption> redeemDiscount(String discountId) async {
    try {
      final response = await client.post(
        '/discounts/$discountId/redeem',
        body: {},
      );
      return DiscountRedemption.fromJson(
        response as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch the current user's redemption history.
  /// Calls GET /discounts/my-redemptions (if endpoint exists; otherwise skip).
  /// If the endpoint does NOT exist in the API, UI will derive redemptions
  /// from discount list and track locally.
  Future<List<DiscountRedemption>> getMyRedemptions() async {
    try {
      final response = await client.get('/discounts/my-redemptions');
      return (response as List)
          .map((json) => DiscountRedemption.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If 404 (endpoint doesn't exist), return empty list
      if (e is ApiException && e.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }
}
```

**Wire PerksApi into AppState (packages/social-app/lib/providers/app_state.dart):**

```dart
class AppState extends ChangeNotifier {
  late PerksApi perksApi;

  AppState() {
    final apiClient = ApiClient();
    // ... other APIs
    perksApi = PerksApi(apiClient);
  }
}
```

### 3. perks_screen.dart

**High-level structure:**

```dart
class PerksScreen extends StatefulWidget {
  @override
  State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  late Future<List<Discount>> _discountsFuture;
  Set<String> _redeemedDiscountIds = {}; // Track locally

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    _loadMyRedemptions();
  }

  void _loadDiscounts() {
    _discountsFuture = context.read<AppState>().perksApi.getDiscounts();
  }

  Future<void> _loadMyRedemptions() async {
    try {
      final redemptions = await context.read<AppState>().perksApi.getMyRedemptions();
      setState(() {
        _redeemedDiscountIds = redemptions.map((r) => r.discountId).toSet();
      });
    } catch (e) {
      // Silently fail — UI will just show all buttons as active
    }
  }

  Future<void> _onRefresh() async {
    _loadDiscounts();
    await _discountsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perks')),
      body: FutureBuilder<List<Discount>>(
        future: _discountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Could not load perks. Try again.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(_loadDiscounts);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final discounts = snapshot.data ?? [];
          if (discounts.isEmpty) {
            return const Center(
              child: Text(
                'No perks available right now — check back after the next event',
                textAlign: TextAlign.center,
              ),
            );
          }

          // Group by sponsor, or use flat list sorted by sponsor name
          // Flat list is simpler; group if UX calls for it
          final sortedDiscounts = discounts
            ..sort((a, b) => (a.customerName ?? '').compareTo(b.customerName ?? ''));

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDiscounts.length,
              itemBuilder: (context, index) {
                final discount = sortedDiscounts[index];
                final isRedeemed = _redeemedDiscountIds.contains(discount.id);
                return DiscountCard(
                  discount: discount,
                  isRedeemed: isRedeemed,
                  onTap: () {
                    context.push('/sponsors/${discount.customerId}', extra: discount);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

### 4. sponsor_detail_screen.dart

**High-level structure:**

```dart
class SponsorDetailScreen extends StatefulWidget {
  final String sponsorId;
  final Discount? initialDiscount; // Optional, from navigation extra

  const SponsorDetailScreen({
    required this.sponsorId,
    this.initialDiscount,
  });

  @override
  State<SponsorDetailScreen> createState() => _SponsorDetailScreenState();
}

class _SponsorDetailScreenState extends State<SponsorDetailScreen> {
  late Future<(Customer, List<Discount>)> _dataFuture;
  Set<String> _redeemedDiscountIds = {};
  Set<String> _redeeming = {}; // Track which discounts are currently redeeming

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMyRedemptions();
  }

  void _loadData() {
    _dataFuture = Future.wait([
      // Load sponsor by ID (may not have direct endpoint; derive from discounts)
      // OR use initialDiscount.customerId and load that customer
      context.read<AppState>().perksApi.getDiscounts().then((discounts) {
        final sponsorDiscounts = discounts.where(
          (d) => d.customerId == widget.sponsorId
        ).toList();
        if (sponsorDiscounts.isEmpty) throw 'Sponsor not found';
        // You'll need a way to get Customer by ID; for now, extract from discount
        final customer = Customer(
          id: widget.sponsorId,
          name: sponsorDiscounts.first.customerName ?? 'Sponsor',
          // ... other fields
        );
        return (customer, sponsorDiscounts);
      }),
    ]).then((results) => results[0] as (Customer, List<Discount>));
  }

  Future<void> _loadMyRedemptions() async {
    try {
      final redemptions = await context.read<AppState>().perksApi.getMyRedemptions();
      setState(() {
        _redeemedDiscountIds = redemptions.map((r) => r.discountId).toSet();
      });
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> _redeemDiscount(Discount discount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redeem Perk'),
        content: Text('Did you use this perk at ${discount.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _redeeming.add(discount.id));

    try {
      final redemption = await context.read<AppState>().perksApi.redeemDiscount(discount.id);
      setState(() {
        _redeemedDiscountIds.add(discount.id);
        _redeeming.remove(discount.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perk redeemed!')),
      );
    } catch (e) {
      setState(() => _redeeming.remove(discount.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record redemption. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor Perks')),
      body: FutureBuilder<(Customer, List<Discount>)>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final (customer, discounts) = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Sponsor header
                SponsorHeader(customer: customer),
                const SizedBox(height: 24),
                // Discount list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: discounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final discount = discounts[index];
                    final isRedeemed = _redeemedDiscountIds.contains(discount.id);
                    final isRedeeming = _redeeming.contains(discount.id);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              discount.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              discount.description ?? 'No description',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            if (discount.expiresAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Valid until ${_formatDate(discount.expiresAt!)}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _isExpiringSoon(discount.expiresAt!)
                                    ? Theme.of(context).colorScheme.error
                                    : Colors.grey[500],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isRedeemed || isRedeeming
                                  ? null
                                  : () => _redeemDiscount(discount),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isRedeemed
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                                ),
                                child: isRedeeming
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : Text(isRedeemed
                                    ? 'Used on ${_formatDate(discount.redeemedAt!)}'
                                    : 'I Used This'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Use intl package: DateFormat('MMM d, y').format(date)
    return '${date.month}/${date.day}/${date.year}'; // Simple fallback
  }

  bool _isExpiringSoon(DateTime expiresAt) {
    final now = DateTime.now();
    final daysUntilExpiry = expiresAt.difference(now).inDays;
    return daysUntilExpiry <= 7;
  }
}
```

### 5. discount_card.dart (reusable widget)

```dart
class DiscountCard extends StatelessWidget {
  final Discount discount;
  final bool isRedeemed;
  final VoidCallback onTap;

  const DiscountCard({
    required this.discount,
    required this.isRedeemed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discount.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          discount.customerName ?? 'Sponsor',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (isRedeemed)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (discount.description ?? '').length > 100
                  ? '${(discount.description ?? '').substring(0, 100)}...'
                  : discount.description ?? '',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (discount.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Valid until ${discount.expiresAt!.month}/${discount.expiresAt!.day}/${discount.expiresAt!.year}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

### 6. sponsor_header.dart

```dart
class SponsorHeader extends StatelessWidget {
  final Customer customer;

  const SponsorHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
          ),
          child: customer.logoUrl != null && customer.logoUrl!.isNotEmpty
            ? Image.network(
              customer.logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _logoFallback(context, customer),
            )
            : _logoFallback(context, customer),
        ),
        const SizedBox(height: 16),
        Text(
          customer.name,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          customer.description ?? 'Premium sponsor',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        if (customer.website != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _launchUrl(customer.website!),
            child: Text(
              customer.website!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _logoFallback(BuildContext context, Customer customer) {
    final initial = (customer.name.isNotEmpty ? customer.name[0] : 'S').toUpperCase();
    return CircleAvatar(
      radius: 60,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
```

### 7. Routes (packages/social-app/lib/config/routes.dart)

**Add or verify these routes:**

```dart
GoRoute(
  path: '/perks',
  name: 'perks',
  builder: (context, state) => const PerksScreen(),
),
GoRoute(
  path: '/sponsors/:id',
  name: 'sponsor-detail',
  builder: (context, state) {
    final sponsorId = state.pathParameters['id']!;
    final discount = state.extra as Discount?;
    return SponsorDetailScreen(
      sponsorId: sponsorId,
      initialDiscount: discount,
    );
  },
),
```

### 8. Bottom Nav Integration (packages/social-app/lib/main.dart or app.dart)

**Verify Perks tab exists in bottom nav:**

```dart
// In the main app scaffold, add Perks to BottomNavigationBar
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
    BottomNavigationBarItem(icon: Icon(Icons.handshake), label: 'Connect'),
    BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
    BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
    BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Perks'), // <- Add this
  ],
  onTap: (index) {
    // Navigate to /perks on index 4
    if (index == 4) context.go('/perks');
  },
)
```

Or if using a top-level GoRouter navigation approach, ensure `/perks` is in the route tree.

---

## Test Suite

### Widget Tests (packages/social-app/test/)

**perks_screen_test.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

class MockPerksApi extends Mock implements PerksApi {}
class MockAppState extends Mock implements AppState {
  late MockPerksApi _perksApi;
  @override
  PerksApi get perksApi => _perksApi;
}

void main() {
  group('PerksScreen', () => {
    testWidgets('loads and displays discounts on init', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      when(mockPerksApi.getDiscounts()).thenAnswer(
        (_) async => [
          Discount(id: '1', title: 'Haircut', customerName: 'Style Studio'),
          Discount(id: '2', title: 'Photoshoot', customerName: 'Photo Co'),
        ],
      );
      when(mockPerksApi.getMyRedemptions()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(home: PerksScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Haircut'), findsOneWidget);
      expect(find.text('Photoshoot'), findsOneWidget);
    });

    testWidgets('shows empty state when no discounts', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      when(mockPerksApi.getDiscounts()).thenAnswer((_) async => []);
      when(mockPerksApi.getMyRedemptions()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(home: PerksScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No perks available right now — check back after the next event'),
        findsOneWidget,
      );
    });

    testWidgets('pull-to-refresh reloads discounts', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      when(mockPerksApi.getDiscounts()).thenAnswer(
        (_) async => [Discount(id: '1', title: 'Haircut', customerName: 'Studio')],
      );
      when(mockPerksApi.getMyRedemptions()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(home: PerksScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
      await tester.pumpAndSettle();

      verify(mockPerksApi.getDiscounts()).called(greaterThan(1));
    });

    testWidgets('shows error state and retry button on API failure', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      when(mockPerksApi.getDiscounts())
        .thenThrow(Exception('Network error'));
      when(mockPerksApi.getMyRedemptions()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(home: PerksScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Could not load perks. Try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
```

**sponsor_detail_screen_test.dart:**

```dart
void main() {
  group('SponsorDetailScreen', () {
    testWidgets('calls redeemDiscount and updates UI on success', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      final discount = Discount(
        id: '1',
        title: 'Haircut',
        customerId: 'sponsor-1',
        customerName: 'Style Studio',
      );

      when(mockPerksApi.getDiscounts()).thenAnswer(
        (_) async => [discount],
      );
      when(mockPerksApi.getMyRedemptions()).thenAnswer((_) async => []);
      when(mockPerksApi.redeemDiscount('1')).thenAnswer(
        (_) async => DiscountRedemption(
          userId: 'user-1',
          discountId: '1',
          redeemedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(
            home: SponsorDetailScreen(
              sponsorId: 'sponsor-1',
              initialDiscount: discount,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "I Used This" button
      await tester.tap(find.text('I Used This'));
      await tester.pump();

      // Confirm dialog
      expect(find.text('Did you use this perk at Style Studio?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      // Verify button changed
      expect(find.text('Used on'), findsOneWidget);
      verify(mockPerksApi.redeemDiscount('1')).called(1);
    });

    testWidgets('already-redeemed discount shows locked button', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      final discount = Discount(
        id: '1',
        title: 'Haircut',
        customerId: 'sponsor-1',
        customerName: 'Style Studio',
      );

      when(mockPerksApi.getDiscounts()).thenAnswer(
        (_) async => [discount],
      );
      when(mockPerksApi.getMyRedemptions()).thenAnswer(
        (_) async => [
          DiscountRedemption(
            userId: 'user-1',
            discountId: '1',
            redeemedAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(
            home: SponsorDetailScreen(
              sponsorId: 'sponsor-1',
              initialDiscount: discount,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Button should show "Used on {date}"
      expect(find.byWidgetPredicate(
        (widget) => widget is ElevatedButton && widget.onPressed == null,
      ), findsOneWidget);
    });

    testWidgets('API error shows snackbar', (tester) async {
      final mockPerksApi = MockPerksApi();
      final mockAppState = MockAppState();
      mockAppState._perksApi = mockPerksApi;

      final discount = Discount(
        id: '1',
        title: 'Haircut',
        customerId: 'sponsor-1',
        customerName: 'Style Studio',
      );

      when(mockPerksApi.getDiscounts()).thenAnswer(
        (_) async => [discount],
      );
      when(mockPerksApi.getMyRedemptions()).thenAnswer((_) async => []);
      when(mockPerksApi.redeemDiscount('1'))
        .thenThrow(Exception('Server error'));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          child: MaterialApp(
            home: SponsorDetailScreen(
              sponsorId: 'sponsor-1',
              initialDiscount: discount,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('I Used This'));
      await tester.pump();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(find.text('Could not record redemption. Try again.'), findsOneWidget);
      // Button should still be active
      expect(find.text('I Used This'), findsOneWidget);
    });
  });
}
```

### Smoke Tests (post-deploy)

```bash
# Verify /discounts endpoint exists and returns valid discount list
RESPONSE=$(curl -s "$API_URL/discounts" \
  -H "Authorization: Bearer $TEST_TOKEN")
echo "$RESPONSE" | jq -e '.[0].title' > /dev/null || \
  (echo "FAIL: /discounts endpoint invalid" && exit 1)

# Verify /discounts/:id/redeem endpoint accepts POST
RESPONSE=$(curl -s -X POST "$API_URL/discounts/$SAMPLE_DISCOUNT_ID/redeem" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
echo "$RESPONSE" | jq -e '.redeemedAt' > /dev/null || \
  (echo "FAIL: /discounts/:id/redeem response invalid" && exit 1)

echo "✓ A3 smoke tests passed"
```

---

## Definition of Done

- [ ] PerksApi fully implemented in packages/shared/lib/api/perks_api.dart
- [ ] perks_screen.dart: loads discounts, shows empty/loading/error states, pull-to-refresh works
- [ ] sponsor_detail_screen.dart: displays sponsor info, all their discounts, "I Used This" button with confirmation dialog
- [ ] Button UX: active state (purple) → tap → confirm → redeeming (spinner) → success ("✓ Used {date}", greyed, disabled)
- [ ] Redemption state tracked locally (Set<String> of redeemed discountIds)
- [ ] On screen init: calls getMyRedemptions() to load prior redemptions and pre-populate button states
- [ ] Navigation: `/perks` route exists; tap discount → `/sponsors/:id`
- [ ] Bottom nav Perks tab added and wired to `/perks` route
- [ ] All routes tested in GoRouter config
- [ ] Widget tests pass: `cd packages/social-app && flutter test`
- [ ] Flutter build succeeds: `cd packages/social-app && flutter build apk` (or iOS)
- [ ] `dart run build_runner build` runs clean in packages/shared (if models changed)
- [ ] Manual test: browse perks, tap discount, confirm redemption, button locks
- [ ] Manual test: re-open app, already-redeemed perks show locked button
- [ ] Smoke tests pass against dev API
- [ ] No existing passing tests broken
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/A3-perks-sponsors`
**Model used:** —
**Date completed:** —

### What I implemented exactly as specced
-

### What I deviated from the spec and why
-

### What I deferred or left incomplete
-

### Technical debt introduced
-

### What happens next (Track B / C / integration planning)
-

---

## Interrogative Session

**Q1 (Agent):** Do the "I Used This" button state transitions feel snappy and clear to the user — does the success feedback (✓ Used) feel immediate?
> Jeff:

**Q2 (Agent):** When a user is offline or the API is slow, does the redemption flow degrade gracefully, or does it hang?
> Jeff:

**Q3 (Agent):** Are there any edge cases in the sponsor logo fallback, date formatting, or empty state copy that could confuse users?
> Jeff:

**Q4 (Agent):** Should redemptions persist in local cache if the user dismisses the app and comes back later (not yet redeemed)? Or does UI always check the API on screen init?
> Jeff:

**Q5 (Agent):** Is the discount sorting/grouping by sponsor name sufficient, or would users benefit from sorting by expiry date or "most popular"?
> Jeff:

**Ready for review:** ☐ Yes

---

## Track A Completion Note

After A3 merges to `integration`, **Track A is complete.** The full social app user journey is now operational:

- ✓ Authentication (phone → SMS → JWT)
- ✓ Onboarding (profile + specialties)
- ✓ Event browsing + check-in
- ✓ QR-scan networking (connections)
- ✓ Community feed (posts + comments + likes)
- ✓ User search + profile viewing
- ✓ **Perks + redemption** (this prompt)

The platform is ready for closed beta testing with creative professionals. All core retention loops are wired. Next: Track B (Admin App) and Track C (Platform Operations) run in parallel to complete the full product launch.

**Track A metrics (post-completion):**
- Onboarded users: 0→100+ (beta phase)
- Events created: 0→5-10 (monthly)
- Avg. connections per user: 3-5 per event
- Feed engagement: 20-30% of active users posting
- Perk redemption rate: TBD (baseline on first beta event)
