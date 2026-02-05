import express from "express";
import { supabaseAnon, supabaseService } from "./supabase.js";

export const feedRouter = express.Router();

function getBearerToken(req) {
  const h = req.headers["authorization"] || req.headers["Authorization"];
  if (!h) return null;
  const s = String(h);
  if (!s.toLowerCase().startsWith("bearer ")) return null;
  return s.slice(7).trim();
}

async function requireAuth(req, res, next) {
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ error: "missing_token" });

    const { data, error } = await supabaseAnon.auth.getUser(token);
    if (error || !data?.user?.id) {
      return res.status(401).json({ error: "invalid_token" });
    }

    req.userId = data.user.id;
    next();
  } catch (e) {
    res.status(500).json({ error: "auth_failed" });
  }
}

function uniqById(rows) {
  const out = [];
  const seen = new Set();
  for (const r of rows) {
    const id = r?.id;
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(r);
  }
  return out;
}

function hoursSince(iso) {
  const t = new Date(iso).getTime();
  return (Date.now() - t) / (1000 * 60 * 60);
}

function safeArray(a) {
  return Array.isArray(a) ? a : [];
}

function computeScore({
  userTagScoreMap,
  followingSet,
  viewerId,
  post,
  sourceHint,
}) {
  const tags = safeArray(post.tags);
  let affinitySum = 0;
  for (const t of tags) affinitySum += userTagScoreMap.get(String(t).toLowerCase()) || 0;

  const affinity = Math.log1p(Math.max(0, affinitySum));
  const engagement = Math.log1p(Number(post.engagement_score || 0));
  const recency = Math.exp(-hoursSince(post.created_at) / 36);

  const followBoost = followingSet.has(post.user_id) ? 0.35 : 0;
  const ownBoost = post.user_id === viewerId ? 0.2 : 0;
  const exploreBoost = sourceHint === "trending" ? 0.08 : 0;

  // weights tuned for MVP: stable + not too "spammy"
  return 0.55 * affinity + 0.25 * engagement + 0.2 * recency + followBoost + ownBoost + exploreBoost;
}

function pickDiverse(sorted, limit, userTopTagsLower) {
  const out = [];
  const picked = new Set();
  const recentAuthors = [];
  const recentTags = [];

  function pushRecent(arr, v, max) {
    arr.push(v);
    while (arr.length > max) arr.shift();
  }

  function primaryTag(post) {
    const tags = safeArray(post.tags).map((t) => String(t).toLowerCase());
    for (const t of tags) if (userTopTagsLower.has(t)) return t;
    return tags[0] || null;
  }

  for (const c of sorted) {
    if (out.length >= limit) break;
    if (picked.has(c.id)) continue;

    const pTag = primaryTag(c);
    const author = c.user_id;

    const authorTooSoon = recentAuthors.includes(author);
    const tagTooSoon = pTag && recentTags.filter((t) => t === pTag).length >= 2;

    if (authorTooSoon || tagTooSoon) continue;

    picked.add(c.id);
    out.push(c);
    pushRecent(recentAuthors, author, 3);
    if (pTag) pushRecent(recentTags, pTag, 6);
  }

  // If diversity constraints were too strict, fill the rest.
  if (out.length < limit) {
    for (const c of sorted) {
      if (out.length >= limit) break;
      if (picked.has(c.id)) continue;
      picked.add(c.id);
      out.push(c);
    }
  }

  return out;
}

function mixSources(scored, limit) {
  const groups = {
    personal: [],
    following: [],
    trending: [],
    other: [],
  };

  for (const c of scored) {
    const s = c._source;
    if (s === "personal") groups.personal.push(c);
    else if (s === "following" || s === "own") groups.following.push(c);
    else if (s === "trending" || s === "fallback") groups.trending.push(c);
    else groups.other.push(c);
  }

  // Keep following present, while still prioritizing interest-based ("personal") results.
  // Roughly: 50% personal, 33% following, 17% trending/fallback.
  const schedule = ["personal", "following", "personal", "following", "trending", "personal"];
  const out = [];

  function shiftAny() {
    return (
      groups.personal.shift() ||
      groups.following.shift() ||
      groups.trending.shift() ||
      groups.other.shift() ||
      null
    );
  }

  let i = 0;
  const maxOut = Math.max(limit * 4, 60); // give diversity filter enough runway
  while (out.length < maxOut) {
    const key = schedule[i % schedule.length];
    const cand = groups[key]?.shift() || shiftAny();
    if (!cand) break;
    out.push(cand);
    i += 1;
  }

  return out;
}

