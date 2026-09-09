window.inkMermaid = {
  __pendingRequestId: null,
  __pendingResult: null,
  __pendingError: null,
  render: function (encodedRequest) {
    if (typeof mermaid === 'undefined' || !mermaid || typeof mermaid.render !== 'function') {
      return Promise.reject(new Error('Mermaid runtime is not available'));
    }
    var request = JSON.parse(encodedRequest);
    var holder = document.getElementById('diagram');
    holder.replaceChildren();
    // mermaid 11 still supports initialize + render; keep securityLevel strict and disable HTML labels.
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: request.theme,
      flowchart: { htmlLabels: false }
    });
    var renderPromise = mermaid.render('ink-mermaid-' + request.id, request.source).then(function (rendered) {
      holder.innerHTML = rendered.svg;
      var svg = holder.querySelector('svg');
      if (!svg) throw new Error('Mermaid did not return SVG');
      // Prefer intrinsic size: journey/gantt etc. set width=100% + max-width, so
      // getBoundingClientRect can shrink to the provisional WKWebView viewport and
      // under-report the real diagram, causing later snapshot crops.
      var size = window.inkMermaid.measureSvg(svg);
      return JSON.stringify({ width: size.width, height: size.height });
    });
    // Fail closed if Mermaid's Promise never settles (e.g. layout waiting on a zero viewport).
    var timeoutPromise = new Promise(function (_, reject) {
      setTimeout(function () {
        reject(new Error('mermaid.render exceeded 25s JS timeout'));
      }, 25000);
    });
    return Promise.race([renderPromise, timeoutPromise]);
  },
  renderViaCallback: function (encodedRequest) {
    var request = JSON.parse(encodedRequest);
    window.inkMermaid.__pendingRequestId = request.id;
    window.inkMermaid.__pendingResult = null;
    window.inkMermaid.__pendingError = null;
    window.inkMermaid.render(encodedRequest).then(function (value) {
      if (window.inkMermaid.__pendingRequestId !== request.id) {
        return;
      }
      window.inkMermaid.__pendingResult = value;
    }).catch(function (error) {
      if (window.inkMermaid.__pendingRequestId !== request.id) {
        return;
      }
      window.inkMermaid.__pendingError = error && error.message ? error.message : String(error);
    });
  },
  pollRenderResult: function (expectedRequestId) {
    if (window.inkMermaid.__pendingRequestId !== expectedRequestId) {
      return null;
    }
    if (window.inkMermaid.__pendingError) {
      // Return as value so WKWebView preserves the message (throw often becomes a generic localized string).
      return JSON.stringify({ ok: false, error: window.inkMermaid.__pendingError });
    }
    if (window.inkMermaid.__pendingResult == null) {
      return null;
    }
    return JSON.stringify({ ok: true, value: window.inkMermaid.__pendingResult });
  },
  clearPendingRender: function () {
    window.inkMermaid.__pendingRequestId = null;
    window.inkMermaid.__pendingResult = null;
    window.inkMermaid.__pendingError = null;
  },
  resize: function (width, height) {
    document.documentElement.style.width = width + 'px';
    document.documentElement.style.height = height + 'px';
    document.body.style.width = width + 'px';
    document.body.style.height = height + 'px';
  },
  measureSvg: function (svg) {
    var rect = svg.getBoundingClientRect();
    var width = rect.width;
    var height = rect.height;
    var vb = svg.viewBox && svg.viewBox.baseVal;
    if (vb && vb.width > 0 && vb.height > 0) {
      var vbWidth = vb.width + (vb.x < 0 ? -vb.x : 0);
      var vbHeight = vb.height + (vb.y < 0 ? -vb.y : 0);
      if (width + 0.5 < vbWidth) width = vbWidth;
      if (height + 0.5 < vbHeight) height = vbHeight;
    }
    var attrWidth = parseFloat(svg.getAttribute('width'));
    var attrHeight = parseFloat(svg.getAttribute('height'));
    if (!isNaN(attrWidth) && attrWidth > width) width = attrWidth;
    if (!isNaN(attrHeight) && attrHeight > height) height = attrHeight;
    return { width: width, height: height };
  },
  // RasterPlan may shrink the WKWebView below Mermaid's natural SVG box.
  // Force absolute width/height (keeping viewBox) so takeSnapshot sees the full diagram.
  fitSvgToSize: function (width, height) {
    var svg = document.querySelector('#diagram svg');
    if (!svg) return false;
    if (!svg.getAttribute('viewBox')) {
      try {
        var bb = svg.getBBox();
        if (bb && bb.width > 0 && bb.height > 0) {
          svg.setAttribute(
            'viewBox',
            bb.x + ' ' + bb.y + ' ' + bb.width + ' ' + bb.height
          );
        }
      } catch (error) {
        // getBBox can throw when the SVG is not rendered; fall through.
      }
    }
    svg.setAttribute('width', String(width));
    svg.setAttribute('height', String(height));
    svg.style.width = width + 'px';
    svg.style.height = height + 'px';
    svg.style.maxWidth = 'none';
    return true;
  }
};
