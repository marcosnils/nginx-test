NGINX_VER := 1.4.1
NODEJS_VERSION := v0.10.7
DIR := $(shell pwd)

export SHELL=/bin/bash -l

base: 
	apt-get update -y
	apt-get install build-essential openssl libssl-dev pkg-config curl vim git-core libssl-dev libpcre3 libpcre3-dev libssl-dev libossp-uuid-dev autotools-dev automake libtool autoconf libncurses5-dev xsltproc groff-base libpcre3-dev g++ -y
	
local-install: base nodejs nginx ldconfig dnsmasq
	nvm use default && npm install --no-bin-link	
	nvm use default && npm update --no-bin-link	

nodejs: nvm
	. $(HOME)/.nvm/nvm.sh; nvm use $(NODEJS_VERSION) || nvm install $(NODEJS_VERSION)
	. $(HOME)/.nvm/nvm.sh; nvm alias default $(NODEJS_VERSION)

nvm:
	test -f $(HOME)/.nvm/nvm.sh || (curl https://raw.githubusercontent.com/creationix/nvm/v0.18.0/install.sh -L | sh)

ldconfig:
	sudo ldconfig

local-test:
	. $(HOME)/.nvm/nvm.sh; nvm use $(NODEJS_VERSION); sudo ./run_tests.sh
	
test: insecure_private_key
	vagrant up
	vagrant ssh -c "cd /vagrant && make local-test -B"

install: insecure_private_key
	vagrant up
	vagrant ssh -c "cd /vagrant && sudo apt-get install make -y && sudo make local-install -B"
	
dnsmasq:
	@which dnsmasq 1>/dev/null || test -d /usr/sbin/dnsmasq || (apt-get -y install dnsmasq*  && update-rc.d -f dnsmasq remove && service dnsmasq stop && sed -ie 's/^#prepend domain-name-servers 127.0.0.1/prepend domain-name-servers 127.0.0.1/' /etc/dnsmasq.conf) || sleep 5

insecure_private_key:
	-@sudo chown -f $(USER) ~/.vagrant.d/insecure_private_key 
	

nginx:
	test -d /usr/src || mkdir -p /usr/src
	rm -rf /usr/src/nginx-$(NGINX_VER)
	test -f /usr/src/nginx-$(NGINX_VER).tar.gz || (cd /usr/src && curl -O http://nginx.org/download/nginx-$(NGINX_VER).tar.gz && tar xf nginx-$(NGINX_VER).tar.gz)
	test -d /usr/src/nginx-$(NGINX_VER) || (cd /usr/src && tar xf nginx-$(NGINX_VER).tar.gz)
	mkdir -p /usr/src/nginx-$(NGINX_VER)/modules
	cd /usr/src/nginx-$(NGINX_VER)/modules && (test -d echo-nginx-module || (git clone https://github.com/agentzh/echo-nginx-module.git && cd echo-nginx-module && git checkout v0.42))
	cd /usr/src/nginx-$(NGINX_VER)/modules && (test -d ngx_devel_kit || (git clone https://github.com/simpl/ngx_devel_kit.git && cd ngx_devel_kit && git checkout v0.2.18))
	cd /usr/src/nginx-$(NGINX_VER)/modules && (test -d array-var-nginx-module || (git clone https://github.com/agentzh/array-var-nginx-module.git && cd array-var-nginx-module && git checkout v0.03rc1))
	cd /usr/src/nginx-$(NGINX_VER)/modules && (test -d set-misc-nginx-module || (git clone https://github.com/agentzh/set-misc-nginx-module.git && cd set-misc-nginx-module && git checkout v0.22rc8))
	cd /usr/src/nginx-$(NGINX_VER)/modules && (test -d headers-more-nginx-module || (git clone https://github.com/agentzh/headers-more-nginx-module.git && cd headers-more-nginx-module && git checkout v0.15rc3))
	cd /usr/src/nginx-$(NGINX_VER) && ./configure --prefix=/opt/nginx-test-rules --with-ld-opt="-lossp-uuid" --with-cc-opt="-I/usr/include/ossp" \
	  --add-module=/usr/src/nginx-$(NGINX_VER)/modules/echo-nginx-module \
	  --add-module=/usr/src/nginx-$(NGINX_VER)/modules/ngx_devel_kit \
	  --add-module=/usr/src/nginx-$(NGINX_VER)/modules/array-var-nginx-module \
	  --add-module=/usr/src/nginx-$(NGINX_VER)/modules/set-misc-nginx-module \
	  --add-module=/usr/src/nginx-$(NGINX_VER)/modules/headers-more-nginx-module \
	  --with-http_stub_status_module
	cd /usr/src/nginx-$(NGINX_VER) && make
	cd /usr/src/nginx-$(NGINX_VER) && make install

