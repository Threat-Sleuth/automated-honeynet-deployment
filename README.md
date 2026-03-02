# Container-Based Honeynet Auto-Deployment

This project has been validated to work correctly on Linux Ubuntu 24.04.3 LTS.  
It provides an automated, container-based honeynet that can be deployed with a single script on most modern Linux distributions.  
The main goals are:

- To simplify the deployment of a **customizable honeynet** using container technology (Docker and Docker Compose).  
- To offer a **non-interactive, automated installer** that performs all steps with a single command.  
- To make it work on **as many Linux distributions as possible** that use systemd and a common package manager (APT, DNF, Zypper, or Pacman).  

Once installed, the honeynet runs as a set of Docker containers orchestrated by `docker compose`, with an optional Portainer container that provides a graphical interface to manage Docker if desired.

### Honeynet architecture overview

The honeynet consists of two distinct sets of services, each deployed as its own group of containers. One group is intended to generate normal or legitimate traffic, while the other is explicitly designed for running different types of attacks against the same or equivalent services. In this way, it is possible to obtain two separate collections of logs: one capturing benign activity and another capturing malicious or attack traffic.

In addition to these core honeypot services, several supporting containers are deployed:

- **Portainer**: a graphical management environment for Docker containers, providing a web-based interface to inspect, start, stop, and monitor the containers that form the honeynet.
- **Fluentd**: a unified logging component that collects logs from the different services and normalizes them into a consistent JSON format, facilitating downstream analysis and correlation.
- **mitmproxy**: a reverse proxy used to intercept and inspect HTTP/HTTPS traffic directed at the web applications in the honeynet, enabling the generation of rich, well-structured logs that capture detailed request and response information.

Together, these elements provide a flexible, observable, and fully instrumented honeynet environment suitable for both normal-traffic simulation and controlled attack experimentation. Containers list and their ports and access credentials:

- dvwa-normalidad -p 80 admin/password

- dvwa-pentesting -p 81 admin/password

- ftp-normalidad -p 2121 ftpuser/password

- ftp-pentesting -p 2122 ftpuser/password

- ssh-normalidad -p 2222 root/password

- ssh-pentesting -p 2223 root/password

- mail-normalidad -p 587 (SMTP), 143 (IMAP) usuario1@normalidad.tics, usuario2@normalidad.tics/password

- mail-pentesting -p 1587 (SMTP), 1143 (IMAP) usuario1@pentesting.tics, usuario2@pentesting.tics/password

- reverse-proxy-normalidad

- reverse-proxy-pentesting

- fluentd

- portainer​ -p 9000

## 1. Overview

This honeynet is designed as a collection of Dockerized services (honeypots and supporting components) defined in a `compose.yml` file.  

The project includes:

- A **universal installer script** (`install_honeynet.sh`) that:
  
  - Installs Docker and Docker Compose (or equivalent) on supported systems.
  - Creates a dedicated user and project directory.
  - Deploys the honeynet files from a compressed archive.
  - Adjusts required permissions for logs and specific services.
  - Brings up all containers using `docker compose up -d`.
  - Installs and enables a systemd service (`honeynet.service`) to ensure the honeynet starts automatically at boot.

- A **honeynet project archive** (`honeynet.tar.gz`) that contains:
  
  - `compose.yml` with the definition of all services/containers.
  - Subdirectories for each service (including Dockerfiles and configuration files).
  - A `logs/` directory where containers can write log files.
  - A `mitmproxy/` directory or other support components, if needed.

- A **systemd unit file** (`honeynet.service`) that:
  
  - Runs `docker compose up -d` from the honeynet directory.
  - Ensures the honeynet is started automatically when the system boots.

The honeynet is intended to be fully **customizable**. You can modify the `compose.yml`, add or remove services, adjust logging paths, or change configurations according to your needs, as long as the overall structure remains consistent with what the installer expects.

---

## 2. Supported Systems

The installer is designed to work on modern Linux distributions that meet the following requirements:

- Use **systemd** as the init system (required for the `honeynet.service` unit).
- Provide one of the following package managers:
  - `apt` (Debian-based systems, including Ubuntu)
  - `dnf` (Fedora / RHEL / CentOS / Rocky / AlmaLinux families)
  - `zypper` (openSUSE / SLES)
  - `pacman` (Arch Linux)

Currently handled distribution families include:

- **Ubuntu / Debian** (APT)  
- **Fedora / RHEL / CentOS / Rocky / AlmaLinux** (DNF)  
- **openSUSE / SLES** (Zypper)  
- **Arch Linux** (Pacman)

Other distributions that are compatible with one of these package managers and use systemd may also work, but are not explicitly supported or tested.

