FROM alpine:3.4

# We're using the hotfix branch since master does not work!
ARG DUDEL_VERSION=5b9b538e942debb05e168cf07fe238d169d1c586
ARG COFFEESCRIPT_VERSION=1.10.0
ARG SASS_VERSION=3.4.22

WORKDIR /app/

# Permanent dependencies
RUN \
	apk add --no-cache \
		gettext \
		libldap \
		libpq \
		libsasl \
		nodejs-lts \
		python \
		uwsgi \
		uwsgi-python \
		ruby
RUN gem install --no-ri --no-rdoc sass -v "$SASS_VERSION"
RUN npm install -g "coffee-script@$COFFEESCRIPT_VERSION"

# Dudel source code
ADD "https://github.com/opatut/dudel/archive/${DUDEL_VERSION}.tar.gz" /tmp/dudel.tar.gz
RUN \
	apk add --no-cache --virtual .builddeps \
		gzip \
		tar \
		&&\
	tar xzf /tmp/dudel.tar.gz --strip-components=1 &&\
	rm /tmp/dudel.tar.gz &&\
	apk del .builddeps

# Apply code patches
ADD patches/ /tmp/patches
RUN \
	cat /tmp/patches/*.patch | patch -p1 &&\
	rm -rf /tmp/patches

# Build-time dependencies and build process itself
RUN \
	mkdir -p /data &&\
	mv config.py.example /data/config.py &&\
	sed -i 's,sqlite:///tmp/dudel.db,sqlite:////data/dudel.db,g' /data/config.py &&\
	sed -i 's,DEBUG\s\+=\s\+TRUE,DEBUG = False,gi' /data/config.py &&\
	sed -i 's,TESTING\s\+=\s\+TRUE,TESTING = False,gi' /data/config.py &&\
	ln -sf /data/config.py config.py &&\
\
	apk add --no-cache --virtual .builddeps \
		alpine-sdk \
		cyrus-sasl-dev \
		openldap-dev \
		postgresql-dev \
		py-pip \
		python-dev \
		&&\
\
	pip install -I \
		blinker==1.4 \
		flask==0.10.1 \
		flask-assets==0.10 \
		flask-babel==0.9 \
		flask-gravatar==0.4.1 \
		flask-login==0.2.11 \
		flask-mail==0.9.0 \
		flask-markdown==0.3 \
		flask-migrate==1.4.0 \
		flask-sqlalchemy==2.1 \
		&&\
	pip install -r requirements.txt &&\
	make i18n-compile &&\
\
	apk del .builddeps &&\
	rm -rf /var/tmp/* /tmp/*

VOLUME /data
CMD [ "python2", "manage.py", "runserver", "--host=0.0.0.0" ]
EXPOSE 5000