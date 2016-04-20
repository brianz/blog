+++
date = "2016-04-20T16:08:07-06:00"
draft = false
tags = [
    'aws',
    'architecture',
    'serverless'
]
title = "Serverless part I"

+++

It's a pretty exciting (and challenging) time to build software-based applications. Every week
there are more and more tools to make our jobs easier or to enable us to focus on *application*
development rather than dealing with the infrastructure around those applications. Of course, this
makes our jobs challenging since we need to keep up with the innovation.

This will be part one of a multi-part series about "serverless" architecture/design. I hesitate to
call this "architecture" but it's definitely a way of doing things both from an infrastructure (or
lack of) side and code organization. The possibility of running web applications without any servers
has become a reality fairly recently and kicked off multiple projects around this idea.
What I'd like to do in Part I is to simply give an intro to "serverless" and talk through some moving parts.

The big question, what is serverless?

> Serverless is a way to author a HTTP service using [AWS API
> Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html) and 
> [AWS Lambda] (https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) which
> eliminates the need to manage or maintain any running servers or EC2 instances. Any servers used to
> process HTTP requests are managed by AWS and never exposed to you as the application developer. 

As a point of clarification, there is a project named Serverless. I'll try to differentiate the
*term* "serverless" from the *project* Serverless by capitalizing the project.

## API Gateway

In July of 2015 [AWS released API
Gateway](https://aws.amazon.com/blogs/aws/amazon-api-gateway-build-and-run-scalable-application-backends/)
which is a service to create and manage public API
endpoints on your behalf. Gateway is comprised of two services really:

- control service to expose a REST endpoint
- execution service to run some code or backend system

There's much more to it of course so I encourage you to [read the docs from
AWS](http://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html). For the purpose of
this post we don't need to go into a *ton* of detail around API Gateway...just imagine that you can
click a few buttons (or make some AWS API calls) and wind up with a URL that you can immediately start
hitting with `curl` without setting up or managing EC2 instances. This is the first step in the
world of "serverless"...getting a pubic HTTP endpoint without managing any servers.

*Without* API Gateway standing up a webserver which does something as simple as returning and empty
response in response to a query to a public URL is quite an endeavor:

- spin up a cloud server
- install a webserver like nginx
- (optionally) pointing DNS at your cloud server

Even if you're skilled at this, it's going to take several minutes. With API Gateway you can
literally accomplish the same thing in 30 seconds. Not only that, you'll be paying every minute
that your EC2 instance is running, regardless of the load. With API Gateway you pay per call.

## Lambda

So what is Lambda? [From Amazon](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html):

> AWS Lambda is a compute service where you can upload your code to AWS Lambda and the service can
> run the code on your behalf using AWS infrastructure.

What does that mean *exactly*?  Well, with Lambda you can 

- author code in Java, Python or JavaScript/Node
- package your code in a zip file
- upload it to the Lambda service
- tell amazon to run your code

What exactly can your code actually *do* though?  Again, this is mostly up to you. While there are
some constraints you need to abide by (mostly around execution time and memory) you can do almost
anything. Provided your code has access to any supporting libraries it needs, AWS will take care of
the runtime. Your code is executed based on some trigger and once it's done, poof! There are no
running servers (which you need to manage) which allows you to focus on your code.

When it's being executed, AWS will magically unpack your code, run it and then be done with it until the next time
it's run. There are several beautiful things about this:

- No servers to maintain
- Pay by execution time...no wasted cycles
- Ability to execute a Lambda from various triggers


## API Gateway + Lambda == Serverless

The confluence of API Gateway and Lambda is what serverless is all about. Above I described how
easy it is to build a public URL which doesn't do anything. That's not interesting at all, but
becomes interesting when you can have that API call trigger a Lambda function. Gateway actually
supports different execution services:

- HTTP proxy
- Mock integration
- AWS Service Proxy
- Lambda function

I'm not going to talk about the first three...we're really interested in having API Gateway execute
a Lambda function on our behalf.  This is the foundation of serverless....API Gateway calls your custom
Lambda function.  Your Lambda function can do whatever you can come up with and provide a response
which is returned to the caller of your HTTP endpoint.  Your Lambda function could:

- fetch data from a database
- write data to a database
- kick off some processes with Kinesis
- anything you manage to accomplish with Lambda

The power of this may or may not have hit you, but here it is: if you can write all of your application code as Lambda
functions you have now created a **completely serverless REST API**.

Let's drill in on this. Imagine making a HTTP call, getting a response
and not having to manage a single EC2 instance (or any other type of server). Furthermore, that
single call cost a fraction of a penny. If you look at the [pricing for
Lambda](https://aws.amazon.com/lambda/pricing/) and [pricing for
Gateway](https://aws.amazon.com/api-gateway/pricing/) you'll get a feel for how cheap this can be.

## Serverless project

One of my big questions was how this fits into the normal development cycle. Sure, this is
**super** powerful, but how do I actually *use* it in the real world. Other folks are realizing the
power of these systems and as usual, tooling is being built up around the AWS services.

One of the more popular projects and one which I was referred to by the AWS folks is
http://serverless.com. There area
others...here's one to run [Django via Gateway/Lambda](https://github.com/Miserlou/django-zappa)
and yet another one [doing the same thing with Flask](https://github.com/Miserlou/flask-zappa). I'm
sure there are other...Google ``"serverless fill-in-the-blank"`` and you'll undoubtedly find something
interesting.

In my initial testing the Serverless project is pretty nice. Since its main job is to wrap API
calls to API Gateway and Lambda you'll need to understand those two services on your own before you
can start building things with Serverless. In my experience that's pretty much always the case with
any tool that wraps AWS services.

That's the high level introduction to what serverless is all about. In Part II I'll do a walk
through of the Serverless project and show some real-world examples of how to build something. Stay
tuned!
