.PHONY: render push clean

DEVICEID := $(shell pixlet devices  | cut -f1 -d" ")

all: render push

render:
	pixlet render evcc.star
push:
	pixlet push $(DEVICEID) evcc.webp
clean:
	rm -f evcc.webp
