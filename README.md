# NZBGet --- Containerized (Build + K8s Ready)

A minimal, reproducible NZBGet container you can build yourself and run
locally or in Kubernetes.\
- **Non-root by default** (PUID/PGID)\
- **Tini** for clean signal handling\
- **Config persistence** at `/config`\
- **Media downloads** at `/downloads` (point this at your NFS share,
e.g. `192.168.1.15:/media/downloads`)\
- GitHub Actions workflow included to **build & publish** to GHCR
(`ghcr.io/<you>/nzbget:<tag>`)

------------------------------------------------------------------------

## Contents

-   `Dockerfile` --- Debian slim + official NZBGet static build\
-   `docker-entrypoint.sh` --- UID/GID remap, TZ, umask, first-run
    config seeding\
-   `nzbget.conf` --- sane defaults; full tuning via Web UI\
-   `.github/workflows/publish.yml` --- multi-arch build & push to GHCR

------------------------------------------------------------------------

## Tags

-   `ghcr.io/<user>/nzbget:21.1` (default in examples)
-   `ghcr.io/<user>/nzbget:latest` (optional in workflow)

> Adjust `NZBGET_VERSION` in the Dockerfile or pass via
> `--build-arg NZBGET_VERSION=…`.

------------------------------------------------------------------------

## Quick Start (Docker)

``` bash
docker build -t my-nzbget:21.1 .

docker run -d --name nzbget   -p 6789:6789   -e PUID=$(id -u)   -e PGID=$(id -g)   -e TZ=America/Los_Angeles   -e UMASK=002   -v $(pwd)/config:/config   -v /mnt/media/downloads:/downloads   my-nzbget:21.1
```

Open: `http://localhost:6789`

------------------------------------------------------------------------

## Docker Compose

``` yaml
services:
  nzbget:
    image: ghcr.io/<user>/nzbget:21.1
    container_name: nzbget
    ports:
      - "6789:6789"
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: America/Los_Angeles
      UMASK: "002"
    volumes:
      - ./config:/config
      - /mnt/media/downloads:/downloads
    restart: unless-stopped
```

------------------------------------------------------------------------

## Kubernetes (NFS-backed)

**Example:** NAS export at `192.168.1.15:/media` with subfolder
`downloads/`.

Create PV/PVC:

``` yaml
apiVersion: v1
kind: PersistentVolume
metadata: { name: pv-media-downloads }
spec:
  capacity: { storage: 5Ti }
  accessModes: [ReadWriteMany]
  nfs:
    server: 192.168.1.15
    path: /media/downloads
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-downloads
  namespace: media
spec:
  accessModes: [ReadWriteMany]
  resources: { requests: { storage: 100Gi } }
  volumeName: pv-media-downloads
```

Deployment + Service:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nzbget
  namespace: media
spec:
  replicas: 1
  selector: { matchLabels: { app: nzbget } }
  template:
    metadata: { labels: { app: nzbget } }
    spec:
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
      containers:
        - name: nzbget
          image: ghcr.io/<user>/nzbget:21.1
          ports: [{ containerPort: 6789, name: http }]
          env:
            - { name: PUID, value: "1000" }
            - { name: PGID, value: "1000" }
            - { name: TZ, value: "America/Los_Angeles" }
            - { name: UMASK, value: "002" }
          volumeMounts:
            - { name: config, mountPath: /config }
            - { name: downloads, mountPath: /downloads }
          readinessProbe: { httpGet: { path: "/", port: 6789 }, initialDelaySeconds: 10, periodSeconds: 15 }
          livenessProbe:  { httpGet: { path: "/", port: 6789 }, initialDelaySeconds: 30, periodSeconds: 30 }
      volumes:
        - name: config
          persistentVolumeClaim: { claimName: nzbget-config }
        - name: downloads
          persistentVolumeClaim: { claimName: media-downloads }
---
apiVersion: v1
kind: Service
metadata: { name: nzbget, namespace: media }
spec:
  selector: { app: nzbget }
  ports: [{ name: http, port: 6789, targetPort: 6789 }]
  type: ClusterIP
