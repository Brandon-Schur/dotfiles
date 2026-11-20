// TabBarAutoCollapse.js — Vivaldi UI mod (Brandon, Nov 2026)
//
// Fixes "Expand Tab Bar on Hover" staying open for 10+ seconds on macOS.
// Vivaldi collapses the bar on the tab bar's mouseleave event. When the
// cursor moves from the bar straight onto a web page, the page belongs to
// another renderer and Vivaldi's UI often never gets that event, so the bar
// only collapses once the cursor later touches Vivaldi's own UI.
//
// Fix: while the bar is expanded and the cursor is on it, lay an invisible
// layer over the rest of the window. Leaving the bar moves the cursor onto
// that layer (part of Vivaldi's UI), so mouseleave fires normally and
// Vivaldi's own close delay (vivaldi.biscuit.auto_hide_close_delay, default
// 800 ms) starts. The layer removes itself as soon as the cursor touches it,
// so clicks and scrolling reach the page.
//
// Installed by ~/VivaldiMods/reapply.sh. To disable: remove this file from
// JS_FILES in reapply.sh and its <script> tag from window.html.

(function () {
  "use strict";

  const BAR = "#tabs-tabbar-container";
  let layer = null;
  let bar = null;
  let inBar = false; // last mouseover was inside the tab bar

  function expanded(el) {
    return !!el && el.classList.contains("tabs-hover-expanded") &&
      (el.classList.contains("left") || el.classList.contains("right"));
  }

  function hideLayer() {
    if (layer) layer.style.display = "none";
  }

  // Cover everything except the tab bar itself.
  function showLayer() {
    if (!expanded(bar)) return hideLayer();
    if (!layer) {
      layer = document.createElement("div");
      layer.id = "tabbar-autocollapse-layer";
      layer.style.cssText =
        "position:fixed;top:0;bottom:0;z-index:2147483647;background:transparent;";
      layer.addEventListener("mouseover", hideLayer);
      document.body.appendChild(layer);
    }
    const r = bar.getBoundingClientRect();
    if (bar.classList.contains("left")) {
      layer.style.left = r.right + "px";
      layer.style.right = "0";
    } else {
      layer.style.left = "0";
      layer.style.right = (window.innerWidth - r.left) + "px";
    }
    layer.style.display = "block";
  }

  // The bar's width animates while expanding, so keep the layer's edge on it.
  const resize = new ResizeObserver(() => {
    if (layer && layer.style.display !== "none") showLayer();
  });

  // Cursor moved over the tab bar (or within it): make sure the layer is up.
  document.addEventListener("mouseover", (e) => {
    const t = e.target;
    if (!t || typeof t.closest !== "function") return;
    const b = t.closest(BAR);
    inBar = !!b;
    if (!b) return;
    if (b !== bar) {
      if (bar) resize.unobserve(bar);
      bar = b;
      resize.observe(bar);
    }
    showLayer();
  }, true);

  // The expanded class lands a moment after the cursor enters, so show the
  // layer then. Drop it once the bar collapses (e.g. after a click).
  new MutationObserver(() => {
    const up = layer && layer.style.display !== "none";
    if (up && !expanded(bar)) hideLayer();
    else if (!up && inBar && expanded(bar)) showLayer();
  }).observe(document.documentElement, {
    subtree: true, attributes: true, attributeFilter: ["class"],
  });
})();
