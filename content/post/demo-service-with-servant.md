+++
date = "2016-08-08T16:14:32-06:00"
draft = true
tags = [
    "python",
    "architecture",
    "microservices",
    "servant",
]
title = "Demo service with Servant"

+++

In a <a href="{{< ref "introducing-servant.md" >}}">previous post</a> I introduced and discussed
about an open source library I authored called Servant. Servant is a framework for building
RPC-style services with Python. Servant is to services as Django or Rails is to web
applications...it's framework you'd use when you need to build a service in Python.

I'll go a bit deeper in this post and show what it's like to actually author and use a service.
Let's first start by writing the service.  To save some time we'll take a look at the <a
href="https://github.com/brianz/servant/tree/master/examples/calculator_service">`calculator_service`</a>
which is in the `examples` directory in the Servant repository.

## Writing the service

### Boilerplate

There are a few requirements to write a service.  I'll start with the boring parts which is mostly
boilerplate to get your service setup as an install-able Python package. I also suggest looking at
the directory structure for the demo `calculator_service` on Github:

https://github.com/brianz/servant/tree/master/examples/calculator_service

At a bare minimum you'll need a `setup.py` file and a directory with the correct name.  In this
example, the name is `calculator_service`.

{{< gist brianz eab945699d396a5656e355e8f1264562 >}}

From there you'll also need a directory where your source code will live.

### Service

Every Servant service needs an entry-point to device the endpoints which will be exposed. This is
pretty simple...create a file names `service.py` which contains a class that subclasses
`servant.service.base.Service`

{{< gist brianz 7addb2cf37a6cadda3d15fd6c623bf21 >}}

Your service class will only need a few things:

- `name` attribute
- `version` attribute (use `1` when getting started)
- `action_map` which is a dictionary mapping endpoint name to an `Action` class

That's really it...of course there are more things you can do in your service class to handle
configuration, etc. However, this is the minimum amount of work you'll need to do in order to get
started.

In our example you can see our `calculator_service` exposed three calculate endpoints...`add`,
`subtract` and `divide`.  These will do what you'd expect.

### Actions

An `Action` is really the meat and potatoes for a particular endpoint. You can organize your
actions however you like...one action per file, multiple actions per file, etc.  Since we're
writing a pretty simple service and only have three actions, we'll put them all in `actions.py`.

{{< gist brianz 91b2a58709d569443aab5b98aaa38e0b >}}

Let's walk through what it takes to implement a single action (or, an "endpoint" from the client's
perspective).  Looking at `AddAction` we can see that there are two required inputs...`number1` and
`number2`. I liken the structure of a servant `Action` to a Django, SQLAlchemy or other type of
model.  You'll need to subclass `servant.service.actions.Action` and usually define one or more
inputs as class attributes which are servant `field` types.

In `AddAction` we ensure that the client passes us `number1` and `number2` by adding
`required=True` to the field's kwargs. This instructs servant to return an error in the case that
the client doesn't pass either of these. Out of the box we get some error checking for free which
is quite nice.  From there it's also your responsibility as the developer to device the return type
which the client will get back after a successful call.  Here, we'll return a single integer using
an `IntField` field type which is named `result`.

Your entry point into an action is the `run` method.  You can see above what it does...it's simple
one-liner.  By the time your `run` method is being executed the basic error checking has completed
and all of the required and optional fields will be available to you as class attributes.  So, our
`run` method simple sets the result using the two inputs we received from the client:

```
def run(self, **kwargs):
    self.result = self.number1 + self.number2
```

The `run` method doesn't need to return anything...all return data is handled via the field
attributes.

If you read the rest of the gist above you can see how the subtract and divide actions are
implemented. Being a calculator, there really isn't much to it.  You'll notice that the subtract
action subclassed the add action and just overrides the `run` method.  The `divide` action mostly
just changes the names of the inputs and output.

## Using the service

One neat feature of Servant is the ability to run your service as a locally installed Python
library.

Let's install both Servant and the calculator service into a new virtualenv:

```
$ cd path/to/servant
$ mkvirtualenv calculator_service
$ pip install -e .
$ cd examples/calculator_service
$ pip install -e .
```

Now that we have these installed, we can actually test our service!

```
import servant.client

client = servant.client.Client('calculator_service', version=1)

response = client.add(number1=10, number2=15)

if response.is_error():
    print response.errors, response.field_errors
else:
    print response.result
```

When we run this, we get our expected result of `25`.

Now, how do we run this on a separate host so that we're actually a stand-alone service?  Quite
easy...first we'll setup a `wsgi` server using `uwsgi`. We need two files...one is a 3-line python
file which is the entry-point for the service.  The other is a very short `uwsgi` config file.
Servant has built-in support for running as a wsgi server so `wsgi_handler.py` is quite short:

{{< gist brianz f74825460c85c5b5f59255d644a2576a >}}

Now, fire up uwsgi: `uwsgi uwsgi.ini`

uwsgi is now ready to serve requests on port 8888...we can run the *exact* same client code as
above.  You'll note that the client code above *only* depends on the `servant` library. Really, the
only reference to the `calculator_service` is when we instantiate the `Client` class.  There is
only one change we need to make to the client code above to hit a remote system:

```
client.configure('http', host='192.168.88.100', port=8888)
```

We're configuring our client to connect via `http` to the given host and port.  Once that single
line is added we can run the client and get the exact same results.

I believe the power of being able to develop a service and run it locally like this and deploy it
remotely with only a single line changing for the client is immensely powerful. Admittedly, when
using Docker standing up a server is pretty easy, but being able to run service code without
depending on a server is still quite valuable. Another big advantage is that it's possible to
actually pip install your service package with your client application and not depend on a remote
system staying up. The advantage is by pip installing a service is that you're able to deploy a
service much faster and iterate simply by pip installing...when it's time to migrate it's just a
matter of a minor change to your client code to point to the remote host.
