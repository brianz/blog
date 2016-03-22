FROM golang

RUN go get -v github.com/spf13/hugo

RUN apt-get update -y
RUN apt-get install -y \
        python-pip \
        python-dev \
        build-essential && \
    pip install --upgrade pip 
RUN pip install pygments

RUN mkdir /blog

RUN cd /blog && \
    hugo new site brianz

WORKDIR /blog/brianz

#RUN cd themes && git clone git@github.com:dim0627/hugo_theme_robust.git
