# online-university
This repository provides usage of an included 1-line script that can be used to attempt to setup a university in a box. It goes about accomplishing this by installing and configuring...
-- ELMS Learning Network
-- Drupal 7 using Publicize to market your institution and what it does
-- Learning Locker for XAPI / TinCanAPI LRS capture(future)
-- Piwik general tracking, analytics (future)

The goals of this repo are obvious; spin up nearly a decade of thought leadership without effort. The most effective way to lead in the future is through empowerment. We seek to empower all.

# Installation
Copy and paste this / deploy it on a new server (CentOS 6.5 install)
`yes | yum -y install git && git clone https://github.com/elmsln/online-university.git online-university && bash online-university/install-online-university.sh elmsln ln elmsln.dev http admin@elmsln.dev yes`

## Assumptions (currently)
Select the cloud provider of your choosing and deploy. This currently works against Digital Ocean / CentOS 6.5 blank servers. Do not run this against anything else.
Assumes run as root user.
Also assumes you have a domain picked out and pointed to the server in question. We haven't automated all that... yet.

Ex Uno Plures!