> **Note:** The project has been primarily tested and validated on Ubuntu 24.04.3 LTS, but the installer is written to be as generic as reasonably possible for other systemd-based distributions.

---

## 3. Project Contents

The repository is expected to contain at least the following files:

- `install_honeynet.sh`  
  Main installation script. This is the entry point for users and is designed to be run once as root (or via `sudo`). It handles Docker installation, honeynet deployment, and systemd configuration.

- `honeynet.tar.gz`  
  Tarball containing the honeynet project files. Inside this archive you will typically find:
  
  - `compose.yml` – Docker Compose file defining all honeypots and supporting containers.
  - `logs/` – Directory where services can write log files (with subdirectories per service).
  - `mitmproxy/` – Directory for mitmproxy-related files, if used.
  - Additional service directories (each with Dockerfiles, configuration files, scripts, etc.).

- `honeynet.service`  
  A systemd service unit that calls `docker compose up -d` in the honeynet directory. This service ensures that all containers start automatically at boot and can be managed through systemd.

You can extend or modify the contents of `honeynet.tar.gz` to customize the honeynet (add new honeypots, change logging strategies, etc.), as long as the project directory structure and the `compose.yml` entry point remain consistent.

---

## 4. How the Installer Script Works

### 4.1 High-Level Behavior

When you run `install_honeynet.sh` as root, the script:

1. Checks that it is executed with root privileges.  
2. Detects your Linux distribution and chooses an appropriate package manager.  
3. Installs Docker Engine and the Docker Compose plugin (or equivalent packages).  
4. Creates a dedicated user and project directory for the honeynet.  
5. Copies and extracts the `honeynet.tar.gz` archive into that project directory.  
6. Adjusts file permissions (for example, on log directories and support components such as mitmproxy).  
7. Starts the honeynet using `docker compose up -d`.  
8. Copies and configures the systemd unit `honeynet.service`, enabling it at boot.

All of these steps are performed non-interactively, so the user only has to run a single command.

### 4.2 Root Privilege Check

The script first verifies that it is being run as root (or via `sudo`).  
If the effective user ID is not 0, it exits with an error and instructs you to run:

`sudo ./install_honeynet.sh`

This is necessary because installing packages, creating system users, and writing to `/etc/systemd/system` all require root privileges.

### 4.3 Distribution and Package Manager Detection

The script reads `/etc/os-release` to obtain the distribution ID (e.g., `ubuntu`, `debian`, `fedora`, `arch`, etc.).  
It then maps this ID to a package manager:

- `ubuntu`, `debian` → `apt`  
- `fedora`, `rhel`, `centos`, `rocky`, `almalinux` → `dnf`  
- `opensuse`, `sles` → `zypper`  
- `arch` → `pacman`  

If the distribution is not recognized, the script stops and instructs you to install Docker manually before re-running the script (in which case the Docker installation step will not be needed).

### 4.4 Docker and Docker Compose Installation

Depending on the detected package manager, the script installs Docker as follows:

- **APT-based systems (Ubuntu/Debian)**  
  
  - Installs prerequisites such as `ca-certificates`, `curl`, and `gnupg`.  
  - Adds Docker’s official APT repository and GPG key.  
  - Installs packages like `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`.

- **DNF-based systems (Fedora/RHEL-like)**  
  
  - Installs `dnf-plugins-core`.  
  - Adds the Docker repository for the specific distribution.  
  - Installs Docker Engine and, if necessary, falls back to distribution-provided `docker` and `docker-compose` packages.

- **Zypper-based systems (openSUSE/SLES)**  
  
  - Refreshes repositories.  
  - Installs `docker` and either `docker-compose` or `docker-compose-plugin`, depending on availability.

- **Pacman-based systems (Arch)**  
  
  - Synchronizes and installs `docker` and `docker-compose`, or the Docker Compose plugin variant if required.

After installation, the script enables and starts the `docker` service using:

`systemctl enable docker`  
`systemctl start docker`

### 4.5 Honeynet User and Project Directory

To isolate the honeynet and keep its files organized, the script:

- Creates a dedicated system user called `honeynet` (if it does not already exist).  
- Creates the directory `/opt/honeynet/honeynet`.  
- Sets the ownership of this directory to the `honeynet` user.

This directory becomes the root of the honeynet project.

### 4.6 Deploying the Honeynet Files

The script expects that both `honeynet.tar.gz` and `honeynet.service` are located in the **same directory as the installer script**. It then:

1. Determines the directory where `install_honeynet.sh` resides.  

2. Copies `honeynet.tar.gz` into `/opt/honeynet/honeynet`.  

3. Changes into that directory and extracts the archive with: 
   
   `tar -xzvf honeynet.tar.gz`

4. Recursively sets ownership of the project directory and its contents to the `honeynet` user.

