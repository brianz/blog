all : clean
	hugo

clean:
	rm -rf public

prod : 
	hugo -d production
