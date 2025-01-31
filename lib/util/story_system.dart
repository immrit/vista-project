// // story_system.dart
// import 'dart:async';
// import 'dart:io';
// import 'package:Vista/main.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path/path.dart' as path;
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:uuid/uuid.dart';
// import 'package:mime/mime.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// import '../../../provider/uploadStoryImage.dart';

// // -------------------- مدل‌های داده --------------------
// @immutable
// class StoryUser {
//   final String id;
//   final String username;
//   final String? profileImageUrl;
//   final DateTime? lastStoryDate;
//   final List<AppStoryContent> stories;

//   const StoryUser({
//     required this.id,
//     required this.username,
//     this.profileImageUrl,
//     this.lastStoryDate,
//     this.stories = const [],
//   });

//   StoryUser copyWith({
//     List<AppStoryContent>? stories,
//     DateTime? lastStoryDate,
//   }) {
//     return StoryUser(
//       id: id,
//       username: username,
//       profileImageUrl: profileImageUrl,
//       stories: stories ?? this.stories,
//       lastStoryDate: lastStoryDate ?? this.lastStoryDate,
//     );
//   }
// }

// class AppStoryContent {
//   final String? id;
//   final String mediaUrl;
//   final DateTime createdAt;
//   final Duration duration;
//   final String? userId;

//   const AppStoryContent({
//     this.id,
//     required this.mediaUrl,
//     required this.createdAt,
//     this.userId,
//     this.duration = const Duration(seconds: 7),
//   });
// }

// enum MediaType { image, video }

// class Story {
//   final String id;
//   final String userId;
//   final String mediaUrl;
//   final String? caption;
//   final DateTime createdAt;
//   final DateTime expiresAt;
//   final bool isViewed;
//   final String mediaType;
//   final int viewsCount; // اضافه کردن تعداد بازدیدها

//   Story({
//     required this.id,
//     required this.userId,
//     required this.mediaUrl,
//     this.caption,
//     required this.createdAt,
//     required this.expiresAt,
//     this.isViewed = false,
//     required this.mediaType,
//     this.viewsCount = 0, // مقدار پیش‌فرض
//   });

//   factory Story.fromMap(Map<String, dynamic> map) {
//     return Story(
//       id: map['id']?.toString() ?? '',
//       userId: map['user_id']?.toString() ?? '',
//       mediaUrl: map['media_url'] ?? '',
//       caption: map['caption'],
//       createdAt:
//           DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
//       expiresAt: DateTime.parse(map['expires_at'] ??
//           DateTime.now().add(const Duration(hours: 24)).toIso8601String()),
//       isViewed: map['is_viewed'] ?? false,
//       mediaType: map['media_type'] ?? 'image',
//       viewsCount: map['views_count'] ?? 0, // اضافه کردن تعداد بازدیدها
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'user_id': userId,
//       'media_url': mediaUrl,
//       'caption': caption,
//       'created_at': createdAt.toIso8601String(),
//       'expires_at': expiresAt.toIso8601String(),
//       'media_type': mediaType,
//       'views_count': viewsCount, // اضافه کردن تعداد بازدیدها
//     };
//   }
// }

// // -------------------- سرویس Supabase --------------------
// class StoryService {
//   final SupabaseClient _client;
//   static final _uuid = const Uuid();

//   StoryService() : _client = supabase;

//   Future<List<StoryUser>> fetchActiveUsers() async {
//     final response = await _client.from('stories').select('''
//         user_id,
//         profiles!inner(username, avatar_url),
//         media_url,
//         created_at
//       ''').order('created_at', ascending: false).limit(100);

//     final usersMap = <String, StoryUser>{};

//     for (final item in response) {
//       final userId = item['user_id'] as String;
//       final story = AppStoryContent(
//         mediaUrl: item['media_url'] as String,
//         createdAt: DateTime.parse(item['created_at'] as String),
//       );

//       if (!usersMap.containsKey(userId)) {
//         usersMap[userId] = StoryUser(
//           id: userId,
//           username: item['profiles']['username'] as String,
//           profileImageUrl: item['profiles']['avatar_url'] as String?,
//           lastStoryDate: DateTime.parse(item['created_at'] as String),
//           stories: [story], // اضافه کردن استوری به لیست
//         );
//       } else {
//         usersMap[userId] = usersMap[userId]!.copyWith(
//           stories: [...usersMap[userId]!.stories, story],
//         );
//       }
//     }

