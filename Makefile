all : prod

prod :
	hugo -d production

release :
	git push
	git subtree push --prefix=production --squash production master

post :
	hugo new post/$(NAME).md
