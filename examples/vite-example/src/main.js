import "./style.css";

document.querySelector("#app").innerHTML = `
  <section class="shell">
    <p class="eyebrow">Enmanner + Vite</p>
    <h1>Your source is the app.</h1>
    <p class="intro">
      This page is served by the project and presented by a small native Mac
      launcher. Edit <code>src/main.js</code> and save to watch Vite update this
      window without rebuilding the <code>.app</code>.
    </p>
    <div class="status">
      <span class="pulse" aria-hidden="true"></span>
      <div>
        <strong>Local server connected</strong>
        <small>Enmanner owns startup, readiness, logs, recovery, and shutdown.</small>
      </div>
    </div>
  </section>
`;
