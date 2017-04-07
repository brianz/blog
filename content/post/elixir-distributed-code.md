+++
date = "2017-04-07T15:47:42-06:00"
title = "exixir distributed code"
tags = []
draft = true

+++


^Cbrianz@utah(master=)$ iex --sname utah --cookie sekrt  
ssh ubuntu@ec2-35-162-25-187.us-west-2.compute.amazonaws.com


services/ubuntu@ip-172-31-25-107:~$ curl http://169.254.169.254/latest/meta-data/public-ipv4/
172.31.25.107

iex(ubuntu@35.162.25.187)1> Node.self()
:"ubuntu@35.162.25.187"

Cbrianz@utah(master=)$ iex --name $(whoami)@$(hostname) --cookie sekrt 
Erlang/OTP 19 [erts-8.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false]
[dtrace]

Interactive Elixir (1.4.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(brianz@utah.local)1> Node.connect :"ubuntu@35.162.25.187"
true
iex(brianz@utah.local)2>


ubuntu@ip-172-31-25-107:~$ iex --name $(whoami)@$(curl http://169.254.169.254/latest/meta-data/public-ipv4/) --cookie sekrt
iex(ubuntu@35.162.25.187)1> Node.self()
:"ubuntu@35.162.25.187"


iex> ls = fn -> IO.puts(Enum.join(File.ls!, ",")) end
iex(brianz@utah.local)4> ls.()
.git,.gitignore
:ok
iex(brianz@utah.local)5> Node.list 
[:"ubuntu@35.162.25.187"]
iex(brianz@utah.local)6> List.first(Node.list)
:"ubuntu@35.162.25.187"
iex(brianz@utah.local)7> aws = List.first(Node.list)
:"ubuntu@35.162.25.187"
iex(brianz@utah.local)8> Node.spawn(aws, ls)
.sudo_as_admin_successful,.bashrc,.cache,.ssh,.profile,.bash_history,.bash_logout,erlang-solutions_1.0_all.deb
#PID<9160.93.0>
iex(brianz@utah.local)9>
