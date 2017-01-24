.PHONY : prod release post


prod :
	hugo -d production

post :
	hugo new post/$(NAME).md
