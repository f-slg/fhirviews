// Dibuja los diagramas mermaid del sitio pkgdown (en GitHub se muestran solos).
document.addEventListener("DOMContentLoaded", function () {
  var bloques = document.querySelectorAll(
    "pre.mermaid, pre.sourceCode.mermaid, code.language-mermaid, pre > code.mermaid"
  );
  if (bloques.length === 0) return;
  bloques.forEach(function (b) {
    var pre = b.tagName === "PRE" ? b : b.parentElement;
    var div = document.createElement("div");
    div.className = "mermaid";
    div.textContent = b.textContent;
    pre.replaceWith(div);
  });
  import("https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.esm.min.mjs")
    .then(function (m) {
      m.default.initialize({ startOnLoad: false, theme: "neutral",
                             securityLevel: "strict" });
      m.default.run({ querySelector: "div.mermaid" });
    });
});