//     return usersMap.values.toList();
//   }

//   Future<Map<String, dynamic>> uploadImageStory(File imageFile) async {
//     try {
//       _validateImageFile(imageFile);

//       final userId = _client.auth.currentUser?.id;
//       if (userId == null) {
//         throw Exception('User not authenticated');
//       }

//       final imageUrl =
//           await StoryImageUploadService.uploadStoryImage(imageFile);
//       if (imageUrl == null) {
//         throw Exception('Failed to upload image');
//       }

//       final storyId = _uuid.v4(); // Generate UUID for story

//       final insertResponse = await _client
//           .from('stories')
//           .insert({
//             'id': storyId, // Add explicit ID
//             'user_id': userId,
//             'media_url': imageUrl,
//             'media_type': 'image',
//             'created_at': DateTime.now().toIso8601String(),
//             'expires_at':
//                 DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
//           })
//           .select()
//           .single();

//       print('Story created with ID: ${insertResponse['id']}');
//       return insertResponse;
//     } catch (e) {
//       print('Error uploading story: $e');
//       rethrow;
//     }
//   }

//   Future<void> uploadStory(String userId, String filePath) async {
//     try {
//       final imageUrl = await _uploadImage(userId, filePath);

//       final res = await _client.from('stories').insert({
//         'id': const Uuid().v4(),
//         'user_id': userId,
//         'media_url': imageUrl,
//         'media_type': 'image',
//         'status': 'active',
//         'is_active': true,
//         'created_at': DateTime.now().toIso8601String(),
//         'expires_at': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
//       }).select();

//       if (res.isEmpty) {
//         throw Exception('خطای دیتابیس: پاسخ خالی از سرور دریافت شد');
//       }

//       final insertedData = res.first;
//       print('استوری با موفقیت ذخیره شد: ${insertedData['id']}');
//     } catch (error) {
//       print('Error uploading story: $error');
//       throw Exception('خطا در آپلود استوری: ${error.toString()}');
//     }
//   }

//   Future<String> _uploadImage(String userId, String filePath) async {
//     try {
//       final fileExtension = path.extension(filePath);
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final storageFileName = '${timestamp}_compressed$fileExtension';
//       final storageKey = 'stories/$userId/$storageFileName';

//       // Upload file
//       await _client.storage.from('coffevista').upload(
//             storageKey,
//             File(filePath),
//             fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
//           );

//       // Get public URL
//       return _client.storage.from('coffevista').getPublicUrl(storageKey);
//     } catch (error) {
//       print('Error uploading image: $error');
//       throw Exception('Failed to upload image: $error');
//     }
//   }

//   void _validateImageFile(File file) {
//     const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
//     final mimeType = lookupMimeType(file.path);

//     if (mimeType == null || !allowedTypes.contains(mimeType)) {
//       throw Exception('فقط مجاز به آپلود تصویر (JPEG, PNG, GIF) هستید');
//     }

//     final sizeInMB = file.lengthSync() / (1024 * 1024);
//     if (sizeInMB > 15) {
//       throw Exception('حداکثر سایز فایل ۱۵ مگابایت است');
//     }
//   }

//   Future<String> createStory(String userId, String mediaUrl) async {
//     try {
//       final storyId = const Uuid().v4(); // تولید UUID برای story_id
//       final response = await _client
//           .from('stories')
//           .insert({
//             'id': storyId, // استفاده از UUID
//             'user_id': userId,
//             'media_url': mediaUrl,
//             'media_type': 'image',
//             'created_at': DateTime.now().toIso8601String(),
//             'expires_at':
//                 DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
//           })
//           .select()
//           .single();

//       print('Story created with ID: $storyId');
//       return storyId;
//     } catch (e) {
//       print('Error creating story: $e');
//       throw Exception('Failed to create story: $e');
//     }
//   }

//   Future<void> trackStoryView(String storyId) async {
//     try {
//       final userId = supabase.auth.currentUser?.id;
//       if (userId == null) throw 'User not authenticated';