After extraction, the honeynet’s `compose.yml` and all related service directories, logs, and configuration files are in place.

### 4.7 Permissions for Logs and Support Components

Some services (for example, mitmproxy and the logging containers) require write access to specific directories.  
The script:

- If a `mitmproxy` directory exists, changes its ownership to `UID 1000:GID 1000`.  
- If a `logs` directory exists and includes subdirectories such as `logs/dvwa_pentesting` and `logs/dvwa_normalidad`, grants write permissions (e.g., `chmod 777`) so containers can write logs there.

These steps help avoid permission-related errors when Docker tries to bind-mount directories and write log files.

### 4.8 Starting the Honeynet with Docker Compose

Once the files and permissions are in place, the script:

1. Changes into the project directory (where `compose.yml` is located).  
2. Runs: `docker compose up -d`

This builds and starts all containers in the background (detached mode).  
From this point, the honeynet should be up and running.

### 4.9 Systemd Service Installation and Auto-Start

To ensure the honeynet restarts automatically whenever the system boots, the script:

1. Copies `honeynet.service` to `/etc/systemd/system/honeynet.service`.  

2. Edits the `WorkingDirectory` entry in the service unit to match the actual project directory (for example, `/opt/honeynet/honeynet`).  

3. Reloads systemd units with: `systemctl daemon-reload`

4. Enables and starts the service:
   
   `systemctl enable honeynet.service`  
   `systemctl start honeynet.service`

From now on, the honeynet will be started automatically during system boot via systemd.

---

## 5. How to Use the Project

### 5.1 Prerequisites

- A Linux distribution that:
- Uses systemd.
- Has one of the supported package managers (APT, DNF, Zypper, Pacman).
- Root access (or the ability to use `sudo`).

No manual Docker installation is required; the script will handle it if your distribution is supported.

### 5.2 Deployment Steps

1. **Download or copy the files to the target machine**

Place the following files in the same directory:

- `install_honeynet.sh`  

- `honeynet.tar.gz`  

- `honeynet.service`
2. **Make the script executable**
   
   `chmod +x install_honeynet.sh`

3. **Run the installer as root**
   
   `sudo ./install_honeynet.sh`
   
   The script will:
   
   - Detect your distribution.  
   
   - Install Docker and Docker Compose (if needed).  
   
   - Create the `honeynet` user and project directory.  
   
   - Extract the honeynet archive into `/opt/honeynet/honeynet`.  
   
   - Apply the necessary permissions.  
   
   - Run `docker compose up -d`.  
   
   - Set up and enable the `honeynet.service` systemd unit.

4. **Verify the installation**
   
   To check the running containers: `sudo docker ps`
   
   To check the systemd service: `systemctl status honeynet.service`

### 5.3 Managing the Honeynet After Installation

To manage the honeynet manually using Docker Compose, first change into the project directory: `cd /opt/honeynet/honeynet`

Then you can use the usual Docker Compose commands:

- Start or recreate containers in the background: `sudo docker compose up -d`
- Stop and remove containers: `sudo docker compose down`
- Stop containers without removing them: `sudo docker compose stop`
- Start previously stopped containers: `sudo docker compose start`
- You can also control the auto-start behavior via systemd:
  - Stop the honeynet service: `sudo systemctl stop honeynet.service`
  - Disable the service so it does not start at boot: `sudo systemctl disable honeynet.service`

---

## 6. Optional: Portainer Web UI

The honeynet includes a container that runs **Portainer**, a web-based management UI for Docker.  
Portainer is completely **optional**: you can manage the honeynet solely through terminal commands if you prefer.

### 6.1 What Portainer Provides

Portainer offers:

- A graphical dashboard for managing Docker containers, images, networks, and volumes.  
- An intuitive interface to:
- Start, stop, restart, and remove containers.
- Inspect logs and resource usage.
- View metrics and container details.

This makes Portainer particularly useful if you are not very familiar with Docker’s command-line interface, or if you want a quick visual overview of the honeynet’s state.

### 6.2 Portainer Deployment

Portainer is already defined as one of the services in the `compose.yml` file within the honeynet project.  
This means:

- When you install the honeynet using `install_honeynet.sh`, and `docker compose up -d` is executed, the Portainer container will be started along with the other honeypots and services (assuming it is enabled in `compose.yml`).

No additional installation steps are required beyond running the main installer.

### 6.3 Accessing Portainer

