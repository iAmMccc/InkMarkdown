window.inkMermaid = {
  render: async function (encodedRequest) {
    const request = JSON.parse(encodedRequest);
    const holder = document.getElementById('diagram');
    holder.replaceChildren();
    mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: request.theme, flowchart: { htmlLabels: false } });
    const rendered = await mermaid.render('ink-mermaid-' + request.id, request.source);
    holder.innerHTML = rendered.svg;
    const svg = holder.querySelector('svg');
    if (!svg) throw new Error('Mermaid did not return SVG');
    const rect = svg.getBoundingClientRect();
    return JSON.stringify({ width: rect.width, height: rect.height });
  },
  resize: function (width, height) {
    document.documentElement.style.width = width + 'px';
    document.documentElement.style.height = height + 'px';
    document.body.style.width = width + 'px';
    document.body.style.height = height + 'px';
    return true;
  }
};
