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

- [part I]({{< ref "serverless-part-i.md" >}}) 
- [part II]({{< ref "serverless-part-ii.md" >}})
- [part III]({{< ref "serverless-part-iii.md" >}})

In the previous posts I worked through some of the basics of Serverless and stood up an API
endpoint which returned HTML.  Now I'd like to start working through some more real-world examples
and talk through some warts I've found with Serverless.  Of course, not project is
perfect...Serverless is still quite new and the team behind it is making great progress.  As of
this writing there are a few stumbling blocks which can be solved but are not quite as easy as they
could be.  As long as you're aware of these issues they're fairly easy to work around.

So, what we'll disuss here is:

- Syncing sensitive AWS data with the `meta sync` plugin
- Working on an existing project after a `git clone`
- Creating a new API endpoint and function

## Syncing with the `meta sync` plugin

One issue you will quickly run in to when either working on a project with someone else *or*
working on your own project on different computers is that of the `_meta` directory. If you [look at
the repository for this demo project](https://github.com/brianz/serverless-demo)
you'll notice there isn't a `_meta` directory. The reason is
that this directory stores (potentially) sensitive information about your project such as private keys, etc.
Not only that, different "environments" or "stages" in the world of Lambda, will undoubtedly have
different configuration settings at some point. Imagine an endpoint which needs to talk to DynamoDB
or an SNS topic. Serverless allows us to reference things like this with environment variables
which are injected at deploy time through some `_meta` files 
(see [part III]({{< ref "serverless-part-iii.md" >}}) to learn about variables).
By default, Serverless will [add `_meta` to the `.gitignore` of your
project](https://github.com/brianz/serverless-demo/blob/part-ii/serverless-demo/.gitignore#L43).

What this means is that when you `git clone` a repository Serverless won't have a clue what to do
with it.  Any `sls` command you issue will result in an error since Serverless doesn't know what
resources to work with.  **This is one area where Serverless needs to improve.**  I find this part
quite clunkly since there are a few things to make a simple `git clone` actually work.

First, you'll want to use a plugin which will sync your `_meta` folder to S3. All this does is give
you a way to (in effect) copy and paste the contents of `_meta` between computers in a secure
manner.  The caveat being that users or systems using this will both need to have read/write access
to the S3 bucket which is configure.  How you manage your AWS keys between systems is an entirely
different discussion which we won't talk about (and a question which I'm working out myself).

Setting up `meta sync` is pretty simple...the github page give you all the details you'll need:
https://github.com/serverless/serverless-meta-sync

Someone will need to initially set this up to actually put the `_meta` directory up in S3.  If
you're working between different systems and you're the sole developer it'll be pretty easy...if
you're working on a team the same instructions apply as long as your colleagues have access to the
S3 bucket.

Let's setup `meta sync`:

```
root@1035dd7cffb6:/code# npm install serverless-meta-sync --save
```

Now that the plugin is installed I just need to update the project file:

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
I'll reiterate...if you have multiple stages for your project you'll need to issue multiple `sls
meta sync` commands.  From part iii of this series I created two stages...`dev` and
`production`...I'll be doing this on my laptop:

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

Ok...this is what we expect.  There isn't a `_meta` folder but let's start getting setup and see
what happens (as a reminder I'm in a Docker container when running `sls` aka `serverless`):

```
root@bcdeb57d5754:/code# sls meta sync  
/usr/local/lib/node_modules/serverless/node_modules/bluebird/js/release/async.js:61
        fn = function () { throw arg; };
                           ^

ServerlessError: This plugin could not be found: serverless-meta-sync
```

Doh!  We need to install the plugin which makes sense. Since we (or our colleauge who setup the
project) performed an `npm install --save` of the plugin it'll be in our `package.json` file so all
we'll need to do is `npm install`:

```
root@bcdeb57d5754:/code#  npm install
.....
npm info ok 
root@bcdeb57d5754:/code# 
root@bcdeb57d5754:/code# sls meta sync 
/usr/local/lib/node_modules/serverless/node_modules/bluebird/js/release/async.js:61
        fn = function () { throw arg; };
                           ^

ServerlessError: No existing stages in the project
```

Hrmmm....it's really not that simple. The root cause here is that Serverless still knows nothing of
our project.  Since Serverless works by keeping track of several files in the `_meta` directory it
doesn't even know what your project is about...what resource it needs, nada.  **Serverless should
really make this easier and more intuitive.**.

    After cloning a repo you will need to perform a `sls project init` command

This will walk you through some prompts to get setup...you can also pass command line arguments to
speed this up as needed.  Doing a `sls project init --help` will show you all of the options you
can use.  Note, this is the same command you'll use to setup a brand new serverless project.  Here,
the `project init` command will initialize and existing project since we're *inside* the project
directory already.

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


### Setting up Meta Sync

[Serverless Meta Sync](https://github.com/serverless/serverless-meta-sync) to the rescue.  This
plugin is pretty simple...what it does is store these magic files in an S3 bucket and allows you
"syncing" them periodically when there are changes.  This has the benefit that sensistive
information (environment variables, etc.) stay out of source control but are also shared between
systems. I recommend [reading through the Serverless Project 
Structure docs](http://docs.serverless.com/docs/project-structure) for a more comprehensive
explanation of all the critical files.

Let's walk through setting it up on an existing projects. If you read the plugin's docs you'll see
that the setup is just a matter of adding some data to your `s-project.json` file and running the
`npm install`.

```
root@8941047f877c:/code/serverless-demo# npm install serverless-meta-sync --save
```

Here is what I added to `s-project.json`:

```
root@8941047f877c:/code/serverless-demo# cat s-project.json 
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

Now, it's time to sync. 

```
root@12de1c686e55:/code/serverless-demo# sls meta sync -s dev -r us-west-2
```

And with that, your files will be uploaded to S3.

### Syncing stages and regions

It's not obvious at all...but if you have multiple stages, each stage will need
to be sync separately. Basically, each combination of region/stage needs to be synced
explicity...the `sls meta sync` command will **not** by default sync all of the parameters for all of
the stages/regions. To make this more interesting let's reference an environment variable in our
Labmda Function:

```
def handler(event, context):
    value = os.environ.get('MY_MAGIC_VARIABLE', 'dev')
    # Use value later on
```

We'll now create a new stage called `test` and set that variable to something else:

```
root@12de1c686e55:/code/serverless-demo# sls stage create 
Serverless: Enter a new stage name for this project:  (dev) test
Serverless: For the "test" stage, do you want to use an existing Amazon Web Services profile or
create a new one?
  > Existing Profile
    Create A New Profile
Serverless: Select a profile for your project: 
  > default
Serverless: Creating stage "test"...  
Serverless: Select a new region for your stage: 
    us-east-1
  > us-west-2
    eu-west-1
    eu-central-1
    ap-northeast-1
Serverless: Creating region "us-west-2" in stage "test"...  
Serverless: Deploying resources to stage "test" in region "us-west-2" via Cloudformation (~3 minutes)... 
Serverless: Successfully deployed "test" resources to "us-west-2"  
Serverless: Successfully created region "us-west-2" within stage "test"  
Serverless: Successfully created stage "test"  
```

After a new stage is created we get some files in our `_meta` directory where we can add our new
environment variable:

```
brianz@bz-cconline(master=)$ ls -l _meta/variables/
total 40
-rw-r--r--  1 brianz  staff   34 May  2 16:50 s-variables-common.json
-rw-r--r--  1 brianz  staff  220 May  2 21:40 s-variables-dev-uswest2.json
-rw-r--r--  1 brianz  staff   20 May  2 16:50 s-variables-dev.json
-rw-r--r--  1 brianz  staff   27 May 31 20:57 s-variables-test-uswest2.json
-rw-r--r--  1 brianz  staff   21 May 31 20:57 s-variables-test.json
```

To use a variable, there are three places you'll need to deal with it:

- The variables file for a specific stage. Here, I'll add our `MY_MAGIC_VARIABLE` variable to the `s-variables-test.json`
- The `s-function.json` file which actually pulls the variable from the previous file and injects
  it into your lambda function.
- Your actual handler code

```
brianz@bz-cconline(master=)$ cat _meta/variables/s-variables-test.json 
{
  "stage": "test",
  "MY_MAGIC_VARIABLE": "wavy gravy"
}
```

In `s-function.json`:

```
"environment": {
    "MY_MAGIC_VARIABLE": "${MY_MAGIC_VARIABLE}",
```

Now, we'll `sls dash deploy` this to our `test` stage. When we hit our `test` endpoint we can see
that "wavy gravy" is listed in the output. Try for yourself...load up
https://4m98c4l3i1.execute-api.us-west-2.amazonaws.com/test/hello in your browser to take a look.

That was a lot of setup just to show how we're going to sync out two different stages. But, this is
important....we have two different "stacks" if you will.  Imagine these being your production
system and your qa system. 

We'll now push our changes *up* into S3 so that we can get at these settings from a different
machine and our imaginary collegues can also get them.

```
root@12de1c686e55:/code/serverless-demo# sls meta sync
Serverless: Select an existing stage: 
  > 1) dev
    2) test
Serverless: WARNING: This variable is not defined: region  
Serverless: WARNING: This variable is not defined: region  
Serverless: Going to sync "s-variables-dev.json"... 
  
 {
-  MY_MAGIC_VARIABLE: "dev"
 }

Serverless: How should these differences be handled?
    Review these changes one by one
    Apply these changes to the local version
  > Discard these changes and sync the remote version with the local one
    Cancel
Serverless: Done 
```


"But wait", you ask...if files are stored in S3 how do you actually *connect* to S3 to pull down
the files?  Yes, there are some minimum requirements here...any Serverless project is going to need
to reference some AWS credentials so that it can perform the nessecary actions.  You'll notice
above there are some other files missing, notably the `admin.env` file which points to some AWS
credentials stored in my home directory.  Since that is in `.gitignore` you'll need to recreate the
AWS auth setup on each newly cloned repository.

I use a Docker image for installing and using the Serverless library.  One stage of my `Dockerfile`
copies over the AWS credentials in the correct location...once that is done my image is
bootstrapped and away I go.  If you were doing this on your own system you may not need to do that
since Serverless will simply look in the normal locations for AWS credentials.  For me, all I need
to do is copy over my `credentials` file to the newly cloned repo and I'm done.

```
brianz@gold(master=)$ cp ~/Sync/serverless-demo/credentials  .
brianz@gold(master=)$ make
$ # snip
Successfully built 59d18fcd3d6c
```

I can now fire up a container and start meta syncing~

```
brianz@gold(master=)$ make shell
docker run --rm -it \
        -v `pwd`:/code \
        --name=slsdemo "bz/serverless" bash
root@8941047f877c:/code# 
```

You can read the docs on how to actually set up Meta Sync on an existing project...it's really
really simple.  We can see here that I've already set it up:

```
root@8941047f877c:/code# cd serverless-demo/
root@8941047f877c:/code/serverless-demo# cat s-project.json 
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



## Setting up environment variables

