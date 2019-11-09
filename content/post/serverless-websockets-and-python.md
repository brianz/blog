---

title: "Building a Serverless Slack clone with Python and Websockets"
date: 2019-10-08T18:27:24-06:00
draft: false
tags: [
    "aws",
    "architecture",
    "python",
    "websockets",
    "serverless"
]

---

In late 2018, API Gateway [released support for websockets](https://aws.amazon.com/blogs/compute/announcing-websocket-apis-in-amazon-api-gateway/). This was a really exciting milestone for API Gateway and serverless computing since, historically, serverless APIs were mostly limited to stateless connections. Wouldn't it be great if we could bring along our serverless architectures as we move to a more real-time style of application development. Well, now we can!

You may be thinking, how on earth does this work since Lambda functions (or FaaS, in general) are (mostly) stateless? That is a really great question, and one I asked myself as soon as I heard about Websocket support in API Gateway. The detailed answer is down below, but in short:

---

Lambdas functions are still stateless, but by using a datastore (like DynamoDB) to store state, we can mimic a long-lived stateful connection between client and server.

---

**Note:** All of the code can be found [in the Github repository](https://github.com/brianz/noco-serverless-chat)

The whole thing went well...you can see the results in the asciicast below:

[![asciicast](https://asciinema.org/a/O1ya9VitrkhH1lQVCqxbJsV6P.svg)](https://asciinema.org/a/O1ya9VitrkhH1lQVCqxbJsV6P)

# Websockets and Python on AWS

I organize of the Northern Colorado AWS Meetup in Fort Collins, CO. There was a request to do a hands-on lab to get people more familiar with building something for real, rather than just hearing a presentation. Since websockets was new, and because I'm a Python guy, I decided to do a hands-on demo of building a chat application using Python and websockets. What I quickly found (at the time) was that _there is very little documentation or example code using Python and websockets_. Most of the documentation/blogs I found (back in April of 2019) centered around Node.

I was able to come up with a pretty cool chat application using the Node examples that I found as a guide. The funny thing is that the websocket part is actually very very small. There is a big caveat with the Python implementation, which I'll call out below.

# Websockets and API Gateway

I'll start at a high level...how does API Gateway work with Websockets? First, let's take a quick look at how to create a Websocket endpoint in API GW using the Serverless framework.

In the [serverless.yml](https://github.com/brianz/noco-serverless-chat/blob/master/serverless/serverless.yml) file, you define functions and handlers as you normally would. The difference from an API endpoint is in the `events` key. Here, the `event` is a `websocket` event.

```yaml
functions:
  connect:
    handler: handler.connect
    events:
      - websocket: $connect
  disconnect:
    handler: handler.disconnect
    events:
      - websocket: $disconnect
  default:
    handler: handler.default
    events:
      - websocket: $default
```

There are three websocket events which are triggered by default from any websocket client library. Those are:

- `connect` -> Triggered when the initial connection is established
- `disconnect` -> Triggered when the a connection closed
- `default` -> Everything else

You should note here that these handler functions I've set up are just plain ol' Python Lambda functions. What is slightly different is, of course, the payload that these functions receive when they are triggered from a Websocket invocation.

Remember, a websocket connection is a full-duplex connection. This is just a fancy way of saying that when a connection is opened, it stays open until either the client or server severs the connection. While that connection is open, the client may send data to the server, and the server can _push_ data down to the client. This is exactly what we want in a chat system...if a new message arrives, we want to _push_ that message to all of the connected users.

API Gateway provides us with that long-lived websocket connection. The connection with a client is actually made between the client, and API Gateway. API GW is in charge of keeping that connection alive, and proxying the data between the client and our Lambda function.

I'll walk you through a brief exchange to make things more clear (this is all very high level):

- Client establishes a connection with our API GW Websocket endpoint

```javascript
const ws = new Websocket('wss://our-apigatewayendpoint.us-west2.amazon.com')
```

- API GW creates a "connection id" with that client, and invokes `handler.connect` (using example from above)
- Our `handler.connect` function is invoked...in the payload is a `connectionId` which uniquely identifies that single client.
- The client now sends some data:

```javascript
ws.send(JSON.stringify({ message: "ping" })
```

- Our `handler.default` function is invoked...in the payload is a `connectionId` which identifies that single client on that 
  same connection. Also in the payload the a JSON-encoded data which was sent: `'{"message":"ping"}'`. Using the 
  `connectionId`, we can send a message _back_ to the client (I'll demonstrate how to do this, later). We can also perform
  any business logic based on the payload sent.
- The client closes the connection:

```javascript
ws.close();
```

- Our `handler.disconnect` function is invoked...in the payload is a `connectionId` which identifies that single client on that same connection. We can now clean up any state we have for that connection since we now know it's gone.

---

**The key with all of this is that API Gateway gives us a `connectionId`, which identifies a unique, connected client. Our Lambda functions receive messages from clients that include a `connectionId` and we use that `connectionId` to push messages to clients.**

---

# Slack clone

Chat applications are sort of like the "Hello World!" of websockets, in my opinion. Rather than just doing a basic chat app, I wanted to support a couple of more features akin to Slack or other chat platforms...what I ended up with:

- Setting a username
- Different "channels"

That's not very complicated, but it's pretty clear there will be some state that we'll need to keep track of. In my implementation, I used DynamoDB which is very well-suited for this application. If you think through the basics of a chat application (broadcasting messages), and the two additial features above, I'll need to save:

- A list of users, and what channel they are connected to
- A mapping of "connection" to username, to allow people to change their user name
- A list of all the messages and what room those messages were sent

So, let's dig into some of the code and figure out how this all works. I'll walk through it in three blocks, which map 1-to-1 with the websocket lifecycle methods:

- `connect`
- `default`
- `disconnect`

# Connect

So, a user connects...what do we need to do if we're implementing a chat system? In my case, I'm going to:

- Extract the `connectionId` from the request
- Save the `connectionId`, treating them as an `anonymous` user
- Place the user in the `general` channel

You can follow the logic in [my handler.py file on Github](https://github.com/brianz/noco-serverless-chat/blob/master/serverless/handler.py), but it's so simple we can walk through it here:

{{< highlight python >}}
def connect(event, context):
    """Lambda handler for a websocket connect event"""
    connection_id = _get_connection_id(event)
    aws.set_connection_id(connection_id)

    return {
        'statusCode': 200,
        'body': 'connect',
    }

def _get_connection_id(event):
    ctx = event['requestContext']
    return ctx['connectionId']
{{< /highlight >}}

Pretty simple stuff. You can see the `_get_connection_id` helper just pulls out the `connectionId` from the Lambda event payload. I pass that `connectionId` to the other helper. This is my own code that I namespace within my Lambda package. You can read it [in its entirety on Github as well](https://github.com/brianz/noco-serverless-chat/blob/master/serverless/noco/aws.py). Frankly, most of the complexity in this app (and in the `set_connection_id` 
helper function) comes from saving the state in DynamoDB and getting the structure right so that we can easily query it. In short, what I do in 
DynamoDB during a connection is:

- Update the list of channels. If someone connects for the first time, a `#general` channel is stored
- Inserting a record for the `connectionId`. When someone connects, I basically store the fact that they are connected and in the `#general` channel.

So, now let's assume two people have connected. What do we need to do when someone types a message in the `#general` channel?

# Default

Now, something a bit more fun...a user types a message into our chat system and hits `Enter`. What do we do? Well, to start, this is not
a `connect` or `disconnect` event, so API Gateway will invoke our `default` handler. There is a way to create your own websocket event types
which you can map to different functions, but I won't cover that here.

{{< highlight python "linenos=inline">}}

def default(event, context):
    """Default handler for websocket messages"""
    message = event.get('body', '')

    if not message.strip():
        return {
            'statusCode': 200,
        }

    if message.startswith('/'):
        return _handle_slash(message, event)

    connection_id, request_time = _get_conn_id_and_time(event)

    user = aws.get_user(connection_id)
    channel_name = user.get('channel_name', 'general')
    username = user.get('username', 'anonymous')

    # Save the message to dynamodb
    aws.save_message(connection_id, request_time, message, channel_name)

    # broadcast the message to all connected users
    _broadcast(
        message,
        _get_endpoint(event),
        connection_id,
        channel_name,
        username,
    )

    return {
        'statusCode': 200,
        'body': safe_dumps(message),
    }

{{< /highlight >}}

Let's break this down. When there is a regular text message (ie, not a `/` command, as picked up on line 10): 

- I extract out the `connectionId` and time of the request. This is used to save the message, using the time of the request as the sort key in DynamoDB
- Get the user from DynamoDB, using the `connectionId` as the unique identifier, which I saved
  during the `connect` event
- Get the channel name, which is stored in the `user` record in DynamoDB. Defaults to `general`.
- Get the `username`, also in the `user` record in DynamoDB. Defaults to `anonymous`.
- Save the new message in DynamoDB
- Broadcast the message out to other users, for this particular channel

That's sort of a lot, but most of it is just housekeeping, saving state in DynamoDB to support people
changing the usernames and changing channels. The interesting bit here is the `_broadcast` helper which 
will push out the message to other users in the channel. Let's look at that since that's the meat
of this entire blog post.

Pushing a message to open websockets is pretty simple. Here it the `_broadcast` helper, in its entirety:

{{< highlight python "linenos=inline">}}
def _broadcast(message, endpoint, sender, channel, username):
    client = boto3.client('apigatewaymanagementapi', endpoint_url=endpoint)

    # need to look up what channel the user is connected to
    for connection_id in aws.get_connected_connection_ids(channel):
        if connection_id == sender:
            continue

        client.post_to_connection(
            ConnectionId=connection_id,
            Data='#{} {}: {}'.format(channel, username, message),
        )
{{< /highlight >}}

You can use boto3 to push messages to a websocket connection using the `post_to_connection` API call, as shown above.

---

**A big caveat here is that you need to use a new version of boto3. The boto3 that comes with Python Lambda functions
is out-of-date, and does not have this API included!**

---

This function works by taking a message, API GW Http endpoint (See Github code for details on how to extract that), the sender's
`connectionId`, the `channel` the message was sent, and the `username` of who sent it. It's really only four lines of code, so
let's break it down further.

First, I need a client object from boto3...nothing fancy there. The only trick is that we need to pass in an `endpoint_url`. The
boto3 docs do not call this out explicitly. There is a [Github issue tracking this](https://github.com/boto/boto3/issues/1914). Hopefully
the docs get updated soon. I'm fairly certain the reason this endpoint URL is required is that, behind the scenes, the interface
to the open Websocket connections is handled via HTTP. You can read about it 
[in the API Gateway docs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-how-to-call-websocket-api-connections.html)

Now that I have a client object, i need to fetch the list of connections/people who need to receive the message. This is all
handled in the `get_connection_connection_ids` helper on line 5. There isn't any magic here...it's just a DynamoDB query to fetch the list
of users in the channel.

Since we don't want to echo message back to the user who sent it, we `continue` when we inevitably see the `connection_id` of the
`sender` on lines 6-7.

Now, it's time to broadcast! This is just a simple call to `client.post_to_connection`, which takes a connection id, and some
string data. Here, I'm just formatting the message so recipients see the channel name, username of who sent the message, and the 
message itself:

```
< #general BZ1: hello from BZ1 
< #general BZ1: what's up?
```

# Disconnect

When a client willingly closes the connection or it times out due to inactivity, the `disconnect` event is triggered. All I do here
is clean up that user's data in DynamoDB, since we no longer want to attempt to send them messages. You can peruse the code if
you're curious on the details

# Conclusion

Using websockets with API Gateway, Lambda functions and Python is quite simple and fun. The trick to most of this is using the latest
version of boto3, and using the undocumented `boto3.client('apigatewaymanagementapi', endpoint_url=endpoint)` client.

One thing which will make your life easier is created a Lambda Layer with a new boto3 package, and using it in your projects. This
is exactly what I did...the layer is public, so if you like, you're welcome to use it in `us-west-2`. It looks like this in 
a `serverless.yml` file:

```yaml
connect:
  handler: handler.connect
  layers:
    - arn:aws:lambda:us-west-2:420819310858:layer:boto3-botocore:1
  events:
    - websocket: $connect
```

Just like serverless architectures shine for certain cases, there are times when something else is better suited. For example,
if you were trying to implement a copy of Google docs using websockets and Lambdas, I'd say you would have a hard time. While
websockets are quite fast, using them with API Gateway, Lambda and a database does add latency to your round trips. If you need
something which handles a round trip in a few milliseconds, I'd say a traditional server storing state in memory would be a
better starting point. However, if you have something which doesn't have extremely low latency demands, consider API Gateway
and Lambda.