async function fetchFollowingIds(viewerId) {
  // Table `follows` is used by the Flutter client already.
  const { data, error } = await supabaseService
    .from("follows")
    .select("following_id")
    .eq("follower_id", viewerId);

  if (error) throw error;
  return safeArray(data).map((r) => r.following_id).filter(Boolean);
}

async function fetchPendingFollowRequests(viewerId, authorIds) {
  if (!authorIds?.length) return new Set();
  const { data, error } = await supabaseService
    .from("follow_requests")
    .select("recipient_id, status")
    .eq("requester_id", viewerId)
    .in("recipient_id", authorIds);

  if (error) {
    // If follow_requests doesn't exist / RLS blocks, just return none.
    return new Set();
  }

  const set = new Set();
  for (const row of safeArray(data)) {
    if (row?.status === "pending" && row?.recipient_id) set.add(row.recipient_id);
  }
  return set;
}

async function fetchUserTopTags(viewerId, limit = 20) {
  const { data, error } = await supabaseService.rpc("get_user_top_tags", {
    p_user_id: viewerId,
    limit_count: limit,
  });
  if (error) throw error;
  return safeArray(data).map((r) => ({ tag: r.tag, score: Number(r.score || 0) }));
}

async function fetchTrendingTags(limit = 10) {
  const { data, error } = await supabaseService.rpc("get_trending_tags", {
    limit_count: limit,
    days_back: 7,
  });
  if (error) throw error;
  return safeArray(data).map((r) => r.tag).filter(Boolean);
}

async function fetchNegativePostIds(viewerId) {
  const { data, error } = await supabaseService
    .from("user_post_feedback")
    .select("post_id")
    .eq("user_id", viewerId)
    .in("feedback_type", ["hide", "not_interested"]);

  if (error) throw error;
  return new Set(safeArray(data).map((r) => r.post_id).filter(Boolean));
}

async function fetchSeenPostIds(viewerId) {
  const sinceIso = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabaseService
    .from("user_feed_seen")
    .select("post_id")
    .eq("user_id", viewerId)
    .gte("seen_at", sinceIso);

  if (error) throw error;
  return new Set(safeArray(data).map((r) => r.post_id).filter(Boolean));
}

async function fetchUserPrivacyMap(userIds) {
  if (!userIds.length) return new Map();
  const { data, error } = await supabaseService
    .from("user_settings")
    .select("user_id, is_private")
    .in("user_id", userIds);

  if (error) {
    // If the table doesn't exist yet, default to "public".
    return new Map();
  }

  const map = new Map();
  for (const row of safeArray(data)) {
    map.set(row.user_id, Boolean(row.is_private));
  }
  return map;
}

