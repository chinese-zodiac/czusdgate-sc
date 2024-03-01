## TCu29 Sale

Allows purchase of TCu29 up to $10,000 in one transaction, with no slippage.

## Official Deployments

BSC:0x035240D340450b50acd7b1b104c2F8b727d7bB76

## deployment

The admin address is hardcoded in the deployment script.

forge script script/DeployCzusdGateV2.s.sol:DeployCzusdGateV2 --broadcast --verify -vvv --rpc-url https://rpc.ankr.com/bsc --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
