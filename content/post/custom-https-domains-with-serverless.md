+++
date = "2017-02-14T12:05:22-07:00"
title = "custom https domains with serverless"
tags = []
draft = true

+++

brianz@utah$ docker run --rm -it bz/certbot bash
root@cc90e67b78d3:/# certbot certonly --manual
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Enter email address (used for urgent renewal and security notices) (Enter 'c' to
cancel):brianz@gmail.com

-------------------------------------------------------------------------------
Please read the Terms of Service at
https://letsencrypt.org/documents/LE-SA-v1.1.1-August-1-2016.pdf. You must agree
in order to register with the ACME server at
https://acme-v01.api.letsencrypt.org/directory
-------------------------------------------------------------------------------
(A)gree/(C)ancel: A

-------------------------------------------------------------------------------
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about EFF and
our work to encrypt the web, protect its users and defend digital rights.
-------------------------------------------------------------------------------
(Y)es/(N)o: Y
Please enter in your domain name(s) (comma and/or space separated)  (Enter 'c'
to cancel):connector.brianz.bz
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for connector.brianz.bz

-------------------------------------------------------------------------------
NOTE: The IP of this machine will be publicly logged as having requested this
certificate. If you're running certbot in manual mode on a machine that is not
your server, please ensure you're okay with that.

Are you OK with your IP being logged?
-------------------------------------------------------------------------------
(Y)es/(N)o: Y

-------------------------------------------------------------------------------
Make sure your web server displays the following content at
http://connector.brianz.bz/.well-known/acme-challenge/fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs before continuing:

fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs.cn-j1bwbdeTbrxZ88VCAX9ztMBlwHUP8rkPXeiOjIRU

If you don't have HTTP server configured, you can run the following
command on the target server (as root):

mkdir -p /tmp/certbot/public_html/.well-known/acme-challenge
cd /tmp/certbot/public_html
printf "%s" fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs.cn-j1bwbdeTbrxZ88VCAX9ztMBlwHUP8rkPXeiOjIRU > .well-known/acme-challenge/fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs
# run only once per server:
$(command -v python2 || command -v python2.7 || command -v python2.6) -c \
"import BaseHTTPServer, SimpleHTTPServer; \
s = BaseHTTPServer.HTTPServer(('', 80), SimpleHTTPServer.SimpleHTTPRequestHandler); \
s.serve_forever()" 
-------------------------------------------------------------------------------
Press Enter to Continue
Waiting for verification...
Cleaning up challenges
Generating key (2048 bits): /etc/letsencrypt/keys/0000_key-certbot.pem
Creating CSR: /etc/letsencrypt/csr/0000_csr-certbot.pem

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at
   /etc/letsencrypt/live/connector.brianz.bz/fullchain.pem. Your cert
   will expire on 2017-05-15. To obtain a new or tweaked version of
   this certificate in the future, simply run certbot again. To
   non-interactively renew *all* of your certificates, run "certbot
   renew"
 - If you lose your account credentials, you can recover through
   e-mails sent to brianz@gmail.com.
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

root@cc90e67b78d3:/# cd /etc/letsencrypt/live/
root@cc90e67b78d3:/etc/letsencrypt/live# ls -l
total 4
drwxr-xr-x 2 root root 4096 Feb 14 18:56 connector.brianz.bz
root@cc90e67b78d3:/etc/letsencrypt/live# cd connector.brianz.bz/
root@cc90e67b78d3:/etc/letsencrypt/live/connector.brianz.bz# ls -l
total 4
-rw-r--r-- 1 root root 543 Feb 14 18:56 README
lrwxrwxrwx 1 root root  43 Feb 14 18:56 cert.pem -> ../../archive/connector.brianz.bz/cert1.pem
lrwxrwxrwx 1 root root  44 Feb 14 18:56 chain.pem -> ../../archive/connector.brianz.bz/chain1.pem
lrwxrwxrwx 1 root root  48 Feb 14 18:56 fullchain.pem -> ../../archive/connector.brianz.bz/fullchain1.pem
lrwxrwxrwx 1 root root  46 Feb 14 18:56 privkey.pem -> ../../archive/connector.brianz.bz/privkey1.pem
root@cc90e67b78d3:/etc/letsencrypt/live/connector.brianz.bz# cd ../../archive/
root@cc90e67b78d3:/etc/letsencrypt/archive# ls -l
total 4
drwxr-xr-x 2 root root 4096 Feb 14 18:56 connector.brianz.bz
root@cc90e67b78d3:/etc/letsencrypt/archive# cd connector.brianz.bz/
root@cc90e67b78d3:/etc/letsencrypt/archive/connector.brianz.bz# ls -l
total 16
-rw-r--r-- 1 root root 1809 Feb 14 18:56 cert1.pem
-rw-r--r-- 1 root root 1647 Feb 14 18:56 chain1.pem
-rw-r--r-- 1 root root 3456 Feb 14 18:56 fullchain1.pem
-rw-r--r-- 1 root root 1704 Feb 14 18:56 privkey1.pem
root@cc90e67b78d3:/etc/letsencrypt/archive/connector.brianz.bz# pwd
/etc/letsencrypt/archive/connector.brianz.bz
root@cc90e67b78d3:/etc/letsencrypt/archive/connector.brianz.bz# ls 
cert1.pem  chain1.pem  fullchain1.pem  privkey1.pem
root@cc90e67b78d3:/etc/letsencrypt/archive/connector.brianz.bz# exit



root@ip-172-31-43-60:/home/ubuntu# cat cert.sh 
#!/bin/bash
if [[ ! -d /tmp/certbot/public_html/.well-known/acme-challenge ]]; then
  mkdir -p /tmp/certbot/public_html/.well-known/acme-challenge
fi
cd /tmp/certbot/public_html
printf "%s" fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs.cn-j1bwbdeTbrxZ88VCAX9ztMBlwHUP8rkPXeiOjIRU > .well-known/acme-challenge/fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs
# run only once per server:
$(command -v python2 || command -v python2.7 || command -v python2.6) -c \
"import BaseHTTPServer, SimpleHTTPServer; \
s = BaseHTTPServer.HTTPServer(('', 80), SimpleHTTPServer.SimpleHTTPRequestHandler); \
s.serve_forever()"
root@ip-172-31-43-60:/home/ubuntu# ./cert.sh 




ubuntu@ip-172-31-43-60:~$ sudo su
root@ip-172-31-43-60:/home/ubuntu# ./cert.sh 
66.133.109.36 - - [14/Feb/2017 18:56:34] "GET /.well-known/acme-challenge/fhKqLc6FuM97zg3Y7SAcJdeotnwtgjLqs0TkJT_h4Xs HTTP/1.1" 200 -
