(() => {
  const API_URL = (window.__CONFIG__ && window.__CONFIG__.API_URL) || "";
  const postsEl = document.getElementById("posts");
  const btnMore = document.getElementById("btnMore");
  const toastEl = document.getElementById("toast");
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  let nextCursor = null;
  let loading = false;

  function showToast(msg, ok=true) {
    toastEl.textContent = msg;
    toastEl.style.background = ok ? "#0b2817" : "#3a0b0b";
    toastEl.style.borderColor = ok ? "#124d2b" : "#5a1b1b";
    toastEl.classList.add("show");
    setTimeout(() => toastEl.classList.remove("show"), 2500);
  }

  function fmtDate(iso) {
    try { return new Date(iso).toLocaleDateString('pt-BR', { day:"2-digit", month:"short", year:"numeric"}); }
    catch { return iso || ""; }
  }

  function el(html) {
    const d = document.createElement("div");
    d.innerHTML = html.trim();
    return d.firstElementChild;
  }

  async function fetchPosts(initial=false) {
    if (!API_URL) return showToast("Defina API_URL em config.js", false);

    if (loading) return;
    loading = true;
    btnMore.disabled = true;

    const url = new URL(API_URL + "/api/posts");
    url.searchParams.set("limit", "9");
    if (!initial && nextCursor) url.searchParams.set("cursor", nextCursor);

    try {
      const res = await fetch(url, { headers: { "content-type": "application/json" } });
      if (!res.ok) throw new Error("Falha ao carregar posts: " + res.status);
      const data = await res.json();
      const items = data.items || [];
      nextCursor = data.nextCursor || null;

      if (initial && items.length === 0) {
        postsEl.appendChild(el(`<p class="muted">Nenhum post publicado ainda.</p>`));
      } else {
        for (const p of items) {
          postsEl.appendChild(renderPostCard(p));
        }
      }

      btnMore.disabled = !nextCursor;
    } catch (err) {
      console.error(err);
      showToast(err.message, false);
    } finally {
      loading = false;
    }
  }

  function renderPostCard(p) {
    const title = p.title || (p.slug ? p.slug.replace(/[-_]/g," ") : "Sem título");
    const published = p.publishedAt ? fmtDate(p.publishedAt) : "";
    const author = p.author || "Autor";
    const excerpt = p.excerpt || (p.content ? String(p.content).slice(0, 160) + "…" : "");
    const cover = p.coverUrl || "https://picsum.photos/800/400?random=" + Math.floor(Math.random()*1000);
    const slug = (p.slug || "").toString();

    const card = el(`
      <article class="post-card" data-slug="${slug}">
        <img class="post-cover" alt="" src="${cover}" loading="lazy" />
        <div class="post-body">
          <h3 class="post-title">${escapeHtml(title)}</h3>
          <div class="post-meta">
            ${published ? `<span>📅 ${published}</span>` : ""}
            ${author ? `<span>✍️ ${escapeHtml(author)}</span>` : ""}
          </div>
          ${Array.isArray(p.tags) && p.tags.length ? `<div class="tags">${p.tags.map(t => `<span class="tag">#${escapeHtml(String(t))}</span>`).join("")}</div>` : ""}
          ${excerpt ? `<p class="post-excerpt">${escapeHtml(excerpt)}</p>` : ""}
          <div class="card-actions">
            <button class="btn secondary" type="button">Comentar</button>
          </div>

          <form class="comment-form" hidden>
            <input type="text" name="author" placeholder="Seu nome" autocomplete="name" required>
            <input type="email" name="email" placeholder="Seu e-mail (opcional)" autocomplete="email">
            <textarea name="content" placeholder="Escreva um comentário..." required></textarea>
            <div class="row">
              <button class="btn" type="submit">Enviar comentário</button>
              <span class="status"></span>
            </div>
          </form>
        </div>
      </article>
    `);

    const btnComment = card.querySelector(".btn.secondary");
    const form = card.querySelector(".comment-form");
    const statusEl = card.querySelector(".status");

    btnComment.addEventListener("click", () => {
      form.hidden = !form.hidden;
      if (!form.hidden) form.querySelector("input[name=author]").focus();
    });

    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      if (!slug) return showToast("Slug ausente no post", false);
      const fd = new FormData(form);
      const payload = {
        author: fd.get("author")?.toString()?.trim(),
        email: fd.get("email")?.toString()?.trim() || undefined,
        content: fd.get("content")?.toString()?.trim(),
      };
      if (!payload.author || !payload.content) {
        return showToast("Preencha nome e comentário.", false);
      }
      statusEl.textContent = "Enviando…";

      try {
        const res = await fetch(`${API_URL}/api/posts/${encodeURIComponent(slug)}/comments`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(payload),
        });
        if (!res.ok) {
          const txt = await res.text();
          throw new Error(`Falha ao enviar: ${res.status} ${txt}`);
        }
        showToast("Comentário enviado para moderação.");
        statusEl.textContent = "Enviado ✔";
        form.reset();
      } catch (err) {
        console.error(err);
        showToast(err.message || "Erro ao enviar.", false);
        statusEl.textContent = "Erro ao enviar.";
      }
    });

    return card;
  }

  function escapeHtml(s){
    return String(s).replace(/[&<>"']/g, m => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
    })[m]);
  }

  // initial fetch
  fetchPosts(true);
  btnMore.addEventListener("click", () => fetchPosts(false));
})();
