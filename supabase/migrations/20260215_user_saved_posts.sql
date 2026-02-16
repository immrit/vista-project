BEGIN;

DO $$
DECLARE
  v_posts_id_type text;
  v_saved_post_id_type text;
BEGIN
  IF to_regclass('public.posts') IS NULL THEN
    RAISE EXCEPTION 'public.posts table not found';
  END IF;

  SELECT format_type(a.atttypid, a.atttypmod)
  INTO v_posts_id_type
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'posts'
    AND a.attname = 'id'
    AND a.attnum > 0
    AND NOT a.attisdropped;

  IF v_posts_id_type IS NULL THEN
    RAISE EXCEPTION 'public.posts.id column not found';
  END IF;

  IF to_regclass('public.user_saved_posts') IS NULL THEN
    EXECUTE format(
      'CREATE TABLE public.user_saved_posts (
        user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        post_id %s NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT user_saved_posts_pkey PRIMARY KEY (user_id, post_id)
      )',
      v_posts_id_type
    );
  ELSE
    SELECT format_type(a.atttypid, a.atttypmod)
    INTO v_saved_post_id_type
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'user_saved_posts'
      AND a.attname = 'post_id'
      AND a.attnum > 0
      AND NOT a.attisdropped;

    IF v_saved_post_id_type IS DISTINCT FROM v_posts_id_type THEN
      RAISE EXCEPTION
        'Type mismatch: user_saved_posts.post_id is %, posts.id is %',
        v_saved_post_id_type,
        v_posts_id_type;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS user_saved_posts_user_created_at_idx
  ON public.user_saved_posts (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS user_saved_posts_post_id_idx
  ON public.user_saved_posts (post_id);

ALTER TABLE public.user_saved_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_saved_posts_select_own ON public.user_saved_posts;
CREATE POLICY user_saved_posts_select_own
ON public.user_saved_posts
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_saved_posts_insert_own ON public.user_saved_posts;
CREATE POLICY user_saved_posts_insert_own
ON public.user_saved_posts
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_saved_posts_update_own ON public.user_saved_posts;
CREATE POLICY user_saved_posts_update_own
ON public.user_saved_posts
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_saved_posts_delete_own ON public.user_saved_posts;
CREATE POLICY user_saved_posts_delete_own
ON public.user_saved_posts
FOR DELETE
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_saved_posts TO authenticated;

COMMIT;
