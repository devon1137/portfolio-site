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

  // ---- Blinking hexes on the hero honeycomb (home hero + page intros) ----
  // A pool of hex outlines inside .hex-blinks, a layer that pans with the
  // pattern. Each one is parked on a lattice cell, flashed, then moved to
  // another random cell after a random pause. The lattice geometry
  // matches the CSS tile (side 22px, pointy-top): cell centres sit at
  // y = 22 + 33j, x = 38.105i, offset by half a cell on even rows.
  const blinkLayer = document.querySelector('.hex-blinks');
  if (blinkLayer && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const W = 38.105, ROW = 33, POOL = 6, PAN_MS = 20000;
    const rnd = (a, b) => a + Math.random() * (b - a);

    // Keep the layer's pan in phase with the pattern's, whatever order
    // their animations happened to start in.
    const patternPan = document.getAnimations().find((a) => a.animationName === 'hex-pan');
    const layerPan = blinkLayer.getAnimations().find((a) => a.animationName === 'hex-blinks-pan');
    if (patternPan && layerPan) layerPan.currentTime = patternPan.currentTime;

    const place = (el) => {
      // Random cell, biased to the middle of the layer where the mask is
      // bright (the outer ring fades to nothing anyway).
      const w = blinkLayer.clientWidth, h = blinkLayer.clientHeight;
      const j = Math.round(rnd(0.12, 0.58) * h / ROW);   /* mask is brightest around (40%, 35%) */
      const i = Math.round(rnd(0.15, 0.65) * w / W);
      const cx = i * W + (j % 2 === 0 ? W / 2 : 0);
      const cy = 22 + j * ROW;
      el.style.left = `${cx - W / 2}px`;
      el.style.top = `${cy - 22}px`;
    };
    const schedule = (el) => {
      let wait = rnd(400, 2600);
      const dur = rnd(600, 1100);
      // Don't let a flash straddle the pan's loop point (the layer snaps
      // back by one lattice step there and the hex would visibly jump).
      if (layerPan) {
        const untilLoop = PAN_MS - (layerPan.currentTime % PAN_MS);
        if (untilLoop < wait + dur + 100 && untilLoop > wait) wait = untilLoop + 50;
      }
      setTimeout(() => {
        place(el);
        el.style.setProperty('--dur', `${Math.round(dur)}ms`);
        el.classList.remove('on');
        el.getBoundingClientRect();          // force a reflow so the animation restarts (SVG has no offsetWidth)
        el.classList.add('on');
      }, wait);
    };

    for (let n = 0; n < POOL; n++) {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('class', 'blink');
      svg.setAttribute('viewBox', '0 0 38.105 44');
      const hex = document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
      hex.setAttribute('points', '19.05,0.75 37.35,11.4 37.35,32.6 19.05,43.25 0.75,32.6 0.75,11.4');
      svg.appendChild(hex);
      svg.addEventListener('animationend', () => schedule(svg));
      blinkLayer.appendChild(svg);
      schedule(svg);
    }
  }

  // ---- Track Record count-up (index.html) ----
  // Each .record .value rolls from 0 to its printed figure the first time
  // its row is well into view — after the row's own slide-in, so the two
  // don't compete. Prefix ($), thousands separators, decimals and suffix
  // (+, %) are all read from the markup and preserved.
  const values = document.querySelectorAll('.record .value');
  if (values.length && 'IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const parse = (text) => {
      const m = text.trim().match(/^([^\d]*)([\d,]+(?:\.\d+)?)(.*)$/);
      if (!m) return null;
      const decimals = (m[2].split('.')[1] || '').length;
      return { prefix: m[1], target: parseFloat(m[2].replace(/,/g, '')), decimals, suffix: m[3] };
    };
    const fmt = (n, d) => n.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
    const roll = (el, spec) => {
      const dur = 1100, t0 = performance.now();
      const step = (now) => {
        const p = Math.min(1, (now - t0) / dur);
        const eased = 1 - Math.pow(1 - p, 3);          // ease-out cubic
        el.textContent = spec.prefix + fmt(spec.target * eased, spec.decimals) + spec.suffix;
        if (p < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    };
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        io.unobserve(e.target);
        const spec = parse(e.target.textContent);
        if (!spec) return;
        e.target.textContent = spec.prefix + fmt(0, spec.decimals) + spec.suffix;
        setTimeout(() => roll(e.target, spec), 350);   // let the row's slide-in land first
      });
    }, { threshold: 0.6 });
    values.forEach((v) => io.observe(v));
  }

  // ---- Work page entries: pills appear one at a time once in view ----
  // Each tag gets its index as --i for the CSS stagger; the entry is
  // marked .is-in the first time it's meaningfully on screen. Without
  // IntersectionObserver (or with reduced motion) the CSS shows them.
  const entries = document.querySelectorAll('.entries > .entry');
  if (entries.length && 'IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    entries.forEach((en) => en.querySelectorAll('.tags li').forEach((li, i) => li.style.setProperty('--i', i)));
    const io = new IntersectionObserver((list) => {
      list.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); } });
    }, { threshold: 0.25 });
    entries.forEach((en) => io.observe(en));
  } else {
    entries.forEach((en) => en.classList.add('is-in'));
  }

  // ---- Renamed anchors keep resolving ----
  // services.html#starter became #launch when the tier was renamed;
  // an old link is rewritten to the new hash and scrolled into place.
  const hashAliases = { '#starter': '#launch' };
  const newHash = hashAliases[location.hash];
  if (newHash && document.querySelector(newHash)) {
    history.replaceState(null, '', newHash);
    document.querySelector(newHash).scrollIntoView({ behavior: 'instant' });
  }

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

  // ---- Work submenu (case studies) ----
  // Hover/focus-within open it on desktop via CSS; the caret button toggles
  // it for touch and keyboard, and is the only way it opens on mobile.
  document.querySelectorAll('nav.primary .has-sub').forEach((item) => {
    const btn = item.querySelector('.sub-toggle');
    if (!btn) return;
    const set = (open) => { item.classList.toggle('open', open); btn.setAttribute('aria-expanded', open ? 'true' : 'false'); };
    btn.addEventListener('click', (e) => { e.stopPropagation(); set(!item.classList.contains('open')); });
    document.addEventListener('click', (e) => { if (item.classList.contains('open') && !item.contains(e.target)) set(false); });
    item.addEventListener('keydown', (e) => { if (e.key === 'Escape' && item.classList.contains('open')) { set(false); btn.focus(); } });
    // Mouse leaving a hover-opened menu shouldn't leave the caret stuck open.
    item.addEventListener('mouseleave', () => { if (!item.contains(document.activeElement)) set(false); });
  });

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

    // Package selector: the sections carry [data-pkg="launch"|"foundation"]
    // variants; only the chosen package's show (and print). ?package=launch
    // in the URL preselects, so each services-page button lands on its own
    // terms. The heading follows.
    const pkgRadios = [...agreement.querySelectorAll('input[name="package"]')];
    if (pkgRadios.length) {
      const names = { launch: 'Launch Package', foundation: 'Foundation Package' };
      const applyPkg = () => {
        const pkg = agreement.elements.package.value;
        // An element shows when its package matches (if it names one). A
        // discount row stays in the table either way, struck through until
        // its box in Section 4 is ticked, so the reader sees what's on offer.
        document.querySelectorAll('[data-pkg], [data-discount]').forEach((el) => {
          el.hidden = !!el.dataset.pkg && el.dataset.pkg !== pkg;
          if (el.dataset.discount) {
            const box = agreement.elements[el.dataset.discount];
            el.classList.toggle('is-off', !(box && box.checked));
          }
        });
        document.querySelectorAll('[data-pkg-name]').forEach((el) => { el.textContent = names[pkg]; });
        document.title = `${names[pkg]} Agreement — Devon Kubacki`;
        // Price table: the deposit is half the package price; the ticked
        // discounts come off the other half; the total is their sum.
        const money = (n) => '$' + n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        const priceCell = [...document.querySelectorAll('[data-price]')].find((c) => !c.closest('tr').hidden);
        if (priceCell) {
          const half = Number(priceCell.dataset.price) / 2;
          const off = [...document.querySelectorAll('[data-off]')]
            .filter((c) => { const tr = c.closest('tr'); return !tr.hidden && !tr.classList.contains('is-off'); })
            .reduce((sum, c) => sum + Number(c.dataset.off), 0);
          priceCell.textContent = money(half);
          document.querySelector('[data-balance]').textContent = money(half - off);
          document.querySelector('[data-total]').textContent = money(half + half - off);
        }
      };
      // The hand-coded tier was Starter Site, then Foundation Package, now Launch Package; old links keep landing on it.
      const aliases = { starter: 'launch' };
      const asked = new URLSearchParams(location.search).get('package');
      const wanted = aliases[asked] || asked;
      const pre = pkgRadios.find((r) => r.value === wanted);
      if (pre) pre.checked = true;
      pkgRadios.forEach((r) => r.addEventListener('change', applyPkg));
      // The discount boxes (Section 4) re-run the same visibility pass.
      ['footer_credit', 'own_copy'].forEach((n) => agreement.elements[n]?.addEventListener('change', applyPkg));
      applyPkg();
    }

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

  // ---- Lightbox (native <dialog>; gallery.html and projects.html) ----
  // Gallery-page tiles open it directly; entry galleries open it from
  // their main image (see below) via openLightbox. Prev/next and the
  // arrow keys step through the figures of the container the opened one
  // came from.
  let openLightbox = null;
  const lightbox = document.querySelector('dialog.lightbox');
  if (lightbox && typeof lightbox.showModal === 'function') {
    const img = lightbox.querySelector('img');
    const closeBtn = lightbox.querySelector('.close');
    const prevBtn = lightbox.querySelector('.lb-prev');
    const nextBtn = lightbox.querySelector('.lb-next');
    const caption = lightbox.querySelector('.lb-caption');
    let group = [];      // figures in the current gallery
    let index = -1;
    let lastTrigger = null;

    // Caption line: "<figcaption> · n / N", plus a link to the source page
    // (live, or the exact Wayback capture) when the figure has data-source.
    const sourceLink = document.createElement('a');
    sourceLink.className = 'lb-source';
    sourceLink.target = '_blank';
    sourceLink.rel = 'noopener';

    // 1:1 toggle — show the true-size file at its actual pixels (scrolling)
    // instead of fitted to the viewport. Click on the image toggles too.
    const zoomBtn = document.createElement('button');
    zoomBtn.type = 'button';
    zoomBtn.className = 'lb-zoom';
    zoomBtn.setAttribute('aria-pressed', 'false');
    zoomBtn.title = 'Toggle actual size (1:1)';
    zoomBtn.textContent = '1:1';
    lightbox.appendChild(zoomBtn);
    const setActual = (on) => {
      lightbox.classList.toggle('is-actual', on);
      zoomBtn.setAttribute('aria-pressed', String(on));
      zoomBtn.textContent = on ? 'Fit' : '1:1';
      if (on) { const stage = lightbox.querySelector('.stage'); stage.scrollTop = 0; stage.scrollLeft = 0; }
    };
    zoomBtn.addEventListener('click', () => setActual(!lightbox.classList.contains('is-actual')));
    img.addEventListener('click', () => setActual(!lightbox.classList.contains('is-actual')));

    const show = (i) => {
      index = (i + group.length) % group.length;
      const fig = group[index];
      setActual(false);
      img.src = fig.getAttribute('data-full');
      img.alt = fig.querySelector('img')?.alt || fig.querySelector('figcaption')?.textContent.trim() || '';
      if (caption) {
        const cap = fig.querySelector('figcaption')?.textContent.trim() || '';
        caption.textContent = group.length > 1 ? `${cap}  ·  ${index + 1} / ${group.length}` : cap;
        const src = fig.dataset.source;
        if (src) {
          // Mirror the frame's URL-bar link: an affiliate source keeps rel="sponsored" and says so.
          const affiliate = fig.querySelector('.frame a.url')?.rel.includes('sponsored');
          sourceLink.href = src;
          sourceLink.rel = affiliate ? 'sponsored noopener' : 'noopener';
          sourceLink.textContent = src.startsWith('https://web.archive.org/') ? 'Open archived page ↗' : (affiliate ? 'Open on Amazon (affiliate link) ↗' : 'Open live page ↗');
          caption.appendChild(sourceLink);
        }
      }
      const single = group.length < 2;
      if (prevBtn) prevBtn.hidden = single;
      if (nextBtn) nextBtn.hidden = single;
    };
    const open = (fig, trigger) => {
      const container = fig.closest('.entry-gallery, .gallery-grid') || document;
      group = [...container.querySelectorAll('figure[data-full]')];
      lastTrigger = trigger || fig;
      show(group.indexOf(fig));
      lightbox.showModal();
    };
    openLightbox = open;

    document.querySelectorAll('.gallery-grid figure[data-full]').forEach((fig) => {
      // Keyboard-reachable without changing the markup people write.
      fig.setAttribute('tabindex', '0');
      fig.setAttribute('role', 'button');
      fig.setAttribute('aria-label', `Open full-size: ${fig.querySelector('figcaption')?.textContent.trim() || 'image'}`);
      // The frame's URL is a real link; let it be one (no lightbox on that click,
      // and Enter on the focused link navigates instead of opening the dialog).
      fig.addEventListener('click', (e) => { if (!e.target.closest('a')) open(fig); });
      fig.addEventListener('keydown', (e) => {
        if (e.target !== fig) return;
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(fig); }
      });
    });

    prevBtn?.addEventListener('click', () => show(index - 1));
    nextBtn?.addEventListener('click', () => show(index + 1));
    closeBtn?.addEventListener('click', () => lightbox.close());
    lightbox.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { e.preventDefault(); lightbox.close(); }   // covers browsers that don't do it natively
      else if (e.key === 'ArrowLeft' && group.length > 1) { e.preventDefault(); show(index - 1); }
      else if (e.key === 'ArrowRight' && group.length > 1) { e.preventDefault(); show(index + 1); }
    });
    // Click on the backdrop (outside the image) closes.
    lightbox.addEventListener('click', (e) => {
      if (e.target === lightbox || e.target.classList.contains('stage')) lightbox.close();
    });
    lightbox.addEventListener('close', () => {
      img.removeAttribute('src');
      lastTrigger?.focus();
    });
  }

  // ---- Entry galleries (projects.html) — main image + thumbnails ----
  // The figures in .eg-track are the thumbnails (and the lightbox set).
  // A main slot is built from the active thumbnail's frame and caption;
  // clicking a thumbnail swaps it in, clicking the main opens the
  // lightbox at that shot. Galleries with a single image get no thumb row.
  document.querySelectorAll('.entry-gallery').forEach((g) => {
    const track = g.querySelector('.eg-track');
    const figs = [...g.querySelectorAll('figure[data-full]')];
    if (!track || !figs.length) return;

    // A div with role=button rather than a <button>: the cloned frame carries
    // the source-page link, and a link inside a button isn't valid HTML.
    const main = document.createElement('div');
    main.className = 'eg-main';
    main.setAttribute('role', 'button');
    main.setAttribute('tabindex', '0');
    g.insertBefore(main, track);
    let active = null;

    const setActive = (fig) => {
      active = fig;
      figs.forEach((f) => f.classList.toggle('is-active', f === fig));
      const cap = fig.querySelector('figcaption')?.textContent.trim() || '';
      const frame = fig.querySelector('.frame').cloneNode(true);
      // The thumbnail's <img> declares sizes="4.5rem"; the clone fills the
      // main slot, so tell the browser its real width to get the 960w file.
      const shot = frame.querySelector('img');
      if (shot) { shot.sizes = '(max-width: 720px) calc(100vw - 5rem), 744px'; shot.loading = 'eager'; }
      main.replaceChildren(frame);
      const caption = document.createElement('span');
      caption.className = 'eg-caption';
      caption.textContent = cap;
      main.appendChild(caption);
      main.setAttribute('aria-label', `Open full size: ${cap}`);
    };

    figs.forEach((fig) => {
      fig.setAttribute('tabindex', '0');
      fig.setAttribute('role', 'button');
      fig.setAttribute('aria-label', `Show: ${fig.querySelector('figcaption')?.textContent.trim() || 'image'}`);
      fig.addEventListener('click', (e) => { if (!e.target.closest('a')) setActive(fig); });
      fig.addEventListener('keydown', (e) => {
        if (e.target !== fig) return;
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); setActive(fig); }
      });
    });
    const openMain = () => { if (openLightbox && active) openLightbox(active, main); };
    main.addEventListener('click', (e) => { if (!e.target.closest('a')) openMain(); });
    main.addEventListener('keydown', (e) => {
      if (e.target !== main) return;
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openMain(); }
    });

    setActive(figs[0]);
    if (figs.length < 2) track.hidden = true;
  });

  // ---- TOC rail on narrow screens: a fixed "Contents" tab that opens the panel ----
  // The CSS only shows the tab below the rail breakpoint; at desktop widths
  // the rail is its usual sticky self and the button is display: none.
  document.querySelectorAll('.toc-rail').forEach((rail) => {
    const toc = rail.querySelector('.toc');
    if (!toc) return;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'toc-toggle';
    btn.setAttribute('aria-expanded', 'false');
    btn.setAttribute('aria-controls', toc.id || (toc.id = 'toc-panel'));
    btn.textContent = 'Contents';
    rail.prepend(btn);
    const setOpen = (open) => {
      rail.classList.toggle('open', open);
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    };
    btn.addEventListener('click', () => setOpen(!rail.classList.contains('open')));
    toc.addEventListener('click', (e) => { if (e.target.closest('a')) setOpen(false); });
    document.addEventListener('click', (e) => { if (rail.classList.contains('open') && !rail.contains(e.target)) setOpen(false); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && rail.classList.contains('open')) { setOpen(false); btn.focus(); } });
  });

  // ---- Sticky TOC rail: mark the section currently in view ----
  // The link whose target is the topmost section crossing the reader's line
  // (a third of the way down the viewport) gets aria-current="location".
  document.querySelectorAll('.toc-rail .toc').forEach((toc) => {
    const links = [...toc.querySelectorAll('a[href^="#"]')];
    const targets = links.map((a) => document.getElementById(decodeURIComponent(a.hash.slice(1)))).filter(Boolean);
    if (!targets.length) return;
    // Labels are clamped to two lines in CSS; keep the full title reachable.
    links.forEach((a) => { if (!a.title) a.title = a.textContent.trim(); });
    let ticking = false;
    const update = () => {
      ticking = false;
      const line = window.innerHeight / 3;
      let current = targets[0];
      for (const t of targets) { if (t.getBoundingClientRect().top <= line) current = t; else break; }
      links.forEach((a) => {
        const on = a.hash === '#' + current.id;
        if (on) a.setAttribute('aria-current', 'location'); else a.removeAttribute('aria-current');
      });
    };
    const onScroll = () => { if (!ticking) { ticking = true; requestAnimationFrame(update); } };
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();
  });

  // ---- Click-to-load video (figure.video[data-video]) ----
  // The page ships a local poster; YouTube's player is only requested when
  // the visitor presses play, so nothing third-party loads on page view. The
  // privacy-enhanced embed domain is used, and the iframe replaces the poster
  // with autoplay so it's one click, not two.
  document.querySelectorAll('figure.video[data-video]').forEach((fig) => {
    const btn = fig.querySelector('.video-poster');
    if (!btn) return;
    btn.addEventListener('click', () => {
      const id = fig.dataset.video;
      const iframe = document.createElement('iframe');
      iframe.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(id)}?autoplay=1&rel=0`;
      iframe.title = fig.dataset.videoTitle || 'Video';
      iframe.setAttribute('allow', 'autoplay; encrypted-media; picture-in-picture; fullscreen');
      iframe.setAttribute('allowfullscreen', '');
      iframe.setAttribute('loading', 'eager');
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      btn.replaceWith(iframe);
      iframe.focus();
    });
  });
});