```

Ingress (optional):

``` yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nzbget
  namespace: media
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  rules:
    - host: nzbget.example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nzbget
                port:
                  number: 6789
```

> If your package is **private**, add an `imagePullSecrets` entry and
> create a GHCR pull secret in the `media` namespace. If you make the
> package **public**, no secret is required.

------------------------------------------------------------------------

## Configuration

-   **Web UI:** `Settings → PATHS`
    -   `MainDir=/downloads`
    -   `DestDir=${MainDir}/completed`
    -   `InterDir=${MainDir}/incomplete`
    -   `ScriptDir=${MainDir}/scripts` (mount a folder and drop
        post-processing scripts)
-   **Listening:** `ControlIP=0.0.0.0`, `ControlPort=6789` (default in
    CMD)
-   **TLS:** Prefer terminating TLS at your reverse proxy/Ingress.\
    If you must enable HTTPS in NZBGet: set `SecureControl=yes` and
    provide cert/key paths inside the container (e.g., from a secret).

------------------------------------------------------------------------

## Environment Variables

  Var       Purpose                   Default
  --------- ------------------------- -----------
  `PUID`    Run NZBGet as this UID    `1000`
  `PGID`    Run NZBGet as this GID    `1000`
  `TZ`      Time zone                 `Etc/UTC`
  `UMASK`   File mode creation mask   `002`

Align `PUID/PGID/UMASK` with your NAS/export so Radarr/Sonarr/Jellyfin
can read/write.

------------------------------------------------------------------------

## Volumes

-   `/config` --- persistent settings, history, queue\
-   `/downloads` --- incomplete/complete files and scripts

> In k8s, keep `/config` on fast storage (local SSD/NVMe or small NFS
> path).\
> For homelabs, an NFS dir is fine.

------------------------------------------------------------------------

## Ports

-   `6789/tcp` --- NZBGet Web UI & API

------------------------------------------------------------------------

## Healthcheck

The container includes an HTTP healthcheck to `/` on port `6789` for
orchestration friendliness.

------------------------------------------------------------------------

## Build & Publish via GitHub Actions

The repo ships with `.github/workflows/publish.yml`.

-   **Manual run:** Actions → *Publish NZBGet image* → **Run workflow**
    and set `version` (e.g., `21.1`).
-   **Automatic:** Pushing changes to `main` that touch the Docker
    context triggers a build.
-   **Outputs:** Multi-arch images pushed to
    `ghcr.io/<user>/nzbget:<version>` (and `:latest` if enabled).

Make the package **public** in Repo → **Settings → Packages**, if you
want to pull without auth.

------------------------------------------------------------------------

## Troubleshooting

-   **GHCR 403 on push:** Use the provided GitHub Actions workflow (no
    PAT needed), or create a **Classic PAT** with
    `write:packages, read:packages` and `docker login ghcr.io`.
-   **Permission denied on downloads:** Ensure NAS export ownership or
    map with `PUID/PGID`, and set `UMASK=002`. In k8s, add
    `fsGroup: 1000`.
-   **NFS stale file handle / slow I/O:** Verify NFS vers/options;
    consider `nconnect` on clients and proper `rsize/wsize`. Keep
    metadata on `/config` separate from large media I/O when possible.
-   **Web UI not reachable in k8s:** Check Service/Ingress and that your
    MetalLB/Ingress controller is healthy. Curl the pod:
    `kubectl -n media exec -it deploy/nzbget -- curl -sf http://127.0.0.1:6789/`.

------------------------------------------------------------------------

## Security Notes

-   Runs as a dedicated non-root user.
-   Prefer TLS termination at Ingress/Reverse Proxy.
-   Consider network policy limiting outbound if you want tighter egress
    control.

------------------------------------------------------------------------

## License

MIT (container files). NZBGet is distributed under its respective
license. Check NZBGet's upstream terms for usage details.

------------------------------------------------------------------------

## Credits

-   NZBGet upstream project and maintainers.\
-   This repo glues together a clean, non-root image + k8s-friendly
    defaults so you can slot it into a homelab stack quickly.
