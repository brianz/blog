all : clean
	hugo

clean:
	rm -rf public

prod : 
	hugo -d production

release :
	git push 
	git subtree push --prefix=production production master
