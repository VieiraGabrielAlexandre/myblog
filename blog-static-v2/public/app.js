(() => {
  const API_URL = (window.__CONFIG__ && window.__CONFIG__.API_URL) || "";
  const { fmtDate, escapeHtml } = window.__helpers || {};

  const postsEl = document.getElementById("posts");
  const btnMore = document.getElementById("btnMore");
  const toastEl = document.getElementById("toast");
  const searchInput = document.getElementById("search");
  const tagInput = document.getElementById("tag");
  const applyBtn = document.getElementById("applyFilters");
  const clearBtn = document.getElementById("clearFilters");

  // Se não estamos na index (elementos não existem), sai.
  if (!postsEl) return;

  let nextCursor = null;
  let loading = false;
  let allLoaded = [];

  function showToast(msg, ok=true) {
    if (!toastEl) return;
    toastEl.textContent = msg;
    toastEl.style.background = ok ? "#0b2817" : "#3a0b0b";
    toastEl.style.borderColor = ok ? "#124d2b" : "#5a1b1b";
    toastEl.classList.add("show");
    setTimeout(() => toastEl.classList.remove("show"), 2200);
  }

  async function fetchPosts(initial=false) {
    if (!API_URL) { showToast("Defina API_URL em config.js", false); return; }
    if (loading) return;
    loading = true;
    if (btnMore) btnMore.disabled = true;

    const url = new URL(API_URL + "/api/posts");
    url.searchParams.set("limit", "12");
    if (!initial && nextCursor) url.searchParams.set("cursor", nextCursor);

    try {
      const res = await fetch(url); // sem headers para evitar preflight
      if (!res.ok) throw new Error("Falha ao carregar posts: " + res.status);
      const data = await res.json();
      const items = data.items || [];
      nextCursor = data.nextCursor || null;
      allLoaded = initial ? items.slice() : allLoaded.concat(items);
      render(allLoaded);
      if (btnMore) btnMore.disabled = !nextCursor;
    } catch (err) {
      console.error(err);
      showToast(err.message, false);
    } finally {
      loading = false;
    }
  }

  function render(list) {
    const q = (searchInput?.value || "").toLowerCase().trim();
    const tags = (tagInput?.value || "")
      .split(",")
      .map(s => s.trim().toLowerCase())
      .filter(Boolean);

    const filtered = list.filter(p => {
      const hay = ((p.title||"") + " " + (p.author||"")).toLowerCase();
      const okQ = !q || hay.includes(q);
      const postTags = Array.isArray(p.tags) ? p.tags.map(t => String(t).toLowerCase()) : [];
      const okTags = tags.length === 0 || tags.every(t => postTags.includes(t));
      return okQ && okTags;
    });

    postsEl.innerHTML = "";
    if (filtered.length === 0) {
      postsEl.innerHTML = `<p class="muted">Nenhum post encontrado com os filtros.</p>`;
      return;
    }
    for (const p of filtered) {
      postsEl.appendChild(renderPostCard(p));
    }
  }

  function renderPostCard(p) {
    const title = p.title || (p.slug ? p.slug.replace(/[-_]/g," ") : "Sem título");
    const published = p.publishedAt ? fmtDate(p.publishedAt) : "";
    const author = p.author || "Autor";
    const excerpt = p.excerpt || (p.content ? String(p.content).slice(0, 160) + "…" : "");
    const cover = p.coverUrl || "https://picsum.photos/800/400?random=" + Math.floor(Math.random()*1000);
    const slug = (p.slug || "").toString();

    const el = document.createElement("article");
    el.className = "post-card";
    el.innerHTML = `
      <img class="post-cover" alt="" src="${cover}" loading="lazy" />
      <div class="post-body">
        <h3 class="post-title">
          <a href="post.html?slug=${encodeURIComponent(slug)}">${escapeHtml(title)}</a>
        </h3>
        <div class="post-meta">
          ${published ? `<span>📅 ${published}</span>` : ""}
          ${author ? `<span>✍️ ${escapeHtml(author)}</span>` : ""}
        </div>
        ${Array.isArray(p.tags) && p.tags.length ? `<div class="tags">${p.tags.map(t => `<span class="tag">#${escapeHtml(String(t))}</span>`).join("")}</div>` : ""}
        ${excerpt ? `<p class="post-excerpt">${escapeHtml(excerpt)}</p>` : ""}
      </div>
    `;
    return el;
  }

  // Bind filtros se existirem
  applyBtn?.addEventListener("click", () => render(allLoaded));
  clearBtn?.addEventListener("click", () => {
    if (searchInput) searchInput.value = "";
    if (tagInput) tagInput.value = "";
    render(allLoaded);
  });

  // Inicializar
  fetchPosts(true);
  btnMore?.addEventListener("click", () => fetchPosts(false));
})();
