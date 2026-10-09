# Mermaid bundled distribution

This directory contains the offline Mermaid distribution and local bridge used by
`InkMermaidBridge.html`. The page loads `mermaid.min.js` and then `InkMermaidBridge.js`
from the application bundle. It has no CDN fallback and does not request Mermaid resources
from the network.

| Item | Value |
| --- | --- |
| Package | `mermaid` |
| Fixed version | `11.16.0` |
| Bundled file | `mermaid.min.js` |
| Application bridge files | `InkMermaidBridge.html`, `InkMermaidBridge.js` |
| SHA-256 | `74d7c46dabca328c2294733910a8aa1ed0c37451776e8d5295da38a2b758fb9b` |
| Distribution source | https://unpkg.com/mermaid@11.16.0/dist/mermaid.min.js |
| Upstream release | https://github.com/mermaid-js/mermaid/tree/v11.16.0 |
| License | MIT; see the verbatim `MERMAID-LICENSE.txt` in this directory. |

The application-owned bridge files are `InkMermaidBridge.html` and
`InkMermaidBridge.js`. The HTML permits only local scripts with `script-src 'self'` and
contains no inline executable script or event handler.

## Verify the bundled file

Run this command from the repository root and compare the printed digest with the value above:

```sh
shasum -a 256 Sources/InkMarkdown/Rendering/Mermaid/Resources/mermaid.min.js
```
