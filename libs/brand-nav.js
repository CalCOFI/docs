/* the brand's words in quarto's navbar — calcofi.io brand v3 § 4.6 (https://calcofi.io/brand/v3/)

   quarto owns this book's navbar, so the brand's own <header class="cc-header"> is not used here. the
   words are still the brand's ONE list: brand/v3/header.js (loaded by brand-head.html) reads nav.json
   from beside itself and hands it over as window.ccHeader.words(); this script draws that list as
   quarto / bootstrap navbar items — a word with a menu becomes a dropdown, a menu with two columns
   keeps them — into the navbar's right-hand list, replacing the one stand-in item typed in _quarto.yml.
   nothing about the words is typed in this repo: a word, a menu line or a link changes in calcofi.io's
   _data/nav.yml and reaches this book with no render.

   it also points the navbar's title ("Docs") at this book's root: quarto gives the logo and the title
   the same href, and the brand wants the lockup -> calcofi.io and the title -> the product.

   state is on the list as data-cc-nav-state = loading | ready | failed (brand-navbar.scss hides the
   stand-in until it is ready, and shows it again when the list could not be read). */
(function () {
  "use strict";

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  // one line of a menu: a rule, or a link with its title and the small words under it
  function line(i) {
    if (i.rule) return '<li><hr class="dropdown-divider"></li>';
    return '<li><a class="dropdown-item" href="' + esc(i.url) + '"><span class="dropdown-text">' + esc(i.title) + "</span>" +
      (i.small ? "<small>" + esc(i.small) + "</small>" : "") + "</a></li>";
  }

  // the words as navbar items
  function html(words) {
    return (words || []).map(function (w) {
      var id = esc(w.id);
      if (!w.menu) {
        return '<li class="nav-item" data-word="' + id + '"><a class="nav-link' + (w.ext ? " cc-ext" : "") + '" href="' + esc(w.url) + '">' +
          '<span class="menu-text">' + esc(w.title) + "</span></a></li>";
      }
      var two = w.menu.length > 1;
      var cols = w.menu.map(function (c) {
        var lines = (c.items || []).map(line).join("");
        return two
          ? '<li class="cc-menu-col">' + (c.title ? '<h6 class="dropdown-header">' + esc(c.title) + "</h6>" : "") + '<ul class="list-unstyled">' + lines + "</ul></li>"
          : lines;
      }).join("");
      return '<li class="nav-item dropdown" data-word="' + id + '">' +
        '<a class="nav-link dropdown-toggle" href="#" id="cc-nav-' + id + '" role="button" data-bs-toggle="dropdown" aria-expanded="false">' +
        '<span class="menu-text">' + esc(w.title) + "</span></a>" +
        '<ul class="dropdown-menu cc-menu' + (two ? " cc-menu-2" : "") + (w.align === "right" ? " dropdown-menu-end" : "") + '" aria-labelledby="cc-nav-' + id + '">' +
        cols + "</ul></li>";
    }).join("");
  }

  function start() {
    var bar = document.querySelector("#quarto-header .navbar");
    if (!bar) return;
    // the title -> this book's root (quarto:offset is the page's path back to it)
    var title = bar.querySelector(".navbar-brand:not(.navbar-brand-logo)");
    var off = document.querySelector('meta[name="quarto:offset"]');
    if (title) title.setAttribute("href", (off && off.getAttribute("content")) || "./");
    // the words
    var list = bar.querySelector(".navbar-collapse .navbar-nav");
    if (!list) return;
    list.setAttribute("aria-label", "Sections");
    if (!window.ccHeader || !window.ccHeader.words) { list.setAttribute("data-cc-nav-state", "failed"); return; }
    list.setAttribute("data-cc-nav-state", "loading");
    window.ccHeader.words().then(function (words) {
      if (!words || !words.length) throw new Error("nav.json has no words");
      list.innerHTML = html(words);
      list.setAttribute("data-cc-nav-state", "ready");
    }).catch(function (e) {
      list.setAttribute("data-cc-nav-state", "failed");
      if (window.console) console.warn("brand v3: the navbar's words could not be loaded", e);
    });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
