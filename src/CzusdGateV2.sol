// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.19;

import {ICzusdGateV2} from "./interfaces/ICzusdGateV2.sol";
import {IERC20MintableBurnable} from "./interfaces/IERC20MintableBurnable.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {WETH} from "@solmate/tokens/WETH.sol";

contract CzusdGateV2 is ICzusdGateV2, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20MintableBurnable public immutable CZUSD; //0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70
    WETH public immutable WBNB; //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
    AggregatorV3Interface public immutable priceFeed; //0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE

    uint256 public targetCollateralUsd = 10_000 ether;

    uint256 public buyFeeBasis = 49;
    uint256 public sellFeeBaseBasis = 199;
    uint256 public sellFeeVolumeBasis = 250;
    uint256 public sellFeeVolumeSize = 750 ether;
    uint256 public sellFeeCollateralPer10PctBasis = 250;

    uint256 public volumePeriod = 24 hours;
    uint256 public volumeCap = 50_000 ether;

    uint256 public sellVolume;
    uint256 public lastSell;

    uint256 public buyVolume;
    uint256 public lastBuy;

    bool public isReceiving;

    constructor(
        IERC20MintableBurnable _czusd,
        WETH _wbnb,
        AggregatorV3Interface _bnbPriceFeed,
        address _owner
    ) Ownable(_owner) {
        CZUSD = _czusd;
        WBNB = _wbnb;
        priceFeed = _bnbPriceFeed;
    }

    receive() external payable {
        require(isReceiving, "Not receiving");
        isReceiving = false;
    }

    function sellBnbForCzusd(address _to) public payable {
        _buyUnwrapped(getCzusdOut(msg.value), msg.value, _to);
    }

    function buyBnbWithCzusd(uint256 _bnbToBuy, address payable _to) public {
        _sellUnwrapped(getCzusdIn(_bnbToBuy), _bnbToBuy, _to);
    }

    function sellCzusdForBnb(uint256 _czusdToSell, address payable _to) public {
        _sellUnwrapped(_czusdToSell, getBnbOut(_czusdToSell), _to);
    }

    function buyCzusdWithBnb(uint256 _czusdToBuy, address _to) public payable {
        _buyUnwrapped(_czusdToBuy, getBnbIn(_czusdToBuy), _to);
    }

    function sellWbnbForCzusd(uint256 _bnbToSell, address _to) public {
        _buy(getCzusdOut(_bnbToSell), _bnbToSell, _to);
    }

    function buyWbnbWithCzusd(uint256 _bnbToBuy, address _to) public {
        _sell(getCzusdIn(_bnbToBuy), _bnbToBuy, _to);
    }

    function sellCzusdForWbnb(uint256 _czusdToSell, address _to) public {
        _sell(_czusdToSell, getBnbOut(_czusdToSell), _to);
    }

    function buyCzusdWithWbnb(uint256 _czusdToBuy, address _to) public {
        _buy(_czusdToBuy, getBnbIn(_czusdToBuy), _to);
    }

    function _buyUnwrapped(
        uint256 boughtCzusd,
        uint256 soldBnb,
        address to
    ) internal nonReentrant {
        require(boughtCzusd >= 0.01 ether, "Trade too small");
        _updateBuyVolume(boughtCzusd);
        CZUSD.mint(to, boughtCzusd);
        require(msg.value >= soldBnb, "Not Enough BNB");
        WBNB.deposit{value: msg.value}();
    }

    function _sellUnwrapped(
        uint256 soldCzusd,
        uint256 boughtBnb,
        address payable to
    ) internal nonReentrant {
        require(soldCzusd >= 0.01 ether, "Trade too small");
        _updateSellVolume(soldCzusd);
        CZUSD.burnFrom(msg.sender, soldCzusd);
        isReceiving = true;
        WBNB.withdraw(boughtBnb);
        (bool sent, ) = to.call{value: boughtBnb}("");
        require(sent, "Failed _sellUnwrapped");
    }

    function _buy(uint256 boughtCzusd, uint256 soldWbnb, address to) internal {
        require(boughtCzusd >= 0.01 ether, "Trade too small");
        _updateBuyVolume(boughtCzusd);
        CZUSD.mint(to, boughtCzusd);
        WBNB.transferFrom(msg.sender, address(this), soldWbnb);
    }

    function _sell(uint256 soldCzusd, uint256 boughtWbnb, address to) internal {
        require(soldCzusd >= 0.01 ether, "Trade too small");
        _updateSellVolume(soldCzusd);
        CZUSD.burnFrom(msg.sender, soldCzusd);
        WBNB.transfer(to, boughtWbnb);
    }

    function _updateSellVolume(uint256 _soldCzusd) internal {
        if (lastSell + volumePeriod < block.timestamp) {
            sellVolume = _soldCzusd;
        } else {
            sellVolume += _soldCzusd;
        }
        lastSell = block.timestamp;
        require(buyVolume <= volumeCap, "Cap exceeded");
    }

    function _updateBuyVolume(uint256 _boughtCzusd) internal {
        if (lastBuy + volumePeriod < block.timestamp) {
            buyVolume = _boughtCzusd;
        } else {
            buyVolume += _boughtCzusd;
        }
        lastBuy = block.timestamp;
        require(buyVolume <= volumeCap, "Cap exceeded");
    }

    function getCzusdIn(
        uint256 _bnbToBuy
    ) public view returns (uint256 czusdIn) {
        uint256 czusdInBeforeFees = (_bnbToBuy * getBnbUsdPriceWad()) / 1 ether;
        return
            (czusdInBeforeFees *
                (10_000 + getSellFeeBasis(czusdInBeforeFees))) / 10_000;
    }

    function getCzusdOut(
        uint256 _bnbToSell
    ) public view returns (uint256 czusdOut) {
        return
            (_bnbToSell * getBnbUsdPriceWad() * (10_000 - buyFeeBasis)) /
            10_000 ether;
    }

    function getBnbIn(uint256 _czusdToBuy) public view returns (uint256 bnbIn) {
        return
            (1 ether * _czusdToBuy * (10_000 + buyFeeBasis)) /
            getBnbUsdPriceWad() /
            10_000;
    }

    function getBnbOut(
        uint256 _czusdToSell
    ) public view returns (uint256 bnbOut) {
        return
            (1 ether *
                _czusdToSell *
                (10_000 - getSellFeeBasis(_czusdToSell))) /
            getBnbUsdPriceWad() /
            10_000;
    }

    function getSellFeeBasis(
        uint256 _toSellWad
    ) public view returns (uint256 sellFeeBasis) {
        return
            getSellVolumeFeeBasis(_toSellWad) +
            getSellCollateralFeeBasis(_toSellWad) +
            sellFeeBaseBasis;
    }

    function getSellCollateralFeeBasis(
        uint256 _toSellWad
    ) public view returns (uint256 sellCollateralFeeBasis_) {
        uint256 collatUsd = getCurrentCollateralUsd() - _toSellWad;
        if (collatUsd >= targetCollateralUsd) {
            return 0;
        } else {
            return
                (sellFeeCollateralPer10PctBasis *
                    10 *
                    (targetCollateralUsd - collatUsd)) / (targetCollateralUsd);
        }
    }

    function getSellVolumeFeeBasis(
        uint256 _toSellWad
    ) public view returns (uint256 sellVolumeFeeBasis_) {
        uint256 newSellVolume = block.timestamp <= lastSell + volumePeriod
            ? sellVolume + _toSellWad
            : _toSellWad;
        if (newSellVolume <= sellFeeVolumeSize) {
            return 0;
        } else {
            return
                (sellFeeVolumeBasis * (newSellVolume - sellFeeVolumeSize)) /
                sellFeeVolumeSize;
        }
    }

    function getCurrentCollateralUsd()
        public
        view
        returns (uint256 collateralUsd_)
    {
        return (WBNB.balanceOf(address(this)) * getBnbUsdPriceWad()) / 1 ether;
    }

    function getBnbUsdPriceWad() public view returns (uint256 bnbPrice_) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        // BNB price has a precision of 8 decimals, so adjust it to wad (10**18)
        require(answer > 1 ** 10, "Failed getBnbUsdPriceWad");
        bnbPrice_ = uint256(answer) * 10 ** 10;
    }

    function setTargetCollateralUsd(uint256 _to) public onlyOwner {
        targetCollateralUsd = _to;
    }

    function setSellFeeParams(
        uint256 baseBasis,
        uint256 volumeBasis,
        uint256 volumeSize,
        uint256 _volumePeriod
    ) public onlyOwner {
        sellFeeBaseBasis = baseBasis;
        sellFeeVolumeBasis = volumeBasis;
        sellFeeVolumeSize = volumeSize;
        volumePeriod = _volumePeriod;
    }

    function setBuyFeeBasis(uint256 _to) public onlyOwner {
        buyFeeBasis = _to;
    }

    function recoverERC20(
        address tokenAddress,
        address destination,
        uint256 wad
    ) external onlyOwner {
        if (wad == 0) wad = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).safeTransfer(destination, wad);
    }

    function recoverEther(address destination) external onlyOwner {
        payable(destination).transfer(address(this).balance);
    }
}
