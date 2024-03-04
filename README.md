## CZUSD Gate V2

Exchange CZUSD for BNB, with dynamic fees based on the available collateral and recent volumes.

## Official Deployments

BSC:0xe3CB4dB558fB7BaF59eC71F5B178be02726ab265

## deployment

The admin address is hardcoded in the deployment script.

forge script script/DeployCzusdGateV2.s.sol:DeployCzusdGateV2 --broadcast --verify -vvv --rpc-url https://rpc.ankr.com/bsc --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
