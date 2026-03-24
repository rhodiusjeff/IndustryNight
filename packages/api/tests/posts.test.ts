import request from 'supertest';
import { getApp } from './helpers/app';
import { getTestPool, resetDb } from './helpers/db';
import { createUser, createPost } from './helpers/fixtures';
import { socialToken } from './helpers/auth';
import fs from 'fs';
import path from 'path';

const app = getApp();

beforeEach(async () => {
  await resetDb();
});

describe('Posts route SQL parameterization', () => {
  it('does not interpolate request data into SQL template literals', () => {
    const content = fs.readFileSync(
      path.join(__dirname, '../src/routes/posts.ts'),
      'utf8'
    );

    expect(content).not.toMatch(/\$\{req\.(params|query|body|user)/);
  });
});

describe('DELETE /posts/:id/comments/:commentId', () => {
  it('returns 404 when comment does not exist on post', async () => {
    const user = await createUser();
    const post = await createPost(user.id);
    const token = socialToken(user.id);

    const res = await request(app)
      .delete(`/posts/${post.id}/comments/00000000-0000-0000-0000-000000000000`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('returns 403 when non-author non-admin tries to delete comment', async () => {
    const author = await createUser();
    const otherUser = await createUser();
    const post = await createPost(author.id);
    const pool = getTestPool();
    const commentResult = await pool.query(
      `INSERT INTO post_comments (post_id, author_id, content)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [post.id, author.id, 'author comment']
    );
    const commentId = commentResult.rows[0].id as string;

    const res = await request(app)
      .delete(`/posts/${post.id}/comments/${commentId}`)
      .set('Authorization', `Bearer ${socialToken(otherUser.id)}`);

    expect(res.status).toBe(403);
  });

  it('returns 200 and deletes when author deletes own comment', async () => {
    const author = await createUser();
    const post = await createPost(author.id);
    const pool = getTestPool();
    const commentResult = await pool.query(
      `INSERT INTO post_comments (post_id, author_id, content)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [post.id, author.id, 'author comment']
    );
    const commentId = commentResult.rows[0].id as string;

    const res = await request(app)
      .delete(`/posts/${post.id}/comments/${commentId}`)
      .set('Authorization', `Bearer ${socialToken(author.id)}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const check = await pool.query('SELECT id FROM post_comments WHERE id = $1', [
      commentId,
    ]);
    expect(check.rows).toHaveLength(0);
  });

  it('returns 200 when admin deletes any comment', async () => {
    const author = await createUser();
    const adminUser = await createUser({ role: 'platformAdmin' });
    const post = await createPost(author.id);
    const pool = getTestPool();
    const commentResult = await pool.query(
      `INSERT INTO post_comments (post_id, author_id, content)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [post.id, author.id, 'author comment']
    );
    const commentId = commentResult.rows[0].id as string;

    const res = await request(app)
      .delete(`/posts/${post.id}/comments/${commentId}`)
      .set('Authorization', `Bearer ${socialToken(adminUser.id, 'platformAdmin')}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

describe('DELETE /posts/:id/like', () => {
  it('returns 200 with success payload', async () => {
    const user = await createUser();
    const post = await createPost(user.id);
    const token = socialToken(user.id);

    await request(app)
      .post(`/posts/${post.id}/like`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const res = await request(app)
      .delete(`/posts/${post.id}/like`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ success: true });
  });
});
