import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../widgets/post_card.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/community/create'),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10, // TODO: Replace with actual data
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PostCard(
              postId: 'post_$index',
              authorName: 'User ${index + 1}',
              authorImageUrl: null,
              content:
                  'Just wrapped up an amazing shoot! So grateful to work with such talented people. #industrynight #creative',
              likeCount: index * 5,
              commentCount: index * 2,
              timeAgo: '${index + 1}h ago',
              onTap: () => context.push('/community/post/post_$index'),
              onLike: () {},
              onComment: () => context.push('/community/post/post_$index'),
            ),
          );
        },
      ),
    );
  }
}
