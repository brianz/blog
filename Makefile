all : clean
	hugo

clean:
	rm -rf public

prod : 
	hugo -d production

release :
	git subtree push --prefix=production production master
