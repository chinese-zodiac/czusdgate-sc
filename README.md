## CZUSD Gate V2

Exchange CZUSD for BNB, with dynamic fees based on the available collateral and recent volumes.

## Official Deployments

BSC:0x035240D340450b50acd7b1b104c2F8b727d7bB76

## deployment

The admin address is hardcoded in the deployment script.

forge script script/DeployCzusdGateV2.s.sol:DeployCzusdGateV2 --broadcast --verify -vvv --rpc-url https://rpc.ankr.com/bsc --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
