# 1C:Enterprise + PostgreSQL in Docker

**Author:** kastrel  
**Date:** 2026-09  
**Status:** working stand ✅

> Fault-tolerant test stand for development and debugging of 1C:Enterprise 8.3 solutions, fully containerized in Docker on Linux. Suitable for both learning and real development by 1C franchisees.

---

## 🎯 What is this

Fully containerized stand **«1C:Enterprise 8.3.26.1540 + PostgreSQL 15.17-1.1C»**, deployed on Ubuntu VM inside VirtualBox. All components run in Docker and are accessible from Windows host over network.

**Key components:**

- 🐘 **PostgreSQL 15.17-1.1C** — official build from 1C with `mchar`, `fasttrun` extensions
- 🏢 **1C Server 8.3.26.1540** — server cluster (`ragent`, `rmngr`, `rphost`)
- 🎨 **X11 over TCP (VcXsrv)** — for GUI operations inside containers
- 🔑 **Community license** — activated on 1C server container
- 🖥️ **1C Thin Client on Windows** — connects to server over network

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Windows host (192.168.0.129)                                  │
│  ┌────────────────────────┐   ┌──────────────────────────────┐ │
│  │  1C Thin Client        │   │  VcXsrv (X server)           │ │
│  │  MobaXterm, SSH        │   │  TCP :6000                   │ │
│  └───────────┬────────────┘   └──────────────┬───────────────┘ │
└──────────────┼──────────────────────────────┼─────────────────┘
               │ TCP 1540/1541                │ TCP 6000
               ▼                              ▼
┌────────────────────────────────────────────────────────────────┐
│  Ubuntu VM (192.168.0.173, VirtualBox, Bridged Adapter)        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Docker Engine + Compose                                 │  │
│  │  ┌────────────────────────┐   ┌───────────────────────┐  │  │
│  │  │  Container pg-1c       │   │  Container 1c-server  │  │  │
│  │  │  PostgreSQL 15.17-1.1C │◄──┤  ragent + rmngr +     │  │  │
│  │  │  :5432                 │   │  rphost :1540/:1541   │  │  │
│  │  └────────────────────────┘   └───────────────────────┘  │  │
│  │  Docker network: 1c-net (bridge)                         │  │
│  │  Volumes: pg_data, 1c_data, 1c_logs                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

Full documentation (in Russian) — see [`docs/`](docs/).

---

## 🛠️ Tech Stack

| Component | Version | Purpose |
|---|---|---|
| **Ubuntu** | 26.04 LTS | Host OS in VirtualBox |
| **VirtualBox** | 7.x | Hypervisor on Windows |
| **Docker Engine** | 29.1.3 | Containerization |
| **Docker Compose** | 2.40.3 | Container orchestration |
| **PostgreSQL** | 15.17-1.1C | DBMS with 1C patches |
| **1C:Enterprise** | 8.3.26.1540 | Application server |
| **VcXsrv** | — | X server on Windows |
| **MobaXterm** | — | SSH client + X11 |

---

## 📚 Documentation

Full technical documentation (Russian) starts at [`docs/01-intro.md`](docs/01-intro.md).

The root [`README.md`](README.md) contains the same overview in Russian.

---

## 🚀 Quick Start

**Prerequisites:** access to `releases.1c.ru`, Docker, VirtualBox.

```bash
# 1. Clone repository
git clone <url> && cd 1c-docker-stand

# 2. Download distributions from releases.1c.ru:
#    - setup-full-8.3.26.1540-x86_64.run → 1c-server/distr/
#    - postgresql_15.17_1_ubuntu_24.04_x86_64_package.tar.bz2 → postgres/distr/
#    - postgresql_15.17_1_ubuntu_24.04_x86_64_package_addon.tar.bz2 → postgres/distr/

# 3. Unpack .deb for PostgreSQL
cd postgres/distr && tar -xjf *.tar.bz2 && mkdir -p ../distr-min
cp postgresql-15_*.deb libpq5_*.deb postgresql-client-15_*.deb \
   postgresql-client-common_*.deb postgresql-common_*.deb ../distr-min/
cd ../..

# 4. Run
docker compose build
docker compose up -d
docker compose ps
```

**Detailed step-by-step guide** — see [`docs/02-vm-setup.md`](docs/02-vm-setup.md) and beyond.

---

## ⚠️ Known Issues

1. **Community license is tied to container MAC.** Don't recreate `1c-server` without need. See [`docs/07-license.md`](docs/07-license.md).
2. **GUI operations require X server on Windows** (VcXsrv or MobaXterm). See [`docs/05-x11-forwarding.md`](docs/05-x11-forwarding.md).
3. **Windows thin client needs `hosts` entry** for container name resolution. See [`docs/08-thin-client.md`](docs/08-thin-client.md).

---

## 📄 License

MIT. See [LICENSE](LICENSE).

**Note:** 1C and PostgreSQL distributions are **commercial software** not included in this repository. You need **access to `releases.1c.ru`** (ITS or partner).

---

## 🙏 Acknowledgments

- **1C** — for the platform and Community license for developers
- **PostgresPro** — for PostgreSQL build with 1C patches
- **Community** — for numerous articles and solutions to the problems we encountered

---

## 📞 Feedback

Created as a pet project for practicing DevOps and 1C administration skills.  
Issues and pull requests welcome.
