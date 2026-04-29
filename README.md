# Psychedelic Society of Kansas City

Modern Astro static site for `psychedelickc.org`.

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

## Build

```sh
npm run build
```

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

Useful overrides:

```sh
PSKC_PORT=8081 pskc-lan-preview
PSKC_BUILD=0 pskc-lan-preview
PSKC_HOST=127.0.0.1 pskc-lan-preview
```

For D-WSL/WSL2, the script binds inside the Linux environment. If another device on your LAN cannot reach the printed WSL IP, enable WSL mirrored networking or add a Windows firewall/portproxy rule for the chosen port.

The site uses Astro content collections for published news posts, Tailwind CSS through the official Vite plugin, and static assets from `public/assets/images`. The `public/CNAME` file preserves the custom domain in the generated `dist/` output.
