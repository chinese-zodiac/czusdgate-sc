// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CzusdGateV2.sol";

contract DeployCzusdGateV2 is Script {
    function run() public {
        vm.broadcast();
        new CzusdGateV2(
            IERC20MintableBurnable(0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70),
            WETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)),
            AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE),
            address(0x745A676C5c472b50B50e18D4b59e9AeEEc597046)
        );
    }
}
