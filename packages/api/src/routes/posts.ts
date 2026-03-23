import { Router } from 'express';
import { z } from 'zod';
import { validate, paginationSchema } from '../middleware/validation';
import { authenticate, optionalAuth } from '../middleware/auth';
import { query, queryOne } from '../config/database';
import { NotFoundError, ForbiddenError } from '../utils/errors';

const router = Router();

// Get feed
const getFeedSchema = paginationSchema.extend({
  query: paginationSchema.shape.query.extend({
    type: z.enum(['general', 'collaboration', 'job', 'announcement']).optional(),
  }),
});

router.get('/', optionalAuth, validate(getFeedSchema), async (req, res, next) => {
  try {
    const { type, limit = 20, offset = 0 } = req.query as unknown as {
      type?: string;
      limit: number;
      offset: number;
    };
    const userId = req.user?.userId;

    let whereClause = 'WHERE p.is_hidden = false';
    const params: unknown[] = [];
    let paramIndex = 1;

    if (type) {
      whereClause += ` AND p.type = $${paramIndex++}`;
      params.push(type);
    }

    let likeSubquery = 'false as is_liked_by_current_user';
    if (userId) {
      likeSubquery = `EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_id = $${paramIndex++}::uuid) as is_liked_by_current_user`;
      params.push(userId);
    }

    params.push(limit, offset);

    const posts = await query(
      `SELECT p.*,
              u.name as author_name, u.profile_photo_url as author_photo,
              ${likeSubquery}
       FROM posts p
       JOIN users u ON p.author_id = u.id
       ${whereClause}
       ORDER BY p.is_pinned DESC, p.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json({ posts });
  } catch (error) {
    next(error);
  }
});

// Get post by ID
router.get('/:id', optionalAuth, async (req, res, next) => {
  try {
    const userId = req.user?.userId;
    const params: unknown[] = [req.params.id];

    let likeSubquery = 'false as is_liked_by_current_user';
    if (userId) {
      likeSubquery = `EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_id = $2::uuid) as is_liked_by_current_user`;
      params.push(userId);
    }

    const post = await queryOne(
      `SELECT p.*,
              u.name as author_name, u.profile_photo_url as author_photo,
              ${likeSubquery}
       FROM posts p
       JOIN users u ON p.author_id = u.id
       WHERE p.id = $1`,
      params
    );

    if (!post) {
      throw new NotFoundError('Post not found');
    }

    res.json({ post });
  } catch (error) {
    next(error);
  }
});

// Create post
const createPostSchema = z.object({
  body: z.object({
    content: z.string().min(1).max(2000),
    type: z.enum(['general', 'collaboration', 'job']).default('general'),
  }),
});

router.post('/', authenticate, validate(createPostSchema), async (req, res, next) => {
  try {
    const { content, type } = req.body;

    const post = await queryOne(
      `INSERT INTO posts (author_id, content, type)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [req.user!.userId, content, type]
    );

    res.status(201).json({ post });
  } catch (error) {
    next(error);
  }
});

// Update post
const updatePostSchema = z.object({
  body: z.object({
    content: z.string().min(1).max(2000),
  }),
});

router.patch('/:id', authenticate, validate(updatePostSchema), async (req, res, next) => {
  try {
    const existing = await queryOne<{ author_id: string }>(
      'SELECT author_id FROM posts WHERE id = $1',
      [req.params.id]
    );

    if (!existing) {
      throw new NotFoundError('Post not found');
    }

    if (existing.author_id !== req.user!.userId) {
      throw new ForbiddenError('Cannot edit this post');
    }

    const post = await queryOne(
      `UPDATE posts SET content = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [req.body.content, req.params.id]
    );

    res.json({ post });
  } catch (error) {
    next(error);
  }
});

// Delete post
router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    const existing = await queryOne<{ author_id: string }>(
      'SELECT author_id FROM posts WHERE id = $1',
      [req.params.id]
    );

    if (!existing) {
      throw new NotFoundError('Post not found');
    }

    if (existing.author_id !== req.user!.userId && req.user!.role !== 'platformAdmin') {
      throw new ForbiddenError('Cannot delete this post');
    }

    await query('DELETE FROM posts WHERE id = $1', [req.params.id]);

    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

// Like post
router.post('/:id/like', authenticate, async (req, res, next) => {
  try {
    await query(
      `INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [req.params.id, req.user!.userId]
    );

    await query(
      `UPDATE posts SET like_count = (SELECT COUNT(*) FROM post_likes WHERE post_id = $1) WHERE id = $1`,
      [req.params.id]
    );

    const post = await queryOne('SELECT * FROM posts WHERE id = $1', [req.params.id]);
    res.json({ post });
  } catch (error) {
    next(error);
  }
});

// Unlike post
router.delete('/:id/like', authenticate, async (req, res, next) => {
  try {
    await query(
      'DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2',
      [req.params.id, req.user!.userId]
    );

    await query(
      `UPDATE posts SET like_count = (SELECT COUNT(*) FROM post_likes WHERE post_id = $1) WHERE id = $1`,
      [req.params.id]
    );

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

// Get comments
router.get('/:id/comments', async (req, res, next) => {
  try {
    const comments = await query(
      `SELECT c.*, u.name as author_name, u.profile_photo_url as author_photo
       FROM post_comments c
       JOIN users u ON c.author_id = u.id
       WHERE c.post_id = $1
       ORDER BY c.created_at ASC`,
      [req.params.id]
    );

    res.json({ comments });
  } catch (error) {
    next(error);
  }
});

// Add comment
const addCommentSchema = z.object({
  body: z.object({
    content: z.string().min(1).max(500),
  }),
});

router.post('/:id/comments', authenticate, validate(addCommentSchema), async (req, res, next) => {
  try {
    const comment = await queryOne(
      `INSERT INTO post_comments (post_id, author_id, content)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [req.params.id, req.user!.userId, req.body.content]
    );

    await query(
      `UPDATE posts SET comment_count = comment_count + 1 WHERE id = $1`,
      [req.params.id]
    );

    res.status(201).json({ comment });
  } catch (error) {
    next(error);
  }
});

// Delete comment
router.delete('/:id/comments/:commentId', authenticate, async (req, res, next) => {
  try {
    const { id: postId, commentId } = req.params;
    const userId = req.user!.userId;

    const comment = await queryOne<{ id: string; author_id: string }>(
      `SELECT id, author_id
       FROM post_comments
       WHERE id = $1 AND post_id = $2`,
      [commentId, postId]
    );

    if (!comment) {
      throw new NotFoundError('Comment not found');
    }

    const isAuthor = comment.author_id === userId;
    const isAdmin = req.user!.role === 'platformAdmin';
    if (!isAuthor && !isAdmin) {
      throw new ForbiddenError('Cannot delete this comment');
    }

    await query('DELETE FROM post_comments WHERE id = $1', [commentId]);
    await query(
      `UPDATE posts
       SET comment_count = (SELECT COUNT(*) FROM post_comments WHERE post_id = $1)
       WHERE id = $1`,
      [postId]
    );

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

export default router;
