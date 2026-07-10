-- ============================================================
-- SOCIALBOOST UZ — TO'LIQ SUPABASE SXEMASI
-- Bu yagona, yakuniy SQL fayl. Eski jadvallarni o'chirib,
-- barcha kod fayllariga (admin, worker, dashboard, login,
-- register, admin-login) 100% mos holda qaytadan yaratadi.
-- ============================================================

-- ----------------------------------------------------------
-- 0-QADAM: ESKI JADVALLARNI TOZALASH
-- (Tartib muhim: avval bog'liq jadvallar, keyin asosiylari)
-- ----------------------------------------------------------
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS withdraws CASCADE;
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS referral_requests CASCADE;
DROP TABLE IF EXISTS bajarilgan_ishlar CASCADE;
DROP TABLE IF EXISTS cheklar CASCADE;
DROP TABLE IF EXISTS buyurtmalar CASCADE;
DROP TABLE IF EXISTS paketlar CASCADE;
DROP TABLE IF EXISTS foydalanuvchilar CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ----------------------------------------------------------
-- 1-JADVAL: users
-- Barcha foydalanuvchilar: admin, customer, worker
-- Ishlatadigan fayllar: register, login, admin-login,
-- dashboard, worker, admin
-- ----------------------------------------------------------
CREATE TABLE users (
  id uuid PRIMARY KEY,                          -- Supabase Auth user.id bilan bir xil bo'lishi shart
  ism text NOT NULL,
  email text UNIQUE NOT NULL,
  login text,
  login_lower text UNIQUE,
  phone text,
  user_id text UNIQUE,                          -- "SBxxxxxx" yoki "ADM001" — referal va admin uchun ko'rinadigan ID
  customer_id text UNIQUE,                      -- "B-xxxxxxxxxx" — faqat customer uchun (dashboard.html generatsiya qiladi)
  rol text DEFAULT 'customer' CHECK (rol IN ('admin','customer','worker')),
  referred_by text,                             -- referal havola orqali kelgan bo'lsa, taklif qiluvchining user_id si
  balans numeric DEFAULT 0,
  status text DEFAULT 'active' CHECK (status IN ('active','blocked')),
  blocked_at timestamp,
  balance_frozen boolean DEFAULT false,
  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 2-JADVAL: paketlar
-- Admin yaratadigan xizmat paketlari
-- Ishlatadigan fayllar: admin (savePkg/deletePkg),
-- dashboard (paket tanlash)
-- ----------------------------------------------------------
CREATE TABLE paketlar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  platforma text NOT NULL,                      -- Telegram, Instagram, YouTube, TikTok
  xizmat_turi text NOT NULL,                     -- Obunachi, Layk, Ko'rish va h.k.
  narx numeric NOT NULL,                         -- Customer to'laydigan summa
  ball numeric NOT NULL,                         -- Eski ustun nomi; bir workerga to'lanadigan summa (so'm)
  soni numeric DEFAULT 1,                        -- Nechta worker kerak (buyurtma soni)
  tavsif text,
  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 3-JADVAL: buyurtmalar
-- Customer bergan buyurtmalar
-- Ishlatadigan fayllar: dashboard (yaratish),
-- admin (ko'rish/status o'zgartirish), worker (qabul qilish)
-- ----------------------------------------------------------
CREATE TABLE buyurtmalar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id uuid REFERENCES users(id) ON DELETE CASCADE,
  paket_id uuid REFERENCES paketlar(id) ON DELETE SET NULL,
  havola text NOT NULL,                          -- Customer kiritgan ijtimoiy tarmoq havolasi
  holat text DEFAULT 'pending' CHECK (holat IN ('pending','active','completed','rejected')),
  payment_status text DEFAULT 'kutilmoqda' CHECK (payment_status IN ('kutilmoqda','chek_yuborildi')),
  expires_at timestamp,                          -- 10 daqiqalik to'lov muddati
  accepted_workers integer DEFAULT 0,            -- Nechta worker qabul qildi
  needed_workers integer DEFAULT 1,              -- Nechta worker kerak (paket.soni dan olinadi)
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 4-JADVAL: cheklar
-- Customer to'lov chekini yuklaganda
-- Ishlatadigan fayllar: dashboard (yuklash),
-- admin (ko'rish), dashboard (buyurtmachi tasdiqlaydi va workerga pul yoziladi)
-- ----------------------------------------------------------
CREATE TABLE cheklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  buyurtma_id uuid REFERENCES buyurtmalar(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES users(id) ON DELETE CASCADE,
  rasm_url text NOT NULL,                        -- ImgBB havolasi
  holat text DEFAULT 'kutilmoqda' CHECK (holat IN ('kutilmoqda','tasdiqlandi','rad_etildi')),
  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 5-JADVAL: bajarilgan_ishlar
-- Worker buyurtmani qabul qilib, bajarib, screenshot yuborganda
-- Ishlatadigan fayllar: worker (qabul qilish/screenshot yuborish),
-- admin (tasdiqlash/rad etish -> Screenshotlar bo'limi)
-- ----------------------------------------------------------
CREATE TABLE bajarilgan_ishlar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  buyurtma_id uuid REFERENCES buyurtmalar(id) ON DELETE CASCADE,
  worker_id uuid REFERENCES users(id) ON DELETE CASCADE,
  screenshot_url text DEFAULT '',                -- Bajarganlik isboti (ImgBB)
  holat text DEFAULT 'qabul_qilindi' CHECK (holat IN ('qabul_qilindi','kutilmoqda','tasdiqlandi','rad_etildi')), -- kutilmoqda: buyurtmachi tasdig'i
  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 6-JADVAL: referral_requests
-- Worker referal havola orqali odam taklif qilganda
-- Ishlatadigan fayllar: register (yaratish),
-- admin (tasdiqlash/rad etish -> Referal so'rovlar bo'limi),
-- worker (o'z referallarini ko'rish)
-- ----------------------------------------------------------
CREATE TABLE referral_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,

  referrer_user_id text NOT NULL,                -- Taklif qiluvchi workerning user_id si (masalan "SBabc123")
  referrer_uid uuid REFERENCES users(id) ON DELETE CASCADE,
  referrer_name text,

  referred_user_id text,                         -- Yangi ro'yxatdan o'tgan foydalanuvchining user_id si
  referred_uid uuid REFERENCES users(id) ON DELETE CASCADE,
  referred_name text,
  referred_email text,
  referred_role text DEFAULT 'customer',

  admin_approved boolean DEFAULT false,
  admin_approved_at timestamp,
  admin_rejected_at timestamp,
  admin_note text,

  orders_completed integer DEFAULT 0,            -- Nechta vazifa bajarildi (5 tagacha kuzatiladi)
  bonus_ball numeric DEFAULT 10,
  bonus_given boolean DEFAULT false,
  bonus_given_at timestamp,

  status text DEFAULT 'pending' CHECK (
    status IN ('pending','approved','bonus_ready','completed','rejected')
  ),

  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 7-JADVAL: withdraws
-- Worker real pulni yechib olish so'rovi yuborganda
-- Ishlatadigan fayllar: worker (so'rov yuborish),
-- admin (tasdiqlash/rad etish -> Pul yechish bo'limi)
-- ----------------------------------------------------------
CREATE TABLE withdraws (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  worker_id uuid REFERENCES users(id) ON DELETE CASCADE,
  worker_name text,
  worker_user_id text,
  card_number text NOT NULL,
  card_holder text,
  amount numeric NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  created_at timestamp DEFAULT now(),
  processed_at timestamp
);

-- ----------------------------------------------------------
-- 8-JADVAL: settings
-- Umumiy key-value sozlamalar: to'lov kartalari,
-- minimal yechib olish balli va h.k.
-- Ishlatadigan fayllar: admin (yozish), dashboard (o'qish)
-- ----------------------------------------------------------
CREATE TABLE settings (
  key text PRIMARY KEY,
  value text
);

-- ----------------------------------------------------------
-- 9-JADVAL: notifications
-- Worker/customerga yuboriladigan bildirishnomalar
-- (masalan referal tasdiqlandi, bonus berildi)
-- Ishlatadigan fayllar: admin (yaratish),
-- worker (o'qish va "o'qildi" deb belgilash)
-- ----------------------------------------------------------
CREATE TABLE notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  rol text DEFAULT 'worker' CHECK (rol IN ('worker','customer','admin')),
  user_uid uuid REFERENCES users(id) ON DELETE CASCADE,
  type text,                                     -- 'referral_approved', 'referral_bonus' va h.k.
  referral_req_id uuid,
  referred_name text,
  referred_user_id text,
  title text,
  message text,
  fullscreen boolean DEFAULT false,
  read boolean DEFAULT false,
  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 10-JADVAL: reviews
-- Customer buyurtma yakunida fikr-mulohaza qoldirsa
-- Ishlatadigan fayllar: dashboard (yozish)
-- ----------------------------------------------------------
CREATE TABLE reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  buyurtma_id uuid REFERENCES buyurtmalar(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES users(id) ON DELETE CASCADE,
  customer_name text,
  review text,
  created_at timestamp DEFAULT now()
);

-- ----------------------------------------------------------
-- 11-JADVAL: blocklist
-- Admin "Foydalanuvchini butunlay o'chirish" tugmasini bosganda,
-- o'sha email qaytadan ro'yxatdan o'tolmasligi uchun
-- ----------------------------------------------------------
CREATE TABLE blocklist (
  email_key text PRIMARY KEY,
  email text NOT NULL,
  deleted_at timestamp DEFAULT now(),
  reason text
);

-- ----------------------------------------------------------
-- 12-QADAM: ROW LEVEL SECURITY — barchasi o'chirilgan
-- (Loyiha hozircha kichik, faqat admin panel orqali
-- boshqariladi, RLS keraksiz murakkablik qo'shadi)
-- ----------------------------------------------------------
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE paketlar DISABLE ROW LEVEL SECURITY;
ALTER TABLE buyurtmalar DISABLE ROW LEVEL SECURITY;
ALTER TABLE cheklar DISABLE ROW LEVEL SECURITY;
ALTER TABLE bajarilgan_ishlar DISABLE ROW LEVEL SECURITY;
ALTER TABLE referral_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE withdraws DISABLE ROW LEVEL SECURITY;
ALTER TABLE settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;
ALTER TABLE blocklist DISABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------
-- 12-QADAM: SUPERADMIN YOZUVI
-- DIQQAT: Bu qismni ishlatishdan oldin Supabase dashboard ->
-- Authentication -> Users bo'limida "Create new user" orqali
-- shmurodov200@gmail.com / 01070521 hisobini yarating va
-- undan qaytgan UID ni pastdagi 'PUT-ADMIN-UID-HERE' o'rniga
-- qo'ying. Agar admin-login.html orqali birinchi marta kirsangiz,
-- bu yozuv kod tomonidan avtomatik yaratiladi — shu holda bu
-- qismni ishlatmasangiz ham bo'ladi.
-- ----------------------------------------------------------
-- INSERT INTO users (id, ism, email, login, login_lower, user_id, rol, balans)
-- VALUES (
--   'PUT-ADMIN-UID-HERE',
--   'Superadmin',
--   'shmurodov200@gmail.com',
--   'mirzo2005',
--   'mirzo2005',
--   'ADM001',
--   'admin',
--   0
-- );

-- ============================================================
-- TUGADI. Jami 10 ta jadval yaratildi:
-- users, paketlar, buyurtmalar, cheklar, bajarilgan_ishlar,
-- referral_requests, withdraws, settings, notifications, reviews
-- ============================================================
