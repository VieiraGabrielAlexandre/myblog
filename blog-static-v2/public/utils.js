(function(){
  // Theme
  const root = document.documentElement;
  const saved = localStorage.getItem("theme");
  if (saved === "light" || saved === "dark") {
    root.setAttribute("data-theme", saved);
  }
  function toggleTheme() {
    const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    localStorage.setItem("theme", next);
  }
  window.__toggleTheme = toggleTheme;

  // Common helpers
  window.__helpers = {
    fmtDate(iso){
      try { return new Date(iso).toLocaleDateString('pt-BR', { day:"2-digit", month:"short", year:"numeric"}); }
      catch { return iso || ""; }
    },
    escapeHtml(s){
      return String(s).replace(/[&<>"']/g, m => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[m]));
    },
    qs: (sel, el=document) => el.querySelector(sel),
    qsa: (sel, el=document) => Array.from(el.querySelectorAll(sel)),
    on: (el, ev, fn) => el && el.addEventListener(ev, fn)
  };

  // Navbar toggle button binding (both pages)
  document.addEventListener("DOMContentLoaded", () => {
    const tbtn = document.getElementById("themeToggle");
    if (tbtn) tbtn.addEventListener("click", toggleTheme);
    const year = document.getElementById("year");
    if (year) year.textContent = new Date().getFullYear();
  });
})();
