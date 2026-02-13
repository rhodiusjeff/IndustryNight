import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final error = validatePostContent(_contentController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // TODO: Implement API call
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isSubmitting = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _createPost,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
                style: AppTypography.bodyLarge,
              ),
            ),

            // Action bar
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: () {
                    // TODO: Implement image picker
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    // TODO: Implement camera
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
