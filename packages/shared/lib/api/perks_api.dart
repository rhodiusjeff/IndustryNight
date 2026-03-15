import 'api_client.dart';
import '../models/customer.dart';
import '../models/discount.dart';

/// API client for social-side sponsor/discount/redemption endpoints
class PerksApi {
  final ApiClient _client;

  PerksApi(this._client);

  /// Get active sponsors (customers with sponsorship products)
  Future<List<Customer>> getSponsors() async {
    final response = await _client.get<Map<String, dynamic>>('/sponsors');
    return (response['sponsors'] as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get sponsor detail with active discounts
  Future<Customer> getSponsor(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/sponsors/$id');
    return Customer.fromJson(response['sponsor'] as Map<String, dynamic>);
  }

  /// Get all active discounts across all customers
  Future<List<Discount>> getDiscounts() async {
    final response = await _client.get<Map<String, dynamic>>('/discounts');
    return (response['discounts'] as List)
        .map((e) => Discount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Record a discount redemption ("I Used This")
  Future<void> redeemDiscount(String discountId) async {
    await _client.post<Map<String, dynamic>>(
      '/discounts/$discountId/redeem',
      body: {'method': 'self_reported'},
    );
  }

  /// Check if the current user has already redeemed a discount
  Future<bool> hasRedeemed(String discountId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/discounts/$discountId/redeemed',
    );
    return response['redeemed'] as bool;
  }
}