//       await supabase.from('story_views').insert({
//         'story_id': storyId,
//         'viewer_id': userId,
//       });

//       debugPrint('Story view tracked successfully');
//     } catch (e) {
//       debugPrint('Error tracking story view: $e');
//       throw 'Failed to track story view';
//     }
//   }

//   Future<Map<String, dynamic>> getStoryAnalytics(String storyId) async {
//     try {
//       final response = await supabase
//           .from('story_analytics')
//           .select()
//           .eq('story_id', storyId)
//           .single();

//       return response;
//     } catch (e) {
//       debugPrint('Error fetching story analytics: $e');
//       throw 'Failed to fetch story analytics';
//     }
//   }
// }

// // -------------------- Riverpod Providers --------------------
// final storyServiceProvider = Provider<StoryService>((ref) {
//   return StoryService();
// });

// final storyUsersProvider = FutureProvider.autoDispose<List<StoryUser>>((ref) {
//   final service = ref.watch(storyServiceProvider);
//   return service.fetchActiveUsers();
// });

// final currentStoryProvider = StateProvider<AppStoryContent?>((ref) => null);

// // -------------------- ویجت‌ها --------------------
// class StoryBar extends ConsumerWidget {
//   const StoryBar({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final storiesAsync = ref.watch(storyUsersProvider);

//     return SizedBox(
//       height: 100,
//       child: storiesAsync.when(
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (err, _) => _ErrorView(error: err.toString()),
//         data: (users) => ListView.builder(
//           scrollDirection: Axis.horizontal,
//           itemCount: users.length + 1,
//           itemBuilder: (ctx, index) {
//             if (index == 0) return const _AddStoryButton();
//             return _StoryRing(user: users[index - 1]);
//           },
//         ),
//       ),
//     );
//   }
// }

// class _StoryRing extends StatelessWidget {
//   final StoryUser user;

//   const _StoryRing({required this.user});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Column(
//         children: [
//           GestureDetector(
//             onTap: () => _navigateToStoryScreen(context, user),
//             child: Container(
//               width: 70,
//               height: 70,
//               decoration: BoxDecoration(
//                 gradient: user.stories.isNotEmpty
//                     ? const LinearGradient(
//                         colors: [Colors.purple, Colors.orange],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       )
//                     : null,
//                 shape: BoxShape.circle,
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(3.0),
//                 child: CircleAvatar(
//                   backgroundImage: CachedNetworkImageProvider(
//                     user.profileImageUrl ??
//                         AssetImage('/lib/util/images/default-avatar.jpg')
//                             .assetName,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(user.username, style: const TextStyle(fontSize: 12))
//         ],
//       ),
//     );
//   }

