# Contributing

Contributions should preserve reproducibility, environment separation and complete event capture.

Before submitting a change:

1. validate shell and Python syntax;
2. run `docker compose config --quiet`;
3. deploy on a clean supported VM;
4. run `scripts/healthcheck.sh` and `scripts/validate_honeynet.sh`;
5. execute a short normal and anomalous campaign;
6. document changes to ports, credentials, images, schemas and log formats;
7. verify pinned external image tags exist and match the configuration syntax used;
8. update `CHANGELOG.md` and relevant documentation.

Never commit runtime logs, generated certificates, secrets, databases, mail state or Docker volumes.
