var should = require('should'),
	http = require('http'),
	log = require("node-logging"),
	Cookies = require('cookies'),
	os = require("os"),
	util = require('util'),
	spawn = require('child_process').spawn,
	net = require('net'),
	request = require('request'),
	sugar = require('sugar'),
	Tail = require("tailnative");
log.setLevel("info")

var express = require('express');
var backend = express();

var logformat = new Array();
logformat['time_iso8601'] = 0;
logformat['proxy_host'] = 1;
logformat['upstream_addr'] = 2;
logformat['status'] = 3;
logformat['request_time'] = 4;
logformat['upstream_status'] = 5;
logformat['upstream_response_time'] = 6;
logformat['request_length'] = 7;
logformat['http_x_forwarded_for'] = 8;


Date.prototype.getShortMonth = function(month) {
        switch(this.getMonth())   {
                case 0: return 'Jan';
                case 1: return 'Feb';
                case 2: return 'Mar';
                case 3: return 'Apr';
                case 4: return 'May';
                case 5: return 'Jun';
                case 6: return 'Jul';
                case 7: return 'Aug';
                case 8: return 'Sep';
                case 9: return 'Oct';
                case 10: return 'Nov';
                case 11: return 'Dec';
                default: return false;
        }
}

var LS = "\t";

backend.use(express.cookieParser());

backend.get('*', function(req, res){
	backend.emit('request', req);
	if (backend.listeners('response').length == 0) {
		res.send('hello world');
	} else {
		backend.emit('response', res);
	}
});

backend.put('*', function(req, res){
	backend.emit('request', req);
	if (backend.listeners('response').length == 0) {
		res.send('hello world');
	} else {
		backend.emit('response', res);
	}
});

backend.post('*', function(req, res){
	backend.emit('request', req);
	if (backend.listeners('response').length == 0) {
		res.send('hello world');
	} else {
		backend.emit('response', res);
	}
});


backend.listen(8080);
backend.listen(80);

describe("Basic" ,function(done){
	afterEach(function(done){
		backend.removeAllListeners('request');
		backend.removeAllListeners('response');
		done();
 	});
  
  	beforeEach(function(done){
		backend.removeAllListeners('request');
		backend.removeAllListeners('response');
		done();
 	});
 	
	it("ping", function(done){
		http.get({
			port: 9999,
			agent:false,
			path: '/ping'
		}, function(response) {
			should.exist(response)
			response.statusCode.should.equal(200)
			response.on('data', function (body) {
				body.toString().should.equal('pong\n')
			});
		}).on('error', function(e) {
			should.fail('expected an error!')
		}).on('close', function () {
			done()		
		});
	});

	it("nginx_status", function(done){
		http.get({
			port: 9999,
			agent:false,
			path: '/nginx_status'
		}, function(response) {
			should.exist(response)
			response.statusCode.should.equal(200)
		}).on('error', function(e) {
			should.fail('expected an error!')
		}).on('close', function () {
			done()		
		});
	});
});

describe("Headers" ,function(done){
	   
	afterEach(function(done){
		backend.removeAllListeners('request');
		backend.removeAllListeners('response');
		done();
 	});
  
  	beforeEach(function(done){
		backend.removeAllListeners('request');
		backend.removeAllListeners('response');
		done();
 	});

	it("X-Forwarded-For en proxy", function(done){
		backend.on ('request', function (request) {
			should.exist(request.headers['x-forwarded-for']);
			request.headers['x-forwarded-for'].should.include("172.16.16.16");
		});
		http.get({
			port: 9999,
			path: '/nginx',
			agent:false,
			headers: {"X-Forwarded-For": "172.16.16.16"}
		}, function(response) {
			should.exist(response)
			response.statusCode.should.equal(200)
		}).on('error', function(e) {
			should.fail('expected an error!')
		}).on('close', function () {
			done()		
		});
	});
});

describe("Access log" ,function(done){
	var accesslog = new Tail("/tmp/access.log");
	afterEach(function(done){
		backend.removeAllListeners('request');
		backend.removeAllListeners('response');
		accesslog.removeAllListeners('data');
		done();
 	});

  	beforeEach(function(done){
		backend.removeAllListeners('request');
		backend.removeAllListeners('response');
		accesslog.removeAllListeners('data');
		done();
 	});

	it("Log $status", function(done){
		backend.on ('response', function (response) {
			response.send(202);
		});

		accesslog.on ('data', function (line) { 
			line.split(LS)[logformat['status']].should.equal("202");
			done();
		});
		http.get({
			port: 9999,
			path: '/nginx/test',
			agent:false			
		}, function(response) {
			should.exist(response)
			response.statusCode.should.equal(202)
		}).on('error', function(e) {
			should.fail('expected an error!')
		});
	});

	it("Log $http_x_forwarded_for", function(done){
		accesslog.on ('data', function (line) { 
			line.split(LS)[logformat['http_x_forwarded_for']].should.equal("172.16.16.16");
			done();
		});
		http.get({
			port: 9999,
			path: '/nginx/test',
			agent:false,
			headers: {"X-Forwarded-For": "172.16.16.16"}
		}, function(response) {
			should.exist(response)
			response.statusCode.should.equal(200)
		}).on('error', function(e) {
			should.fail('expected an error!')
		});
	});

}); 