//   void _navigateToStoryScreen(BuildContext context, StoryUser user) {
//     if (user.stories.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('هیچ استوری برای نمایش وجود ندارد')),
//       );
//       return;
//     }

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => StoryPlayerScreen(
//           initialUser: user,
//           users: [user],
//         ),
//       ),
//     );
//   }
// }

// class _AddStoryButton extends ConsumerWidget {
//   const _AddStoryButton();

//   Future<void> _handleImageUpload(BuildContext context, WidgetRef ref) async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 85,
//       maxWidth: 1080,
//     );

//     if (pickedFile != null) {
//       try {
//         final service = ref.read(storyServiceProvider);
//         await service.uploadImageStory(File(pickedFile.path));

//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('استوری با موفقیت اضافه شد')),
//           );
//           ref.invalidate(storyUsersProvider);
//         }
//       } catch (e) {
//         if (context.mounted) {
//           print('خطا $e');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('خطا: ${e.toString()}')),
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: GestureDetector(
//         onTap: () => _handleImageUpload(context, ref),
//         child: Column(
//           children: [
//             Container(
//               width: 70,
//               height: 70,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade300),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.add, size: 30),
//             ),
//             const Text('افزودن استوری'),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class StoryItem {
//   final ImageProvider image;
//   final Duration duration;

//   StoryItem({
//     required this.image,
//     required this.duration,
//   });
// }

// class StoryController {
//   int currentStoryIndex = 0;
//   double currentStoryProgress = 0.0;

//   void nextStory() {
//     currentStoryIndex++;
//     currentStoryProgress = 0.0;
//   }

//   void previousStory() {
//     if (currentStoryIndex > 0) {
//       currentStoryIndex--;
//       currentStoryProgress = 0.0;
//     }
//   }

//   void dispose() {
//     // رهاسازی منابع اگر لازم است
//   }
// }

// // بخش اصلاحی StoryPlayerScreen
// class StoryPlayerScreen extends ConsumerStatefulWidget {
//   final StoryUser initialUser;
//   final List<StoryUser> users;

//   const StoryPlayerScreen({
//     required this.initialUser,
//     required this.users,
//     super.key,
//   });

//   @override
//   ConsumerState<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
// }

// class _StoryPlayerScreenState extends ConsumerState<StoryPlayerScreen>
//     with SingleTickerProviderStateMixin {
//   late final PageController _pageController;
//   late final StoryController _storyController;
//   late AnimationController _animationController;
//   late Timer _progressTimer;

//   int _currentUserIndex = 0;
//   int _currentStoryIndex = 0; // تغییر به متغیر قابل تغییر

//   Future<void> trackStoryView(String storyId, String viewerId) async {
//     try {
//       debugPrint(
//           'Attempting to track story view - Story ID: $storyId, Viewer ID: $viewerId');

//       if (storyId.isEmpty || viewerId.isEmpty) {
//         throw Exception('Story ID or Viewer ID is empty');
//       }

//       final response = await supabase.from('story_views').insert({
//         'story_id': storyId,
//         'viewer_id': viewerId,
//         'viewed_at': DateTime.now().toIso8601String(),
//       }).select();

//       debugPrint('Story view tracked successfully: $response');
//     } catch (e) {
//       debugPrint('Error tracking story view: $e');
//       throw Exception('Failed to track story view: $e');
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _currentUserIndex = widget.users.indexOf(widget.initialUser);
//     _currentStoryIndex = 0;

//     _pageController = PageController(initialPage: _currentStoryIndex);
//     _storyController = StoryController();

//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 7),
//     )..addListener(_handleAnimationProgress);

//     // تاخیر در شروع برای اطمینان از آماده بودن ویجت
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _startTimer();
//       _trackCurrentStory();
//     });
//   }

//   void _trackCurrentStory() async {
//     final currentUserId = supabase.auth.currentUser?.id;
//     if (currentUserId == null) {
//       debugPrint('Error: Current user ID is null');
//       return;
//     }

//     final currentStory = widget.initialUser.stories[_currentStoryIndex];
//     if (currentStory.id == null) {
//       debugPrint(
//           'Error: Story ID is null for story at index $_currentStoryIndex');
//       return;
//     }

//     // فقط اگر بیننده با صاحب استوری متفاوت است، ترک می‌کنیم
//     if (currentUserId != currentStory.userId) {
//       try {
//         debugPrint(
//             'Tracking view for story ${currentStory.id} by user $currentUserId');
//         await trackStoryView(currentStory.id!, currentUserId);
//       } catch (e) {
//         debugPrint('Failed to track story view: $e');
//       }
//     }
//   }

//   void _startTimer() {
//     _animationController.reset();
//     _animationController.forward();
//     _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
//       if (!_animationController.isAnimating) {
//         _animationController.forward();
//       }
//     });
//   }

//   void _handleAnimationProgress() {
//     if (!mounted) return;

//     final progress = _animationController.value;
//     _storyController.currentStoryProgress = progress;

//     if (progress >= 1.0) {
//       _handleNextStory();
//     }
//   }

//   void _handleNextStory() {
//     if (_currentStoryIndex < widget.initialUser.stories.length - 1) {
//       setState(() {
//         _currentStoryIndex++;
//         _pageController.nextPage(
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeInOut,
//         );
//       });
//       _animationController.reset();
//       _trackCurrentStory();
//     } else {
//       Navigator.pop(context);
//     }
//   }

//   void _handlePreviousStory() {
//     if (_currentStoryIndex > 0) {
//       setState(() {
//         _currentStoryIndex--;
//         _pageController.previousPage(
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeInOut,
//         );
//       });
//       _animationController.reset();
//       _trackCurrentStory();
//     }
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     _storyController.dispose();
//     _animationController.dispose();
//     _progressTimer.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GestureDetector(
//         onTapDown: (details) {
//           final screenWidth = MediaQuery.of(context).size.width;
//           final tapPosition = details.globalPosition.dx;

//           if (tapPosition < screenWidth * 0.35) {
//             _handlePreviousStory();
//           } else if (tapPosition > screenWidth * 0.65) {
//             _handleNextStory();
//           } else {
//             if (_animationController.isAnimating) {
//               _animationController.stop();
//             } else {
//               _animationController.forward();
//             }
//           }
//         },
//         child: Stack(
//           children: [
//             PageView.builder(
//               controller: _pageController,
//               physics: const NeverScrollableScrollPhysics(),
//               onPageChanged: (index) {
//                 setState(() {
//                   _currentStoryIndex = index;
//                 });
//                 _trackCurrentStory();
//               },
//               itemCount: widget.initialUser.stories.length,
//               itemBuilder: (context, index) {
//                 final story = widget.initialUser.stories[index];
//                 return Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     CachedNetworkImage(
//                       imageUrl: story.mediaUrl,
//                       fit: BoxFit.cover,
//                       placeholder: (context, url) => const Center(
//                         child: CircularProgressIndicator(),
//                       ),
//                       errorWidget: (context, url, error) => const Center(
//                         child: Icon(Icons.error),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//             Positioned(
//               top: 40,
//               right: 20,
//               child: CloseStoryButton(),
//             ),
//             Positioned(
//               top: 30,
//               left: 0,
//               right: 0,
//               child: StoryProgressBar(
//                 controller: _storyController,
//                 itemCount: widget.initialUser.stories.length,
//                 activeColor: Colors.white,
//                 passiveColor: Colors.white.withOpacity(0.4),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class ErrorLogger {
//   void logError(Object error, StackTrace stackTrace) {
//     // پیادهسازی سرویس لاگگیری شما
//     print('❌ Error: $error');
//     print('📌 StackTrace: $stackTrace');

//     // میتوانید این موارد را اضافه کنید:
//     // 1. ارسال به Crashlytics/Firebase
//     // 2. ذخیره در دیتابیس محلی
//     // 3. نمایش به کاربر
//   }
// }

// final errorLoggerProvider = Provider<ErrorLogger>((ref) {
//   return ErrorLogger();
// });

// // کلاس جدید برای ProgressBar
// class StoryProgressBar extends StatelessWidget {
//   final StoryController controller;
//   final int itemCount;
//   final Color activeColor;
//   final Color passiveColor;

//   const StoryProgressBar({
//     required this.controller,
//     required this.itemCount,
//     required this.activeColor,
//     required this.passiveColor,
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//       child: Row(
//         children: List.generate(itemCount, (index) {
//           return Expanded(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 2.0),
//               child: LinearProgressIndicator(
//                 value: index == controller.currentStoryIndex
//                     ? controller.currentStoryProgress
//                     : index < controller.currentStoryIndex
//                         ? 1.0
//                         : 0.0,
//                 backgroundColor: passiveColor,
//                 valueColor: AlwaysStoppedAnimation(activeColor),
//                 minHeight: 2,
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }
// }

// class CloseStoryButton extends StatelessWidget {
//   const CloseStoryButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       icon: Container(
//         decoration: BoxDecoration(
//           color: Colors.black54,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         padding: const EdgeInsets.all(4),
//         child: const Icon(Icons.close, color: Colors.white),
//       ),
//       onPressed: () => Navigator.pop(context),
//     );
//   }
// }

// class _ErrorView extends StatelessWidget {
//   final String error;

//   const _ErrorView({required this.error});
//   print(error) {
//     // TODO: implement print
//     throw UnimplementedError();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.error_outline, color: Colors.red, size: 40),
//           const SizedBox(height: 10),
//           Text('خطا در دریافت داده‌ها',
//               style: Theme.of(context).textTheme.titleMedium),
//           Text(error, style: const TextStyle(color: Colors.grey)),
//         ],
//       ),
//     );
//   }
// }