By default, Portainer exposes a web UI on **port 9000** of the local host.  
After the honeynet is running, you can access Portainer via: [http://localhost:9000](http://localhost:9000/)

On first access, Portainer will prompt you to create an **administrator account**.  

> **Important security notes:**
> 
> - Choose a **strong, secure password** for the Portainer admin user.  
>   Anyone with Portainer access can interact with the Docker daemon, which includes the ability to deploy arbitrary containers and potentially install malicious software.
> - Do **not expose the Portainer web interface directly to the Internet**.  
>   The default configuration is intended for access from the local host only. If you intentionally expose Portainer over a network, you must harden the environment appropriately and understand the associated risks.

If you do not wish to use Portainer, you can simply ignore this service or remove/disable the corresponding section from `compose.yml`.

### 6.4 Using Portainer

Once an administrator account has been created in Portainer and you have logged in, you must connect to the *local environment* in order to manage the containers running on the host. From the Portainer home screen, select the local Docker environment to access the management dashboard for this honeynet deployment.

From the main dashboard, you can navigate to the different elements of the honeynet, including containers, images, networks, and volumes. This interface provides an organized view of all services, making it easy to inspect their status, restart or stop containers, and access logs and basic metrics.

In this deployment, several containers are duplicated in order to provide **two distinct sets of services**, that is, two separate honeynets within the same infrastructure. On one of them (*normality*), only legitimate or benign traffic should be generated, with the goal of collecting activity logs that represent normal service usage. On the other (*pentesting*), different types of attacks are intentionally launched to obtain logs that capture malicious behavior against the same services. This design allows researchers to work with two clearly differentiated log sets: one for normal traffic and one for attack traffic.

---

## 7. Customization

This project is designed to be **customizable**:

- You can edit `compose.yml` to:
  
  - Add new honeypots or remove existing ones.
  - Adjust ports, volumes, and environment variables.
  - Integrate additional monitoring or logging services.

- You can modify the contents of `honeynet.tar.gz`:
  
  - Add custom service directories with their own Dockerfiles.
  - Change log directory structure, as long as the script’s permission logic is updated accordingly.

- You can adapt `honeynet.service`:
  
  - To tweak restart behavior.
  - To add dependencies on other system services if needed.

Whenever you modify the honeynet project, remember to:

1. Update the `honeynet.tar.gz` archive with the new files.  
2. Re-deploy or update the running environment as appropriate (`docker compose up -d` from the project directory).

---

## 8. Disclaimer

This project deploys a honeynet, which is by definition intended to attract, observe, or analyze potentially malicious activity.  
It is **your responsibility** to:

- Use it in a controlled environment (e.g., lab or isolated network).  
- Ensure compliance with local laws, regulations, and organizational policies.  
- Properly secure the host system and any exposed services.

Use at your own risk.



---

## 9. Uninstallation

The project includes a helper script called `uninstall_honeynet.sh`, which is designed to completely remove the honeynet deployment from the system and revert all changes performed by the installer.

### 9.1 What the Uninstall Script Does

When executed with sufficient privileges, `uninstall_honeynet.sh` performs the following actions:

1. Stops the `honeynet.service` systemd unit (if present).
2. Disables the service to prevent automatic start at boot.
3. Executes `docker compose down -v --remove-orphans` from the honeynet project directory (`/opt/honeynet/honeynet`) to:
   - Stop all running containers.
   - Remove containers.
   - Remove associated volumes.
4. Deletes the systemd unit file (`/etc/systemd/system/honeynet.service`).
5. Removes the honeynet project directory (`/opt/honeynet`).
6. Optionally prunes unused Docker images, volumes, networks, and build cache.

After successful execution, the honeynet containers, images created by the project, service unit, and project files will be removed from the system.

### 9.2 Requirements for Proper Execution

For `uninstall_honeynet.sh` to function correctly, the following conditions must be met:

- The script must be executed with **root privileges**, for example:
  
  `sudo ./uninstall_honeynet.sh`

- The user executing Docker commands must have permission to access the Docker daemon.
  
  This can be achieved in one of two ways:
  
  **Option A – Run everything with sudo (recommended for simplicity)**  
  Always execute the uninstall script using `sudo`.
  
  **Option B – Add the user to the docker group**  
  
  `sudo usermod -aG docker <username>`
  
  After running this command, the user must log out and log back in for the group membership to take effect.
  
  You can verify group membership with: `groups`
  
  The output should include `docker`.
  
  If the user does not have permission to access `/var/run/docker.sock`, Docker commands will fail with an error such as: permission denied while trying to connect to the docker API at unix:`///var/run/docker.sock`
  
  In that case, either use `sudo` or ensure proper group membership before running the uninstall script.

### 9.3 Manual Verification After Uninstallation

To confirm that the honeynet has been fully removed, you may check:

- Running containers:
  
  `docker ps`

- Existing containers (including stopped ones):
  
  `docker ps -a`

- Systemd service status:
  
  `systemctl status honeynet.service`

- Project directory:
  
  `ls /opt`

The honeynet should no longer appear in any of these checks if uninstallation completed successfully.
