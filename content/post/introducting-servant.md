+++
date = "2016-04-04T17:26:23-06:00"
draft = false
tags = [
    "python",
    "architecture"
]
title = "Introducing servant"

+++

Late in 2014 we began the process of discussing a payment system at
[work](http://www.clearcareonline.com). The system was to have a fairly simple reason for
existing...to do all the work needed to charge credit cards on behalf of our customers.

Backing up a bit...our system is mainly a B2B application. Home care agencies all over the country
run our SAAS application which helps them to run their businesses. Our new Payment System was aimed at allowing
our customers to charge *their* customers' credit cards directly, meaning our customers don't need
to wait for checks or paper invoicing. Our SAAS is a pretty typical Python stack with the **major**
components being:

- monolithic Django app
- Postgres
- Elasticsearch
- Redis
- Celery/RabbitMQ

For us it was pretty clear that we wanted to build this as a stand-alone service and stick with
Python. Yeah...we wanted a *microservice* which is all the rage now. We knew that we needed to
start evolving our architecture and services, while having their own sets of challenges, make a lot
of sense. In late 2014 the issue was that there really wasn't (and still aren't) many existing and
proven frameworks for building services in Python.

## Enter servant

Leaning on a custom service framework I had worked with while at
[Eventbrite](http://eventbrite.com) I came up with servant. You can see the project page on Github.
We currently have multiple services deployed in production at Clearcare based on servant and so
far, they've been working great:

https://github.com/clearcare/servant

What exactly is this library? At a very high level servant is:

- a Python library/framework for authoring and communicating with services
- to services what Django/Flask/Rails are to web applications
- designed primarily for *internal* non-publicly facing services

Servant is actually pretty simple and doesn't perform much magic.  What it does do 
is give you, the service author, a framework for designing RPC-style services in Python which
can run on their own, independently, and are easy to connect to and interface with. In addition,
it's not an opinionated framework so you can choose whatever tooling you'd like in order to author
your service. Our typical recipe at work includes pytest for testing and sqlalchemy for talking to
the Postgres. However, you use whatever you want depending on your needs...servant stays out of
your way and deals with executing service calls on behalf of the client. There is some validation
here and there to ensure the service call is well-formed but I won't go over that right now.

## Quick code examples

When I first started using services I had no idea what looked like both authoring a service or
talking to a service. If you have never worked with a service framework you may think it's a matter
of writing or talking to a REST endpoint. Servant is a bit different...so here are a few small code
snippets which should make things more clear.

In this example, we'll create a silly little "Calculator Service". I'll implement an `add` endpoint
which will take two numbers, add them up and return the sum.

### Client

As a client, the only dependencies is having the servant library installed. You could call this
from a Django app, one-off script...wherever. Install servant from github. Here I install it into a
virtualenv using virtualenvwrapper:

```
brianz@gold$ mkvirtualenv test_servant

(test_servant)brianz@gold$ pip install git+https://github.com/clearcare/servant.git@master
```

Now, I can write some client code:

```
# test_add.py
import servant.client

client = servant.client.Client('calculator_service', version=1)

# add is the actual endpoint we're calling
response = client.add(number1=10, number2=15)

if response.is_error():
    print response.errors, response.field_errors
else:
    print response.result
```

That's about it for client code! Provided you have a service named `calculator_service` available,
this code will work and spit out the expected result of `25`. You can actually install
`calculator_service` yourself and run this code.

```
(test_servant)brianz@gold$ cd servant/examples/calculator_service/
(test_servant)brianz@gold$ pip install .
```


```
(test_servant)brianz@bz-cconline$ python test_calculator.py 
25
```

That's how you actually *use* a servant service. How do you author one?

### Server

Authoring a service is a bit more work but still quite easy. This is how you'd implement the `add`
method we used above. Note you can also [peruse the
`calculator_service`](https://github.com/clearcare/servant/tree/master/examples/calculator_service)
to see a more thorough implemenation..but the below code will actually work.

First, you need to define a single `service.py` file which defines your service and declares all
its endpoints:

```
# service.py
from servant.service.base import Service

import actions

class Calculator(Service):

    name = 'calculator_service'
    version = 1 

    action_map = { 
            'add': actions.AddAction,
            # we won't implement subtract now
            # 'subtract': actions.SubtractAction,
    }
```

Next, you'll need to create one or more actions. Note above we import `actions` and point to two
different action classes...we'll only show one here for brevity. But, how you map endpoint
names to actions is entirely up to you. We always have an `actions/` directory with different
actions broken up by area of responsibility. Again, for brevity we'll just show a single action for
our calculator service.

```
# actions.py
import servant.fields
from servant.service.actions import Action

class AddAction(Action):
    number1 = servant.fields.IntField(
            required=True,
            in_response=True,
    )   
    number2 = servant.fields.IntField(
            required=True,
            in_response=True,
    )   
    result = servant.fields.IntField(
            in_response=True,
    )   

    def run(self, **kwargs):
        self.result = self.number1 + self.number2
```

If you ignore `setup.py` and any other packaging code or files, our actual service is only a few
files:

```
(test_servant)brianz@gold$ tree
├── __init__.py
├── actions.py
└── service.py
```

You can imagine what `SubtractAction` would look like. From there, provided you
can install your service as a Python package, this code is fully functional. You can see all of
this and actually give it a try...clone the repo and look in
the [the examples directory](https://github.com/clearcare/servant/tree/master/examples/calculator_service).


## Local library mode

One killer feature IMO which I have only seen in Eventbrite's SOA library is that of local mode.
You'll notice in all of the code above, there is no mention or reference to where the service is
running. You didn't event start a server. Where is the client connecting? How does the client code
know where to connect? What port is the server running on?

When you author a service and are able to install it as a Python package, you can talk to it just
as if it were running on a remote system. The magic here is that the servant client code imports
your service and executes it as a local library.  When you're ready to deploy your service
somewhere else and point your clients to the *real* server, it's a one line change:

```
import servant.client

client = servant.client.Client('calculator_service', version=1)
# Now point your client to the remote host
client.configure('remote-host-name-or-ip')
```

The big advantage to this is that it's trivially easy to start developing and testing your service.
Unit testing is *really* easy.  The code which gets executed is almost exactly the same. Of course,
running on a real server rather than as a local library cannot be *identical*, but it's quite close
and any differences are definitely worth the increase in productivity.


## Why servant?

> This is dumb, REST rules!

Hey, we (mostly) all like REST...it's great, but has some limitations:

- HTTP  by definition
- Requires a running server
- Usually end up using a wrapper library
- Various interpretations
- Can be challenging to get your Resources right

Being a RPC-style library, with servant:

- Transport/broker can be anything (library call, HTTP, Redis, ØMQ, RabbitMQ...)
- Develop quickly with local library mode
- RPC endpoints can be more descriptive...no need to interpret PUT vs POST
- ONE way of implementing a service vs. author's interpretation of REST

In terms of the transport, we currently have implementations for local mode and HTTP mode. If you
look at the
[README](https://github.com/clearcare/servant/blob/master/examples/calculator_service/README.md)
you'll see example of how to run the demo via `uwsgi`.

## Trade offs

As with any technology there are trade-offs. Here are a few issues with servant today:

- Currently Python only. Other languages would need a Servant library implemented.
- No mechanism for exploration...need knowledge of service before hitting it
- Can't simply use curl to hit an endpoint
- Need another layer to expose a service publicly (i.e., hitting from JavaScript)

## Closing thoughts

Servant has served us quite well at work and I really would like to keep iterating on it. It's open
source, so if you're interested clone the repo and give it a try. I haven't looked at the current
landscape for service libraries in Python in a while but know that others are popping up here and
there. Still, I do know that there aren't any really big libraries that the community if flocking
to when starting their journey into a microservice architecture. From what I can tell people mostly
reach for a REST or REST-like design when building services.

In a future post I'll go into some more detail about servant and some ideas that I've had but
haven't been implemented yet.
