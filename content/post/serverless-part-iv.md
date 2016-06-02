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

I'll be covering two topics in this post:

- API Gateway Stages
- Managing configuration with stage variables

## Syncing with the `meta sync` plugin

One issue you will quickly run in to when either working on a project with someone else *or*
working on your own project on different computers is that of the `_meta` directory. If you look at
the repository for this demo project you'll notice there isn't a `_meta` directory. The reason is
that this stores (potentiall) sensitive information about your project such as private keys, etc.
Not only that, different "environments" or "stages" in the world of Lambda, will undoubtedly have
different configuration settings at some point. Imagine an endpoint which needs to talk to DynamoDB
or an SNS topic. Serverless allows us to reference things like this with environment variables
which are injected at deploy time through some `_meta` files.
By default, Serverless will [add `_meta` to the `.gitignore` of your
project](https://github.com/brianz/serverless-demo/blob/part-ii/serverless-demo/.gitignore#L43).

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
going to clone this in a different location on my iMac for the sake of this demo since I
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

Herein lies the issue...without the `_meta` directory Serverless won't know anything about where
our Lambda function(s) live, how to configure API Gateway or the other necessary things for running
our system such as environment variables which may be refernced or needed to run our functions. 
You'll end up in this situation whenever you clone an existing serverless project
whether it's on a new system or when you're on a team working on a project.

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

