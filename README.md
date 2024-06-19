**IMPORTANT: Have docker installed!**
**THIS VERSION CURRENTLY ONLY WORKS WITH DOCKER, NOT WITH PODMAN**
**FOR TESTING ON LOCAL MACHINES**

### Hopefully "foolproof" instructions:
0. Log files will be mounted at /tmp/qiita_logs on your local machine. Make sure the directory exists and is accessible for you. Otherwise, change the file path to your desired path in the compose file as well as in the qiita, nginx and supervisord conf.
1. Clone repository
2. Move into Image Folder `cd Images/qiita`
3. Build docker image `docker build . -f qiita/Dockerfile -t qiita`
4. Build the nginx Image the same way as the qiita image, only in the nginx folder.
5. Move to folder containing compose file `cd ../..`
6. Copy the `qiita_db.env.example` and the `qiita.env.example` files, configure them to your needs, and delete the `.example` from the file names.
7. Run docker compose `docker compose up qiita-db nginx qiita`
8. Open `http://localhost:21174`
9. To stop: Run `docker compose down qiita nginx qiita-db`
    - Use `docker compose down qiita nginx qiita-db --volumes`if you wish to remove all associated volumes as well.

Extras:
- If you want to remove a specific volume `docker volume rm <volume name>`
- If you want to access a container `docker ps`to fetch the ID and `docker exec -it <ID> bash`

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