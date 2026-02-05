# Vista Node Feed (Tag-Based Personalized Feed v1)

This folder contains a minimal Node.js (Express) implementation of a Twitter/Threads-like "For You" feed **without AI**, powered by:

- `posts.tags` (`text[]`)
- user interaction events → `user_tag_affinity`
- mixing + diversity rules on the server

It is designed to match the mobile client usage:

- Base URL: `https://function-vista.chbk.dev/api`
- Endpoints added:
  - `POST /feed/for-you`
  - `POST /feed/event`

## Requirements (Supabase)

Apply the migration:

- `supabase/migrations/20260205_personalized_feed_v1.sql`

That creates:

- `user_feed_events`
- `user_tag_affinity`
- `user_post_feedback`
- `user_feed_seen`
- RPC `apply_feed_event`
- RPC `get_trending_tags`

## Environment Variables

Set these in your Node server environment:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

> We use the **anon key** to validate user JWTs (`auth.getUser(token)`), and the **service role key** to read/write feed tables and published posts.

## Run Locally

```bash
cd server/vista-node-feed
npm i
npm run dev
```

Server starts on `http://localhost:3000/api`.

## Integration Into Your Existing Server

If your production server is already running at `function-vista.chbk.dev`, you can either:

1. Copy `src/feed.routes.js` into your codebase and mount it under `/api/feed`
2. Or run this as a separate service behind your reverse proxy

## Notes (Design Choices)

- **Privacy**: excludes posts from private users unless the viewer follows them (mirrors current client logic).
- **Dedupe**: uses `user_feed_seen` to avoid showing the same posts repeatedly.
- **Diversity**: avoids consecutive posts from the same author/tag as much as possible.
- **No AI**: relies on tags + events; can later be upgraded to embeddings.

