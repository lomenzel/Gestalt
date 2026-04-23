APP_NAME ?= app

all: $(APP_NAME)

$(APP_NAME): main.cpp
	$(CXX) main.cpp -o $(APP_NAME) -lapp

install: $(APP_NAME)
	mkdir -p $(out)/bin
	install -m755 $(APP_NAME) $(out)/bin/$(APP_NAME)