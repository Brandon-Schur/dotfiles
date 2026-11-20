// StackFolderClick.js — Vivaldi UI mod (Brandon, Nov 2026)
//
// Goes with StackFolders.css. In Accordion stacking, the stack's header row is
// really a tab: clicking it switches to that page. This makes a left-click
// anywhere on the header expand/collapse the stack instead, like a folder, by
// clicking Vivaldi's own expand/collapse strip for that stack.
//
// Left untouched: right-click (context menu, Rename Tab Stack), middle-click,
// the header's buttons (close, mute), and Alt+drag, which still moves the stack.
// Only active with the tab bar on the left or right.
//
// Installed by ~/VivaldiMods/reapply.sh. To disable: remove this file from
// JS_FILES in reapply.sh and its <script> tag from window.html.

(function () {
  "use strict";

  const HEADER = ".tab.tab-accordion";
  const ARROW = ".tab-position.accordion-toggle-arrow";
  console.info("[StackFolderClick] loaded in", document.title);

  function headerFor(e) {
    if (e.button !== 0 || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return null;
    const browser = document.getElementById("browser");
    if (!browser || !browser.matches(".tabs-left, .tabs-right")) return null;
    const t = e.target;
    // No instanceof: Vivaldi builds the UI in another document (main.html), so its
    // elements fail `instanceof Element` checks made from this window.
    if (!t || typeof t.closest !== "function" || t.closest("button")) return null;
    return t.closest(HEADER);
  }

  // The stack's strip is the first one below its header in the same tab bar
  // (directly under it when collapsed, under the last tab when expanded).
  function arrowFor(header) {
    const scope = header.closest(".tab-strip") || document;
    const h = header.getBoundingClientRect();
    let best = null, bestTop = Infinity;
    for (const a of scope.querySelectorAll(ARROW)) {
      const r = a.getBoundingClientRect();
      const overlaps = r.left < h.right && r.right > h.left;
      if (overlaps && r.top >= h.bottom - 2 && r.top < bestTop) { best = a; bestTop = r.top; }
    }
    return best;
  }


  function block(e) {
    if (!headerFor(e)) return;
    e.preventDefault();
    e.stopPropagation();
  }

  // Vivaldi activates tabs and starts drags on press, so swallow the press too.
  for (const t of ["pointerdown", "pointerup", "mousedown", "mouseup"]) window.addEventListener(t, block, true);
  window.addEventListener("click", (e) => {
    const header = headerFor(e);
    if (!header) return;
    e.preventDefault();
    e.stopPropagation();
    const arrow = arrowFor(header);
    console.info("[StackFolderClick] header click, toggle strip found:", !!arrow);
    if (arrow) arrow.click();
  }, true);
})();
