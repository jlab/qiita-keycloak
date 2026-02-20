# the URL for your users to browse to your qiita instance
QIITA_BASE_URL = localhost

# an email address users will direct help requests to
HELP_EMAIL = foo@tinqiita.com

# The email address, Qiita sends internal notifications to a sys admin
SYSADMIN_EMAIL = jeff@tinqiita.com


# Communication between qiita main (this is all services but the plugins) and
# the multiple qiita plugins need verification for both directions:
# a) plugin verifies main
#    This is done via SSL certificates. In the below target, a self signed 
#    certificat is created for your BASE_URL (e.g. qiita.jlab.bio), which will 
#    be distributed to main (located at /qiita_certificates) and plugin
#    (located at /qiita_server_certificates) docker images.
#    Thus, the plugin can double check that main is the correct server. Feel
#    free to change configuration of the certificat within the *_csr.conf and 
#    *_cert.conf, but be careful with renaming the according files, as 
#    file*names* (not file content) must be kept in sync between the build
#    images and the files you are mounting to the images.
# b) main authorizes plugin
#    Communication from the plugin with main is implemented via qiita_client,
#    which is part of each plugin. Main needs to authorize a plugin by adding
#    its oauth ID and secret into the database. Both values get created with
#    the "configure_PLUGIN" script and are stored in a config file in each 
#    plugin image under /unshared_plugins/...*.conf at build time of the image.
#    (This is also the place where the filepath to the SSL certificat of a) is
#    registered). The plugin_collector service iterates over plugins and
#    transfers these files to main, such that main can add the according values
#    into the database.
OPENSSL=/bin/openssl
$(DIR_REFERENCES)/Certificates/%: Configuration/%_csr.conf Configuration/%_cert.conf
	# === create own certificates ===
	mkdir -p $@
	# Generate a new root CA private key and certificate
	cd $@ && $(OPENSSL) req -x509 -sha256 -days 356 -nodes -newkey rsa:2048 -subj "/CN=tinqiita-nginx-1/C=DE/L=Giessen" -keyout $*_rootca.key -out $*_rootca.crt
	# Generate a new server private key
	cd $@ && $(OPENSSL) genrsa -out $*_server.key 2048
	# Copy the following to a new file named csr.conf and modify to suit your needs
	# Copy the following to a new file named cert.conf and modify to suit your needs
	# Nils: alt_names is the important aspect. Make entries for all valid hostnames with which services shall be addressed
	for f in `echo "$^"`; do cat $$f > $@/`basename $$f`; done
	#cp $^ $@/
	# Generate a certificate signing request
	cd $@ && $(OPENSSL) req -new -key $*_server.key -out $*_server.csr -config $*_csr.conf
	# Generate a new signed server.crt to use with your server.key
	cd $@ && $(OPENSSL) x509 -req -in $*_server.csr -CA $*_rootca.crt -CAkey $*_rootca.key -CAcreateserial -out $*_server.crt -days 365 -sha256 -extfile $*_cert.conf
	# concat rootca and server certificates into one file
	cd $@ && cat $*_rootca.crt $*_server.crt > $*_server_certificates.pem
	# === end: create own certificates ===

