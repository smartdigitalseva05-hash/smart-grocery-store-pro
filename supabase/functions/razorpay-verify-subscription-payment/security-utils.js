export async function readBodyLimited(req, maxBytes) {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 1) {
    throw new TypeError("maxBytes must be a positive safe integer");
  }
  const declared = req.headers.get("content-length");
  if (declared !== null) {
    if (!/^\d+$/.test(declared)) return { error: "invalid_content_length" };
    const length = Number(declared);
    if (!Number.isSafeInteger(length) || length < 0) return { error: "invalid_content_length" };
    if (length > maxBytes) return { error: "too_large" };
  }

  const reader = req.body?.getReader();
  if (!reader) return { bytes: new Uint8Array(0) };
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        return { error: "too_large" };
      }
      chunks.push(value);
    }
  } finally {
    try { reader.releaseLock(); } catch { /* Stream may already be cancelled. */ }
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { bytes };
}
