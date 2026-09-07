const root = document.documentElement;
const header = document.querySelector("[data-header]");
const menuToggle = document.querySelector("[data-menu-toggle]");
const nav = document.querySelector("[data-nav]");

menuToggle.addEventListener("click", () => {
  const open = menuToggle.getAttribute("aria-expanded") === "true";
  menuToggle.setAttribute("aria-expanded", String(!open));
  menuToggle.setAttribute("aria-label", open ? "Открыть меню" : "Закрыть меню");
  nav.classList.toggle("is-open", !open);
});

nav.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", () => {
    nav.classList.remove("is-open");
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "Открыть меню");
  });
});

window.addEventListener(
  "scroll",
  () => header.classList.toggle("is-scrolled", window.scrollY > 24),
  { passive: true }
);

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.14 }
);

document.querySelectorAll(".reveal").forEach((item) => revealObserver.observe(item));

document.querySelectorAll("[data-accordion]").forEach((item) => {
  const trigger = item.querySelector(".expertise-trigger");
  trigger.addEventListener("click", () => {
    const isOpen = item.classList.contains("is-open");
    document.querySelectorAll("[data-accordion]").forEach((other) => {
      other.classList.remove("is-open");
      other.querySelector(".expertise-trigger").setAttribute("aria-expanded", "false");
    });
    if (!isOpen) {
      item.classList.add("is-open");
      trigger.setAttribute("aria-expanded", "true");
    }
  });
});

const process = document.querySelector("[data-process]");
const processObserver = new IntersectionObserver(
  ([entry]) => {
    if (entry.isIntersecting) {
      process.classList.add("is-active");
      processObserver.disconnect();
    }
  },
  { threshold: 0.3 }
);
processObserver.observe(process);

const tilt = document.querySelector("[data-tilt]");
const portrait = tilt.querySelector(".portrait-frame");
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

if (!reduceMotion.matches && window.matchMedia("(pointer: fine)").matches) {
  tilt.addEventListener("pointermove", (event) => {
    const bounds = tilt.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width - 0.5;
    const y = (event.clientY - bounds.top) / bounds.height - 0.5;
    portrait.style.transform = `rotateY(${x * 6}deg) rotateX(${-y * 6}deg) rotate(0.8deg)`;
  });

  tilt.addEventListener("pointerleave", () => {
    portrait.style.transform = "rotateY(0) rotateX(0) rotate(0.8deg)";
  });
}

if (!reduceMotion.matches) {
  const glitch = document.querySelector(".glitch");
  window.setInterval(() => {
    glitch.classList.add("is-glitching");
    window.setTimeout(() => glitch.classList.remove("is-glitching"), 480);
  }, 6200);
}

document.querySelector("[data-year]").textContent = new Date().getFullYear();

const cookieBanner = document.querySelector("[data-cookie-banner]");
const cookieAccept = document.querySelector("[data-cookie-accept]");
const consentCookieName = "bg_cookie_notice";

function hasCookieNoticeConsent() {
  return document.cookie
    .split("; ")
    .some((item) => item.startsWith(`${consentCookieName}=`));
}

if (cookieBanner && !hasCookieNoticeConsent()) {
  cookieBanner.hidden = false;
}

cookieAccept?.addEventListener("click", () => {
  document.cookie = `${consentCookieName}=accepted; Max-Age=31536000; Path=/; SameSite=Lax; Secure`;
  cookieBanner.hidden = true;
});
