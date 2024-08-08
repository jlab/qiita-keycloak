**IMPORTANT: Have docker installed!**
**THIS VERSION CURRENTLY ONLY WORKS WITH DOCKER, NOT WITH PODMAN**
**FOR TESTING ON LOCAL MACHINES**

### Hopefully "foolproof" instructions:
0. Log files will be mounted at qiita_logs on your local machine in this repo directory. Otherwise, change the file path to your desired path in the compose file as well as in the qiita, nginx and supervisord conf.
1. Clone repository
2. Move into Image Folder `cd Images/qiita`
3. Build docker image `docker build . -f qiita/Dockerfile -t local-qiita`
4. Build the nginx Image the same way as the qiita image, only in the nginx folder, using the image tag `local-nginx_qiita`.
5. Move to folder containing compose file `cd ../..`
6. Copy the `qiita_db.env.example` and the `qiita.env.example` files, configure them to your needs, and delete the `.example` from the file names.
7. Run docker compose `docker compose up qiita-db redis nginx qiita`
8. Open `http://localhost:8383`
9. To stop: Run `docker compose down qiita nginx qiita-db redis`
    - Use `docker compose down qiita nginx qiita-db --volumes`if you wish to remove all associated volumes as well.

Extras:
- If you want to remove a specific volume `docker volume rm <volume name>`
- If you want to access a container `docker ps`to fetch the ID and `docker exec -it <ID> bash`

### IF YOU WANT TO USE LOCAL KEYCLOAK:

1. Clone repository
2. Run `docker compose up keycloak keycloakdb`
3. Open `http://localhost:8080`, login admin pw admin
4. Configure Qiita as a service, create a user
5. Edit `config_qiita_oidc.cfg` to fit your local Keycloak configuration, remove # from necessary oidc block.
6. Open a new terminal, move into Image Folder `cd Images/qiita`
7. Build docker image for qiita and nginx according to steps 3 and 4 from the instructions above.
8. Move to folder containing compose file `cd ../..`
9. Copy the `qiita_db.env.example` and the `qiita.env.example` files, configure them to your needs, and delete the `.example` from the file names.
10. Run docker compose `docker compose up qiita qiita-db redis nginx`
11. Open `http://localhost:8383`

### IF YOU WANT TO RUN MULTIPLE INSTANCES WITHOUT SUPERVISORD

1. Perform all the steps listed in the keycloak instructions until you arrive at step 10
2. Check the amount of replicas you desire for your run in the compose file.
3. Run docker compose with `docker compose up qiita qiita-db redis qiita_worker nginx`
4. Open `http://localhost:8383`
