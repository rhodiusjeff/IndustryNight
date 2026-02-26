import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';

class PostCard extends StatelessWidget {
  final String postId;
  final String authorName;
  final String? authorImageUrl;
  final String content;
  final List<String>? imageUrls;
  final int likeCount;
  final int commentCount;
  final String timeAgo;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;

  const PostCard({
    super.key,
    required this.postId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    this.imageUrls,
    required this.likeCount,
    required this.commentCount,
    required this.timeAgo,
    this.onTap,
    this.onLike,
    this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: authorImageUrl != null
                        ? NetworkImage(authorImageUrl!)
                        : null,
                    backgroundColor: AppColors.surfaceLight,
                    child: authorImageUrl == null
                        ? Text(
                            getInitials(authorName),
                            style: AppTypography.labelMedium,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authorName, style: AppTypography.titleMedium),
                        Text(timeAgo, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Content
              Text(
                content,
                style: AppTypography.bodyMedium,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),

              // Images
              if (imageUrls != null && imageUrls!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrls!.first,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(likeCount),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  InkWell(
                    onTap: onComment,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.comment_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(commentCount),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