async function fetchCandidates({
  viewerId,
  followingIds,
  userTopTags,
  trendingTags,
  beforeIso,
}) {
  const userTags = userTopTags.map((x) => x.tag).filter(Boolean);

  // Keep a generous window so users can scroll far without huge queries.
  const windowIso = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();

  const candidates = [];

  // Personal: overlap with top tags
  if (userTags.length) {
    let q = supabaseService
      .from("posts")
      .select("id, user_id, created_at, engagement_score, tags")
      .eq("status", "published")
      .gte("created_at", windowIso);
    if (beforeIso) q = q.lt("created_at", beforeIso);
    const { data, error } = await q
      .overlaps("tags", userTags)
      .order("created_at", { ascending: false })
      .limit(250);
    if (error) throw error;
    for (const r of safeArray(data)) candidates.push({ ...r, _source: "personal" });
  }

  // Following: recent posts from followed users
  if (followingIds.length) {
    let q = supabaseService
      .from("posts")
      .select("id, user_id, created_at, engagement_score, tags")
      .eq("status", "published")
      .gte("created_at", windowIso);
    if (beforeIso) q = q.lt("created_at", beforeIso);
    const { data, error } = await q
      .in("user_id", followingIds)
      .order("created_at", { ascending: false })
      .limit(200);
    if (error) throw error;
    for (const r of safeArray(data)) candidates.push({ ...r, _source: "following" });
  }

  // Trending: discovery candidates
  if (trendingTags.length) {
    let q = supabaseService
      .from("posts")
      .select("id, user_id, created_at, engagement_score, tags")
      .eq("status", "published")
      .gte("created_at", windowIso);
    if (beforeIso) q = q.lt("created_at", beforeIso);
    const { data, error } = await q
      .overlaps("tags", trendingTags)
      .order("engagement_score", { ascending: false })
      .limit(200);
    if (error) throw error;
    for (const r of safeArray(data)) candidates.push({ ...r, _source: "trending" });
  }

  // Global fallback: top engagement posts (keeps feed alive even if tags are sparse).
  {
    let q = supabaseService
      .from("posts")
      .select("id, user_id, created_at, engagement_score, tags")
      .eq("status", "published")
      .gte("created_at", windowIso);
    if (beforeIso) q = q.lt("created_at", beforeIso);
    const { data, error } = await q
      .order("engagement_score", { ascending: false })
      .limit(200);
    if (error) throw error;
    for (const r of safeArray(data)) candidates.push({ ...r, _source: "fallback" });
  }

  // Always include viewer's own recent posts (so they don't "disappear")
  let ownQ = supabaseService
    .from("posts")
    .select("id, user_id, created_at, engagement_score, tags")
    .eq("status", "published")
    .gte("created_at", windowIso)
    .eq("user_id", viewerId);
  if (beforeIso) ownQ = ownQ.lt("created_at", beforeIso);
  const { data: own, error: ownErr } = await ownQ
    .order("created_at", { ascending: false })
    .limit(50);
  if (ownErr) throw ownErr;
  for (const r of safeArray(own)) candidates.push({ ...r, _source: "own" });

  return uniqById(candidates);
}

async function hydratePosts(viewerId, postIdsInOrder) {
  if (!postIdsInOrder.length) return [];

  const { data: posts, error } = await supabaseService
    .from("posts")
    .select(
      `
      id,
      user_id,
      content,
      image_url,
      video_url,
      music_url,
      created_at,
      likes_count,
      comments_count,
      engagement_score,
      tags,
      profiles!posts_user_id_fkey (
        username,
        full_name,
        avatar_url,
        is_verified,
        verification_type
      )
    `
    )
    .in("id", postIdsInOrder);

  if (error) throw error;

  // Aggregate like/comment counts from tables (don't rely on denormalized counters).
  let likeCountMap = new Map();
  try {
    const { data: allLikes, error: allLikesErr } = await supabaseService
      .from("likes")
      .select("post_id")
      .in("post_id", postIdsInOrder);
    if (!allLikesErr) {
      for (const r of safeArray(allLikes)) {
        const pid = r?.post_id;
        if (!pid) continue;
        likeCountMap.set(pid, (likeCountMap.get(pid) || 0) + 1);
      }
    }
  } catch (_) {
    likeCountMap = new Map();
  }

  let commentCountMap = new Map();
  try {
    const { data: allComments, error: allCommentsErr } = await supabaseService
      .from("comments")
      .select("post_id")
      .in("post_id", postIdsInOrder);
    if (!allCommentsErr) {
      for (const r of safeArray(allComments)) {
        const pid = r?.post_id;
        if (!pid) continue;
        commentCountMap.set(pid, (commentCountMap.get(pid) || 0) + 1);
      }
    }
  } catch (_) {
    commentCountMap = new Map();
  }

  // Fetch "is_liked" in one query
  const { data: likes, error: likeErr } = await supabaseService
    .from("likes")
    .select("post_id")
    .eq("user_id", viewerId)
    .in("post_id", postIdsInOrder);

  if (likeErr) throw likeErr;
  const likedSet = new Set(safeArray(likes).map((r) => r.post_id));

  const byId = new Map();
  for (const p of safeArray(posts)) {
    byId.set(p.id, p);
  }

  return postIdsInOrder
    .map((id) => byId.get(id))
    .filter(Boolean)
    .map((p) => ({
      ...p,
      like_count:
        likeCountMap.get(p.id) != null
          ? Number(likeCountMap.get(p.id) || 0)
          : Number(p.likes_count || 0),
      comment_count:
        commentCountMap.get(p.id) != null
          ? Number(commentCountMap.get(p.id) || 0)
          : Number(p.comments_count || 0),
      is_liked: likedSet.has(p.id),
      // Keep both keys for compatibility with existing Dart parsing
      hashtags: safeArray(p.tags),
    }));
}

