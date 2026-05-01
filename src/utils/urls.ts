const basePath =
  import.meta.env.BASE_URL === "/" ? "" : import.meta.env.BASE_URL.replace(/\/$/, "");

export const isExternalUrl = (url: string) =>
  /^[a-z][a-z0-9+.-]*:/i.test(url) || url.startsWith("//");

export function withBase(path: string) {
  if (isExternalUrl(path) || path.startsWith("#") || !path.startsWith("/")) {
    return path;
  }

  if (!basePath || path === basePath || path.startsWith(`${basePath}/`)) {
    return path;
  }

  return `${basePath}${path}`;
}

export function stripBase(path: string) {
  if (!basePath) {
    return path;
  }

  if (path === basePath) {
    return "/";
  }

  if (path.startsWith(`${basePath}/`)) {
    return path.slice(basePath.length) || "/";
  }

  return path;
}
