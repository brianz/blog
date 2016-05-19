+++
date = "2016-05-18T16:27:48-06:00"
draft = true
title = "Serverless part III"
tags = [
    'aws',
    'architecture',
    'serverless'
]

+++

This is part three in my series about creating serverless systems using AWS API Gateway + Lambda
via the [Serverless](http://serverless.com) project. If you're haven't already you can read 
[part I]({{< ref "serverless-part-i.md" >}}) and [part II]({{< ref "serverless-part-ii.md" >}}).

My goal is to continue evolving this example to walk through a non-trivial example of doing
something with the serverless architecture. Along the way I'll demo some useful features which
you'll undoubtedly run into when doing real development with Serverless.

## Syncing with the `meta sync` plugin

One issue you will quickly run in to when either working on a project with someone else *or*
working on your own project on different computers is that of the `_meta` directory. If you look at
the repository for this demo project you'll notice there isn't a `_meta` directory. The reason is
that this stores (potentiall) sensitive information about your project such as private keys, etc.
By default, Serverless will (add this to the `.gitignore` of your
project)[https://github.com/brianz/serverless-demo/blob/part-ii/serverless-demo/.gitignore#L43].

So, why is this a big deal? Imagine a very simple case and one which I experience when working on
this demo project.  I have two computers, my iMac and MacBook Pro. I authored the project my iMac.
Since everything is bootstrapped here, I have all the information I need, specifically, the `_meta`
directory:

```
brianz@gold(master=)$ tree -L 1 .
.
├── _meta
├── admin.env
├── node_modules
├── package.json
├── s-project.json
├── s-resources-cf.json
└── src
```

Now, I switch over to my MacBook Pro and clone the repo. Let's see what happens (note, I'm really
going to clone this in a different location on my MacBook, but just for demonstration since I
already have this setup on my MacBook and performed the same steps):

```
brianz@gold$ cd ~/dev
brianz@gold$ git clone https://github.com/brianz/serverless-demo.git
brianz@gold$ cd serverless-demo/
brianz@gold(master=)$ ls -l
total 32
-rw-r--r--  1 brianz  staff   182 May 19 09:53 Dockerfile
-rw-r--r--  1 brianz  staff  1081 May 19 09:53 LICENSE
-rwxr-xr-x  1 brianz  staff   174 May 19 09:53 Makefile
-rw-r--r--  1 brianz  staff   411 May 19 09:53 README.md
drwxr-xr-x  7 brianz  staff   238 May 19 09:53 serverless-demo
brianz@gold(master=)$ cd serverless-demo/
brianz@gold(master=)$ ls -l
total 24
-rw-r--r--  1 brianz  staff   328 May 19 09:53 package.json
-rw-r--r--  1 brianz  staff   190 May 19 09:53 s-project.json
-rw-r--r--  1 brianz  staff  1527 May 19 09:53 s-resources-cf.json
drwxr-xr-x  3 brianz  staff   102 May 19 09:53 src
```

Herein lies the issue...without the 



## Setting up environment variables

