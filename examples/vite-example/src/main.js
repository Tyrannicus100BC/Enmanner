import "./style.css";

const greeting = import.meta.env.VITE_GREETING || "Your source is the app.";
const apiKeyStatus = import.meta.env.VITE_TEAM_API_KEY
  ? "Project API key configured"
  : "Project API key not configured";

document.querySelector("#app").innerHTML = `
  <section class="shell">
    <p class="eyebrow">Enmanner + Vite</p>
    <h1 id="greeting"></h1>
    <p class="intro">
      This page is served by the project and presented by a small native Mac
      launcher. Edit <code>src/main.js</code> and save to watch Vite update this
      window without rebuilding the <code>.app</code>.
    </p>
    <div class="status">
      <span class="pulse" aria-hidden="true"></span>
      <div>
        <strong>Local server connected</strong>
        <small>
          Enmanner owns startup, readiness, logs, recovery, and shutdown.
          <span id="api-key-status"></span>.
        </small>
      </div>
    </div>
  </section>
`;

document.querySelector("#greeting").textContent = greeting;
document.querySelector("#api-key-status").textContent = apiKeyStatus;
