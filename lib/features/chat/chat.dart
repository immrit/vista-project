// lib/features/chat/chat.dart
//
// فایل Export اصلی برای Feature چت
//
// استفاده:
// ```dart
// import 'package:vista/features/chat/chat.dart';
// ```

// ═══════════════════════════════════════════════════════════════════════════
// 📦 MODELS
// ═══════════════════════════════════════════════════════════════════════════
export '../../model/message_model.dart';
export '../../model/conversation_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🗄️ REPOSITORIES
// ═══════════════════════════════════════════════════════════════════════════
export 'repositories/chat_repository.dart';
export 'repositories/chat_repository_impl.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 SERVICES
// ═══════════════════════════════════════════════════════════════════════════
export 'services/chat_cache_service.dart';
export 'services/typing_indicator_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
export 'providers/chat_providers.dart';
export 'providers/paginated_messages_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 📱 SCREENS
// ═══════════════════════════════════════════════════════════════════════════
export 'screens/modern_chat_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🧩 WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
export 'widgets/messages_list.dart';
export 'widgets/message_bubble.dart';
export 'widgets/message_input.dart';
export 'widgets/typing_indicator_widget.dart';

