#!/bin/bash -l
PID_FILE_DNSMASQ=/tmp/dnsmasq.pid
NGINX=/opt/nginx-test-rules/sbin/nginx
NGINX_CONF=$PWD/conf/nginx.conf

trap ctrl_c INT

function close () {
	stop
}

function ctrl_c() {
	echo 
        echo "Control-C recibido...matando todo..."
	close
	exit 1
}


function stop_dnsmasq() {
  sed 's/^#//g' -i /etc/resolv.conf
  test -f $PID_FILE_DNSMASQ && kill $(cat $PID_FILE_DNSMASQ)
  rm -f $PID_FILE_DNSMASQ
  local  PID_DNSMASQ=`ps -ef|grep dnsmasq|grep -v grep| awk '{print $2}'`

  if [ "$PID_DNSMASQ" != "" ]; then
	echo "Dnsmasq is running. (Pid: $PID_DNSMASQ).?"
	kill -9 $PID_DNSMASQ
  fi
}

function start_dnsmasq() {
  stop_dnsmasq
  sed 's/^/#/g' -i /etc/resolv.conf
  export PATH=$PATH:/usr/sbin
  DNSMASQ=$(which dnsmasq)
  $DNSMASQ --no-hosts --no-resolv --cache-size=5000 --pid-file=$PID_FILE_DNSMASQ --listen-address=127.0.0.1 --address=/#/127.0.0.1 --address=/#/127.0.0.1 & 
}

function start_nginx() {
    cp $NGINX_CONF ${NGINX_CONF}.final
	sed 's/listen 8080/listen 9999/g' -i ${NGINX_CONF}.final
	($NGINX -s reload 2>/dev/null) || $NGINX -c {NGINX_CONF}.final
}

function stop_nginx() {
  $NGINX -c ${NGINX_CONF}.final -s stop
  pkill -9 nginx
  rm {NGINX_CONF}.final
}

function stop() {
	stop_nginx
	stop_dnsmasq
}

function start() {
	start_dnsmasq $@
	wait_dnsmasq
	start_nginx $@
	wait_nginx
}

function wait_nginx () {
	for i in {1..20}; do
		nginx=$(ps -efa | grep $NGINX | grep -v grep)
		if [ -z "$nginx" ]; then
			sleep 0.1;
		else
			return;
		fi
	done
	echo "Nginx no se pudo levantar."
	stop
	exit 1;
}

function wait_dnsmasq () {
	for i in {1..20}; do
		response=$(ping -c 1 lala${RANDOM} 2>&1)
		if echo $response | grep unknown -q; then
			sleep 0.1;
		else
			return;
		fi
	done
	echo "Dnsmasq no se pudo levantar."
	stop
	exit 1;
}

function exit_with_error () {
	close
	exit $1
}

nvm use default

echo "Running tests...."
start
./node_modules/mocha/bin/_mocha -c --globals myThis,myHolder,myCallee,State_myThis --reporter spec -t 5000 -s 3000 test/tests.js || exit_with_error $?
close

exit 0
