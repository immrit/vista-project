BEGIN;

CREATE TABLE IF NOT EXISTS public.story_user_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  reply_permission text NOT NULL DEFAULT 'everyone' CHECK (reply_permission IN ('everyone', 'following', 'off')),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.story_user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS story_user_settings_select_own ON public.story_user_settings;
CREATE POLICY story_user_settings_select_own
ON public.story_user_settings
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS story_user_settings_insert_own ON public.story_user_settings;
CREATE POLICY story_user_settings_insert_own
ON public.story_user_settings
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS story_user_settings_update_own ON public.story_user_settings;
CREATE POLICY story_user_settings_update_own
ON public.story_user_settings
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.story_user_settings TO authenticated;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS message_type text;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS story_reply_data jsonb;

CREATE OR REPLACE FUNCTION public.get_story_reply_permission(
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT sus.reply_permission
      FROM public.story_user_settings sus
      WHERE sus.user_id = p_user_id
      LIMIT 1
    ),
    'everyone'
  );
$$;

CREATE OR REPLACE FUNCTION public.set_story_reply_permission(
  p_permission text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  IF p_permission NOT IN ('everyone', 'following', 'off') THEN
    RAISE EXCEPTION 'invalid_reply_permission';
  END IF;

  INSERT INTO public.story_user_settings (user_id, reply_permission, updated_at)
  VALUES (v_user_id, p_permission, now())
  ON CONFLICT (user_id)
  DO UPDATE SET
    reply_permission = EXCLUDED.reply_permission,
    updated_at = now();

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.can_reply_to_story(
  p_story_id text,
  p_owner_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id uuid := auth.uid();
  v_owner_id uuid;
  v_expires_at timestamptz;
  v_permission text;
BEGIN
  IF v_current_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT s.user_id, s.expires_at
  INTO v_owner_id, v_expires_at
  FROM public.stories s
  WHERE s.id::text = p_story_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF p_owner_id IS NOT NULL AND p_owner_id <> v_owner_id THEN
    RETURN false;
  END IF;

  IF v_current_user_id = v_owner_id THEN
    RETURN false;
  END IF;

  IF v_expires_at IS NOT NULL AND v_expires_at <= now() THEN
    RETURN false;
  END IF;

  v_permission := COALESCE(
    (
      SELECT sus.reply_permission
      FROM public.story_user_settings sus
      WHERE sus.user_id = v_owner_id
      LIMIT 1
    ),
    'everyone'
  );

  IF v_permission = 'off' THEN
    RETURN false;
  END IF;

  IF v_permission = 'everyone' THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.follows f
    WHERE f.follower_id = v_owner_id
      AND f.following_id = v_current_user_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.send_story_reply(
  p_story_id text,
  p_message text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id uuid := auth.uid();
  v_conversation_id text;
  v_story_id text;
  v_owner_id uuid;
  v_owner_username text;
  v_owner_avatar_url text;
  v_thumbnail_url text;
  v_media_type text;
  v_created_at timestamptz;
  v_expires_at timestamptz;
  v_duration_hours int;
  v_inserted_id text;
  v_inserted_conversation_id text;
  v_inserted_created_at timestamptz;
BEGIN
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  IF trim(COALESCE(p_message, '')) = '' THEN
    RAISE EXCEPTION 'empty_story_reply_message';
  END IF;

  SELECT
    s.id::text,
    s.user_id,
    COALESCE(p.username, ''),
    p.avatar_url,
    COALESCE(NULLIF(s.thumbnail_url, ''), s.media_url, ''),
    COALESCE(NULLIF(s.media_type, ''), 'image'),
    s.created_at,
    s.expires_at
  INTO
    v_story_id,
    v_owner_id,
    v_owner_username,
    v_owner_avatar_url,
    v_thumbnail_url,
    v_media_type,
    v_created_at,
    v_expires_at
  FROM public.stories s
  LEFT JOIN public.profiles p ON p.id = s.user_id
  WHERE s.id::text = p_story_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'story_not_found';
  END IF;

  IF NOT public.can_reply_to_story(v_story_id, v_owner_id) THEN
    RAISE EXCEPTION 'story_reply_not_allowed';
  END IF;

  v_duration_hours := CASE
    WHEN v_expires_at IS NULL OR v_created_at IS NULL THEN NULL
    ELSE GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_expires_at - v_created_at)) / 3600.0)::int)
  END;

  v_conversation_id := public.create_or_get_conversation(v_current_user_id, v_owner_id);

  INSERT INTO public.messages (
    conversation_id,
    sender_id,
    content,
    message_type,
    story_reply_data,
    created_at,
    is_sent,
    is_pending
  )
  VALUES (
    v_conversation_id,
    v_current_user_id,
    trim(p_message),
    'storyReply',
    jsonb_build_object(
      'story_id', v_story_id,
      'story_owner_id', v_owner_id,
      'story_owner_username', v_owner_username,
      'story_owner_avatar_url', v_owner_avatar_url,
      'story_thumbnail_url', v_thumbnail_url,
      'story_media_type', v_media_type,
      'story_created_at', v_created_at,
      'story_expires_at', v_expires_at,
      'story_duration_hours', v_duration_hours
    ),
    now(),
    true,
    false
  )
  RETURNING id, conversation_id, created_at
  INTO v_inserted_id, v_inserted_conversation_id, v_inserted_created_at;

  RETURN jsonb_build_object(
    'message_id', v_inserted_id,
    'conversation_id', v_inserted_conversation_id,
    'created_at', v_inserted_created_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_story_reply_permission(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_story_reply_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_reply_to_story(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_story_reply(text, text) TO authenticated;

COMMIT;
