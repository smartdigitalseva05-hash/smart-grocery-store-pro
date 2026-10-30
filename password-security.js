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
      throw new Error("This browser cannot securely check passwords. Update Chrome and try again.");
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
      throw new Error("Password safety service is unavailable. Check your internet and try again.");
    }
    if (!response.ok) {
      throw new Error("Password safety check could not be completed. Please try again later.");
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