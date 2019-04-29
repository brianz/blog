---

title: "Building a Serverless Slack clone with Python and Websockets"
date: 2019-04-25T11:27:24-06:00
draft: true
tags: [
    "aws",
    "architecture",
    "python",
    "websockets",
    "serverless"
]

---

Not too long ago, API Gateway
[released support for websockets](https://aws.amazon.com/blogs/compute/announcing-websocket-apis-in-amazon-api-gateway/).
This was a really exciting milestone for API Gateway and serverless computing since, historically,
serverless APIs were mostly limited to stateless connections. Wouldn't it be great if we could bring
along our serverless archictures as we move to a more real-time style of application development.
Well, now we can!

You may be thinking, how on earth does this work since Lambda functions (or FaaS, in general) are
(mostly) stateless? That is a really great question. The answer is down below...the answer really is
that Lambdas are still stateless, but using API Gateway along with a datastore (like DynamoDB) we
can get where we need to be.

# Websockets and Python on AWS

I organize of the Northern Colorado AWS Meetup in Fort Collins, CO. There was a request to do a
hands-on lab to get people more familiar with building something for real, rather than just hearing
a presentation. Since websockets was new, and because I'm a Python guy, I decided to do a hands-on
demo of building a chat application using Python and websockets. What I quickly found was that
_there is very little documentation or example code using Python and websockets_.

I was able to come up with a pretty cool chat application using the Javascript examples I found as a
guide. The funny thing is that the websocket part is acctually very very small. There is a big
caveat I found, which I'll call out below.

# Slack clone

Chat applications are sort of like the "Hello World!" of websockets, in my opinion. Rather than just
doing a basic chat app, I wanted to support a couple of more features akin to Slack or other chat
platforms.

[![asciicast](https://asciinema.org/a/O1ya9VitrkhH1lQVCqxbJsV6P.svg)](https://asciinema.org/a/O1ya9VitrkhH1lQVCqxbJsV6P)