async function markSeen(viewerId, seenRows) {
  if (!seenRows?.length) return;
  const nowIso = new Date().toISOString();
  const rows = safeArray(seenRows)
    .map((r) => ({
      user_id: viewerId,
      post_id: r?.post_id,
      seen_at: nowIso,
      source: r?.source || "for_you",
    }))
    .filter((r) => Boolean(r.post_id));

  if (!rows.length) return;
  await supabaseService.from("user_feed_seen").upsert(rows, {
    onConflict: "user_id,post_id",
  });
}

feedRouter.post("/event", requireAuth, async (req, res) => {
  try {
    const viewerId = req.userId;
    const { postId, eventType, meta } = req.body || {};
    if (!postId || !eventType) {
      return res.status(400).json({ error: "missing_fields" });
    }

    const weightMap = {
      open: 0.2,
      view: 0.2,
      like: 2,
      unlike: -1,
      comment: 3,
      share: 4,
      hide: -5,
      not_interested: -6,
    };

    const weight = weightMap[String(eventType)] ?? 1;

    if (eventType === "hide" || eventType === "not_interested") {
      await supabaseService.from("user_post_feedback").upsert(
        [
          {
            user_id: viewerId,
            post_id: postId,
            feedback_type: String(eventType),
          },
        ],
        { onConflict: "user_id,post_id,feedback_type" }
      );
    }

    // Update tag affinity (SQL function reads post.tags)
    await supabaseService.rpc("apply_feed_event", {
      p_user_id: viewerId,
      p_post_id: postId,
      p_event_type: String(eventType),
      p_weight: weight,
    });

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: "event_failed" });
  }
});

