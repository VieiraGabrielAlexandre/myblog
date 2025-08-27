(() => {
  const API_URL = (window.__CONFIG__ && window.__CONFIG__.API_URL) || "";
  const { fmtDate, escapeHtml } = window.__helpers || {};
  const toastEl = document.getElementById("toast");
  const articleEl = document.getElementById("article");
  const form = document.getElementById("commentForm");
  const statusEl = document.getElementById("status");
  const listEl = document.getElementById("commentsList");
  const moreBtn = document.getElementById("moreComments");

  if (!articleEl) return; // se não é a página de post, sai

  let commentsCursor = null;
  let loadingComments = false;

  function showToast(msg, ok=true) {
    if (!toastEl) return;
    toastEl.textContent = msg;
    toastEl.style.background = ok ? "#0b2817" : "#3a0b0b";
    toastEl.style.borderColor = ok ? "#124d2b" : "#5a1b1b";
    toastEl.classList.add("show");
    setTimeout(() => toastEl.classList.remove("show"), 2200);
  }

  const params = new URLSearchParams(location.search);
  const slug = params.get("slug");

  async function loadPost() {
    if (!slug) {
      articleEl.innerHTML = "<p class='muted'>Slug não informado.</p>";
      if (form) form.hidden = true;
      return;
    }
    try {
      const res = await fetch(`${API_URL}/api/posts/${encodeURIComponent(slug)}`);
      if (!res.ok) throw new Error("Falha ao carregar post: " + res.status);
      const p = await res.json();
      renderPost(p);
      await loadComments(true);
    } catch (err) {
      console.error(err);
      articleEl.innerHTML = `<p class="muted">Erro ao carregar o post.</p>`;
    }
  }

  function renderPost(p) {
    const title = p.title || slug;
    const cover = p.coverUrl || "https://picsum.photos/1200/500?random=" + Math.floor(Math.random()*1000);
    const author = p.author || "";
    const published = p.publishedAt ? fmtDate(p.publishedAt) : "";

    articleEl.innerHTML = `
      <img class="post-cover" alt="" src="${cover}" loading="lazy" />
      <h1>${escapeHtml(title)}</h1>
      <p class="lead">${published ? `📅 ${published}` : ""} ${author ? ` · ✍️ ${escapeHtml(author)}` : ""}</p>
      ${Array.isArray(p.tags) && p.tags.length ? `<div class="tags" style="margin:.5rem 0 1rem">${p.tags.map(t => `<span class="tag">#${escapeHtml(String(t))}</span>`).join("")}</div>` : ""}
      <div class="prose">${DOMPurify.sanitize(marked.parse(p.content || ""))}</div>
    `;
    document.title = `${escapeHtml(title)} — Meu Blog`;
  }

  function renderComment(c){
    const name = (c.author || "Anônimo");
    const when = c.createdAt || c.publishedAt || c.updatedAt || "";
    const content = (c.content || "").toString();
    const el = document.createElement("div");
    el.className = "comment";
    el.innerHTML = `
      <div class="meta">💬 <strong>${escapeHtml(name)}</strong> · ${when ? fmtDate(when) : ""}</div>
      <div class="body">${escapeHtml(content).replace(/\n/g, "<br>")}</div>
    `;
    return el;
  }

  async function loadComments(initial=false){
    if (!listEl) return;
    if (loadingComments) return;
    loadingComments = true;
    try{
      const url = new URL(`${API_URL}/api/comments`);
      url.searchParams.set("slug", slug);
      url.searchParams.set("limit", "10");
      if (!initial && commentsCursor) url.searchParams.set("cursor", commentsCursor);

      const r = await fetch(url); // GET sem headers
      if (!r.ok) throw new Error("Falha ao carregar comentários: " + r.status);
      const data = await r.json();
      const items = data.items || [];
      if (initial) listEl.innerHTML = "";
      for (const c of items) listEl.appendChild(renderComment(c));
      commentsCursor = data.nextCursor || null;
      if (moreBtn) moreBtn.hidden = !commentsCursor;
    }catch(err){
      console.error(err);
      if (initial) listEl.innerHTML = `<p class="muted">Não foi possível carregar os comentários.</p>`;
    }finally{
      loadingComments = false;
    }
  }

  // Submit do comentário
  if (form) {
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      if (!slug) return showToast("Slug ausente.", false);
      const fd = new FormData(form);
      const payload = {
        author: fd.get("author")?.toString()?.trim(),
        email: fd.get("email")?.toString()?.trim() || undefined,
        content: fd.get("content")?.toString()?.trim(),
      };
      if (!payload.author || !payload.content) return showToast("Preencha nome e comentário.", false);
      statusEl.textContent = "Enviando…";
      try {
        const res = await fetch(`${API_URL}/api/posts/${encodeURIComponent(slug)}/comments`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error("Falha ao enviar: " + res.status);
        showToast("Comentário enviado para moderação.");
        statusEl.textContent = "Enviado ✔";
        form.reset();
        commentsCursor = null;
        await loadComments(true);
      } catch (err) {
        console.error(err);
        statusEl.textContent = "Erro ao enviar.";
        showToast(err.message || "Erro ao enviar.", false);
      }
    });
  }

  // More comments
  moreBtn?.addEventListener("click", () => loadComments(false));

  // Inicialização
  document.addEventListener("DOMContentLoaded", loadPost);
})();
