.PHONY: render push clean

all: render push

render:
	pixlet render evcc.star
push:
	pixlet push namely-impeccable-vivacious-pitta-02f evcc.webp
clean:
	rm -f evcc.webp
