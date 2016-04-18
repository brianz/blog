+++
date = "2016-04-18T16:05:16-06:00"
draft = true
tags = [
    "aws", "serverless"
]
title = "Getting started with serverless"

+++

It's a pretty exciting (and challenging) time to build software-based applications. Every week
there are more and more tools to make our jobs easier or to enable us to focus on *application*
development rather than dealing with the infrastructure around those applications. Of course, this
makes our jobs challenging since we need to keep up with the innovation.

Here I'll be doing a walkthrough of the [Serverless](http://docs.serverless.com/) system/library.
Before we get going, "serverless" is new enough to warrant a definition.

Not too long ago AWS released API Gateway which is a service to create and manage public API
endpoints on your behalf. Gateway is comprised of two services really:

- control service to expose the REST endpoint
- execution service to run some code or backend system

There's much more to it of course so I encourage you to [read the docs from
AWS](http://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html).

We'll narrow in on the execution service with AWS Lambda. Lambda is yet another service from AWS
which allows you to upload some code and execute that code based on some trigger. Your code is run
on AWS-managed infrastructure, not an EC2 instance which you maintain. As an author, you
author your code in Java, node, or Python and upload it to Lambda as a zip file. When it's being
executed, AWS will magically unpack your code, run it and then be done with it until the next time
it's run. There are several beautiful things about this:

- No servers to maintain
- Pay by execution time...no wasted cycles
- Ability to execute a Lambda from various triggers

This last point is where we'll focus for now. Again, you can [read the
Lambda](http://docs.aws.amazon.com/lambda/latest/dg/intro-core-components.html) documentation to
get the full list of ways to trigger a Lambda function. The important one for this post is that **we
can wire up an API Gateway front-end to a Lambda function**.

That snippet is what sums up the term *serverless*. Imagine making an HTTP call, getting a response
and not having to manage a single EC2 instance (or any other type of server). Furthermore, that
single call cost a fraction of a penny. If you look at the [pricing for
Lambda](https://aws.amazon.com/lambda/pricing/) and [pricing for
Gateway](https://aws.amazon.com/api-gateway/pricing/) you'll get a feel for how cheap this can be.

## Serverless project

Since this is such a power design there appears to be a lot of development wrapping these two
offerings from AWS. One of the more popular ones seems to be http://serverless.com. There are
others...here's one to run [Django via Gateway/Lambda](https://github.com/Miserlou/django-zappa)
and yet another one [doing the same thing with Flask](https://github.com/Miserlou/flask-zappa). I'm
sure there are other...google ``fill-in-th-blank serverless`` and you'll undoubtedly find something
interesting.

The Serverless docs are a bit lacking and it's not entirely clear *how* to use this thing for a
real project...but let's give it a spin. Most of the challenge of this and any other project which
wraps AWS services is that you need to be fluent in the language of AWS. For example, eventually
you'll need to know what an API Gateway Stage is or how content types are mapped bewtween method
execution steps.

## Getting started

As usual I'll demo this using a Docker container. You can check out the code on Github and follow
along: https://github.com/brianz/serverless-demo  I also recommend reading the [getting started
docs on the serverless website](http://docs.serverless.com/docs/configuring-aws).

Fire up your container and let's take this for a spin.

```
root@ea44710fc5db:/code# sls --version
0.5.5
```

Great...serverless is ready to go. The first thing we'll do is create a new project which will
bootstrap the entire project. This will end up creating a few resources via Cloudformation which
are mostly IAM roles AFAICT.

```
root@c477313ae84f:/code# serverless project create
 _______                             __
|   _   .-----.----.--.--.-----.----|  .-----.-----.-----.
|   |___|  -__|   _|  |  |  -__|   _|  |  -__|__ --|__ --|
|____   |_____|__|  \___/|_____|__| |__|_____|_____|_____|
|   |   |             The Serverless Application Framework
|       |                           serverless.com, v0.5.5
`-------'

Serverless: Initializing Serverless Project...  
Serverless: Enter a name for this project:  (serverless-bju57y) serverless-demo
Serverless: Enter a new stage name for this project:  (dev) 
Serverless: For the "dev" stage, do you want to use an existing Amazon Web Services profile or
create a new one?
    Existing Profile
  > Create A New Profile
Serverless: Please enter the ACCESS KEY ID for your Admin AWS IAM User:  YOUR-ACCESS-KEY
Serverless: Enter the SECRET ACCESS KEY for your Admin AWS IAM User: YOUR-SECRET-KEY
Serverless: Enter the name of your new profile:  (serverless-demo_dev) 
Serverless: Creating stage "dev"...  
Serverless: Select a new region for your stage: 
    us-east-1
  > us-west-2
    eu-west-1
    eu-central-1
    ap-northeast-1
Serverless: Creating region "us-west-2" in stage "dev"...  
Serverless: Deploying resources to stage "dev" in region "us-west-2" via Cloudformation (~3 minutes)...  
Serverless: Successfully deployed "dev" resources to "us-west-2"  
Serverless: Successfully created region "us-west-2" within stage "dev"  
Serverless: Successfully created stage "dev"  
Serverless: Successfully initialized project "serverless-demo" 
```

Next up, we need to actually create a Lambda function. It's important to understand that after we
created the *project* we need to `cd` into that project directory

```
root@c477313ae84f:/code# cd serverless-demo/
root@c477313ae84f:/code/serverless-demo# ls -l
total 16
drwxr-xr-x 1 1000 staff  136 Apr 18 22:46 _meta
-rw-r--r-- 1 1000 staff   35 Apr 18 22:46 admin.env
-rw-r--r-- 1 1000 staff  287 Apr 18 22:45 package.json
-rw-r--r-- 1 1000 staff   64 Apr 18 22:45 s-project.json
-rw-r--r-- 1 1000 staff 1527 Apr 18 22:45 s-resources-cf.json
```

Your source code can go anywhere really...but what I'll do here is create a `lib` directory to hold
any library dependencies (which we'll use later) and a `src` directory which is where we'll put our
own source code.

```
root@c477313ae84f:/code/serverless-demo# mkdir lib
root@c477313ae84f:/code/serverless-demo# mkdir src
```

Now, we're ready to create our own Lambda function which will be a Python 2.7 function.

```
root@c477313ae84f:/code/serverless-demo# sls function create src/hello
Serverless: Please, select a runtime for this new Function
    nodejs4.3
  > python2.7
    nodejs (v0.10, soon to be deprecated)
Serverless: For this new Function, would you like to create an Endpoint, Event, or just the
Function?
  > Create Endpoint
    Create Event
    Just the Function...
Serverless: Successfully created function: "src/hello"  
```

The last question isn't quite intuitive. What exactly is serverless asking you?

- `Create Endpoint`: Will create *both* an API Gateway endpoint plus the Lambda function
- `Create Event`: Will create *just* the API Gateway endpoint 
- `Just the Function...`: Will create *just* the Lambda function

Now, we have some Python code:

```
root@c477313ae84f:/code/serverless-demo# ls -l src/hello/
total 12
-rw-r--r-- 1 1000 staff    2 Apr 18 22:53 event.json
-rw-r--r-- 1 1000 staff  226 Apr 18 22:53 handler.py
-rw-r--r-- 1 1000 staff 1198 Apr 18 22:53 s-function.json
```

You can inspect the code or just trust me when I say that all it does at this point is log the
API Gateway event using normal Python `logging.debug`.  As simple as this is, we can deploy this
code and start calling it right away. Here, we want to deploy *both* the endpoint and function
since neither have been deployed yet.

```
root@c477313ae84f:/code/serverless-demo# sls dash deploy
Serverless: Select the assets you wish to deploy:
    hello
      function - hello
      endpoint - hello - GET
    - - - - -
  > Deploy
    Cancel
Serverless: Deploying the specified functions in "dev" to the following regions: us-west-2  
Serverless: ------------------------  
Serverless: Successfully deployed the following functions in "dev" to the following regions:   
Serverless: us-west-2 ------------------------  
Serverless:   hello (serverless-demo-hello):
arn:aws:lambda:us-west-2:123874195435:function:serverless-demo-hello:dev  

Serverless: Deploying endpoints in "dev" to the following regions: us-west-2  
Serverless: Successfully deployed endpoints in "dev" to the following regions:  
Serverless: us-west-2 ------------------------  
Serverless:   GET - hello - https://bx12nlel0f.execute-api.us-west-2.amazonaws.com/dev/hello  
```

With that we get a URL...let's test it out:

```
brianz@bz-cconline(master=)$ curl -vv https://bx12nlel0f.execute-api.us-west-2.amazonaws.com/dev/hello
*   Trying 54.230.7.130...
* Connected to bx12nlel0f.execute-api.us-west-2.amazonaws.com (54.230.7.130) port 443 (#0)
* TLS 1.2 connection using TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256
* Server certificate: *.execute-api.us-west-2.amazonaws.com
* Server certificate: Symantec Class 3 Secure Server CA - G4
* Server certificate: VeriSign Class 3 Public Primary Certification Authority - G5
> GET /dev/hello HTTP/1.1
> Host: bx12nlel0f.execute-api.us-west-2.amazonaws.com
> User-Agent: curl/7.43.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< Content-Type: application/json;charset=UTF-8
< Content-Length: 2
< Connection: keep-alive
< Date: Mon, 18 Apr 2016 23:03:03 GMT
< x-amzn-RequestId: b4670e7e-05b9-11e6-9c54-6f4c3501e39b
< X-Cache: Miss from cloudfront
< Via: 1.1 4bbcb79375d11f12fb83e17cf9cb2749.cloudfront.net (CloudFront)
< X-Amz-Cf-Id: scxP8tMtlxIh1N6XrYvDa9eaZPrMXMcY37Xfk3XX2mx6pFeoavX7vQ==
< 
* Connection #0 to host bx12nlel0f.execute-api.us-west-2.amazonaws.com left intact
{}
```

You can see that it just returns a blank/empty json object, but hot damed, it worked! 
