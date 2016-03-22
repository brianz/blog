all: clean
	hugo

clean:
	rm -rf production
	rm -rf public

prod clean: 
	hugo -d production
