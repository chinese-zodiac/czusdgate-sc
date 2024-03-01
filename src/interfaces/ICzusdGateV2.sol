// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.19;

interface ICzusdGateV2 {
    function sellBnbForCzusd(address _to) external payable;
    function buyBnbWithCzusd(uint256 _bnbToBuy, address payable _to) external;
    function sellCzusdForBnb(
        uint256 _czusdToSell,
        address payable _to
    ) external;
    function buyCzusdWithBnb(uint256 _czusdToBuy, address _to) external payable;
    function sellWbnbForCzusd(uint256 _bnbToSell, address _to) external;
    function buyWbnbWithCzusd(uint256 _bnbToBuy, address _to) external;
    function sellCzusdForWbnb(uint256 _czusdToSell, address _to) external;
    function buyCzusdWithWbnb(uint256 _czusdToBuy, address _to) external;
}
