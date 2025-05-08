## Howto start-up qiita through docker compose
Note: this does currently **not** work with podman :-( So strictly stick to docker here.

1. We assume you operate on your local computer, i.e. not within the BCF cluster as you won't have docker, on a Ubuntu/Mint like OS.
2. Install necessary software (git, docker.io): `sudo apt-get install git docker.io`
3. Install docker-compose:
   - You need to register their apt repository first: see https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository for details). In short: copy & paste the following command and execute in terminal:
    ```
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    ```
    - Install docker-compose through apt: `sudo apt-get update && sudo apt-get install docker-compose-plugin`
4. clone a local copy of this repository, branch "tinqiita": `git clone -b tinqiita https://github.com/jlab/qiita-keycloak.git tinqiita`
5. change into this new directory: `cd tinqiita`
6. create necessary images and other files (as this will create multiple docker images, it can take quite some time, approx. 30min?!): `sudo make all`



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
