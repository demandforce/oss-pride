default : render
.PHONY : clean render

render : clean html/index.html html/stylesheets html/images

clean :
	rm -rf html
	rm -rf public

# Build all the assets in the html directory
html/index.html : render.coffee src/index.eco
	mkdir -p html
	./node_modules/.bin/coffee render.coffee > html/index.html
html/stylesheets : src/stylesheets/screen.less
	mkdir -p html/stylesheets
	./node_modules/.bin/lessc --yui-compress src/stylesheets/screen.less > html/stylesheets/screen.css
html/images: src/images/old_mathematics.png
	mkdir -p html/images
	cp src/images/old_mathematics.png html/images/old_mathematics.png


# Update the public repository
public : render
	git clone git@github.com:demandforce/demandforce.github.com.git public
	mv html/* public/

publish :
	cd public
	git add --all
	git commit -m "Update for $(date)"
	git push