feedRouter.post("/for-you", requireAuth, async (req, res) => {
  try {
    const viewerId = req.userId;
    const limit = Math.min(Math.max(Number(req.body?.limit || 15), 1), 30);
    const debug = Boolean(req.body?.debug === true);
    const beforeRaw = req.body?.before;
    const beforeIso = (() => {
      if (!beforeRaw) return null;
      const d = new Date(String(beforeRaw));
      return Number.isFinite(d.getTime()) ? d.toISOString() : null;
    })();

    const followingIds = await fetchFollowingIds(viewerId);
    const followingSet = new Set(followingIds);

    let userTopTags = await fetchUserTopTags(viewerId, 25);
    let trendingTags = await fetchTrendingTags(12);

    // Cold start: if no affinity yet, use trending tags as "pseudo interests".
    if (!userTopTags.length) {
      userTopTags = trendingTags.map((t) => ({ tag: t, score: 1 }));
    }

    const userTagScoreMap = new Map(
      userTopTags.map((x) => [String(x.tag).toLowerCase(), Number(x.score || 0)])
    );
    const userTopTagsLower = new Set(userTopTags.map((x) => String(x.tag).toLowerCase()));

    const negativePostIds = await fetchNegativePostIds(viewerId);
    const seenPostIds = await fetchSeenPostIds(viewerId);

    const candidates = await fetchCandidates({
      viewerId,
      followingIds,
      userTopTags,
      trendingTags,
      beforeIso,
    });

    // Privacy filter (mirror Flutter logic):
    // - show own posts
    // - show followed users
    // - otherwise: only public users
    const authorIds = Array.from(new Set(candidates.map((c) => c.user_id))).filter(Boolean);
    const privacyMap = await fetchUserPrivacyMap(authorIds);

    const afterNegSeen = candidates.filter((c) => {
      if (!c?.id) return false;
      if (negativePostIds.has(c.id)) return false;
      if (seenPostIds.has(c.id)) return false;
      return true;
    }).length;

    const filtered = candidates.filter((c) => {
      if (!c?.id) return false;
      if (negativePostIds.has(c.id)) return false;
      if (seenPostIds.has(c.id)) return false;

      const authorId = c.user_id;
      if (!authorId) return false;
      if (authorId === viewerId) return true;
      if (followingSet.has(authorId)) return true;
      const isPrivate = privacyMap.get(authorId) === true;
      return !isPrivate;
    });

    const scored = filtered
      .map((c) => ({
        ...c,
        _score: computeScore({
          userTagScoreMap,
          followingSet,
          viewerId,
          post: c,
          sourceHint: c._source,
        }),
      }))
      .sort((a, b) => (b._score || 0) - (a._score || 0));

    // Mix sources to avoid "samey" feed (a.k.a. the anti-boredom lever).
    const mixed = mixSources(scored, limit);
    const picked = pickDiverse(mixed, limit, userTopTagsLower);
    const pickedIds = picked.map((p) => p.id);

    const metaById = new Map(picked.map((p) => [p.id, p]));
    const items = await hydratePosts(viewerId, pickedIds);

    const hydratedAuthorIds = Array.from(new Set(items.map((p) => p.user_id))).filter(Boolean);
    const requestedSet = await fetchPendingFollowRequests(viewerId, hydratedAuthorIds);

    const itemsWithMeta = items.map((p) => {
      const meta = metaById.get(p.id);
      const src = meta?._source || "fallback";
      const authorId = p.user_id;
      const authorFollowStatus =
        authorId === viewerId
          ? "following"
          : followingSet.has(authorId)
          ? "following"
          : requestedSet.has(authorId)
          ? "requested"
          : "none";

      return {
        ...p,
        feed_source: src,
        ...(debug ? { feed_score: Number(meta?._score || 0) } : {}),
        author_follow_status: authorFollowStatus,
      };
    });

    // Cursor for keyset pagination: oldest created_at from this batch
    let nextBefore = null;
    for (const it of itemsWithMeta) {
      const d = new Date(it?.created_at);
      if (!Number.isFinite(d.getTime())) continue;
      if (!nextBefore || d.getTime() < nextBefore.getTime()) nextBefore = d;
    }
    const nextBeforeIso = nextBefore ? nextBefore.toISOString() : null;

    // Dedupe: mark seen as soon as we return.
    await markSeen(
      viewerId,
      itemsWithMeta.map((p) => ({ post_id: p.id, source: p.feed_source }))
    );

    const sourceCounts = {};
    for (const p of itemsWithMeta) {
      const key = p.feed_source || "unknown";
      sourceCounts[key] = (sourceCounts[key] || 0) + 1;
    }

    res.json({
      items: itemsWithMeta,
      hasMore: Boolean(nextBeforeIso && itemsWithMeta.length > 0),
      ...(nextBeforeIso ? { nextBefore: nextBeforeIso } : {}),
      ...(debug
        ? {
            debug: {
              sourceCounts,
              topTags: userTopTags.slice(0, 10),
              candidateCounts: {
                total: candidates.length,
                afterNegSeen,
                afterPrivacy: filtered.length,
              },
            },
          }
        : {}),
    });
  } catch (e) {
    res.status(500).json({ error: "feed_failed" });
  }
});
