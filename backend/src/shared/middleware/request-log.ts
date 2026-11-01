import morgan from "morgan";

// Signed media URLs carry bearer credentials in their query string. Referrer
// headers may contain those URLs too, so neither belongs in access logs.
export function requestLog(stream?: { write: (message: string) => void }) {
  return morgan((tokens, req, res) => {
    const path = (req.url ?? "/").split(/[?#]/)[0]!.replace(/[\r\n\t]/g, "_");
    return [tokens.method!(req, res), path, tokens.status!(req, res),
      tokens["response-time"]!(req, res), "ms"].join(" ");
  }, { stream });
}
