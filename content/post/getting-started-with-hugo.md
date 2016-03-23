+++
date = "2016-03-21T15:45:26-06:00"
draft = false
tags = [
    "hugo"
]
title = "getting started with hugo"

+++

It's been a very very long time since I've posted anything publicly. Blogging has drastically
changed since the early days. As most of you, I consume a *lot* of material and resources on the
internet. For a while I've wanted to contribute back...I'm constantly learning new things and some
of them are really useful. So, this is my way to hopefully help others.

With that, my inaugural post will be on how I set up this blog. Later, I plan on mostly writing
about building microservices with Python and overall architecture patterns for microservices.

I knew that I definitely wanted something static, meaning I didn't want to stand up my own virtual
server nor did I want to sign up with any of the hosted solutions for Wordpress, Blogger, etc.
I tried out [Jekyll](https://jekyllrb.com) a long time ago which looked neat and had tight
integration with [Github Pages](https://pages.github.com).  At some point I came across
[Hugo](https://gohugo.io/) and played around with it. It's quite slick and apparently has been
gaining more and more users. I went with Hugo since it's pretty darn fast, easy-ish to set up and
it's written in Go (I usually hate dealing with Ruby gems and dependencies).

Here's the TL;DR of what I did to go from zero to blogging *(this is from memory so it may not be
100% correct)*:

    $ brew install hugo
    $ mkdir bz-blog && cd bz-blog
    $ hugo new site brianz

To find a theme I liked went to the [Hugo themes](http://themes.gohugo.io) site and picked
[greyshade](http://themes.gohugo.io/greyshade/). Hugo themes are *really* easy to use:

    $ cd brianz/themes
    $ git clone https://github.com/cxfksword/greyshade.git

I don't especially like the `.toml` syntax which is what you get by default for the config file. I
change `config.toml` into `config.yaml`. The main thing is that I don't like needed to add quotes
around everything in the `toml` files. With yaml, I can just write stuff like this>

    baseurl: http://brianz.bz/
    languageCode: en-us
    title: Brian Z
    theme: greyshade

I wanted syntax highlighting, so installed `pygments` inside a virtual environment. Also, there are
different "themes" for syntax highlighting which can be looked up directly from pygments:

```
$ mkvirtualenv hugo
$ pip install pygments
$ python
```

```
>>> from pygments.styles import get_all_styles
>>> list(get_all_styles())
```

I ended up using the `lovelace` theme by setting `pygmentsstyle: lovelace` in `config.yaml`

**Note:**, there is a small issue with the greyshade theme in that Hugo will throw an error when
creating a new post. To fix this simply create a file at `archetypes/default.md` with the following
contents (or customize as you see fit):

```
+++

draft=true
tags = []

+++
```

With that, I can now create new posts and see it in real-time using `hugo server --buildDrafts`.

Now that things are working, I'll talk about publishing things in my next post.
