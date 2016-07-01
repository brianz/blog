+++
date = "2016-06-29T16:27:48-06:00"
draft = true
title = "Serverless part IV"
tags = [
    'aws',
    'architecture',
    'serverless'
]

+++

Welcome to part four in my series about [Serverless](http://serverless.com). As a reminder, there
are now three other parts you can read if you aren't coming here from those posts already:

- [Serverless Part I]({{< ref "serverless-part-i.md" >}}) 
- [Serverless Part II]({{< ref "serverless-part-ii.md" >}})
- [Serverless Part III]({{< ref "serverless-part-iii.md" >}})

In the previous posts I worked through some of the basics of Serverless and stood up an API
endpoint which returned HTML.  Now I'd like to start working through some more real-world examples
and talk through some warts I've found with Serverless.  Of course, no project is
perfect...Serverless is still quite new and the team behind it is making great progress.  As of
this writing there are a few stumbling blocks which can be solved but are not quite as easy as they
could be. I think the Serverless team is aware of the shortcomings since they've openly discussed
these in their push towards v1.0. Only a few days ago [they announce a beta version of
1.0](http://blog.serverless.com/serverless-v1-0-alpha1-announcement/) which I have yet to try out.

In any case, as long as you're aware of the issues in v0.5.5 which is what is currently stable you
should have no trouble working around them. With v1.0 being not too far away I suspect very soon
I'll start writing about that system since it appears to be much improved and fundamentally
different in the way it organizing things.

So, what we'll discuss here is:

- Syncing sensitive AWS data with the `meta sync` plugin
- Working on an existing project after a `git clone`
- Creating a new API endpoint and function

## Syncing with the `meta sync` plugin

One issue you will quickly run in to when either working on a project with someone else *or*
working on your own project on different computers is that of the `_meta` directory. If you [look at
the repository for this demo project](https://github.com/brianz/serverless-demo)
you'll notice there isn't a `_meta` directory. The reason is
that this directory stores (potentially) sensitive information about your project such as private keys, etc.
By default, Serverless will [add `_meta` to the `.gitignore` of your
project](https://github.com/brianz/serverless-demo/blob/part-ii/serverless-demo/.gitignore#L43).
Not only that, different "environments" (or "stages" in the world of Lambda) will undoubtedly have
different configuration settings at some point. Imagine an endpoint which needs to talk to DynamoDB
or an SNS topic. Serverless allows us to reference things like this with environment variables
which are injected at deploy time through some `_meta` files 
(see [part III]({{< ref "serverless-part-iii.md" >}}) to learn about variables).

What this means is that when you `git clone` a repository Serverless won't have a clue what to do
with it.  Any `sls` command you issue will result in an error since Serverless doesn't know what
resources to work with.  **This is one area where Serverless needs to improve.**  I find this part
quite clunky since there are multiple hoops to jump through in order to get a project running
after a simple `git clone`.

To start, you'll want to use a plugin which will sync your `_meta` folder to S3. All this does is give
you a way to (in effect) copy and paste the contents of `_meta` between computers in a secure
manner.  The caveat being that users or systems using this will both need to have read/write access
to the designated S3 bucket.  How you manage your AWS keys between systems is an entirely
different discussion which we won't talk about now (and is a question which I'm working out myself).

Setting up `meta sync` is pretty simple...the Github page gives you all the details you'll need:
https://github.com/serverless/serverless-meta-sync

Someone will need to initially set this up to actually put the `_meta` directory up in S3.  If
you're working between different systems and you're the sole developer it'll be pretty easy...if
you're working on a team the same instructions apply as long as your colleagues have access to the
S3 bucket.

Let's setup `meta sync`. To be crystal clear, this setup only needs to be performed *once* by the
original author of the project. After all, the `_meta` directory will be created when the project
is first brought to life, so it'll be the responsibility of that first developer to set this up:

```
root@1035dd7cffb6:/code# npm install serverless-meta-sync --save
```

Now that the plugin is installed I just need to update the `s-project.json` file:

```json
{
  "name": "serverless-demo",
  "custom": {
    "meta": {
      "name": "brianz-cco-serverless-test",
      "region": "us-west-2"
    }
  },
  "plugins": [
    "serverless-meta-sync"
  ]
}
```

All I'm doing is telling the plugin to sync the `_meta` directory to an S3 bucket named
`brianz-cco-serverless-test` in `us-west-2`.  Now that that's done, I issue the sync command...the
trick here is ensuring you *sync for all of your stages and regions*. That's easy to gloss over but
I'll pause here to reemphasize

> **If you have multiple stages for your project you'll need to issue multiple `sls
> meta sync` commands.**

From part iii of this series I created two stages...`dev` and
`production`. I authored that project on my laptop so I'll be doing the following on that computer:

```bash
root@5457e51bf687:/code# sls meta sync -s dev -r us-west-2
Serverless: Going to sync "s-variables-dev-uswest2.json"... 
Serverless: Creating remote copy of s-variables-dev-uswest2.json...  
Serverless: Done  
root@5457e51bf687:/code# sls meta sync -s production -r us-west-2
Serverless: Creating remote copy of s-variables-production-uswest2.json...  
Serverless: Done  
```

This is the first step in setting yourself up for development on multiple system.


## Setup a project after `git clone`

Now, I switch over to my iMac and clone the repo. You'd hope that you'd just be able to clone the
repo, install packages, `sync` the `_meta` folder and you'd be done.  You'd be wrong.

```
brianz@gold$ git clone https://github.com/brianz/serverless-demo.git
brianz@gold$ cd serverless-demo/
brianz@gold(master=)$ ls -l
total 32
-rw-r--r--  1 brianz  staff   182 May 19 09:53 Dockerfile
-rw-r--r--  1 brianz  staff  1081 May 19 09:53 LICENSE
-rwxr-xr-x  1 brianz  staff   174 May 19 09:53 Makefile
-rw-r--r--  1 brianz  staff   411 May 19 09:53 README.md
-rw-r--r--  1 brianz  staff    39 May 31 20:24 config
drwxr-xr-x  7 brianz  staff   238 May 31 20:17 serverless-demo/
brianz@gold(master=)$ cd serverless-demo/
brianz@gold(master=)$ ls -l
total 24
-rw-r--r--  1 brianz  staff   328 May 19 09:53 package.json
-rw-r--r--  1 brianz  staff   190 May 19 09:53 s-project.json
-rw-r--r--  1 brianz  staff  1527 May 19 09:53 s-resources-cf.json
drwxr-xr-x  3 brianz  staff   102 May 19 09:53 src
```

OK...this is what we expect.  There isn't a `_meta` folder. Let's start getting set up and see
what happens (as a reminder I'm in a Docker container when running `sls` aka `serverless`):

```
root@bcdeb57d5754:/code# sls meta sync  
/usr/local/lib/node_modules/serverless/node_modules/bluebird/js/release/async.js:61
        fn = function () { throw arg; };
                           ^

ServerlessError: This plugin could not be found: serverless-meta-sync
```

Doh!  We need to install the plugin which makes sense. Since we (or our colleague who setup the
project, aka me on my MBPro) performed an `npm install --save` of the plugin it'll be in our `package.json`. As with
any node/npm system all we'll need to do is `npm install`:

```
root@bcdeb57d5754:/code#  npm install
# snip...lots of output
npm info ok 
root@bcdeb57d5754:/code# 
```

Now that we have met all our requirements let's try to sync again:

```
root@bcdeb57d5754:/code# sls meta sync 
/usr/local/lib/node_modules/serverless/node_modules/bluebird/js/release/async.js:61
        fn = function () { throw arg; };
                           ^

ServerlessError: No existing stages in the project
```

Hrmmm....it's really not that simple. The root cause here is that Serverless still knows nothing of
our project.  Since Serverless works by keeping track of several files in the `_meta` directory it
doesn't even know what your project is about...what resource it needs, nada.  **Serverless should
really make this easier and more intuitive.**

> **After cloning a repo you will need to perform one or more `sls project init` commands**

While the meta-sync plugin will sync your variables files, there are some other files in the
`_meta` directory which aren't synced. In order to get that directory and some other non-variable
files bootstrapped and created you'll need to use `sls project init`. This can be confusing since
that same command is exactly what you'd use to setup a brand new project. Here, because we're
issuing the command in and *existing* project, Serverless will setup your `_meta` directory and
recreate a few files.

So let's do it.  Note, you can also pass command line arguments to
speed this up as needed.  Doing a `sls project init --help` will show you all of the options you
can use.

```
root@bcdeb57d5754:/code# sls project init
 _______                             __
|   _   .-----.----.--.--.-----.----|  .-----.-----.-----.
|   |___|  -__|   _|  |  |  -__|   _|  |  -__|__ --|__ --|
|____   |_____|__|  \___/|_____|__| |__|_____|_____|_____|
|   |   |             The Serverless Application Framework
|       |                           serverless.com, v0.5.5
`-------'

Serverless: Initializing Serverless Project...  
Serverless: Enter a new stage name for this project:  (dev) 
Serverless: For the "dev" stage, do you want to use an existing Amazon Web Services profile or
create a new one?
  > Existing Profile
    Create A New Profile
Serverless: Select a profile for your project: 
  > default
Serverless: Creating stage "dev"...  
Serverless: Select a new region for your stage: 
    us-east-1
  > us-west-2
    eu-west-1
    eu-central-1
    ap-northeast-1
Serverless: Creating region "us-west-2" in stage "dev"...  
Serverless: Deploying resources to stage "dev" in region "us-west-2" via Cloudformation (~3
minutes)...  
Serverless: No resource updates are to be performed.  
Serverless: Successfully created region "us-west-2" within stage "dev"  
Serverless: Successfully created stage "dev"  
Serverless: Successfully initialized project "serverless-demo"  
```

```bash
brianz@gold(master=)$ l
total 32
drwxr-xr-x   4 brianz  staff   136 Jun 28 16:58 _meta/
-rw-r--r--   1 brianz  staff    23 Jun 28 16:58 admin.env
drwxr-xr-x  20 brianz  staff   680 Jun 28 16:56 node_modules/
-rw-r--r--   1 brianz  staff   327 Jun 28 16:58 package.json
-rw-r--r--   1 brianz  staff   189 Jun 28 16:58 s-project.json
-rw-r--r--   1 brianz  staff  1527 Jun 28 16:58 s-resources-cf.json
drwxr-xr-x   3 brianz  staff   102 May 19 09:53 src/
```

Voila!  Our `_meta` directory is now available.  

At this point, if you inspect any of the `variables` files inside `_meta/` you'll see that they're
empty.  We're finally at the point where we can pull down our secret variables and config which we
previously synced using meta-sync.

```
root@bcdeb57d5754:/code# sls meta sync 
Serverless: WARNING: This variable is not defined: magicVariable  
Serverless: WARNING: This variable is not defined: region  
Serverless: WARNING: This variable is not defined: region  
Serverless: Going to sync "s-variables-dev.json"... 
  
 {
+  MY_MAGIC_VARIABLE: "dev"
 }

Serverless: How should these differences be handled?
    Review these changes one by one
  > Apply these changes to the local version
    Discard these changes and sync the remote version with the local one
    Cancel
Serverless: Done 
```

Excellent...it finally worked.  At this point we're all set to use the `dev` stage.  

```
root@bcdeb57d5754:/code# ls -l _meta/variables/
total 12
-rw-r--r-- 1 1000 staff 34 Jun 28 22:58 s-variables-common.json
-rw-r--r-- 1 1000 staff 27 Jun 28 22:58 s-variables-dev-uswest2.json
-rw-r--r-- 1 1000 staff 50 Jun 28 23:08 s-variables-dev.json
```

What's missing? Remember, we have a "production" stage with it's own variables. That stage's
variables file hasn't been pulled down after our `sync`.  **We
need to issue multiple `project init` and sync commands for different stages/regions!** This is
clunky, but at least we only need to do it once per stage:

```
root@bcdeb57d5754:/code# sls project init -s production
Serverless: Initializing Serverless Project...  
Serverless: For the "production" stage, do you want to use an existing Amazon Web Services profile
or create a new one?
  > Existing Profile
    Create A New Profile
Serverless: Select a profile for your project: 
  > default
Serverless: Creating stage "production"...  
Serverless: Select a new region for your stage: 
    us-east-1
  > us-west-2
    eu-west-1
    eu-central-1
    ap-northeast-1
Serverless: Creating region "us-west-2" in stage "production"...  
Serverless: Deploying resources to stage "production" in region "us-west-2" via Cloudformation (~3
minutes)...  
Serverless: No resource updates are to be performed.  
Serverless: Successfully created region "us-west-2" within stage "production"  
Serverless: Successfully created stage "production"  
Serverless: Successfully initialized project "serverless-demo"  
```

Now that we've `init'ed` the production stage we can finally sync it:

```
root@bcdeb57d5754:/code# sls meta sync -s production
Serverless: WARNING: This variable is not defined: magicVariable  
Serverless: WARNING: This variable is not defined: region  
Serverless: WARNING: This variable is not defined: region  
Serverless: Going to sync "s-variables-production.json"... 
  
 {
+  magicVariable: "Magic production thingie"
 }

Serverless: How should these differences be handled?
    Review these changes one by one
  > Apply these changes to the local version
    Discard these changes and sync the remote version with the local one
    Cancel
Serverless: Done  
```

Phew. In my opinion that's a lot of work to do just to get the project in a state where you can
start working on. I expect and hope this flow to get much easier in Serverless v1.0.


## Creating a new API endpoint

Now that we're set up on a new system let's start the process of creating a new function. A simple
`Hello world!` example is quite boring, so what I'll do is create a new endpoint which accepts a
`jwt` token in a `json` payload validates that it's correct.  To do this, we'll use a 3rd party
Python library and some of our own Python code. This will demonstrate a few things:

- how to package requirements
- how to deal with POST data

First we'll create the function and endpoint...this is a Python 2.7 function:

```
root@bcdeb57d5754:/code# sls function create src/authenticate -r python2.7
Serverless: For this new Function, would you like to create an Endpoint, Event, or just the
Function?
  > Create Endpoint
    Create Event
    Just the Function...
Serverless: Successfully created function: "src/authenticate"  
```

Now that the function and API endpoint are set up we'll actually need to write some some. Crack
open the `src/authenticate/handler.py` function if you're following along. You can also [look at
the final version on
Github](https://github.com/brianz/serverless-demo/blob/part-iiii/serverless-demo/src/authenticate/handler.py).

There are a few things to note in order to get non-trivial functions like this one working:

### Installing libraries

Since we're relying on a `jwt` library from a 3rd party we need to send that up to Lambda with our
own function. Serverless does the work of creating a zip file of your code and any supporting
code/libraries and uploading that to Lambda. With Python, we can "install" any supporting libraries
in a folder next to our application code.  In this example I'll use the `lib` directory. [If you
look at this repo on
Github](https://github.com/brianz/serverless-demo/tree/master/serverless-demo/src) you'll see a
`requirements.txt` file along with a little helper script to create and populate the `lib/`
directory.  Running this script will get the `lib/` directory bootstrapped...only after that is
done will you be able to move on to the next step.  *Without* the supporting libraries installed
and uploaded your function will throw an `ImportError` and not execute successfully.

### Path hacking

With our `lib/` directory successfully populated and uploaded with our application code we need
to make our application code/Lambda function aware that it exists.  Remember, this is just an
arbitrary directory with Python packages that we're uploading with our main Lambda function...our
Lambda function/handler has no way of knowing that it should look in this directory for any of its
dependencies.  

**Before** any imports to 3rd party packages we need to hack the system path ourselves:

```python
cwd = os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(cwd, "../lib"))

# now you can import jwt or anything else you install
```

Pretty simple...if you decide to change the name of your directory which holds your dependencies
you'll of course need to change your functions to reference that location.  Also, if you create a
function which is nested any deeper in the package structure you'll have to adjust the
`os.path.join` call...for example if you create a function in `authenticate/users/handler.py` that
function would then need to use `"../..lib" since it's two directories away from `lib/`.

### Packaging `lib/`

The last thing we need to take care of is instructing Serverless to package up our `lib/` directory
with our handler function. This is done by mangling the `handler` value in `s-function.json`. In
short, all you do it change the path to the handler which you're using. Originally the `handler`
value is a simple string, pointing to your handlerfile.handlerfunction like this:

```json
    "handler": "handler.handler",
```

Our change will add in one level to the path to that handler file:

```json
    "handler": "authenticate/handler.handler",
```

Serverless will notice this and then package up everything which sits alongside the `authenticate`
directory:

```bash
brianz@gold(master=)$ ls -l
total 16
drwxr-xr-x  5 brianz  staff  170 Jul  1 11:18 authenticate/
-rwxr-xr-x  1 brianz  staff   94 Jun 28 20:46 build-requirements.sh*
drwxr-xr-x  5 brianz  staff  170 Jun 20 16:18 hello/
drwxr-xr-x  4 brianz  staff  136 Jun 28 20:45 lib/
-rw-r--r--  1 brianz  staff   13 Jun 28 20:41 requirements.txt
```

Everything you see here will wind up in our final zip file.

### Extracting POST body

Finally, there's the work of extracting content from the actual `POST` body and sending it over to
the Lambda function.  This is handled by API Gateway.  Here's the change/addition in
`s-function.json`:

```json
  "requestTemplates": {
    "application/json": {
      "token": "$input.json('$.token')"
    }   
  }
```

This is one of the most confusing parts of API Gateway IMO. This ends up injecting a `token` field
into your Lambda `event` by extracting the `token` field from the expected json payload in the
`POST`.  Our Python function can then reference this:


```python
    token = event.get('token', '')
```

Phew! Let's try this out. Our JWT secret for signing our tokens is simply the string `"secret"`.
You can visit https://jwt.io and generate a new token and try it for yourself. My Lambda function
will simply decode the token and return the results if it's valid. If it's *not* valid the Lambda
function will raise an exception which will be returned to you:

Here's a valid token:


```bash curl -s -d '{"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImJyaWFueiIsIm9yaWdfaWF0IjoxNDY3MTMyMTgzLCJleHAiOjE3ODI3NTIzNzIsImVtYWlsIjoiYnJpYW56QGdtYWlsLmNvbSIsInNjb3BlcyI6WyJkZXZlbG9wZXIiLCJzZXJ2ZXJsZXNzLWZhbiJdfQ.tmbOyytr0vbNdaFL0wc31SIpWw8E_xqUIDoWsXYM2do"}' https://4m98c4l3i1.execute-api.us-west-2.amazonaws.com/dev/authenticate | python -mjson.tool
{
    "email": "brianz@gmail.com",
    "exp": 1782752372,
    "orig_iat": 1467132183,
    "scopes": [
        "developer",
        "serverless-fan"
    ],
    "username": "brianz"
}
```

Neat! Generated this token by plugging in some arbitrary data at the https://jwt.io playground. Note
that I pushed the `exp` (expires) field far in the future.

Let's try an invalid signature where the `exp` field is in the past:

```bash
curl -s -d '{"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImJyaWFueiIsIm9yaWdfaWF0IjoxNDY3MTMyMTgzLCJleHAiOjE0NjcyMTk2OTMsImVtYWlsIjoiYnJpYW56QGdtYWlsLmNvbSIsInNjb3BlcyI6WyJkZXZlbG9wZXIiLCJzZXJ2ZXJsZXNzLWZhbiJdfQ.A1UJOKcSfpUSuAgZoBO9g0oBtGdkrl71VtNt4F5eJZg"}' https://4m98c4l3i1.execute-api.us-west-2.amazonaws.com/dev/authenticate | python -mjson.tool
{
    "errorMessage": "Signature has expired",
    "errorType": "ExpiredSignatureError",
    "stackTrace": [
        [
            "/var/task/authenticate/handler.py",
            30,
            "handler",
            "decoded = jwt_decode_handler(token)"
        ],
        [
            "/var/task/authenticate/handler.py",
            21,
            "jwt_decode_handler",
            "return jwt.decode(token, JWT_SECRET_KEY)"
        ],
        [
            "/var/task/authenticate/../lib/jwt/api_jwt.py",
            75,
            "decode",
            "self._validate_claims(payload, merged_options, **kwargs)"
        ],
        [
            "/var/task/authenticate/../lib/jwt/api_jwt.py",
            104,
            "_validate_claims",
            "self._validate_exp(payload, now, leeway)"
        ],
        [
            "/var/task/authenticate/../lib/jwt/api_jwt.py",
            149,
            "_validate_exp",
            "raise ExpiredSignatureError('Signature has expired')"
        ]
    ]
}
```

Pretty cool. And how about a missing token?


```bash
curl -s -X POST https://4m98c4l3i1.execute-api.us-west-2.amazonaws.com/dev/authenticate | python -mjson.tool
{
    "errorMessage": "Mission token",
    "errorType": "Exception",
    "stackTrace": [
        [
            "/var/task/authenticate/handler.py",
            27,
            "handler",
            "raise Exception('Mission token')"
        ]
    ]
}
```

If you were doing this for real you'd want to handle failures more gracefully.  With API Gateway
you can match on certain responses to control HTTP return codes. Of course, you'd also want to hide
the details of the stack blowing up and instead return some nicer error messages.

That was a big post...hopefully this gives  you some idea on how to use Serverless for a *real*
application. I'll continue developing this series and I'm sure there will be updates as Serverless
v1.0 evolves!
