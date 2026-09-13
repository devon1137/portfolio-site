document.addEventListener('DOMContentLoaded', () => {
  const header = document.querySelector('header.site');
  const toggle = document.querySelector('.nav-toggle');
  const nav = document.querySelector('nav.primary');

  // ---- External links always open in a new tab ----
  // Enforced here so links added later (in HTML or by hand) can't miss it.
  document.querySelectorAll('a[href]').forEach((a) => {
    let url;
    try { url = new URL(a.getAttribute('href'), location.href); } catch { return; }
    if (!/^https?:$/.test(url.protocol) || url.hostname === location.hostname) return;
    a.setAttribute('target', '_blank');
    const rel = new Set((a.getAttribute('rel') || '').split(/\s+/).filter(Boolean));
    rel.add('noopener');
    a.setAttribute('rel', [...rel].join(' '));
  });

  // ---- Sticky header: add a shadow/rule once the page has scrolled ----
  if (header) {
    const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // ---- Card hover phases (.hex-card honeycomb, .orbit-card meteor) ----
  // Three phases, expressed as classes the CSS animates:
  //   is-lit      entering from data-from, then held while hovering
  //   is-leaving  exiting toward data-to, removed when that finishes
  // Directions come from the nearest edge at mouseenter / mouseleave.
  // A leave that arrives while the enter animation is still running is
  // queued until it ends, so a quick pass over a card still plays both
  // halves in full instead of jumping to solid and back.
  // The CSS names which animations close each phase: practice-wipe-in* /
  // orbit-in end the entering phase, practice-meteor-out* / orbit-out end
  // the leaving one.
  const ORBIT_TAIL = 34; // tail dashes behind the head (see .orbit-card in the CSS)
  document.querySelectorAll('.hex-card, .orbit-card').forEach((card) => {
    let entering = false;    // wipe-in still running
    let pendingLeave = null; // edge to leave toward once it has
    const orbits = card.classList.contains('orbit-card');

    // Orbit cards get their comet: a wrapper holding the head dash plus
    // the tail, each dash numbered so the CSS can stagger and fade it.
    if (orbits) {
      const train = document.createElement('span');
      train.className = 'orbit';
      train.setAttribute('aria-hidden', 'true');
      train.style.setProperty('--orbit-n', ORBIT_TAIL);
      for (let i = 0; i <= ORBIT_TAIL; i++) {
        const dash = document.createElement('i');
        dash.style.setProperty('--i', i);
        train.appendChild(dash);
      }
      card.appendChild(train);
    }
    // Where along the border (clockwise from the top-left corner, as a
    // fraction of the perimeter) the midpoint of a given edge sits.
    const edgeStart = (edge) => {
      const w = card.offsetWidth, h = card.offsetHeight, p = 2 * (w + h);
      const at = { top: w / 2, right: w + h / 2, bottom: 1.5 * w + h, left: 2 * w + 1.5 * h };
      return `${(100 * at[edge] / p).toFixed(2)}%`;
    };

    const nearestEdge = (e) => {
      const r = card.getBoundingClientRect();
      const dist = {
        left: e.clientX - r.left,
        right: r.right - e.clientX,
        top: e.clientY - r.top,
        bottom: r.bottom - e.clientY,
      };
      return Object.keys(dist).reduce((a, b) => (dist[a] <= dist[b] ? a : b));
    };

    const enter = (from) => {
      pendingLeave = null;
      if (card.classList.contains('is-lit')) return; // already in or held; just cancel any queued leave
      card.classList.remove('is-leaving');
      delete card.dataset.to;
      card.dataset.from = from;
      if (orbits) card.style.setProperty('--orbit-from', edgeStart(from));
      entering = true;
      card.classList.add('is-lit');
    };
    const leave = (to) => {
      if (!card.classList.contains('is-lit')) return;
      if (entering) { pendingLeave = to; return; }
      card.dataset.to = to;
      card.classList.remove('is-lit');
      card.classList.add('is-leaving');
      if (orbits) {
        // Explode where the head is right now. Its rect already reflects
        // the motion path, so this is the on-screen spot, made relative
        // to the card's padding box (1px border).
        const head = card.querySelector('.orbit > i').getBoundingClientRect();
        const box = card.getBoundingClientRect();
        const burst = document.createElement('span');
        burst.className = 'burst';
        burst.setAttribute('aria-hidden', 'true');
        burst.style.setProperty('--x', `${head.left + head.width / 2 - box.left - 1}px`);
        burst.style.setProperty('--y', `${head.top + head.height / 2 - box.top - 1}px`);
        card.appendChild(burst);
      }
    };

    card.addEventListener('mouseenter', (e) => enter(nearestEdge(e)));
    card.addEventListener('mouseleave', (e) => leave(nearestEdge(e)));
    // Keyboard: in from the left, out to the right.
    card.addEventListener('focusin', () => enter('left'));
    card.addEventListener('focusout', (e) => { if (!card.contains(e.relatedTarget)) leave('right'); });

    card.addEventListener('animationend', (e) => {
      const n = e.animationName;
      if (n.startsWith('practice-wipe-in') || n === 'orbit-in') {
        entering = false;
        if (pendingLeave) { const to = pendingLeave; pendingLeave = null; leave(to); }
      } else if (n.startsWith('practice-meteor-out') || n === 'orbit-out') {
        // Outlasts everything else in the phase, so it ends it. The burst
        // is one-shot DOM, so it goes too. A re-enter mid-burst has
        // already put the card back in is-lit; only is-leaving is cleared.
        if (n === 'orbit-out') e.target.remove();
        card.classList.remove('is-leaving');
        delete card.dataset.to;
      }
    });
  });

  // ---- Mobile nav ----
  if (toggle && nav) {
    const setOpen = (open) => {
      nav.classList.toggle('open', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    };
    const isOpen = () => nav.classList.contains('open');

    toggle.addEventListener('click', () => setOpen(!isOpen()));

    // Close on Escape, on outside click, on link click, and when the
    // viewport grows past the mobile breakpoint.
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && isOpen()) { setOpen(false); toggle.focus(); }
    });
    document.addEventListener('click', (e) => {
      if (isOpen() && !nav.contains(e.target) && !toggle.contains(e.target)) setOpen(false);
    });
    nav.addEventListener('click', (e) => { if (e.target.closest('a')) setOpen(false); });
    window.matchMedia('(min-width: 721px)').addEventListener('change', (mq) => { if (mq.matches) setOpen(false); });
  }

  // ---- Agreement form (agreement.html) — submits to Netlify Forms via fetch ----
  const agreement = document.querySelector('form[data-agreement]');
  if (agreement) {
    const status = agreement.querySelector('.form-status');
    const done = agreement.querySelector('.form-done');
    const submitBtn = agreement.querySelector('button[type="submit"]');
    const printed = agreement.elements.client_printed_name;
    const sig = agreement.elements.client_signature;
    const sigError = agreement.querySelector('.field-error[data-for="client_signature"]');
    const dateField = agreement.elements.client_date;

    // Default the date to today (local), but leave it editable.
    if (dateField && !dateField.value) {
      const d = new Date();
      dateField.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    }

    agreement.querySelector('[data-print]')?.addEventListener('click', () => window.print());

    const norm = (s) => s.trim().replace(/\s+/g, ' ').toLowerCase();
    const sigMatches = () => norm(sig.value) === norm(printed.value);

    const validate = () => {
      let ok = true;
      agreement.querySelectorAll('[required]').forEach((el) => {
        const valid = el.type === 'checkbox' ? el.checked : el.checkValidity();
        el.classList.toggle('invalid', !valid);
        if (!valid) ok = false;
      });
      const match = sig.value.trim() !== '' && sigMatches();
      sig.classList.toggle('invalid', !match);
      sigError.classList.toggle('show', !match && sig.value.trim() !== '');
      return ok && match;
    };
    [printed, sig].forEach((el) => el.addEventListener('input', () => {
      if (sig.classList.contains('invalid')) { sig.classList.toggle('invalid', !sigMatches()); sigError.classList.toggle('show', !sigMatches()); }
    }));

    agreement.addEventListener('submit', async (e) => {
      e.preventDefault();
      status.textContent = '';
      status.classList.remove('error');
      if (!validate()) {
        status.textContent = 'A few fields still need attention, they’re marked in red above.';
        status.classList.add('error');
        agreement.querySelector('.invalid')?.focus();
        return;
      }
      agreement.elements.signed_at.value = new Date().toISOString();
      submitBtn.disabled = true;
      status.textContent = 'Sending…';
      try {
        const res = await fetch(agreement.getAttribute('action') || '/', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams(new FormData(agreement)).toString(),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        status.textContent = '';
        done.classList.add('show');
        agreement.querySelectorAll('input, button').forEach((el) => { if (el.type !== 'button') el.readOnly = true; });
        submitBtn.hidden = true;
        done.scrollIntoView({ block: 'center', behavior: 'smooth' });
      } catch (err) {
        submitBtn.disabled = false;
        status.textContent = 'That didn’t go through. Please try again, or email the signed page to devon.kubacki@gmail.com using Print / Save as PDF.';
        status.classList.add('error');
      }
    });
  }

  // ---- Gallery lightbox (native <dialog>; only present on gallery.html) ----
  const lightbox = document.querySelector('dialog.lightbox');
  if (lightbox && typeof lightbox.showModal === 'function') {
    const img = lightbox.querySelector('img');
    const closeBtn = lightbox.querySelector('.close');
    let lastTrigger = null;

    const open = (fig) => {
      img.src = fig.getAttribute('data-full');
      img.alt = fig.querySelector('figcaption')?.textContent.trim() || '';
      lastTrigger = fig;
      lightbox.showModal();
    };

    document.querySelectorAll('.gallery-grid figure[data-full]').forEach((fig) => {
      // Make placeholder-turned-real tiles keyboard reachable without
      // changing the markup the README asks people to write.
      fig.setAttribute('tabindex', '0');
      fig.setAttribute('role', 'button');
      fig.setAttribute('aria-label', `Open full-size: ${fig.querySelector('figcaption')?.textContent.trim() || 'image'}`);
      fig.addEventListener('click', () => open(fig));
      fig.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(fig); }
      });
    });

    closeBtn?.addEventListener('click', () => lightbox.close());
    // <dialog> closes on Escape natively; this covers browsers that don't.
    lightbox.addEventListener('keydown', (e) => { if (e.key === 'Escape') { e.preventDefault(); lightbox.close(); } });
    // Click on the backdrop (outside the image) closes.
    lightbox.addEventListener('click', (e) => {
      if (e.target === lightbox || e.target.classList.contains('stage')) lightbox.close();
    });
    lightbox.addEventListener('close', () => {
      img.removeAttribute('src');
      lastTrigger?.focus();
    });
  }
});
