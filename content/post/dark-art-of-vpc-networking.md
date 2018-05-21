---

title: "The Dark Art of AWS VPC Networking"
date: 2018-05-12T10:49:15-06:00
draft: true
tags: [
    "aws",
    "serverless",
    "vpc",
]

---


It's been quite some time since a blog post went up here. The reason for this is mainly due to my
book with Packt Publishing,
[Serverless Design Patterns and Best Practices](https://www.packtpub.com/application-development/serverless-design-patterns-and-best-practices).
Happily I can say that it's published and I can turn my technical attention to other things.

In chapters [2](https://github.com/brianz/serverless-design-patterns/tree/master/ch2) and 
[3](https://github.com/brianz/serverless-design-patterns/tree/master/ch2), I walk 
through setting up serverless REST and GraphQL APIs, respectively. Both patterns use RDS as a
backend datastore. One thing which is arguably overly complex with this setup is granting your Lambda
functions network access to RDS. I covered the details of this in 
[a previous post]({{< ref "accessing-vpc-resources-with-lambda.md" >}}). If you follow along in
that post you'll learn how to allow inbound network access to an RDS Postgres instance on port 5432. In the 
[Conclusion]({{< ref "accessing-vpc-resources-with-lambda.md#conclusion" >}}) I make a note:

> Also, if your Lambda function needed to speak to an external API on the public internet it would
> not work. This can be solved as well using NAT Gateways, which will be a topic for another time.

In this post I'd like to walk through an entire setup focused around VPC networking, private/public
subnets and NAT Gateways. The focus will be using my previous scenario, where a Lambda function
needs access to an RDS instance _as well as_ the public internet.
At the end of all this you should have a good understanding of why all of
this complexity exists and a template to set all of this up. There are tons of details I won't be
able to cover, but this exact scenario is quite common and one worth explaining in detail.

**Note:** _I am not a networking expert! Most of the nuts and bolts of networking which I know
come from setting up VPCs on AWS. Advanced networking topics get quite complex in a hurry and
this is meant as an intro for developers so that they can work effectively on AWS, specifically
when building serverless systems._

## VPCs

What exactly is a Virtual Private Cloud from AWS and why do you care about it? In short, a VPC is a
virtual network for your AWS resources which lays out the foundation for any type of system you're
building. Other hosting providers by default will open your VMs or other resources to the world,
meaning if you create a virtual machine all port may be open to the entire internet. 
Throw up some virtual machine, ssh into
it, access a MySQL database, etc. When all ports are open and a machine is exposed to the public
internet, development is easy. While this is very simple, it's also very dangerous from a security
perspective. With a VM or other machine exposed to public internet, you're relying solely on
credentials for protection and hoping there are no security vulnerabilities in the software which
you're running.

**Note:** _I haven't used other hosting providers in a long time, so this may or may not be true
for various providers. I know with Rackspace Cloud Servers this used to be the case. A Rackspace
Cloud Server would, by default, be exposed to the public internet and allow all ports to be exposed
to the outside world. It was an exercise for the developer to use something like IPTables to lock
down their system tighter._

Any new AWS account will come pre-configured with what is called a "default VPC". Default VPCs 
come with a myriad of components which are required to make any VPC useful. You may read all about 
your [Default VPC here](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html).

If you are working with a brand new AWS account and launch an EC2 instance, it's deployed within
your default VPC. Many people who are new to AWS have no idea this is happening. Later, when
deploying other resources which need a VPC, such as an RDS instance, they utilize the default VPC
as well. This comes in handy, since you can quickly get up and running. However, when it's time to
deploy something for _real_, you can get into trouble. For example, it's a bad idea to setup a
production system using your default VPC, simply for the fact that any other resource you deployed
would go into the same VPC and possibly interfere with your production system.

OK, so that still doesn't explain what a VPC is. A VPC is a virtual network which will
allocate private IP address for resources deployed in it, among other things. A VPC will allocate a
private IP address to _every_ resource inside of it. You can configure some resources in a VPC to
have _public_ IP addresses as well. There are several advantages to using VPCs. The most important
for this discussion are:

- Inter-VPC traffic can be routed on the private address space. Because traffic doesn't travel
  across the public Internet it's faster, more secure, and free.
- You may deploy resources in a VPC such that they are completely isolated from the public
  Internet. This is good for security reasons.

A VPC requires a range of IP address from which it will allocate IPs to any system deployed within
it.  With a CIDR of `10.0.0.0/16` any system deployed in the
VPC will get an IP address in the range of `10.0.0.1` to `10.0.255.255`. That equates to
`65,534` unique IP4 addresses, which is a lot of AWS resources. Since you define this CIDR, you can
adjust it to fit your needs. For this post, I'll use an example VPC with a CIDR of `10.0.0.0/16`

**VPCs span Availability Zones and are defined in a single Region.**
When you create a VPC, you will be deploying it to a single geographical AWS Region 
(i.e., `us-west-2`, `us-east-1`, etc.) Your VPCs will, by default, span all of the Availability 
Zones within the region which it's deployed. 
This is important to keep in mind as we
discuss subnets, high availability an general architecture with AWS VPCs. Availability Zones
themselves are stand-alone physical systems in a given geographical region which are networked together. 
They are designed such that if one AZ goes down, other AZs in the same geographical region will not 
be affected. That is the promise from AWS, at least. &#x1F601;


## Subnets, public vs. private

Within a VPC, you may define sub-regions of the network. These are subnets. Subnets use CIDR ranges
to define the range of IP addresses which they will use to when something new is deployed within
them. Using the example from above, a VPC with a CIDR of `10.0.0.0/16` would need subnets which have 
the form:

- `10.0.1.0/24`
- `10.0.2.0/24`
- `10.0.8.0/22`

These are just examples...there are many may more examples. The mask at the end of a CIDR 
(i.e., `/8`, `/16`, `/22`, `24`) determines the range of your
subnet's IP addresses and ultimately how many resources may fit into a subnet. CIDRs are really 
just bit math, which I'll skip.

There are two flavors of subnets, private and public. There isn't any thing special about the IP
range and public vs. private...it's entirely up to you to configure these. So, what exactly are 
the differences? This definition come straight from the [AWS docs about VPCs and
Subnets](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#vpc-subnet-basics).

> If a subnet's traffic is routed to an internet gateway, the subnet is known as a public subnet. 
>
> If a subnet doesn't have a route to the internet gateway, the subnet is known as a private subnet.

Let's drill into that.


### Public subnet routing

A public subnet routes public outbound traffic through an 
[Internet Gateway](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Internet_Gateway.html), 
which is a system
that AWS manages for you. Any traffic with a destination of `10.0.0.0/16` will be routed
locally, using VPC-internal routing. For traffic with any other destination, routing will go
through the Internet Gateway. This routing is transparent to you and allows your resource to contact
the public internet.

If we were to look at the Routing Table for a Public Subnet, it would look like this:

Destination   | Target
--------------|--------------
10.0.0.0/16   | local
0.0.0.0/0     | igw-794bb61d

One important thing to note here is that any resource in a public subnet can reach external
resourced _provided they have a public IP address_. This is noted right alongside the [docs
referenced above](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#vpc-subnet-basics):

> If you want your instance in a public subnet to communicate with the internet over IPv4, it must have
> a public IPv4 address or an Elastic IP address (IPv4).

So, if you launch an EC2 instance in a public
subnet, and that instance **doesn't** have a public IP address, it won't be able to communicate with 
the public internet.

### Private subnet routing

A private subnet doesn't route traffic through an internet gateway, which means that it cannot 
connect to any external resources. It's entirely possible for you to create a subnet which routes
`10.0.0.0/16` traffic within your VPC without any problems, using the internal networking. However,
if a system on this subnet wanted to connect to the outside world, there would be no route for it
to get out.

The Route Table for a Private Subnet _without_ network access would look like the following:

Destination   | Target
--------------|--------------
10.0.0.0/16   | local

Just as a private subnet resource can't get _out_, nothing from the outside world can
get _in_, either. Worried about something hacking into your Postgres RDS instance or your Redis
cluster? A best practice is to put systems like this in your private subnets. Now, you needn't worry
(as much) about someone hacking into them from the outside. Placing resources into a private subnet means
that there is practically no risk of someone hacking directly into your database from the outside
world. From a networking perspective, it's impossible to connect to private subnet systems from _outside_ 
your VPC.

So, given the case that we have an RDS instance on private subnets and a Lambda function which
needs to communicate with it, what do we do? My 
[previous post]({{< ref "accessing-vpc-resources-with-lambda.md" >}}) discusses how to set that up.
But what do we do when our Lambda function needs to communicate with RDS _and_ the public internet?
That's the whole point of this post.

The answer is, change the Route Table to route outbound traffic through a 
[NAT Gateway](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-nat-gateway.html).


## NAT Gateways

A NAT Gateway is a resource managed by AWS which does Network Address Translation (NAT) for us, and also
provides a public Elastic IP address. Once we have a NAT Gateway for a given AZ, we need to setup
our private subnets to use them. This change consists of adding an entry to our Private Subnet's
Route Table, to route any non-internal traffic through the NAT:

Destination   | Target
--------------|--------------
10.0.0.0/16   | local
0.0.0.0/0     | nat-2351837b46c56b865

With this small change, anything in our Private Subnets can:

- Communicate within our VPC's Private _or_ Public Subnets resources on the local network using
  private IPs
- Communicate with the outside world via the NAT Gateway

Another interesting result of this change is that our Lambda functions will have a fixed _inbound_
IP address when connected to external resources. That IP address will be the IP of our NAT Gateway,
which typically is an Elastic IP.  This has the added benefit
of giving our Lambda functions (mostly) static IPs if you even face the situation where IPs need to
be white listed.

**Note:** _I'm working on a project now where we need to talk to the Salesforce API. Every IP we connect
from needs to be white listed. NAT Gateways is our solution to this when talking to Salesforce via
Lambda functions._

## Lambda functions in a private subnet




## Conclusion
