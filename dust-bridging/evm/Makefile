include env/testing.env

.PHONY: all test build dependencies clean integration-test

all: build

unit-test: build
	forge test -vv

build: dependencies
	forge build
	yarn build-types

dependencies: node_modules lib/forge-std lib/openzeppelin-contracts lib/openzeppelin-contracts-upgradeable

clean:
	forge clean
	rm -rf node_modules anvil.log lib forge-scripts ts-types

.PHONY: integration-test
integration-test: dependencies build
	bash shell-scripts/run_integration_tests.sh

.PHONY: test
test: unit-test integration-test

node_modules:
	yarn

lib/forge-std:
	forge install foundry-rs/forge-std@v1.4.0 --no-git --no-commit

lib/openzeppelin-contracts:
	forge install openzeppelin/openzeppelin-contracts@v4.8.1 --no-git --no-commit

lib/openzeppelin-contracts-upgradeable:
	forge install openzeppelin/openzeppelin-contracts-upgradeable@v4.8.1 --no-git --no-commit
