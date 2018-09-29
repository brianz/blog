---

title: "DB Connection Pooling with SQLAlchemy and Serverless"
date: 2018-08-17T16:02:53-06:00
draft: true
tags: [
    "aws",
    "serverless",
    "rds",
    "python"
]

---

## SQLAlchemy Helpers

While not 

I wrote a small mixin class and some helpers which I use for all SQLAlchemy projects. It adds several things which make
working with models easier, as well as creating tables, dropping tables (during tests) as well as
transaction management. You can see the `__init__.py` and `mixins.py` 
files [in this gist](https://gist.github.com/brianz/feedc052d64212b6576fa42dd6dcadab). I'll put
these files into a `db/` directory which also include my models. Normally, I'll create a
`BaseModel` which looks something like the following:

```python
from .mixins import ModelMixin, Base

class BaseModel(ModelMixin):
    """Base model for all of our Model/tables"""
    id = Column(BigInteger, primary_key=True)
  
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text('NOW()'),
    )   
    updated_at = Column(
        DateTime,
        nullable=False,
        server_default=text('NOW()'),
        onupdate=utcnow,
    )   
```

Concrete class may then just subclass this model as well as the declaritive Base class which I
conviently instantiate in `mixins.py`. Below the `BaseModel` I could add

```python
class User(BaseModel, Base):
      """Model for the clients table."""
      email = Column(String(128), nullable=False)
      name = Column(String(128), nullable=False)
```






## Pooling choices

By default, SQLAlchemy will use a pool of five connections to your database. In many situations,
this makes a lot of sense. In others, not so much. The default pooling implementation is
[`QueuePool`](https://docs.sqlalchemy.org/en/latest/core/pooling.html#sqlalchemy.pool.QueuePool).

There are many other choices and the ones I'll discuss here are:

- [`NullPool`](https://docs.sqlalchemy.org/en/latest/core/pooling.html#sqlalchemy.pool.NullPool)
- [`StaticPool`](https://docs.sqlalchemy.org/en/latest/core/pooling.html#sqlalchemy.pool.NullPool)

## NullPool

Quite some time ago, when working on a microservice I started using SQLAlchemy's
[NullPool](https://docs.sqlalchemy.org/en/latest/core/pooling.html#sqlalchemy.pool.NullPool). In
a microservice architecture this was a good choice since requests to my service were coming in from
a web application which had quite a bit of concurrency. Additionally, each HTTP request would only
ever make a single request to my microservice. More precisely, there was a 1-to-1 correlation
between HTTP requests to the main applicaiton and requests to my microservice. Pooling multiple
connections in my microservice was uncessary (unless the pool size was one).

I was fearful of running out of connections, so used `NullPool`. With this configuration, zero
pooling occurs and database connections are closed rather than pooled. Everyone worked great here
and my microservice performed well while never sucking up too many DB connections.

<!-- I began using `NullPool` with my Serverless projects as well. It took me a while to figure out that -->
<!-- this is a bad idea unless you are regimented about cleaning up your connections. -->

## Problems with NullPool



QueuePool
-------------

Without the session commit, table updates are blocked
With the session commit, table updates are blocked


20 concurrency, queue pool with commit

```
Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  16.26 secs
Data transferred:               0.53 MB
Response time:                  0.43 secs
Transaction rate:              12.30 trans/sec
Throughput:                     0.03 MB/sec
Concurrency:                    5.26
Successful transactions:         200
Failed transactions:               0
Longest transaction:            5.94
Shortest transaction:           0.18

Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  11.85 secs
Data transferred:               0.53 MB
Response time:                  0.27 secs
Transaction rate:              16.88 trans/sec
Throughput:                     0.04 MB/sec
Concurrency:                    4.49
Successful transactions:         200
Failed transactions:               0
Longest transaction:            0.54
Shortest transaction:           0.18

Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  12.02 secs
Data transferred:               0.53 MB
Response time:                  0.32 secs
Transaction rate:              16.64 trans/sec
Throughput:                     0.04 MB/sec
Concurrency:                    5.27
Successful transactions:         200
Failed transactions:               0
Longest transaction:            0.65
Shortest transaction:           0.20


```

20 concurrency, null pool, commit
-----------------------------------

```
Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  18.46 secs
Data transferred:               0.53 MB
Response time:                  0.52 secs
Transaction rate:              10.83 trans/sec
Throughput:                     0.03 MB/sec
Concurrency:                    5.67
Successful transactions:         200
Failed transactions:               0
Longest transaction:            6.25
Shortest transaction:           0.22


Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  13.53 secs
Data transferred:               0.53 MB
Response time:                  0.35 secs
Transaction rate:              14.78 trans/sec
Throughput:                     0.04 MB/sec
Concurrency:                    5.13
Successful transactions:         200
Failed transactions:               0
Longest transaction:            0.69
Shortest transaction:           0.23

Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  12.95 secs
Data transferred:               0.53 MB
Response time:                  0.35 secs
Transaction rate:              15.44 trans/sec
Throughput:                     0.04 MB/sec
Concurrency:                    5.38
Successful transactions:         200
Failed transactions:               0
Longest transaction:            0.65
Shortest transaction:           0.24
```


20 concurrency, null pool, no-commit
-------------------------------------

```
Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  16.44 secs
Data transferred:               0.53 MB
Response time:                  0.48 secs
Transaction rate:              12.17 trans/sec
Throughput:                     0.03 MB/sec
Concurrency:                    5.85
Successful transactions:         200
Failed transactions:               0
Longest transaction:            6.19
Shortest transaction:           0.18

Transactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  11.85 secs
Data transferred:               0.53 MB
Response time:                  0.31 secs
Transaction rate:              16.88 trans/sec
Throughput:                     0.04 MB/sec
Concurrency:                    5.20
Successful transactions:         200
Failed transactions:               0
Longest transaction:            0.67
Shortest transaction:           0.19

nsactions:                    200 hits
Availability:                 100.00 %
Elapsed time:                  12.20 secs
Data transferred:               0.53 MB
Response time:                  0.29 secs
Transaction rate:              16.39 trans/sec
Throughput:                     0.04 MB/sec
Concurrency:                    4.76
Successful transactions:         200
Failed transactions:               0
Longest transaction:            0.60
Shortest transaction:           0.17
```


I've been building 


When bumping up the pool size, it stays at 1 connection. This is b/c the Pool implementation is lazy.



```
START RequestId: 1edb1196-a265-11e8-a30c-efcf644e88d5 Version: $LATEST
Connected to: postgresql://root:asfasfsad3123aa@crop1zzyjy6whi.cwc2advv6jap.us-west-2.rds.amazonaws.com:5432/cupping_log
END RequestId: 1edb1196-a265-11e8-a30c-efcf644e88d5
REPORT RequestId: 1edb1196-a265-11e8-a30c-efcf644e88d5	Duration: 600.43 ms	Billed Duration: 700 ms Memory Size: 128 MB	Max Memory Used: 58 MB	

START RequestId: 5b8e5039-a265-11e8-b06e-875667dec4ed Version: $LATEST
END RequestId: 5b8e5039-a265-11e8-b06e-875667dec4ed
REPORT RequestId: 5b8e5039-a265-11e8-b06e-875667dec4ed	Duration: 312.64 ms	Billed Duration: 400 ms Memory Size: 128 MB	Max Memory Used: 58 MB	

START RequestId: 5c73a7a4-a265-11e8-b564-477f8bcae48a Version: $LATEST
END RequestId: 5c73a7a4-a265-11e8-b564-477f8bcae48a
REPORT RequestId: 5c73a7a4-a265-11e8-b564-477f8bcae48a	Duration: 127.91 ms	Billed Duration: 200 ms Memory Size: 128 MB	Max Memory Used: 58 MB	

START RequestId: 7e9be59f-a266-11e8-a000-0146179bc902 Version: $LATEST
END RequestId: 7e9be59f-a266-11e8-a000-0146179bc902
REPORT RequestId: 7e9be59f-a266-11e8-a000-0146179bc902	Duration: 311.02 ms	Billed Duration: 400 ms Memory Size: 128 MB	Max Memory Used: 58 MB	

START RequestId: 7f626a5c-a266-11e8-9585-8d99dc1af95e Version: $LATEST
END RequestId: 7f626a5c-a266-11e8-9585-8d99dc1af95e
REPORT RequestId: 7f626a5c-a266-11e8-9585-8d99dc1af95e	Duration: 131.12 ms	Billed Duration: 200 ms Memory Size: 128 MB	Max Memory Used: 58 MB	

START RequestId: 93475731-a266-11e8-a802-2bfac04bfcda Version: $LATEST
END RequestId: 93475731-a266-11e8-a802-2bfac04bfcda
REPORT RequestId: 93475731-a266-11e8-a802-2bfac04bfcda	Duration: 486.48 ms	Billed Duration: 500 ms Memory Size: 128 MB	Max Memory Used: 58 MB	
```
