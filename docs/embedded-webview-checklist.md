# Embedded WKWebView compatibility

Choosing `window.mode: embedded` is a compatibility decision, not merely a
presentation preference. Exercise the real application in the generated app
before accepting an integration, especially when it uses:

- WebGL, WebGPU, GPU-heavy canvases, fullscreen, or pointer lock;
- file uploads, drag-and-drop, generated downloads, or filesystem handles;
- clipboard reads and writes;
- links that request new windows or application-controlled pop-ups;
- OAuth, payment, or other redirects that cross origins;
- camera, microphone, screen capture, or media autoplay;
- application keyboard shortcuts that overlap macOS menu commands.

Confirm primary navigation, authentication, persistence, failure recovery, and
server restart behavior. Keep `browser` mode when browser-specific behavior is
central to the application or the embedded result is materially degraded.
Enmanner opens user-activated external-host links in the default browser and
retains a persistent default WKWebView data store for embedded applications.
