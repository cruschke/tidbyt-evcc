.PHONY: render push clean

DEVICEID := $(shell pixlet devices  | cut -f1 -d" ")

all: render push serve

render:
	pixlet render evcc.star
push:
	pixlet push $(DEVICEID) evcc.webp

serve:
	pixlet serve -w evcc.star

clean:
	rm -f evcc.webp
