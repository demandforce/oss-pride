# Convenience to compile css
compile.css:
	./node_modules/.bin/lessc --yui-compress src/stylesheets/screen.less > rendered/stylesheets/screen.css