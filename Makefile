.PHONY: render push clean

DEVICEID := $(shell pixlet devices  | cut -f1 -d" ")

all: lint render push serve

lint: 
	pixlet lint --fix  evcc.star
	pixlet format evcc.star
	# pixlet check -r . # FIXEME: manifest is needed

render:
	pixlet render evcc.star
push:
	pixlet push $(DEVICEID) evcc.webp

serve:
	pixlet serve evcc.star

clean:
	rm -f evcc.webp
