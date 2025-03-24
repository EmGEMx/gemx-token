# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

build         	:; forge build
clean        	:; forge clean
remove          :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add .
install	        :; forge install foundry-rs/forge-std --no-commit && \
                   forge install OpenZeppelin/openzeppelin-contracts --no-commit && \
                   forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit && \
                   forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit && \
                   forge install smartcontractkit/chainlink-brownie-contracts --no-commit && \
                   forge install OpenZeppelin/openzeppelin-community-contracts --no-commit
.PHONY: test
test          	:; forge test
test-vvv        :; forge test -vvv
test-gasreport 	:; forge test --gas-report
test-fork       :; forge test --fork-url ${ETH_RPC_URL} -vvv
.PHONY: coverage
coverage        :; mkdir -p ./coverage && forge coverage --no-match-coverage "script|test" --report lcov --report-file coverage/lcov.info && genhtml coverage/lcov.info -o coverage --branch-coverage
snapshot        :; forge snapshot
format          :; forge fmt
anvil           :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing #--block-time 1
fork	        :; anvil --fork-url ${FORK_ETH_RPC_URL} --fork-block-number ${FORK_BLOCK_NUMBER}
watch		  	:; forge test --watch src/
slither         :; slither src/EmGEMxToken.sol --triage-mode

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

COMMON_DEPLOY_ARGS := --keystore keystores/emgemx_deployer --broadcast --slow --verify -vvvv

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := $(COMMON_DEPLOY_ARGS) --rpc-url $(SEPOLIA_RPC_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) 
else ifeq ($(findstring --network fuji,$(ARGS)),--network fuji)
	NETWORK_ARGS := $(COMMON_DEPLOY_ARGS) --rpc-url $(AVALANCHE_FUJI_RPC_URL) --etherscan-api-key "verifyContract" --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan'
else ifeq ($(findstring --network avalanche_mainnet,$(ARGS)),--network avalanche_mainnet)
	NETWORK_ARGS := $(COMMON_DEPLOY_ARGS) --rpc-url $(AVALANCHE_MAINNET_RPC_URL) --etherscan-api-key "verifyContract" --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan'	
endif

deploy:
	@forge script script/DeployToken.s.sol:DeployToken $(NETWORK_ARGS)