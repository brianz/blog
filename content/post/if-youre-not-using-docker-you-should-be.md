+++
date = "2016-04-12T20:33:29-06:00"
draft = true
tags = [
    "docker"
]
title = "If you're not using Docker you should be"

+++


If you're a developer and don't live under a rock you've undoubtedly heard of
[Docker](https://www.docker.com).  There are *many many* sites out there which will tell you about
how to use Docker and how to start using it...this will not be one of those posts. Rather, I'd like
to write about some practical advantages about Docker which I've learned that weren't super obvious
when getting started.

I'll start off by reiterating, **if you're not using Docker you should be**.  It really is quite an
amazing tool.  No software tool is perfect and Docker is no different.  Still, new the problems you
find from going the Docker route are shadowed by the problems it solves. Here are a few ways that
Docker can help you which you may not realize or have thought about.

## Throw away work

As a heavy user of Python I was very accostomed to using `virtualenv` and `virtualenvwrapper` to
test things out.  Want to test out Kafka or Sphinx or whatever?  No problem, create a new
`virtualenv`, install all of your requirements and voila...when your'e done simply `rmvirtualenv
mytest` and you're done.

With Docker, the need for `virtualenv` pretty much goes aways (although, I'm not getting rid of it
anytime soon).  Since containers are so cheap it's trivial to build you're own Docker image and
install all of the packages you need.  Here's a two-line `Dockerfile` which will work and can be
used to build documentation using the popular (Sphinx)[http://sphinx.pocoo.org] library...I'll
install some extension just for fun:

```
# Dockerfile
FROM python:2.7

RUN pip install sphinx sphinxcontrib-argdoc
```

Now, let's build it:

```
docker build -t bz/sphinx .
```

And now you have a little Docker image named `bz/sphinx` which you can use to build Sphinx documentation. Doing that
may not be as obvious as you'd think. If you create a container and write/build your docs,
everything will disappear once the container is killed. The trick is to mount a local folder on
your host system as a volume in the Docker container.

```
brianz@bz-cconline$ docker run --rm -it -v `pwd`:/code  bz/sphinx  bash
root@675a26dba565:/# cd /code/
root@675a26dba565:/code# sphinx-quickstart
```

After stepping through the `sphinx-quickstart` I'm done and can now edit my files on my host system
and build the docs using Sphinx on the Docker container. Even when the Docker container is nuked,
provided I use the volume (using `-v $(pwd):/code`) the files on your host are visibile from within
your container.

This makes is really really easy to use Docker as a sort of **package manager** for *any* system,
language or ecosystem. I've used it for Node, Java and Python to name a few...it's awesome.


## Testing a somewhat complex system

A while ago I wanted to play around with Wordpress a bit. I have no idea how to set up Wordpress or
what the requirements are other than something with PHP...definitely not my world. Of course, I
reached for Docker and docker-compose.  Sure enough, there is an official image which is even so
kind as to give you a demo `docker-compose.yml`:

https://hub.docker.com/_/wordpress/

If you use the example `docker-compose.yml` all you really need to do is hit the IP address of your
host running the Docker deamon and voilá...Wordpress. Just like above, I classify this as
throw-away work because I was just playing around and figuring out how to manipulate Wordpress.
But, the ease and speed at which Docker allows you to spin up a system comprised of multiple
components (a PHP/Apache server and MySQL db in this case) is incredible. Wordpress isn't even that
complicated, but there are many `docker-compose.yml` references out there for much more complex
systems allow you to either do zero work or make some light tweaks to get things to suit your
needs.


## Helper scripts

There is a small theme here...since containers are well, self-contained, you can use them as
package managers in some sense.  This is sort of a contrived example but imagine you want to use
the `opencv` library to run some image analysis. In the past you'd probably spend 8 hours trying to
figure out how to install it on your Mac or even on a Linux machine. Google around a bit and
chances are someone has already created an image...yup..here we go!
https://hub.docker.com/r/kavolorn/opencv/~/dockerfile/

Now I can use this image as a *utility* rather than as a running system. Since containers spin up
and down so quickly there is no reason why we can't consider them executables for *any* command.
Just to make sure I wasn't lying I went ahead and did this...it took a *little* tweaking but not
much.  I was able to successfully:

- Build a Docker image based on the image above
- Install some extra requirements
- Create a color histogram from a <a href="/images/house.jpg">random image</a>

Here's the `Dockerfile`

```
# Dockerfile
FROM kavolorn/opencv

RUN apt-get update
RUN apt-get install -y curl
RUN curl -O https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN apt-get install -y libfreetype6-dev
RUN python3 -m pip install matplotlib
```

And the Python3 file to create the histogram...mostly [copied from
here](http://opencv-python-tutroals.readthedocs.org/en/latest/py_tutorials/py_imgproc/py_histograms/py_histogram_begins/py_histogram_begins.html)

```
# histo.py
import cv2
import numpy as np
from matplotlib import pyplot as plt

img = cv2.imread('house.jpg', 0)

# create a mask
mask = np.zeros(img.shape[:2], np.uint8)
mask[100:300, 100:400] = 255
masked_img = cv2.bitwise_and(img,img,mask = mask)

# Calculate histogram with mask and without mask
# Check third argument for mask
hist_full = cv2.calcHist([img],[0],None,[256],[0,256])
hist_mask = cv2.calcHist([img],[0],mask,[256],[0,256])

plt.subplot(221)
plt.imshow(img, 'gray')

plt.subplot(222)
plt.imshow(mask,'gray')

plt.subplot(223)
plt.imshow(masked_img, 'gray')

plt.subplot(224)
plt.plot(hist_full)
plt.plot(hist_mask)

plt.xlim([0,256])

plt.savefig('histogram.png')
```

And here is how I ran it:

```
# build the image
> docker build -t bz/opencv .
# run the image
> docker run --rm -it -v $(pwd):/code bz/opencv bash
root@f278f7a7124e:/# 
root@f278f7a7124e:/# cd /code
root@f278f7a7124e:/code# python histo.py
```

And with that, I get an image on my *local* system which I can open:

![color-histogram](/images/histogram.png)

From here it'd be pretty easy to add an `ENTRYPOINT` and `CMD` so that we could tell a container to
run this script on startup and point it to any random image.
