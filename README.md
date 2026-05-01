# Psychedelic Society of Kansas City

Modern Astro static site for the PSKC staging URL:
`https://heartlandtranspersonalalliance.github.io/pskc-staging/`.

## Development

```sh
npm install
npm run dev
```

With Nix:

```sh
nix develop
npm run dev
```

If you use `direnv`, run `direnv allow` once. After that, `cd ~/projects/hta/pskc-site` will load the Nix shell automatically through `.envrc`.

When `dist/` already exists, the direnv shell also starts a background Nginx preview on `http://127.0.0.1:8080/` and prints any detected LAN URLs. Disable that with `PSKC_AUTO_PREVIEW=0`.

## Build

```sh
npm run build
```

The staging build is configured for GitHub Pages project hosting with:

- Astro `site` set to `https://heartlandtranspersonalalliance.github.io`
- Astro `base` set to `/pskc-staging`
- trailing slashes enabled for generated routes

## Deployment

Pushing to `main` runs `.github/workflows/astro.yml`, which installs dependencies
with `npm ci`, builds the Astro site, uploads `dist/` as a Pages artifact, and
deploys it through GitHub Pages.

The repository must have GitHub Pages configured to use **GitHub Actions** as the
source in the repository settings. This staging repo does not use a custom domain,
so there is no `public/CNAME` file.

## LAN Preview With Nginx

The flake provides `pskc-lan-preview`, a user-space Nginx wrapper for previewing the generated Astro site on your local network.

```sh
nix develop
pskc-lan-preview
```

By default it:

- installs npm dependencies if `node_modules/` is missing
- runs `npm run build`
- serves `dist/` with Nginx on `0.0.0.0:8080`
- prints local and LAN URLs such as `http://127.0.0.1:8080/` and `http://<wsl-ip>:8080/`

The foreground command blocks until you press Ctrl-C. For a background server:

```sh
pskc-lan-preview --daemon
pskc-lan-preview --status
pskc-lan-preview --stop
```

The direnv auto-start path uses `PSKC_BUILD=0`, so it serves the generated site already in `dist/`. Run `npm run build` first after content or code changes.

Useful overrides:

```sh
PSKC_PORT=8081 pskc-lan-preview
PSKC_BUILD=0 pskc-lan-preview
PSKC_HOST=127.0.0.1 pskc-lan-preview
PSKC_AUTO_PREVIEW=0 direnv reload
```

For D-WSL/WSL2, the script binds inside the Linux environment. If another device on your LAN cannot reach the printed WSL IP, enable WSL mirrored networking or add a Windows firewall/portproxy rule for the chosen port.

The site uses Astro content collections for published news posts, Tailwind CSS through the official Vite plugin, and static assets from `public/assets/images`.
