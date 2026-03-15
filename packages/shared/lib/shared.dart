/// Industry Night shared library
///
/// Contains models, API client, constants, and utilities shared between
/// the mobile app and web admin dashboard.
library industrynight_shared;

// Models
export 'models/user.dart';
export 'models/admin_user.dart';
export 'models/event.dart';
export 'models/event_image.dart';
export 'models/connection.dart';
export 'models/post.dart';
export 'models/market.dart';
export 'models/customer.dart';
export 'models/customer_contact.dart';
export 'models/customer_media_item.dart';
export 'models/product.dart';
export 'models/customer_product.dart';
export 'models/discount.dart';
export 'models/discount_redemption.dart';
export 'models/ticket.dart';

// API
export 'api/api_client.dart';
export 'api/auth_api.dart';
export 'api/admin_auth_api.dart';
export 'api/users_api.dart';
export 'api/events_api.dart';
export 'api/connections_api.dart';
export 'api/posts_api.dart';
export 'api/admin_api.dart';
export 'api/perks_api.dart';

// Constants
export 'constants/specialties.dart';
export 'constants/verification_status.dart';

// Config
export 'config/app_config.dart';

// Utils
export 'utils/validators.dart';
export 'utils/formatters.dart';
export 'utils/storage.dart';
