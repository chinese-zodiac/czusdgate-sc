// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {CzusdGateV2} from "../src/CzusdGateV2.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20BurnableMock} from "./mocks/ERC20BurnableMock.sol";
import {ChainlinkAggregatorMock} from "./mocks/ChainlinkAggregatorMock.sol";
import {WETH} from "@solmate/tokens/WETH.sol";

contract CzusdGateV2Test is Test {
    address[] public users;

    CzusdGateV2 gate;
    ERC20BurnableMock czusd;
    WETH wbnb;
    ChainlinkAggregatorMock priceFeed;

    function setUp() public {
        users.push(makeAddr("user0"));
        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));
        users.push(makeAddr("user4"));

        czusd = new ERC20BurnableMock("CZUSD", "CZUSD");
        wbnb = new WETH();
        priceFeed = new ChainlinkAggregatorMock();
        gate = new CzusdGateV2(czusd, wbnb, priceFeed, address(this));

        priceFeed.setAnswer(40000000000);
    }

    function testViewMethodsInitial() public {
        assertEq(gate.buyFeeBasis(), 49);
        assertEq(gate.targetCollateralUsd(), 10_000 ether);
        assertEq(gate.sellFeeBaseBasis(), 199);
        assertEq(gate.sellFeeVolumeBasis(), 250);
        assertEq(gate.sellFeeVolumeSize(), 750 ether);
        assertEq(gate.sellFeeCollateralPer10PctBasis(), 250);
        assertEq(gate.volumePeriod(), 24 hours);
        assertEq(gate.volumeCap(), 50_000 ether);
        assertEq(gate.sellVolume(), 0 ether);
        assertEq(gate.lastSell(), 0 ether);
        assertEq(gate.buyVolume(), 0);
        assertEq(gate.lastBuy(), 0);

        assertEq(gate.getBnbUsdPriceWad(), 400 ether);

        assertEq(gate.getSellVolumeFeeBasis(1 ether), 0);
        assertEq(gate.getSellVolumeFeeBasis(750 ether), 0);
        assertEq(gate.getSellVolumeFeeBasis(1125 ether), 125);
        assertEq(gate.getSellVolumeFeeBasis(1500 ether), 250);
        assertEq(gate.getSellVolumeFeeBasis(2250 ether), 500);

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);
        assertEq(gate.getCurrentCollateralUsd(), 100 ether * 400);
        assertEq(gate.getSellCollateralFeeBasis(1 ether), 0);
        assertEq(gate.getSellCollateralFeeBasis(30_000 ether), 0);
        assertEq(gate.getSellCollateralFeeBasis(30_500 ether), 125);
        assertEq(gate.getSellCollateralFeeBasis(31_000 ether), 250);
        assertEq(gate.getSellCollateralFeeBasis(32_000 ether), 500);
        assertEq(gate.getSellCollateralFeeBasis(35_000 ether), 1250);

        priceFeed.setAnswer(30000000000);
        assertEq(gate.getCurrentCollateralUsd(), 100 ether * 300);
        assertEq(gate.getSellCollateralFeeBasis(1 ether), 0);
        assertEq(gate.getSellCollateralFeeBasis(20_000 ether), 0);
        assertEq(gate.getSellCollateralFeeBasis(20_500 ether), 125);
        assertEq(gate.getSellCollateralFeeBasis(21_000 ether), 250);
        assertEq(gate.getSellCollateralFeeBasis(22_000 ether), 500);
        assertEq(gate.getSellCollateralFeeBasis(25_000 ether), 1250);

        assertEq(gate.getSellFeeBasis(500 ether), 199);
        assertEq(gate.getSellFeeBasis(1_125 ether), 199 + 125);

        priceFeed.setAnswer(2250000000);
        gate.setTargetCollateralUsd(2_250 ether);
        assertEq(gate.getCurrentCollateralUsd(), 2_250 ether);
        assertEq(gate.getSellFeeBasis(1_125 ether), 199 + 125 + 1250);

        priceFeed.setAnswer(40000000000);
        assertEq(
            gate.getCzusdOut(1 ether),
            400 ether - ((49 * 400 ether) / 10_000)
        );
        assertEq(gate.getBnbIn(400 ether), 1 ether + ((49 * 1 ether) / 10_000));

        assertEq(
            gate.getCzusdIn(1 ether),
            400 ether + ((199 * 400 ether) / 10_000)
        );
        assertEq(
            gate.getBnbOut(400 ether),
            1 ether - ((199 * 1 ether) / 10_000)
        );
    }

    function testFuzz_SellCzusdForWbnbSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);
        deal(address(czusd), address(this), czusdWad);

        uint256 expectedOut = gate.getBnbOut(czusdWad);
        assertLt(expectedOut, bnbWad);

        czusd.approve(address(gate), czusdWad);
        gate.sellCzusdForWbnb(czusdWad, users[0]);
        assertEq(wbnb.balanceOf(users[0]), gate.getBnbOut(czusdWad));
        assertEq(czusd.balanceOf(address(this)), 0);
    }

    function testFuzz_SellCzusdForBnbSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);
        deal(address(czusd), address(this), czusdWad);

        uint256 expectedOut = gate.getBnbOut(czusdWad);
        assertLt(expectedOut, bnbWad);

        czusd.approve(address(gate), czusdWad);
        gate.sellCzusdForBnb(czusdWad, payable(users[0]));
        assertEq(users[0].balance, gate.getBnbOut(czusdWad));
        assertEq(czusd.balanceOf(address(this)), 0);
    }

    function testFuzz_BuyWbnbWithCzusdSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);

        uint256 expectedIn = gate.getCzusdIn(bnbWad);
        assertGt(expectedIn, czusdWad);
        deal(address(czusd), address(this), expectedIn);

        czusd.approve(address(gate), expectedIn);
        gate.buyWbnbWithCzusd(bnbWad, users[0]);
        assertEq(wbnb.balanceOf(users[0]), bnbWad);
        assertEq(czusd.balanceOf(address(this)), 0);
    }

    function testFuzz_BuyBnbWithCzusdSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);

        uint256 expectedIn = gate.getCzusdIn(bnbWad);
        assertGt(expectedIn, czusdWad);
        deal(address(czusd), address(this), expectedIn);

        czusd.approve(address(gate), expectedIn);
        gate.buyBnbWithCzusd(bnbWad, payable(users[0]));
        assertEq(users[0].balance, bnbWad);
        assertEq(czusd.balanceOf(address(this)), 0);
    }

    function testFuzz_SellWbnbForCzusdSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);

        uint256 expectedOut = gate.getCzusdOut(bnbWad);
        assertLt(expectedOut, czusdWad);
        deal(address(wbnb), address(this), bnbWad);

        wbnb.approve(address(gate), bnbWad);
        gate.sellWbnbForCzusd(bnbWad, users[0]);
        assertEq(czusd.balanceOf(users[0]), expectedOut);
        assertEq(wbnb.balanceOf(address(this)), 0);
    }

    function testFuzz_SellBnbForCzusdSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);

        uint256 expectedOut = gate.getCzusdOut(bnbWad);
        assertLt(expectedOut, czusdWad);
        deal(address(this), bnbWad);

        gate.sellBnbForCzusd{value: bnbWad}(users[0]);
        assertEq(czusd.balanceOf(users[0]), expectedOut);
        assertEq(address(this).balance, 0);
    }

    function testFuzz_BuyCzusdWithWbnbSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);

        uint256 expectedIn = gate.getBnbIn(czusdWad);
        assertGt(expectedIn, bnbWad);
        deal(address(wbnb), address(this), expectedIn);

        wbnb.approve(address(gate), expectedIn);
        gate.buyCzusdWithWbnb(czusdWad, users[0]);
        assertEq(czusd.balanceOf(users[0]), czusdWad);
        assertEq(wbnb.balanceOf(address(this)), 0);
    }

    function testFuzz_BuyCzusdWithBnbSmall(uint256 amount) public {
        uint256 czusdWad = 1 ether + (amount % 99 ether);
        uint256 bnbWad = (czusdWad * 1 ether) / gate.getBnbUsdPriceWad();

        deal(address(wbnb), 100 ether);
        deal(address(wbnb), address(gate), 100 ether);

        uint256 expectedIn = gate.getBnbIn(czusdWad);
        assertGt(expectedIn, bnbWad);
        deal(address(this), expectedIn);

        gate.buyCzusdWithBnb{value: expectedIn}(czusdWad, users[0]);
        assertEq(czusd.balanceOf(users[0]), czusdWad);
        assertEq(address(this).balance, 0);
    }

    function testBuyVolume() public {
        deal(address(wbnb), 2000 ether);
        deal(address(wbnb), address(gate), 1000 ether);
        deal(address(wbnb), address(this), 1000 ether);
        wbnb.approve(address(gate), 1000 ether);

        assertEq(gate.buyVolume(), 0);
        assertEq(gate.lastBuy(), 0);
        gate.buyCzusdWithWbnb(100 ether, address(this));
        assertEq(gate.buyVolume(), 100 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        gate.buyCzusdWithWbnb(50 ether, address(this));
        assertEq(gate.buyVolume(), 150 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 150 ether);

        vm.warp(block.timestamp + 1 hours);

        gate.buyCzusdWithWbnb(125 ether, address(this));
        assertEq(gate.buyVolume(), 275 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 275 ether);

        vm.warp(block.timestamp + 25 hours);
        gate.buyCzusdWithWbnb(13 ether, address(this));
        assertEq(gate.buyVolume(), 13 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 288 ether);

        vm.expectRevert("Cap exceeded");
        gate.buyCzusdWithWbnb(49_988 ether, address(this));
        vm.warp(block.timestamp + 25 hours);

        gate.buyCzusdWithWbnb(49_988 ether, address(this));
        assertEq(gate.buyVolume(), 49_988 ether);
        assertEq(czusd.balanceOf(address(this)), 50276 ether);
        assertEq(gate.sellVolume(), 0);
    }

    function testSellVolume() public {
        deal(address(wbnb), 2000 ether);
        deal(address(wbnb), address(gate), 2000 ether);
        deal(address(czusd), address(this), 100_000 ether);
        czusd.approve(address(gate), 100_000 ether);

        assertEq(gate.sellVolume(), 0);
        assertEq(gate.lastSell(), 0);
        gate.sellCzusdForWbnb(100 ether, address(this));
        assertEq(gate.sellVolume(), 100 ether);
        assertEq(gate.lastSell(), block.timestamp);
        gate.sellCzusdForWbnb(50 ether, address(this));
        assertEq(gate.sellVolume(), 150 ether);
        assertEq(gate.lastSell(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 100_000 ether - 150 ether);

        vm.warp(block.timestamp + 1 hours);

        gate.sellCzusdForWbnb(125 ether, address(this));
        assertEq(gate.sellVolume(), 275 ether);
        assertEq(gate.lastSell(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 100_000 ether - 275 ether);
        assertEq(gate.getSellVolumeFeeBasis(1125 ether - 275 ether), 125);

        vm.warp(block.timestamp + 25 hours);
        gate.sellCzusdForWbnb(13 ether, address(this));
        assertEq(gate.sellVolume(), 13 ether);
        assertEq(gate.lastSell(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 100_000 ether - 288 ether);
        assertEq(gate.getSellVolumeFeeBasis(1125 ether - 13 ether), 125);
        assertEq(gate.buyVolume(), 0);
    }

    function testBuyVolumeBnb() public {
        deal(address(wbnb), 1000 ether);
        deal(address(wbnb), address(gate), 1000 ether);
        deal(address(this), 1000 ether);

        assertEq(gate.buyVolume(), 0);
        assertEq(gate.lastBuy(), 0);
        gate.buyCzusdWithBnb{value: gate.getBnbIn(100 ether)}(
            100 ether,
            address(this)
        );
        assertEq(gate.buyVolume(), 100 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        gate.buyCzusdWithBnb{value: gate.getBnbIn(50 ether)}(
            50 ether,
            address(this)
        );
        assertEq(gate.buyVolume(), 150 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 150 ether);

        vm.warp(block.timestamp + 1 hours);

        gate.buyCzusdWithBnb{value: gate.getBnbIn(125 ether)}(
            125 ether,
            address(this)
        );
        assertEq(gate.buyVolume(), 275 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 275 ether);

        vm.warp(block.timestamp + 25 hours);
        gate.buyCzusdWithBnb{value: gate.getBnbIn(13 ether)}(
            13 ether,
            address(this)
        );
        assertEq(gate.buyVolume(), 13 ether);
        assertEq(gate.lastBuy(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 288 ether);

        uint256 bnbIn = gate.getBnbIn(49_988 ether);
        vm.expectRevert("Cap exceeded");
        gate.buyCzusdWithBnb{value: bnbIn}(49_988 ether, address(this));
        vm.warp(block.timestamp + 25 hours);

        gate.buyCzusdWithBnb{value: gate.getBnbIn(49_988 ether)}(
            49_988 ether,
            address(this)
        );
        assertEq(gate.buyVolume(), 49_988 ether);
        assertEq(czusd.balanceOf(address(this)), 50276 ether);
        assertEq(gate.sellVolume(), 0);
    }

    function testSellVolumeBnb() public {
        deal(address(wbnb), 2000 ether);
        deal(address(wbnb), address(gate), 2000 ether);
        deal(address(czusd), address(this), 100_000 ether);
        czusd.approve(address(gate), 100_000 ether);

        assertEq(gate.sellVolume(), 0);
        assertEq(gate.lastSell(), 0);
        gate.sellCzusdForBnb(100 ether, payable(users[1]));
        assertEq(gate.sellVolume(), 100 ether);
        assertEq(gate.lastSell(), block.timestamp);
        gate.sellCzusdForBnb(50 ether, payable(users[1]));
        assertEq(gate.sellVolume(), 150 ether);
        assertEq(gate.lastSell(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 100_000 ether - 150 ether);

        vm.warp(block.timestamp + 1 hours);

        gate.sellCzusdForBnb(125 ether, payable(users[1]));
        assertEq(gate.sellVolume(), 275 ether);
        assertEq(gate.lastSell(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 100_000 ether - 275 ether);
        assertEq(gate.getSellVolumeFeeBasis(1125 ether - 275 ether), 125);

        vm.warp(block.timestamp + 25 hours);
        gate.sellCzusdForBnb(13 ether, payable(users[1]));
        assertEq(gate.sellVolume(), 13 ether);
        assertEq(gate.lastSell(), block.timestamp);
        assertEq(czusd.balanceOf(address(this)), 100_000 ether - 288 ether);
        assertEq(gate.getSellVolumeFeeBasis(1125 ether - 13 ether), 125);
        assertEq(gate.buyVolume(), 0);
    }
}
