+++
draft = true
date = "2017-01-23T10:33:09-07:00"
title = "Authoring Alexa Skills with Python and Lazysusan"
tags = [
    "python",
    "alexa",
    "serverless",
]

+++

Most recently at my [day job](http://joinspartan.com) we were tasked with building an Amazon Alexa
app for a client. As soon as I heard rumors that we would be doing an Alexa app I starting raising
my hand hoping that I'd get put on this project.  If you read these blog posts it should become
quite apparent I'm a pretty big AWS fanboy and Alexa has [pretty tight integration with AWS
Lambda](https://aws.amazon.com/about-aws/whats-new/2015/06/create-new-voice-driven-capabilities-for-alexa-with-aws-lambda/)

## Alexa overview

If you're completely unfamiliar with Alexa it's really quite simple from a layperson's and
technical perspecctive.

Alexa is the voice platform behind the Amazon Echo, Dot and other Amazon speech devices. Regardless
of the Amazon device you're interacting with via speech, it all goes through the "Alexa" platform
(as far as I know).

From a developer's prespective building Alexa apps is really really easy. Alexa apps send `json`
to a given endpoint and expect valid Alexa `json` in response. That's it. Of course, there are many
nuances and details to understand, but from a high level this is it...`json` in and `json` out.

__Note__: You'll notice I said that `json` is sent to an "endpoint". With Alexa applications, you
have two choices for what that endpoint may be:

- A regular ol' https webserver
- A Lambda function

I see absolutely zero advantages to deploying an Alexa application (officially known as "Alexa
Skills") on your own https server. There are many things you'll need to worry about...ssl certs,
scaling, high availability, monitoring...etc. Basically, all of the things any good SAAS
application developer would worry about when deploying a new system.

Because Alexa's integration with Lambda is so seemless, it's going to be the right decision 99% of
the time. 

The only way I would suggest running your own server to back Alexa Skills is if your application
code had some pretty heavy dependencies such as `numpy` or another big and heavy requirement which
couldn't fit inside a Lambda function.

## Lazysusan

During our client engagement we would up authoring an open source Python library for authoring
Alexa applicaitons. We call her [Lazysusan](https://github.com/spartansystems/lazysusan). I'll walk
you through all of the steps in authoring a very very basic Alexa Skill.

## Lazysusan concept(s)

Lazysusan has one big concept which is critical to understanding how to build your own skill...that
is, application state.

Lazysusan handles Alexa requests with the current logic/flow:

- Lookup current state
- Given the current state and the user's intent, find what the response should be
- If no response can be found for user's intent given the current state, fallback to the `default`
  response

In addition to this flow of logic there are a couple of concepts to understand, notably "intent"
and "state". We'll drill into these concepts below. For now, let's look at this flow of Lazysusan
logic as a graphic:

<img src="/images/lazysusan/logic-flow.png" height="600">


## Example application

We have an example application in the Lazysusan repository. Have a look at:

https://github.com/spartansystems/lazysusan/tree/master/examples/age_difference

I'll walk through it fun little Alexa skill and explain how it's built with Lazysusan.

## State definition and flow

The key in any Lazysusan app is a yaml file which definite each reponse and how to handle requests
from a given state. Remember, when a request comes in Lazysusan will figure out two things:

- "What state is the user at?"
- "Given this state and their intent, how should I responsd?"

Here is a very simple example of a `state.yml` file lifted from our Age Calculator example:

```yaml
initialState:
  response:
    card:
      type: Simple
      title: Age Difference
      content: >
        When is your birthday?
    outputSpeech:
      type: PlainText
      text: >
        When is your birthday?
    shouldEndSession: False
  branches: &initialStateBranches
    LaunchRequest: initialState
    MyAgeIntent: !!python/name:callbacks.calc_difference
    default: goodBye

missingYear:
  response:
    outputSpeech:
      type: PlainText
      text: Please say what day, month and year you were born.
    shouldEndSession: True
  branches:
    <<: *initialStateBranches
    LaunchRequest: initialState

goodBye:
  response:
    outputSpeech:
      type: PlainText
      text: >
        Thanks for trying age difference, good bye.
    shouldEndSession: True
  branches:
    <<: *initialStateBranches
    LaunchRequest: initialState
```

A "session" in Alexa parlance can be a bit nebulous. By default, when a user launches your skill and
begins interacting it there is a built-in session which is active. As long as the user is
interacting with your skill and the blue light ring on top of the device is illuminated, the
sesssion is active. If the user doesn't respond at all or reaches the "end" of the skill, the
session will be killed.

Think of an Alexa session as a conversation with a real person...provided you keep the
converstation going, the session is active.  Now imagine during a real conversation you simply walk 
out the door leaving your converstational partner standing there alone. Your conversation has ended
and the session is now over. Or, imagine the other party in the conversation bluntly ends the
chat..."I'm sorry, but I have to go. Goodbye". This is exactly how a session may end with Alexa.
You may simple decide you're done and not reply or the other party may call it quits.

In our example, we ask a simple question and provide a (somewhat) simple response.

- User: "Open age calculator"
- Alexa: "When is your birthday?"
- U: Jan 12, 1972
- A: "You are 45 years, 11 days old, ...."

### Initial state

Upon the first request, there is no session to speak of. In that scenario, Lazysusan will look for
a key in your yaml file named `initialState`.  Alexa apps are often launch with a phrase will will
trigger a `LaunchRequest`. This is exactly what we've done here with the phrase, `Open age
calculator`.  So, we are:

- In `initialState`
- Receiving a `LaunchRequest`

With those to pieces of information, Lazysusan will lookup the `LaunchRequest` key the list of
`branches` in the `initialState` block. As you can see in the yaml above, this simple points back
to the th `initialState` block which contains a fully valid Alexa response in yaml.  Lazysusan will
literally take this content verbatim, convert it into json and sent it back to Alexa.

### Response after initial state

The user has received a question and the state is still active. What happens next? The user
responds with a date which triggers a `MyAgeIntent` from the Alexa platform. So, we are now:

- In `initialState`
- Receiving a `MyAgeIntent`

With those to pieces of information, Lazysusan will lookup the `MyAgeIntent` key the list of
`branches` in the `initialState` block. The value of that is something interesting:

```yaml
    MyAgeIntent: !!python/name:callbacks.calc_difference
```

This is a magicl little part of the [PyYAML](http://pyyaml.org/wiki/PyYAMLDocumentation) package.
Here, `MyAgeIntent` is literally pointing to a Python function. If Lazysusan encounters a callable
object/function in `states.yml` it will call that function with six arguments (you can see those
arguments [in the `app.py`
file](https://github.com/spartansystems/lazysusan/blob/master/lazysusan/app.py#L70)). For the
purposes of this blog post, it's not super critital to understand all the permutations or arguments
passed into a callback...what is important is knowing:

- you can build completely 100% dynamic responses using this callback mechanism.
- you can return either :
    - the name of the next response key which will be looked up in `states.yml`
    - an actual response using `helpers/build_response`

If you look at the source code for this example, we are doing a bunch of fancy date math (made
harder due to leap years, of course) and returning a response with a helper function approprately
called, `build_response`.

## Walking through a callback

Let's take a look at the callback function which Lazysusan invokes when a `MyAgeIntent` is
encountered during an Alexa request:

```python
def calc_difference(**kwargs):
    request = kwargs["request"]
    session = kwargs["session"]
    state_machine = kwargs["state_machine"]
    log = get_logger()

    date_string = request.get_slot_value("dob")
    if not date_string:
        log.error("Could not find date in slots")
        return "goodBye"

    if date_string.startswith('XXXX-'):
        return "missingYear"

    now = datetime.now()

    dob = get_dob_from_date_string(date_string)
    if not is_valid_day(dob):
        return "invalidDate"

    age = get_age_from_dob(dob, now)

    # First get a breakdown of how old user is in years, months, days
    msg = age_breakdown(age)

    # next figure out the days until the users next birthday
    msg += "%s" % (days_until_birthday(dob, now), )

    # finally add whether we're older or younger than the last user
    msg += "%s" % (last_user_difference(session, dob), )

    session.set(DOB_KEY, dob.toordinal())

    response_dict = build_response("ageResponse", msg, state_machine)
    return build_response_payload(response_dict, session.get_state_params())
```

We won't go through every line, but a few things worth noting:

- There are currently six `kwargs` which are passed into a callback from Lazysusan. Here, we really
  only care about three of those and get them out of the `kwargs` dictionary.
- You'll notice three different places where some error checking is performed. If the error
  condition in triggered you'll see somem return statements, such as:

```python
if date_string.startswith('XXXX-'):
    return "missingYear"
```

When a string is returned from a callback, Lazysusan assumes this is a key to a response in
`states.yml`. If the error above was triggered the response would be sythesized from the
`missingYear` text above:

```yaml
text: Please say what day, month and year you were born.
```



https://hub.docker.com/r/joinspartan/serverless/
https://github.com/spartansystems/lazysusan
