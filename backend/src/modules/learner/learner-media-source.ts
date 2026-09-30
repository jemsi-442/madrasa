type MediaSourceInput = { storageProvider: string; storageKey: string; assetType: string };
type MediaSource = { url: string; playerKind: "EMBED" | "VIDEO" | "AUDIO" | "PDF" | "EXTERNAL" };

export const learnerMediaSource = (asset: MediaSourceInput): MediaSource | null => {
  let url: URL;
  try { url = new URL(asset.storageKey); } catch { return null; }
  if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) return null;

  // Embedded players must come from the named provider, never arbitrary HTML.
  if (asset.storageProvider === "YOUTUBE") {
    if (asset.assetType !== "VIDEO" || url.port) return null;
    let id: string | undefined | null;
    if (["youtube.com", "www.youtube.com", "m.youtube.com"].includes(url.hostname)) {
      id = url.pathname === "/watch" ? url.searchParams.get("v")
        : url.pathname.match(/^\/(?:embed|shorts)\/([A-Za-z0-9_-]+)\/?$/)?.[1];
    } else if (url.hostname === "youtu.be") {
      id = url.pathname.match(/^\/([A-Za-z0-9_-]+)\/?$/)?.[1];
    } else if (["youtube-nocookie.com", "www.youtube-nocookie.com"].includes(url.hostname)) {
      id = url.pathname.match(/^\/embed\/([A-Za-z0-9_-]+)\/?$/)?.[1];
    }
    return id && /^[A-Za-z0-9_-]{11}$/.test(id)
      ? { url: `https://www.youtube-nocookie.com/embed/${id}`, playerKind: "EMBED" } : null;
  }
  if (asset.storageProvider === "VIMEO") {
    if (asset.assetType !== "VIDEO" || url.port) return null;
    const match = ["vimeo.com", "www.vimeo.com"].includes(url.hostname)
      ? url.pathname.match(/^\/([0-9]+)(?:\/([A-Za-z0-9]+))?\/?$/)
      : url.hostname === "player.vimeo.com" ? url.pathname.match(/^\/video\/([0-9]+)\/?$/) : null;
    if (!match) return null;
    const hash = match[2] ?? url.searchParams.get("h");
    if (hash && !/^[A-Za-z0-9]+$/.test(hash)) return null;
    return { url: `https://player.vimeo.com/video/${match[1]}${hash ? `?h=${hash}` : ""}`, playerKind: "EMBED" };
  }
  return { url: url.toString(), playerKind: asset.assetType === "VIDEO" ? "VIDEO"
    : asset.assetType === "AUDIO" ? "AUDIO" : asset.assetType === "PDF" ? "PDF" : "EXTERNAL" };
};
