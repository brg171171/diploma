const menuToggle = document.querySelector("[data-menu-toggle]");
const nav = document.querySelector("[data-nav]");

menuToggle?.addEventListener("click", () => {
  const open = menuToggle.getAttribute("aria-expanded") === "true";
  menuToggle.setAttribute("aria-expanded", String(!open));
  menuToggle.setAttribute("aria-label", open ? "Открыть меню" : "Закрыть меню");
  nav?.classList.toggle("is-open", !open);
});

document.querySelectorAll("[data-year]").forEach((item) => {
  item.textContent = new Date().getFullYear();
});

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

