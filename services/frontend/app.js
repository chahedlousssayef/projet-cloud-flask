const API = '/api';
const DIGITS = ['0','1','2','3','4','5','6','7','8','9'];
const digitImages = {};

function toast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.remove('show'), 2800);
}

async function checkHealth() {
  const el = document.getElementById('statusDot');
  try {
    const res = await fetch(`${API}/../health`);
    if (res.ok) {
      el.innerHTML = '<span class="dot online"></span><span class="status-text">En ligne</span>';
      el.title = 'Backend connecté';
      return true;
    }
  } catch(e) {}
  el.innerHTML = '<span class="dot offline"></span><span class="status-text">Hors ligne</span>';
  el.title = 'Backend non disponible';
  return false;
}

function buildGrid() {
  const grid = document.getElementById('digitGrid');
  DIGITS.forEach(d => {
    const card = document.createElement('div');
    card.className = 'digit-card';
    card.innerHTML = `
      <span class="label">${d}</span>
      <div class="thumb" id="thumb-${d}"><span class="placeholder">Aucune<br>image</span></div>
      <input type="file" accept="image/*" id="input-${d}">
      <div class="actions">
        <button class="btn btn-upload" onclick="document.getElementById('input-${d}').click()">Choisir</button>
        <button class="btn btn-delete" onclick="deleteDigit('${d}')">Supprimer</button>
      </div>`;
    card.querySelector('input').addEventListener('change', e => uploadDigit(d, e.target));
    grid.appendChild(card);
  });
}

async function loadDigits() {
  try {
    const res = await fetch(`${API}/clock/digits`);
    if (!res.ok) return;
    const data = await res.json();
    data.forEach(item => {
      digitImages[item.digit] = `${API}/clock/digits/${item.digit}/image?t=${Date.now()}`;
      updateThumb(item.digit);
    });
  } catch(e) {}
}

function updateThumb(digit) {
  const thumb = document.getElementById(`thumb-${digit}`);
  if (!thumb) return;
  if (digitImages[digit]) {
    thumb.innerHTML = `<img src="${digitImages[digit]}" alt="Digit ${digit}">`;
  } else {
    thumb.innerHTML = '<span class="placeholder">Aucune<br>image</span>';
  }
}

async function uploadDigit(digit, input) {
  if (!input.files.length) return;
  const fd = new FormData();
  fd.append('image', input.files[0]);
  try {
    const res = await fetch(`${API}/clock/digits/${digit}`, { method: 'POST', body: fd });
    if (!res.ok) throw new Error((await res.json()).error || 'Erreur upload');
    digitImages[digit] = `${API}/clock/digits/${digit}/image?t=${Date.now()}`;
    updateThumb(digit);
    toast(`Image du chiffre ${digit} mise à jour ✓`);
  } catch(e) {
    toast('Erreur : ' + e.message);
  }
  input.value = '';
}

async function deleteDigit(digit) {
  try {
    const res = await fetch(`${API}/clock/digits/${digit}`, { method: 'DELETE' });
    if (!res.ok && res.status !== 204) throw new Error('Erreur suppression');
    delete digitImages[digit];
    updateThumb(digit);
    toast(`Image du chiffre ${digit} supprimée`);
  } catch(e) {
    toast('Erreur : ' + e.message);
  }
}

function updateClock() {
  const now = new Date();
  const h = String(now.getHours()).padStart(2, '0');
  const m = String(now.getMinutes()).padStart(2, '0');
  const s = String(now.getSeconds()).padStart(2, '0');
  const digits = [h[0], h[1], m[0], m[1], s[0], s[1]];
  const positions = ['h1','h2','m1','m2','s1','s2'];

  positions.forEach((pos, i) => {
    const slot = document.querySelector(`[data-pos="${pos}"]`);
    if (!slot) return;
    const fallback = slot.querySelector('.fallback');
    const img = slot.querySelector('img');
    const d = digits[i];

    fallback.textContent = d;
    if (digitImages[d]) {
      const newSrc = digitImages[d];
      if (img.src !== newSrc) img.src = newSrc;
      img.classList.add('loaded');
    } else {
      img.classList.remove('loaded');
      img.removeAttribute('src');
    }
  });

  const dateEl = document.getElementById('clockDate');
  if (dateEl) {
    dateEl.textContent = now.toLocaleDateString('fr-FR', {
      weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
    });
  }
}

document.querySelectorAll('.nav-links a').forEach(link => {
  link.addEventListener('click', () => {
    document.querySelectorAll('.nav-links a').forEach(l => l.classList.remove('active'));
    link.classList.add('active');
  });
});

buildGrid();
checkHealth();
setInterval(checkHealth, 30000);

loadDigits().then(() => {
  updateClock();
  setInterval(updateClock, 1000);
});
