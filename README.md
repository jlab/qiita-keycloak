**IMPORTANT: Have docker installed!**
**THIS VERSION CURRENTLY ONLY WORKS WITH DOCKER, NOT WITH PODMAN**
**FOR TESTING ON LOCAL MACHINES**

### Hopefully "foolproof" instructions:
1. Clone repository
2. Move into Image Folder `cd Images/qiita`
3. Build docker image `docker build . -f qiita/Dockerfile -t qiita`
4. Move to folder containing compose file `cd ../..`
5. Copy the `qiita_db.env.example` and the `qiita.env.example` files, configure them to your needs, and delete the `.example` from the file names.
6. Run docker compose `docker compose up`
7. Open `http://localhost:21174`
8. To stop: Run `docker compose down qiita qiita-db`
    - Use `docker compose down --volumes`if you wish to remove the database volume as well.

### IF YOU WANT TO USE LOCAL KEYCLOAK:

1. Clone repository
2. Run `docker compose up keycloak_web keycloakdb`
3. Open `http://localhost:8080`, login admin pw admin
4. Configure Qiita as a service, create a user
5. Edit `config_qiita_oidc.cfg` to fit your local Keycloak configuration, remove # from necessary oidc block.
6. Open a new terminal, move into Image Folder `cd Images/qiita`
7. Build docker image `docker build . -f qiita/Dockerfile -t qiita`
8. Move to folder containing compose file `cd ../..`
9. Copy the `qiita_db.env.example` and the `qiita.env.example` files, configure them to your needs, and delete the `.example` from the file names.
10. Run docker compose `docker compose up qiita qiita-db`
11. Open `http://localhost:21174`