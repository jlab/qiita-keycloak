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
7. start the docker ensemble: `sudo docker compose up`
8. take your favorite browser and surf to `https://localhost:8383`. You probably get a warning due to incorrect SSL certificates like:
   ![image](https://github.com/user-attachments/assets/58e978ab-c633-4197-b6f9-b0a62b8b671c) for Firefox. Press "Advanced..." and then "Accept the Risk and Continue"
9. You should now be able to see your living qiita. Log in as user `admin@foo.bar` (or `test@foo.bar`) and password `password`.

That's it. Enjoy!

### pro infos
- log files will be written to `tinqiita/logs`
- You can access the relevant containers by checking for their names with `sudo docker container ls` and then running `sudo docker exec -it <container name>  bash`
- keycloak service is **not** activated at the moment of writing, but should you want to work on that:
   1. Run `sudo docker compose up keycloak keycloakdb`
   2. Open `http://localhost:8080`, login admin pw admin
   3. Configure Qiita as a service, create a user.
   4. Edit `config_qiita_oidc.cfg` to fit your local Keycloak configuration, remove # from necessary oidc block, change SUPERSECRETSTRING.


