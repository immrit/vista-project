import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Provider/publicPostProvider.dart';

class CreatePostWidget extends ConsumerStatefulWidget {
  const CreatePostWidget({super.key});

  @override
  CreatePostWidgetState createState() => CreatePostWidgetState();
}

class CreatePostWidgetState extends ConsumerState<CreatePostWidget> {
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createPostState = ref.watch(createPostProvider);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'متن پست خود را بنویسید...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: createPostState.isLoading
                    ? null
                    : () async {
                        if (_contentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('لطفا متن پست را وارد کنید')),
                          );
                          return;
                        }

                        await ref.read(createPostProvider.notifier).createPost(
                              content: _contentController.text.trim(),
                            );

                        if (mounted) {
                          _contentController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('پست با موفقیت ارسال شد')),
                          );
                        }
                      },
                child: createPostState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ارسال پست'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
