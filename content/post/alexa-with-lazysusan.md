+++
draft = false
date = "2017-01-24T13:05:21-07:00"
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

If you're completely unfamiliar with Alexa it's really quite simple from a both layperson's and
technical perspective.

Alexa is the voice platform behind the Amazon Echo, Dot and other Amazon speech devices. Regardless
of the Amazon device you're interacting with via speech, it all goes through the "Alexa" platform
(as far as I know).

From a developer's perspective building Alexa apps is really really easy. Alexa apps send `json`
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

Due to the seamless integration with Lambda, it's going to be the right decision 99% of
the time when building Alexa Skills. 

The only way I would suggest running your own server to back Alexa Skills is if your application
code had some pretty heavy dependencies such as `numpy` or another big and heavy requirement which
couldn't fit inside a Lambda function. Since Lambda support Python and Node out of the box, those
will likely be your two choices for implementation languages/ecosystems. If you're a real masochist
you can run Java on Lambda. C# was recently released as a supported language as well.

## Lazysusan

During our client engagement we would up authoring an open source Python library for authoring
Alexa applications. We call her [Lazysusan](https://github.com/spartansystems/lazysusan). I'll walk
you through all of the steps in authoring a very very basic Alexa Skill.

I find that Python strikes a really nice balance in terms of readability, capabilities and extensibility 
for Lambda functions. There is an existing `npm` module for Alexa skills from the Amazon teams. We
opted to write our own in Python for the main reason that we found Python to be a much nicer and
easier language to work with.

## Lazysusan concept(s)

Lazysusan has one big concept which is critical to understanding how to build your own skill...that
is, application state.

Lazysusan handles Alexa requests with the current logic/flow:

- Look up current state
- Given the current state and the user's intent, find what the response should be
- If no response can be found for user's intent given the current state, fallback to the `default`
  response

In addition to this flow of logic there are a couple of concepts to understand, notably "intent"
and "state". We'll drill into these concepts below. For now, let's look at this flow of Lazysusan
logic as a graphic:

<img src="/images/lazysusan/logic-flow.png" height="600" align="middle">


## Example application

We have an example application in the Lazysusan repository. Have a look at:

https://github.com/spartansystems/lazysusan/tree/master/examples/age_difference

I'll walk through it fun little Alexa skill and explain how it's built with Lazysusan.

## State definition and flow

The key in any Lazysusan app is a yaml file which definite each response and how to handle requests
from a given state. Remember, when a request comes in Lazysusan will figure out two things:

- "What state is the user at?"
- "Given this state and their intent, how should I responds?"

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
begins interacting it there is a built-in session which is active.  This "session" is nothing more
than some data sent to your Lambda function in the `json` payload.
As long as the user is
interacting with your skill and the blue light ring on top of the device is illuminated, the
session is active. If the user doesn't respond at all or reaches the "end" of the skill, the
session will be killed.

Think of an Alexa session as a conversation with a real person...provided you keep the
conversation going, the session is active.  Now imagine during a real conversation you simply walk 
out the door leaving your conversational partner standing there alone. Your conversation has ended
and the session is now over. Or, imagine the other party in the conversation bluntly ends the
chat..."I'm sorry, but I have to go. Goodbye". This is exactly how a session may end with Alexa.
You may simple decide you're done and not reply or the other party may call it quits.

So, let's define `state` is in Lazysusan parlance.  State is nothing more than a current location
in your Alexa Skill "flow". In concrete terms, "state" will simple be the name of the top-level
keys in your `states.yml` file. In our example above there are three possible states:
`initialState`, `missingYear` and `goodBye`.

In our example, we'll ask a simple question to the user and provide a (somewhat) simple response
given their input intent:

- User: "Open age calculator"
- Alexa: "When is your birthday?"
- U: Jan 12, 1972
- A: "You are 45 years, 11 days old, ...."

### Intents

I will keep the explanation of "intent" brief since there is [lots of documentation about it on the
Alexa developer
site](https://developer.amazon.com/public/solutions/alexa/alexa-skills-kit/docs/alexa-skills-kit-interaction-model-reference). 
For this post it's still important to understand it from a high level.

When defining the interaction model of your Alexa Skill in the Alexa developer portal  you will map
natural language phrases to intents. For example, "My phone number if 555-1212" may map to
something you define as `MyPhoneNumberIntent`.  Your Alexa skill will receive a `json` payload that
literally has the `MyPhoneNumberIntent` string included in it.  Given you know what the user's
intent is, you can make some decisions via application code on how to respond.

Of course there are many details around using and defining intents so I'd encourage you to read the
Amazon docs for more information.

### Initial state

Upon the first request, there is no session to speak of. In that scenario, Lazysusan will look for
a key in your yaml file named `initialState`.  Alexa apps are often launched with a phrase which will
trigger a `LaunchRequest`. This is exactly what we've done here with the phrase, `Open age
calculator`.  So, we are:

- In `initialState`
- Receiving a `LaunchRequest`

With those to pieces of information, Lazysusan will look up the `LaunchRequest` key in the list of
`branches` in the `initialState` block. 

```yaml
initialState:
  # snip
  branches: &initialStateBranches
    LaunchRequest: initialState
    MyAgeIntent: !!python/name:callbacks.calc_difference
    default: goodBye
```

As you can see in the yaml above, `LaunchRequest` simply points back
to the `initialState` block which contains a fully valid Alexa response in yaml.  Lazysusan will
take this content verbatim, convert it into json and sent it back to Alexa.

### Response after initial state

The user has received a question, responded and the session is still active. What happens next?
The user responded with a date which triggers a `MyAgeIntent` from the Alexa platform. So, we are now:

- In `initialState`
- Receiving a `MyAgeIntent`

With those to pieces of information, Lazysusan will look up the `MyAgeIntent` key the list of
`branches` in the `initialState` block. Looking at the `branches` list above we can see how
Lazysusan will determine the response.

```yaml
    MyAgeIntent: !!python/name:callbacks.calc_difference
```

This is a magical little part of the [PyYAML](http://pyyaml.org/wiki/PyYAMLDocumentation) package.
Here, `MyAgeIntent` is literally pointing to a Python function. If Lazysusan encounters a callable
object/function in `states.yml` it will call that function with six arguments (you can see those
arguments [in the `app.py`
file](https://github.com/spartansystems/lazysusan/blob/master/lazysusan/app.py#L70)). 

For the
purposes of this blog post, it's not super critical to understand all the permutations or arguments
passed into a callback...what is important is knowing:

- you can build completely 100% dynamic responses using this callback mechanism
- you can return either :
    - the name of the next response key as a string which will be looked up in `states.yml`
    - an actual response using `helpers/build_response`

If you look at the source code for this example, we are doing a bunch of fancy date math (made
harder due to leap years, of course) and returning a response with a helper function appropriately
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
  condition in triggered you'll see some return statements, such as:

```python
if date_string.startswith('XXXX-'):
    return "missingYear"
```

When a string is returned from a callback, Lazysusan assumes this is a key to a response in
`states.yml`. If the error above was triggered the response would be synthesized from the
`missingYear` text above:

```yaml
text: Please say what day, month and year you were born.
```

As a reminder, the structure of yaml file for responses is completely driven by the required format
for an alexa response. There is zero translation / mutation done by Lazysusan

- One of the objects you have access to is a `session` object. In the call to `session.set` above we 
  are shoving a value into the session for the `DOB_KEY` value. You may use the session however you
  see fit...it's simply a key-value store provided for your use.


## Deployment and management

It may come as no big surprise that we opted to use [Serverless](https://serverless.com) for
managing out Lambda functions and other dependencies. This ended up being a really great choice
since Serverless will manage not only your Lambda functions but anything else that  is supported by
CloudFormation (which is almost everything).

During our client engagement an `sls deploy` would create, update or manage:

- Cloudwatch alarms for DynamoDB
- Cloudwatch alarms for Lambda function
- DynamoDB table
- DynamoDB table IOPs provisioning
- IAM roles for DynamoDB table access
- Lambda function for Alexa
- SNS topic
- SNS topic subscriptions

As of this writing managing Alexa Skills isn't nearly as easy.  The only way to manage your
interaction model and overall configuration is to fire up developer.amazon.com and plug things in
manually.  I know that Amazon is working on driving configuration of Alexa Skills programatically
but it's currently not there.

We've published a Docker image which has all of the requirement for writing Lazysusan applications
and managing them with Serverless:

https://hub.docker.com/r/joinspartan/serverless/

## Final results

Here's a little recording of the demo skill.  As you can hear, there are a lot of calculated valued
returned from the user's input. This shows the flexibility of the callback mechanism we've
implemented.

<audio controls src="/audio/age-calculator.mp3" type="audio/mpeg">
Your user agent does not support the HTML5 Audio element.
</audio>

Lazysusan provides other options to make building Alexa skills easier and more sophisticated
including:

- Pluggable support for using DynamoDB as a session store. This enables sessions to persist for
  longer than the standard eight seconds
- TTL support for sessions when using DynamoDB as a session store
- Support for restarting audio from the last stopped/paused position
- Marking a location in `states.yml` as **not** being a state to track. This is critical when
  receiving callbacks from Alexa during audio playback.
- Configurable logging levels to see request/responses in Cloudwatch

## Conclusion

Lazysusan makes building Alexa apps really really simple. In a future post I'll drill into some
more detail around the apis and things you may need to be aware of.

We've developed a few example applications which can be found [in the examples directory in our
Github repository](https://github.com/spartansystems/lazysusan/tree/master/examples). These are
great places to start exploring if you'd like to take Lazysusan for a spin or have a better
understanding of what the application code looks like.  These examples show a somewhat complex
skill such as the age calculator and some others which are driven almost exclusively from the
`states.yml` file with very very little Python code.
