**IMPORTANT: Have docker installed!**

### Hopefully "foolproof" instructions:
1. Clone repository
2. Move into Image Folder `cd Images/qiita`
3. Build docker image `docker build . -f qiita/Dockerfile -t qiita`
4. Move to folder containing compose file `cd ../..`
5. Run docker compose `docker compose up`
6. To stop: Run `docker compose down`
    - Use `docker compose down --volumes`if you wish to remove the database volume as well.