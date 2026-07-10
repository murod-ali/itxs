// ===== SUPABASE CONFIG =====
// Firebase o'rniga shu faylni ishlating

const SUPABASE_URL = 'https://ylllpkkbohsjlmxdaimm.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_h6lVVhApt3CQxDCyUU4JVQ_uuGeTtZm';

// ===== IMGBB API KEY =====
// Rasm (chek, screenshot) yuklash uchun. api.imgbb.com dan oling.
const IMGBB_API_KEY = '7fca1aaaf7b2c2cf850220bb00b51995';

// Supabase client
const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ===== SUPERADMIN =====
const SUPERADMIN_PROFILE = {
  name: 'Superadmin',
  userId: 'ADM001',
  login: 'mirzo2005',
  email: 'shmurodov200@gmail.com',
  password: '01070521'
};

// ===== YORDAMCHI FUNKSIYALAR =====
function isSuperadminEmail(value) {
  return String(value || '').trim().toLowerCase() === SUPERADMIN_PROFILE.email.toLowerCase();
}

function isSuperadminIdentity(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === SUPERADMIN_PROFILE.login.toLowerCase() ||
    normalized === SUPERADMIN_PROFILE.email.toLowerCase();
}

function normalizeRole(role) {
  const normalized = String(role || '').trim().toLowerCase();
  return ['admin', 'worker', 'customer'].includes(normalized) ? normalized : 'customer';
}

function openSuperadminPanel() {
  localStorage.setItem('sb_admin_profile', JSON.stringify(SUPERADMIN_PROFILE));
  sessionStorage.setItem('sb_admin_auth', '1');
  sessionStorage.removeItem('sb_superadmin_preview');
  localStorage.removeItem('sb_current_user');
  localStorage.removeItem('sb_current_worker');
  window.location.href = 'admin.html';
}

function clearAuthStorage() {
  sessionStorage.removeItem('sb_admin_auth');
  sessionStorage.removeItem('sb_superadmin_preview');
  localStorage.removeItem('sb_current_user');
  localStorage.removeItem('sb_current_worker');
}

function openHelp() {
  const link = (localStorage.getItem('sb_help_link') || '').trim();
  if (link) window.location.href = link;
  else alert('Yordam havolasi hali Superadmin tomonidan kiritilmagan.');
}
