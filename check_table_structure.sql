-- =====================================================
-- بررسی ساختار دقیق جدول posts
-- =====================================================

-- بررسی نوع داده‌های ستون‌های جدول posts
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'posts' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- بررسی نوع داده‌های ستون‌های جدول profiles
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- بررسی نمونه داده‌ها
SELECT 
    id,
    pg_typeof(id) as id_type,
    user_id,
    pg_typeof(user_id) as user_id_type,
    moderator_id,
    pg_typeof(moderator_id) as moderator_id_type,
    likes_count,
    pg_typeof(likes_count) as likes_count_type,
    comments_count,
    pg_typeof(comments_count) as comments_count_type,
    engagement_score,
    pg_typeof(engagement_score) as engagement_score_type
FROM posts 
LIMIT 3; 