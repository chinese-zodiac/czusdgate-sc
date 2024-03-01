// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "../../src/interfaces/AggregatorV2V3Interface.sol";

contract ChainlinkAggregatorMock is AggregatorV3Interface {
    uint80 private roundId;
    int256 private answer;
    uint256 private startedAt;
    uint256 private updatedAt;
    uint80 private answeredInRound;

    constructor() {
        roundId = 0;
        answer = 0;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 0;
    }

    function setAnswer(int256 _to) external {
        answer = _to;
    }

    function setRoundId(uint80 _to) external {
        roundId = _to;
    }

    function setAnsweredInRound(uint80 _to) external {
        answeredInRound = _to;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function description() external pure override returns (string memory) {
        return "mock LINK/ETH data feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    )
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (
            roundId,
            answer,
            block.timestamp,
            block.timestamp,
            answeredInRound
        );
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (
            roundId,
            answer,
            block.timestamp,
            block.timestamp,
            answeredInRound
        );
    }
}
