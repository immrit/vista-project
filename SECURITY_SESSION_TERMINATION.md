# مستندات امنیتی: حذف نشست‌های فعال

## بررسی‌های امنیتی که باید در RPC Functions انجام شوند

### ⚠️ مهم: این بررسی‌ها باید در دیتابیس (RPC Functions) نیز پیاده‌سازی شوند

## 1. RPC Function: `terminate_session`

### پارامترها:
- `session_id`: شناسه نشست مورد نظر برای حذف
- `terminating_session_id`: شناسه نشست فعلی که در حال حذف است

### بررسی‌های امنیتی که باید انجام شوند:

```sql
-- 1. بررسی اینکه terminating_session_id معتبر است و is_active = true
-- 2. بررسی اینکه session_id معتبر است و is_active = true
-- 3. بررسی اینکه هر دو نشست متعلق به همان user_id هستند
-- 4. بررسی منطق 10 روزه:
--    - اگر نشست فعلی >= 10 روز قدمت دارد → می‌تواند همه را حذف کند
--    - اگر نشست فعلی < 10 روز قدمت دارد → فقط می‌تواند نشست‌های جدیدتر را حذف کند
-- 5. بررسی اینکه session_id != terminating_session_id (نمی‌تواند خودش را حذف کند با این function)
```

### مثال پیاده‌سازی:

```sql
CREATE OR REPLACE FUNCTION terminate_session(
  session_id UUID,
  terminating_session_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
  current_created_at TIMESTAMP;
  target_user_id UUID;
  target_created_at TIMESTAMP;
  days_since_creation INTEGER;
BEGIN
  -- 1. دریافت user_id از JWT token (auth.uid())
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- 2. بررسی نشست فعلی (terminating_session_id)
  SELECT user_id, created_at INTO current_user_id, current_created_at
  FROM active_sessions
  WHERE id = terminating_session_id
    AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Terminating session not found or inactive';
  END IF;
  
  -- 3. بررسی امنیتی: مطمئن شویم نشست فعلی متعلق به کاربر فعلی است
  IF current_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Security violation: Session does not belong to current user';
  END IF;

  -- 4. بررسی نشست هدف (session_id)
  SELECT user_id, created_at INTO target_user_id, target_created_at
  FROM active_sessions
  WHERE id = session_id
    AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target session not found or inactive';
  END IF;
  
  -- 5. بررسی امنیتی: مطمئن شویم نشست هدف متعلق به کاربر فعلی است
  IF target_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Security violation: Cannot terminate sessions of other users';
  END IF;
  
  -- 6. بررسی منطق 10 روزه
  days_since_creation := EXTRACT(DAY FROM (NOW() - current_created_at));
  
  IF days_since_creation < 10 THEN
    -- فقط می‌تواند نشست‌های جدیدتر را حذف کند
    IF target_created_at >= current_created_at THEN
      RAISE EXCEPTION 'Cannot terminate older sessions. Wait % more days', (10 - days_since_creation);
    END IF;
  END IF;
  
  -- 7. حذف نشست
  UPDATE active_sessions
  SET is_active = false,
      terminated_at = NOW(),
      terminated_by_session_id = terminating_session_id
  WHERE id = session_id;
  
END;
$$;
```

## 2. RPC Function: `terminate_other_sessions`

### پارامترها:
- `current_session_id`: شناسه نشست فعلی

### بررسی‌های امنیتی که باید انجام شوند:

```sql
-- 1. بررسی اینکه current_session_id معتبر است و is_active = true
-- 2. بررسی اینکه نشست فعلی >= 10 روز قدمت دارد
-- 3. بررسی اینکه همه نشست‌های حذف شده متعلق به همان user_id هستند
```

### مثال پیاده‌سازی:

```sql
CREATE OR REPLACE FUNCTION terminate_other_sessions(
  current_session_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
  current_created_at TIMESTAMP;
  days_since_creation INTEGER;
BEGIN
  -- 1. دریافت user_id از JWT token
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- 2. بررسی نشست فعلی
  SELECT user_id, created_at INTO current_user_id, current_created_at
  FROM active_sessions
  WHERE id = current_session_id
    AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Current session not found or inactive';
  END IF;
  
  -- 3. بررسی امنیتی: مطمئن شویم نشست فعلی متعلق به کاربر فعلی است
  IF current_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Security violation: Session does not belong to current user';
  END IF;

  -- 4. بررسی منطق 10 روزه
  days_since_creation := EXTRACT(DAY FROM (NOW() - current_created_at));
  
  IF days_since_creation < 10 THEN
    RAISE EXCEPTION 'Cannot terminate other sessions. Wait % more days', (10 - days_since_creation);
  END IF;
  
  -- 5. حذف همه نشست‌های دیگر (فقط متعلق به همان کاربر)
  UPDATE active_sessions
  SET is_active = false,
      terminated_at = NOW(),
      terminated_by_session_id = current_session_id
  WHERE user_id = auth.uid()
    AND id != current_session_id
    AND is_active = true;
  
END;
$$;
```

## 3. بررسی‌های امنیتی اضافی

### ✅ بررسی‌های انجام شده در Client-Side:
1. بررسی `user_id` قبل از فراخوانی RPC
2. بررسی `created_at` برای منطق 10 روزه
3. بررسی `is_active` برای هر دو نشست
4. بررسی مجدد قبل از فراخوانی RPC (جلوگیری از Race Condition)

### ⚠️ بررسی‌های ضروری در Server-Side (RPC Functions):
1. **استفاده از `auth.uid()`**: همیشه از JWT token برای دریافت user_id استفاده کنید
2. **بررسی `user_id`**: مطمئن شوید که هر دو نشست متعلق به همان کاربر هستند
3. **بررسی `is_active`**: فقط نشست‌های فعال را می‌توان حذف کرد
4. **بررسی منطق 10 روزه**: در server-side نیز بررسی شود
5. **Row Level Security (RLS)**: مطمئن شوید که RLS policies درست تنظیم شده‌اند

## 4. سناریوهای حمله و دفاع

### حمله 1: تلاش برای حذف نشست کاربر دیگر
**دفاع**: بررسی `user_id` در هر دو client-side و server-side

### حمله 2: دستکاری `session_id` در client
**دفاع**: RPC function باید `user_id` را از JWT token دریافت کند

### حمله 3: Race Condition
**دفاع**: بررسی مجدد در client-side قبل از RPC و بررسی در server-side

### حمله 4: دستکاری `created_at` در client
**دفاع**: RPC function باید `created_at` را مستقیماً از دیتابیس بخواند

## 5. لاگ‌های امنیتی

همه تلاش‌های ناموفق برای حذف نشست باید لاگ شوند:
- تلاش برای حذف نشست کاربر دیگر
- تلاش برای حذف نشست قدیمی‌تر (با نشست جدید)
- تلاش برای حذف نشست با نشست کمتر از 10 روز

## 6. تست‌های امنیتی پیشنهادی

1. تست: تلاش برای حذف نشست کاربر دیگر → باید خطا بدهد
2. تست: تلاش برای حذف نشست قدیمی‌تر با نشست جدید → باید خطا بدهد
3. تست: حذف نشست جدیدتر با نشست قدیمی → باید موفق شود
4. تست: حذف همه نشست‌ها با نشست >= 10 روز → باید موفق شود
5. تست: حذف همه نشست‌ها با نشست < 10 روز → باید خطا بدهد

