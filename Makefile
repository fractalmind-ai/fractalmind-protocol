.PHONY: build test clean

build:
	cd contracts/protocol && sui move build --silence-warnings

test:
	cd contracts/protocol && sui move test --gas-limit 100000000

clean:
	rm -rf contracts/protocol/build
