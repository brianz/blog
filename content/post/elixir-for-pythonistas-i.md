+++
date = "2017-04-07T16:02:32-06:00"
title = "Elixir for Pythonistas part I"
draft = false
tags = [
    "elixir",
    "python",
]
+++

For the past many _many_ years my goto language has been Python. I've written all sorts of
applications using Python:

- Django web apps
- Client side GUI applications with PyQt
- Data science stuff with numpy, pandas, etc.
- Alexa applications
- Serverless systems and web APIs
- Microservices and a [microservice library](https://github.com/brianz/servant)
- Many backend services to power various SAAS and non-SAAS applications

Whenever there is some type of problem I need to solve programatically, I reach for Python. Sure,
I can be effective in other languages, but by and large, I'm a Python guy.

## The problem

Not too long ago I counted it up...over the past seven years I've worked at three companies all
which had these things in common:

- Python web stacks
- Django
- Spaghetti code which is (extremely) hard to reason about and evolve

Where I landed many months ago was being unhappy and unsatisfied with Django and all of the
wrong decisions which are easy to make when using it to build a web application. I don't think 
this is necessarily a problem with Python or
Django themselves, however I do feel that both Python and Django enable developers to make
poor decisions when architecting a web application. Maybe to frame this in a more positive light,
it's _hard_ to make _good_ decisions when writing a large Django application. 
If anything, Django is an enabler (and guilt by association, Python).  

Node and JavaScript are probably even worse and more enabling at bad
patterns.  Rails and Ruby, yes...although with Rails there are such strong conventions around the
"Rails way" that at least people don't have to look very far to figure out the "right" way of doing
something (don't take this as an endorsement...I believe this creates a community which freaks out
if they don't have an existing pattern to copy/paste).

Django makes it very easy to couple
different parts of your application together, in spite of your best intentions.  I would venture
to say that most of this comes down to the ORM.  Want to import some models from a completely 
different part of your application and start firing off queries?  No problem.  Want to write a 
triple nested loop over a queryset and fire off 1M+ DB statements for related records? Sure!
(Note, I _have_ seen 
this done and spent weeks fixing it). Need some data in your template?  Just shove an `all()`
queryset in your template and iterate to your hearts content.  This works *great* when you have 10
rows in your table, not so much when you have 1M rows.

Where I'm going is that I said to myself 

>   There must be a better way

## The (possible) solution

Slowly, I've been digging into Elixir. Why?  I wanted to learn and use a functional language to see
if it would solve some of the problems I've hit with imperative languages like Python. Here are a
few other things which helped point me in the Elixir direction:

- Erlang VM (BEAM)
    - Ability for some massive concurrency
    - Built-in messaging (hello microservices)
    - Possibility of hot-loading new code
- Picking up lots of steam mostly from the Rails community. But the bottom line is that the "there
  must be a better way" theme is shared from different communities
- Ringing endorsements from [other web influencers](https://pragprog.com/book/elixir/programming-elixir)

Of course, I could be wrong...Elixir could _not_ be the solution I'm looking for.  However, I do
know that I ~~want~~ need a new way of building web applications and microservices. Here, I'd like to
do a series of posts about exploring and learning Elixir from the perspective of a Python
developer.


## Elixir for Pythonistas

I would rather not do a series on Elixir syntax, but it's inevitable that I'll need to cover some
things.  There are plenty of resources online about the Elixir language itself...the official docs are quite
good. I'll recommend the following if you'd like to start from zero:

- http://elixir-lang.org/crash-course.html
- My [Elixir Fundamentals talk from the Boulder Elixir
  Meetup](https://speakerdeck.com/brianz/elixir-fundamentals)
- [Programming Elixir by Dave Thomas](https://pragprog.com/book/elixir/programming-elixir)

Very quickly I'd like to get rolling into the distributed nature of Elixir/Erlang, which I currently
don't know many details about. Let's start with some basics.

_NOTE_: I will say things like, "unlike Python..." due to the fact that I'm writing from the
Pythonistas perspective. In reality, these comparisons should be made with procedural or OO
languages. Here, I'll just use Python to represent that class of languages unless I'm discussing
something truly unique to Python.

## Immutability and Variables

Unlike Python, variables are immutable.  For example:

```python
>>> d = {'name': 'bz', 'height': 67}
>>> some_function(d)
```

Now, what is the value of `d` without knowing the details of `some_function`? It's impossible to
answer this. The reason is that you're passing the `d` dictionary _by reference_, which means
`some_function` can mutate any mutable object it's given (lists, sets, class, instances, etc.)

What about Elixir:

```elixir
iex> d = %{name: "brian", height: 67}
%{height: 67, name: "brian"}    
iex> some_function.(d)
%{height: 67, name: "Fred"}  
```

You'll notice that the Elixir shell spits out values while it's evaluating commands. Here, we can
see that `some_function` is replacing the `name` key with `"Fred"`. But, look at `d` after all of
this.

```elixir
iex> d
%{height: 67, name: "brian"} 
```

That's right...our original map (`dict` in Python terms) is unchanged. That's pretty great. All of
a sudden it become _much_ easier to reason about what your program is doing since we're dealing
with _data_ rather than _behavior_.

So, if we really did want to update our map, how would we handle this? We'll simply _reassign_ the
`d` variable to the _results_ returned from `some_function`:

```elixir
iex> d = some_function.(d)                                                     │:yes
%{height: 67, name: "Fred"}
iex> d
%{height: 67, name: "Fred"}
```

Let's just try to manhandle this thing:

```elixir
iex> Map.put(d, :name, "sam")
%{height: 67, name: "sam"}  
iex> d
%{height: 67, name: "Fred"}  
```

Doh! You cannot mutate an existing object. You will always be *creating new* objects. What you do
with those is up to you.

I like this very much. Tracing code is now a matter of looking at what is occurring to the data,
rather than trying to track down what code is changing this class instance, dict, etc from under me. 
There are other implications and advantages to immutable data types I won't cover here.

## Pattern matching

You'll hear the term "pattern matching" a lot with Elixir (and I'd guess, with Erlang). This will
likely be the biggest shift in thinking when coming from Python to Elixir, but I think it's easy to
understand as you work with it.

Above, we seemingly assigned a map to a variable `d`. Don't be fooled here...what we did was
pattern match the left side of the equality operator with the right side. What does that mean
exactly?

Elixir will take an expression and attempt to match whatever is on the left side of the equals sign
with that is on the right side, in this case, what is happening is that Elixir is matching the
variable `d` with the map on the right:

```elixir
iex> d = %{name: "brian", height: 67}
```

There is one item on the left, `d` and one on the right, `%{name: "brian", height: 67}`...so `d`
ends up being pointed at this map.

Let's look an Elixir tuple:

```elixir
iex> tup = {1, 2, 3}
{1, 2, 3}
```

Makes sense.  But we can also do this:

```elixir
iex> {a, b, c} = {1, 2, 3}
{1, 2, 3}
iex> a
1
iex> b
2
iex> c
3
```

What is happening here is that Elixir attempt to match the left and right side. Because we have the
same number of arguments, the right side values are assigned to the left side variables. This is
"unpacking" in Python...we can do the same thing so you may not be very impressed (yet):

```python
>>> tup = (1, 2, 3)
>>> (a, b, c) = tup
```

Going back to our Map / dict, how would you extract the value of a dictionary key and assign it
into a variable?

```python
>>> d
{'name': 'bz', 'height': 67}
>>> myheight = d.get('height')
>>> myheight
67
```

With Elixir, we can extract a value by matching a key on the left with the right:

```elixir
iex> %{height: myheight} = d
%{height: 67, name: "Fred"}
iex> myheight
67
```

Wow...so we're saying, "Elixir, please match a Map with a key of "height" on the left with whatever
is on the right. If that matches, assign the variable `myheight` to whatever the value is on the
right side"

That may seem trivial now, but it's the underpinning of Elixir and helps preventing code like this:

```python
def view_function(request, user, reports=None):
    reports = reports or {}
    for key, f in reports.items():
        perm_key = 'user.can_view_%s_report' % key 
        if key == 'unsigned' and not user.sig_on:
            continue
        if key in ('foo', 'br') and not user.new_user:
            continue
        if key in ('payments', 'all', 'client') and not user.track:
            continue
        if key == 'authorizations' and not user.cms_user:
            continue
        if key == 'totalcostof' and not user.is_foobar:
            continue
        if key == 'premiums' and not \
                (user.some_attribute and request.user.admin and request.user.admin.is_manager):
            continue
```
				
In Elixir, all of these conditionals could be handled with pattern matching, resulting in multiple functions 
that handle some specific part of our domain logic. The code above becomes very very hard to reason
about, test and debug. Sure, this can be refactored, but to my previous points because it's
_possible_ to write code like this, it's inevitable that people will.

## Conclusion

That's it for now. I hope to continue on this path of exploring Elixir and writing about the
highlights I find interesting.
