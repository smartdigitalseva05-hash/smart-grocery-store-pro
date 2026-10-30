/* Shared client-side password screening for Smart Grocery Store Pro.
   Uses Have I Been Pwned's k-anonymity range API: only the first 5 SHA-1
   characters leave the browser. The password and full hash are never sent. */
(function () {
  "use strict";
  async function checkPasswordSecurity(password) {
    if (typeof password !== "string" || password.length < 12) {
      throw new Error("Use a password with at least 12 characters.");
    }
    if (!window.crypto || !window.crypto.subtle || !window.TextEncoder) {
      console.warn("Password breach check skipped: secure browser crypto is unavailable.");
      return true;
    }
    const bytes = new TextEncoder().encode(password);
    const digest = await window.crypto.subtle.digest("SHA-1", bytes);
    const hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("").toUpperCase();
    const prefix = hash.slice(0, 5);
    const suffix = hash.slice(5);
    let response;
    try {
      response = await fetch("https://api.pwnedpasswords.com/range/" + prefix, {
        method: "GET",
        headers: { "Add-Padding": "true" },
        cache: "no-store",
        credentials: "omit",
        referrerPolicy: "no-referrer"
      });
    } catch (_) {
      console.warn("Password breach check skipped: safety service is unreachable.");
      return true;
    }
    if (!response.ok) {
      console.warn("Password breach check skipped: safety service returned an error.");
      return true;
    }
    const body = await response.text();
    const compromised = body.split(/\r?\n/).some(line => {
      const part = line.trim().split(":")[0];
      return part && part.toUpperCase() === suffix;
    });
    if (compromised) {
      throw new Error("This password has appeared in a data breach. Choose a different password.");
    }
    return true;
  }
  Object.defineProperty(window, "checkPasswordSecurity", {
    value: checkPasswordSecurity,
    writable: false,
    configurable: false
  });
})();