RANDOMPWD = $(shell python -c "from base64 import b64encode; from uuid import uuid4; phrase=b64encode(uuid4().bytes + uuid4().bytes); print(phrase.decode())")
propagate_configuration: config_keycloak $(DIR_REFERENCES)/Certificates/tinqiita $(DIR_REFERENCES)/Certificates/keycloak
	# if QIITA_BASE_URL is not "localhost" add it to the certificat configurations
	if ! grep -q $(QIITA_BASE_URL) Configuration/$(CERTNAME)_csr.conf && [ "$(QIITA_BASE_URL)" != "localhost" ]; then \
		lastNo=`grep "^DNS." Configuration/$(CERTNAME)_csr.conf | tail -n 1 | cut -d "=" -f 1 | cut -d "." -f 2 | tr -d " "`; \
		echo "DNS.$$((lastNo + 1)) = $(QIITA_BASE_URL)" >> Configuration/$(CERTNAME)_csr.conf; \
		echo "DNS.$$((lastNo + 1)) = $(QIITA_BASE_URL)" >> Configuration/$(CERTNAME)_cert.conf; \
	fi

	# set secure passphrase for COOKIE_SECRET
	pp=$(RANDOMPWD); escpp=$$(echo "$$pp" | sed 's/[\/&]/\\&/g'); sed -i "/^\[main\]$$/,/^\[/ s|\(^COOKIE_SECRET = \)SECRET|\1$$escpp|" Configuration/config_qiita_oidc.cfg

	# set secure passphrase for secure JWTs for delegated permission artifact download
	pp=$(RANDOMPWD); escpp=$$(echo "$$pp" | sed 's/[\/&]/\\&/g'); sed -i "/^\[main\]$$/,/^\[/ s|\(^JWT_SECRET = \)SUPER_SECRET|\1$$escpp|" Configuration/config_qiita_oidc.cfg

	# Address a user should write to when asking for help
	sed -i "/^\[main\]$$/,/^\[/ s|\(^HELP_EMAIL = \)foo@bar.com|\1$(HELP_EMAIL)|" Configuration/config_qiita_oidc.cfg

	# The email address, Qiita sends internal notifications to a sys admin
	sed -i "/^\[main\]$$/,/^\[/ s|\(^SYSADMIN_EMAIL = \)jeff@bar.com|\1$(HELP_EMAIL)|" Configuration/config_qiita_oidc.cfg

	# for postgres: set admin and user password to the same value, as within the containerized environment, it does not make sense to separate
	pp=$(RANDOMPWD); \
	escpp=$$(echo "$$pp" | sed 's/[\/&]/\\&/g'); \
	sed -i "/^\[postgres\]$$/,/^\[/ s|\(^PASSWORD = \)postgres|\1$$escpp|" Configuration/config_qiita_oidc.cfg; \
	sed -i "/^\[postgres\]$$/,/^\[/ s|\(^ADMIN_PASSWORD = \)postgres|\1$$escpp|" Configuration/config_qiita_oidc.cfg; \
	user=`sed -n "/^\[postgres\]$$/,/^\[/ {/^USER/p}" Configuration/config_qiita_oidc.cfg | cut -d "=" -f 2 | tr -d " "`; \
	dbname=`sed -n "/^\[postgres\]$$/,/^\[/ {/^DATABASE/p}" Configuration/config_qiita_oidc.cfg | cut -d "=" -f 2 | tr -d " "`; \
	pwp_qiitauser=$(RANDOMPWD); \
	if [ ! -f Configuration/qiita_db.env ]; then \
		echo "POSTGRES_USER=$$user" > Configuration/qiita_db.env; \
		echo "POSTGRES_PASSWORD=$$pp" >> Configuration/qiita_db.env; \
		echo "POSTGRES_DATABASE=$$dbname" >> Configuration/qiita_db.env; \
		echo "SECURE_QIITA_DB=$(SECURE_QIITA_DB)" >> Configuration/qiita_db.env; \
		if [ "$(SECURE_QIITA_DB)" = "True" ]; then \
			echo "QIITA_USER_DEFAULT_PWD=$$pwp_qiitauser" >> Configuration/qiita_db.env; \
		fi; \
	fi

	# set redis password
	pp=$(RANDOMPWD); escpp=$$(echo "$$pp" | sed 's/[\/&]/\\&/g'); sed -i "/^\[redis\]$$/,/^\[/ s|\(^PASSWORD =$$\)|\1 $$escpp|" Configuration/config_qiita_oidc.cfg; \
	if [ ! -f Configuration/redis.env ]; then echo "REDISPWD=$$pp" > Configuration/redis.env; fi

	# create an empty keycloak.env file, such that compose.yaml can reference it
	if [ ! -f Configuration/keycloak.env ]; then \
		touch Configuration/keycloak.env; \
	fi;

config_keycloak: $(DIR_REFERENCES)/Certificates/keycloak
	# set up keycloak
	if [ ! -f Configuration/keycloak.env ]; then \
		pp=$(RANDOMPWD); \
		echo "POSTGRES_PASSWORD=$$pp" > Configuration/keycloak.env; \
		echo "KC_DB_PASSWORD=$$pp" >> Configuration/keycloak.env; \
		ppkk=$(RANDOMPWD); \
		echo "KC_BOOTSTRAP_ADMIN_PASSWORD=$$ppkk" >> Configuration/keycloak.env; \
	fi;

	# set true client secret
	# set same password for the four default user
	if grep -q "^CLIENT_SECRET = $$" Configuration/config_qiita_oidc.cfg; then \
		secret=$(RANDOMPWD); \
		escsecret=$$(echo "$$secret" | sed 's/[\/&]/\\&/g'); \
		sed -i "s|\"secret\": \"SUPERSECRET\"|\"secret\": \"$$secret\"|" Configuration/realm-tinqiita.json; \
		sed -i "/^\[oidc_docker\]$$/,/^\[/ s|\(^CLIENT_SECRET = $$\)|\1$$escsecret|" Configuration/config_qiita_oidc.cfg; \
		\
		pp=$(RANDOMPWD); \
		escpp=$$(echo "$$pp" | sed 's/[\/&]/\\&/g'); \
		sed -i "s|\"value\": \"password\",|\"value\": \"$$escpp\",|g" Configuration/realm-tinqiita.json; \
	fi;

	# append DNA entries to enable proper communication from host with services within docker compose containers
	# you need sudo rights for this!
	if [[ -z "$GITHUB_WORKFLOW" ]]; then \
		grep "^127.0.0.1\s*keycloak.local$$" /etc/hosts || echo "127.0.0.1\tkeycloak.local" >> /etc/hosts; \
		grep "^127.0.0.1\s*tinqiita-nginx-1$$" /etc/hosts || echo "127.0.0.1\ttinqiita-nginx-1" >> /etc/hosts; \
	fi;

clean_config:
	git checkout compose.yaml Configuration/config_qiita_oidc.cfg Configuration/tinqiita_cert.conf Configuration/tinqiita_csr.conf Configuration/realm-tinqiita.json
	rm -f Configuration/qiita_db.env Configuration/redis.env Configuration/keycloak.env
