// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockPriceFeedV1Plus is AggregatorV3Interface, Ownable {
    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    RoundData private _latestRoundData;
    uint8 private _decimals;

    constructor(address admin) Ownable(admin) {
        _decimals = 8;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function setDecimals(uint8 decimals_) external onlyOwner {
        _decimals = decimals_;
    }

    function description() external pure override returns (string memory) {
        return "Test Oracle";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            _latestRoundData.roundId,
            _latestRoundData.answer,
            _latestRoundData.startedAt,
            _latestRoundData.updatedAt,
            _latestRoundData.answeredInRound
        );
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            _latestRoundData.roundId,
            _latestRoundData.answer,
            _latestRoundData.startedAt,
            _latestRoundData.updatedAt,
            _latestRoundData.answeredInRound
        );
    }

    function updateRoundData(RoundData memory roundData) external onlyOwner {
        _latestRoundData = roundData;
        emit AnswerUpdated(roundData.answer, roundData.roundId, roundData.updatedAt);
    }
}
