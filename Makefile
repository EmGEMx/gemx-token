# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Update dependencies
setup			:; make update-libs ; make install-deps
update-libs		:; git submodule update --init --recursive
install-deps	:; yarn install --frozen-lockfile

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

build         	:; forge build
clean        	:; forge clean
# Remove modules
remove          :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add .
install	        :; forge install OpenZeppelin/openzeppelin-contracts --no-commit && OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit && forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit && forge install foundry-rs/forge-std --no-commit
lint          	:; yarn run lint
test          	:; forge test
test-vvvv       :; forge test -vvvv
test-gasreport 	:; forge test --gas-report
test-fork       :; forge test --fork-url ${ETH_RPC_URL} -vvv
coverage        :; forge coverage --report debug > coverage-report.txt
snapshot        :; forge snapshot
format          :; forge fmt
anvil           :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1
fork	        :; anvil --fork-url ${FORK_ETH_RPC_URL} --fork-block-number ${FORK_BLOCK_NUMBER}
watch		  	:; forge test --watch src/ 

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployToken.s.sol:DeployToken $(NETWORK_ARGS)