+++
date = "2017-07-21T23:09:49-06:00"
draft = false
title = "Structuring Serverless Applications with Python"
tags = [
    "docker",
    "python",
    "serverless",
]

+++

In spite of [my intentions to get more involved in Elixir]({{< ref "/post/elixir-for-pythonistas-i.md" >}}) 
I've been stuck in the Python tractor beam.  
For all of the issues that may arise in large Python web applications, Python really is a fantastic
do-it-all language.  As one of my colleagues recently said: 

> Python is the second best language for _everything_.

I'm still a very big fan of the [Serverless](https://serverless.com) framework and have been using it
almost constantly at [work](https://verypossible.com).  So far, I've written fairly substantial
Serverless systems for a variety of projects:

- ETL jobs synchronizing Shopify orders with 3rd party fulfillment centers
- Data pipeline / ETL process for Strava data
- REST APIs
- Alexa skill

There is a pattern which I've come up with that has been working out quite well, which is the
subject of this post.

## The problems

There are two main problems with Python code on Lambda which stem from including extra packages in
your project. In the real world, you are very likely going to want or need some packages beyond the
standard library.

1. Python packages which have `C` bindings need to be built using a machine with the same
architecture as that which Lambda functions run (i.e., Linux).
2. With Lambda, you are responsible for managing Python's path so it can find your dependencies.

I'll walk through my setup and discuss how these problems are solved.


## The solutions

1. Docker
2. Add 4 lines of code at the top of `handler.py` to add a directory to your `sys.path`


## Docker

In this setup, we're using Docker as a utility.  The Docker image
I'm using is the official Python 2 image with the Serverless framework installed globally.  
This image is [on Docker hub](https://hub.docker.com/r/verypossible/serverless/) and is maintained
by me, updated whenever there is a new version of Serverless. You can see the
[Dockerfile](https://github.com/verypossible/serverless/blob/master/Dockerfile) as well since it's all
open source.

If you're running Linux on your host system, you won't need to deal with this at all.
Rather, this tip is for the OS X and Windows folks out there.

## Structure

I structure all my Serverless project as so:

```shell
├── Makefile
├── envs
│   └── dev
├── requirements.txt
└── serverless
    ├── handler.py
    ├── lib
    └── serverless.yml
```

The important bits:

- Makefile is used as a controller to lessen the burden of remembering a bunch of commands and to
  allow you to type less.  We'll go through this in more detail.
- `envs` will hold one or more environment variable files.  You may have different files in here
  for your different stacks...`dev`, `test`, `production`.  This allows us to easily switch between
  environments.
- `requirements.txt` should be self explanatory
- `serverless` is the root of your serverless project

## Makefile and envs

It may be better to show and example of what's needed to deploy a new stack.  Using the `Makefile`
I can simply do:

	$ ENV=dev make shell
	docker run --rm -it -v `pwd`:/code --env ENV=dev --env-file envs/dev --name=supersecret-serverless-dev "verypossible/serverless:1.17" bash
	root@f513331941bc:/code# 
	root@f513331941bc:/code# make deploy

Breaking that down:

`ENV=dev make shell` launches the container with the variable `ENV` set to `dev`.  The value 
for this variable needs to map to a file in your `envs` directory. Provided you are getting
configuration from the environment in your Python code (and you should be) this makes is trivial to
change the stack which you're working with.

Imagine you also have `envs/test` and `envs/production` files which hold key-value pairs for
configuration.  In order to launch your `test` stack you would do:

	$ ENV=test make shell

How is this working?  The baseline `Makefile` is shown below.  You will see a command called `run`
which is executed using the `ENV` variable when the `make shell` is called. Using the docker
`--env-file` argument, we inject those variables into the Docker container.

	NAME = "verypossible/serverless:1.17"

	ENVDIR=envs
	LIBS_DIR=serverless/lib
	PROJECT=supersecret

	.PHONY:	clean \
		deploy \
		env-dir \
		shell \
		test \
		test-watch \
		libs

	run = docker run --rm -it \
			-v `pwd`:/code \
			--env ENV=$(ENV) \
			--env-file envs/$2 \
			--name=$(PROJECT)-serverless-$(ENV) $(NAME) $1

	shell : check-env env-dir
		$(call run,bash,$(ENV))

	env-dir :
		@test -d $(ENVDIR) || mkdir -p $(ENVDIR)

	clean :
		@test -d $(LIBS_DIR) || mkdir -p $(LIBS_DIR)
		rm -rf $(LIBS_DIR)/*

	# make libs should be run from inside the container
	libs :
		@test -d $(LIBS_DIR) || mkdir -p $(LIBS_DIR)
		pip install -t $(LIBS_DIR) -r requirements.txt
		rm -rf $(LIBS_DIR)/*.dist-info
		find $(LIBS_DIR) -name '*.pyc' | xargs rm
		find $(LIBS_DIR) -name tests | xargs rm -rf

	# NOTE:
	#
	# 	Deployments assume you are already running inside the docker container
	#
	deploy : check-env
		cd serverless && sls deploy -s $(ENV)

	# Note the ifndef must be unindented
	check-env:
	ifndef ENV
		$(error ENV is undefined)
	endif

I should note that in order to deploy your serverless project you will need AWS credentials.  Each
`envs` file you create will need to have the following:

    AWS_DEFAULT_REGION=us-west-2
    AWS_SECRET_ACCESS_KEY=ASFASDFASFASFASFDSADF
    AWS_ACCESS_KEY_ID=1234ABCDEF

**`envs` should be in your `.gitignore`** You really don't want to be committing sensitive
variables into source control...so please ensure you have added `envs` into your `.gitignore`.

Now that we have a bash shell open in our container, the deployment is simply `make deploy`.
Looking above you can see there isn't much magic there.  The only trick is that we're taking the
value for `ENV` (which also gets injected as a variable into the container) and us that as the
Serverless `stage` using the `-s` argument. With that, you can now work on completely separate
stacks using the exact same code.


## Libraries

Now that the hard work it out of the way we're all clear to install some libraries. Common
libraries which have `C` bindings that you may want to use are `psycopg2`, `python-mysql`, `yaml`, and all
or most of the data science packages (`numpy`, etc.).

Add whatever you need into `requirements.txt`. From **within the container** in the same directory
as the `Makefile` (which happens to be `/code` run:

	root@f513331941bc:/code# make libs

Looking at the `Makefile` you'll see again there isn't much magic to this. The key here is that we
are building our `C` bindings _on the same architecture that Lambda uses to run your functions_,
that is, Linux.

If you shut down your container you will notice that your `libs` directory is still there. This is
nice and on purpose...using the `-v` (volume) argument to `docker run` we're able to map our host's
directory into the container.  Any packages we install will be built from within the Linux
container but will ultimately be written to our host's file-system. You'll only need to `make libs`
when you add or update your `requirements.txt` files.  There is also a `make clean` command which can be
used to start over.

## handler.py

Now that we have all of our libraries we need to tell our Python code how to find them.  At the top of 
`handler.py`, I _always_ have these first four lines of code (two imports + two lines to deal with
`sys.path`):

    # begin magic four lines
    import os
    import sys

    CWD = os.path.dirname(os.path.realpath(__file__))
    sys.path.insert(0, os.path.join(CWD, "lib"))
    # end magic four lines

    # now it's ok to import extra libraries
    import numpy as np

    def handler(event, context):
        pass

Another very useful convention I've come to settle on is using a single `handler.py` function as the
entrypoint for all of my functions.  The handler does nothing more than the basic bootstrapping of
the path, importing my own modules and handing off the work to those other modules.  In the end,
the file structure looks something like this:

    $ tree -L 2
    .
    ├── Dockerfile
    ├── Makefile
    ├── envs
    │   ├── dev
    │   └── production
    ├── requirements.txt
    ├── serverless
    │   ├── handler.py
    │   ├── lib
    │   ├── serverless.yml
    │   └── very
    │       ├── aws.py
    │       ├── constants.py
    │       └── feed.py
    └── tests
        ├── __init__.py
        ├── conftest.py
        ├── test_aws.py
        └── test_feed.py

`handler.py` will import my other modules which happen to be inside the `very` directory in this
example and rely on them to execute my business logic. Using convention you can be sure that the
system path is already set up so that importing your extra modules will work as you'd expect,
_without_ needing to alter the path again.


## Conclusion

Docker along with this `Makefile` make is extremely easy to manage different deployments of your Serverless 
stack and facilitate quickly iterating on your code.
Still, there are a few gotchas which take a little time to learn and master.  Organizing my
Serverless projects like this has saved
me quite a bit of time. I can spin up a new project in a matter of minutes and deploy code changes
within seconds, all while keeping my host system clean and free of any installations of the
Serverless framework.  Changing versions of Serverless is a one-line change in the `Makefile`.

If you try this out and it works or you see some improvments please let me know!
