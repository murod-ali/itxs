// ========================================================
// app-core.js — Supabase uchun umumiy yordamchi kutubxona
// ========================================================
// Bu fayl barcha sahifalarda (admin.html, dashboard.html, worker.html)
// ishlatiladigan umumiy SBApp obyektini taqdim etadi:
//  - Real-time obuna boshqaruvi (Supabase Realtime orqali, Firestore
//    onSnapshot o'rnini bosadi)
//  - Formatlash funksiyalari (sana, narx, matn xavfsizligi)
//  - Holat (state) saqlash joyi
//
// MUHIM: Bu fayldan oldin <script src="supabase-config.js"> va
// Supabase JS SDK <script> tegi yuklangan, va `const supabase = ...`
// global o'zgaruvchisi yaratilgan bo'lishi kerak.

window.SBApp = (function () {
  const state = {
    listeners: {},      // { key: { channel, unsubscribe } }
    cache: {}            // { key: array of rows }
  };

  // ──────────────────────────────────────────────
  // FORMATLASH YORDAMCHILARI
  // ──────────────────────────────────────────────

  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function number(n) {
    const v = Number(n) || 0;
    return v.toLocaleString('ru-RU').replace(/,/g, ' ');
  }

  function formatPrice(n) {
    return number(n) + " so'm";
  }

  function toMillis(value) {
    if (!value) return 0;
    if (typeof value === 'number') return value;
    const t = new Date(value).getTime();
    return isNaN(t) ? 0 : t;
  }

  function formatDate(value) {
    const ms = toMillis(value);
    if (!ms) return '—';
    const d = new Date(ms);
    const pad = (x) => String(x).padStart(2, '0');
    return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function nowServer() {
    // Supabase'da serverdagi "now()" qiymatini olish uchun maxsus
    // chaqiruv shart emas — created_at ustunlari "default now()" bilan
    // avtomatik to'ldiriladi. Frontend tomonda taxminiy vaqt sifatida
    // joriy mahalliy vaqtni qaytaramiz.
    return new Date().toISOString();
  }

  // ──────────────────────────────────────────────
  // REAL-TIME OBUNA BOSHQARUVI
  // ──────────────────────────────────────────────
  // listenMany({ key, table, filter, orderBy, callback })
  // Firestore'dagi onSnapshot'ga o'xshash: jadvaldagi har qanday
  // o'zgarishda (insert/update/delete) callback qayta chaqiriladi
  // va to'liq, joriy ro'yxat (array) beriladi.

  async function fetchTable(table, { filter, orderColumn, ascending } = {}) {
    let query = supabase.from(table).select('*');
    if (filter) query = filter(query);
    if (orderColumn) query = query.order(orderColumn, { ascending: ascending !== false });
    const { data, error } = await query;
    if (error) {
      console.warn(`[SBApp] ${table} so'rovida xato:`, error.message);
      return [];
    }
    return data || [];
  }

  function listenMany({ key, table, filter, orderColumn, ascending, callback }) {
    // Avvalgi obunani tozalaymiz (qayta chaqirilganda dublikat bo'lmasin)
    if (state.listeners[key]) {
      cleanupListener(key);
    }

    // Boshlang'ich ma'lumotni darhol yuklaymiz
    fetchTable(table, { filter, orderColumn, ascending }).then(rows => {
      state.cache[key] = rows;
      callback(rows);
    });

    // Real-time o'zgarishlarga obuna bo'lamiz
    const channel = supabase
      .channel(`sbapp_${key}_${Date.now()}`)
      .on('postgres_changes', { event: '*', schema: 'public', table }, () => {
        // Har qanday o'zgarishda jadvalni to'liq qayta yuklaymiz
        // (Firestore onSnapshot xulq-atvoriga o'xshash, oddiy va ishonchli)
        fetchTable(table, { filter, orderColumn, ascending }).then(rows => {
          state.cache[key] = rows;
          callback(rows);
        });
      })
      .subscribe();

    state.listeners[key] = { channel, table };
    return key;
  }

  function cleanupListener(key) {
    const entry = state.listeners[key];
    if (entry && entry.channel) {
      supabase.removeChannel(entry.channel);
    }
    delete state.listeners[key];
  }

  function cleanupListeners() {
    Object.keys(state.listeners).forEach(cleanupListener);
  }

  // ──────────────────────────────────────────────
  // BUYURTMALARNI AVTOMATIK TOZALASH
  // ──────────────────────────────────────────────
  // Muddati o'tgan, hali to'lov qilinmagan buyurtmalarni bekor qiladi.
  // Firestore versiyasida client tomonda ishlagan, shu mantiqni saqlaymiz.

  async function cleanupExpiredOrders(timeoutMinutes = 30) {
    try {
      const cutoff = new Date(Date.now() - timeoutMinutes * 60 * 1000).toISOString();
      const { data, error } = await supabase
        .from('orders')
        .update({ status: 'rejected' })
        .eq('status', 'pending_payment')
        .lt('created_at', cutoff)
        .select('id');
      if (error) {
        console.warn('[SBApp] cleanupExpiredOrders xato:', error.message);
        return;
      }
      if (data && data.length) {
        console.log(`[SBApp] ${data.length} ta muddati o'tgan buyurtma bekor qilindi`);
      }
    } catch (e) {
      console.warn('[SBApp] cleanupExpiredOrders xato:', e.message);
    }
  }

  // ──────────────────────────────────────────────
  // JOIZ FOYDALANUVCHI PROFILINI OLISH
  // ──────────────────────────────────────────────

  async function getCurrentProfile() {
    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) return null;
    const { data, error } = await supabase.from('profiles').select('*').eq('id', authData.user.id).single();
    if (error) {
      console.warn('[SBApp] Profil olishda xato:', error.message);
      return null;
    }
    return data;
  }

  return {
    state,
    escapeHtml,
    number,
    formatPrice,
    toMillis,
    formatDate,
    nowServer,
    fetchTable,
    listenMany,
    cleanupListener,
    cleanupListeners,
    cleanupExpiredOrders,
    getCurrentProfile
  };
})();
