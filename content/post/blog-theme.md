+++
date = "2016-03-23T11:02:01-06:00"
draft = false
tags = []
title = "Blog theme"

+++

## SAAS Application Architecture

I was finally inspired to get this site up and running after listening to a [Software Engineering
Radio podcast](http://www.se-radio.net/2015/12/se-radio-episode-245-john-sonmez-on-marketing-yourself-and-managing-your-career/)
with [John Sonmez](http://simpleprogrammer.com/). In that podcast episode John talks about how a
technical blog can really help your career...that's never a bad thing and as mentioned in my 
[last post]({{< ref "getting-started-with-hugo.md" >}}), I wanted a place to help others with any
tips, tricks or general things I learn.

John suggests coming up with a "theme" for a tech blog...a theme not in the visual sense but a
theme regarding the content. With that, I've landed on "SAAS Application Architecture".

My career has taken me to a place where I primary work on software systems which have a publicly
facing website and are fairly complex behind the scenes. SAAS (software as a service) can probably
be interpreted many ways but in my mind it's a complex software system composed of multiple
services which allows users to manage and analyze some type of data. The type of data and tasks
performed are typically within a certain domain. Taking some examples from things I've worked on:

- Eventbrite: event/ticketing domain
- Clearcare: in-home health care agency domain
- RoastLog: coffee roasting domain

All of these systems:

- have publicly facing websites
- provide users with access to their data 24/7
- are comprised of multiple backend systems (databases, caching, microservices, etc)
- are non-trivial to implement due to the complexities of the domains

With all of that, what I intend to write about here are my experiences building systems like this.

Also, since the previous post I've changed themes. The new one is called
[blackburn](http://themes.gohugo.io/blackburn/) and is really slick. It only took a few minutes to
completely switch. You can [look through the git history](https://github.com/brianz/blog) for this
blog if you're interested in what I did to make the change.
