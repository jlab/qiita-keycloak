**IMPORTANT: Have docker installed!**
**THIS VERSION CURRENTLY ONLY WORKS WITH DOCKER, NOT WITH PODMAN**
**FOR TESTING ON LOCAL MACHINES**

### Hopefully "foolproof" instructions:
0. Log files will be mounted at qiita_logs on your local machine in this repo directory. Otherwise, change the file path to your desired path in the compose file as well as in the qiita, nginx and supervisord conf.
1. Clone repository
2. Move into Image Folder `cd Images/qiita`
3. Build docker image `sudo docker build . -f qiita/Dockerfile -t local-qiita`
4. Build the nginx Image the same way as the qiita image, only in the nginx folder, using the image tag `local-nginx_qiita`.
5. Repeat with qtp-biom Image as `local-qtp-biom`.
6. Move to folder containing compose file `cd ../..`
7. Copy the `qiita_db.env.example` and the `qiita.env.example` files, configure them to your needs, and delete the `.example` from the file names.
8. Run `sudo docker compose up keycloak keycloakdb`
9. Open `http://localhost:8080`, login admin pw admin
10. Configure Qiita as a service, create a user.
11. Edit `config_qiita_oidc.cfg` to fit your local Keycloak configuration, remove # from necessary oidc block, change SUPERSECRETSTRING.
12. Run docker compose `sudo docker compose up qiita qiita-db redis qiita_worker nginx`
-  Due to some unforseen problem I did not want to deal with, yet, the original "database existence" check does not work anymore. You might have to adjust the command in start_qiita.sh the first time you run it to create your database :/
13. You can access the relevant containers by checking for their names with `sudo docker container ls` and then running `sudo docker exec -it <container name>  bash`
14. Open `http://localhost:8383`
