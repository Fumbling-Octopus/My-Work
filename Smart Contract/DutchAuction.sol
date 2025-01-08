// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract DutchAuction is IDutchAuction {
    address public override seller;
    address public override winner;
    uint256 public override finalPrice;
    
    uint256 private initialPrice;
    uint256 private priceDecrement;
    uint256 public endBlock;
    uint256 private startBlock;

    bool private isFinalized;

    constructor(
        uint256 _initialPrice,
        uint256 _priceDecrement,
        uint256 _duration
    ) {
        seller = msg.sender;
        initialPrice = _initialPrice;
        priceDecrement = _priceDecrement;
        startBlock = block.number;
        endBlock = startBlock + _duration - 1; // Subtract 1 to make it inclusive
    }

    function bid() external payable override {
        require(block.number <= endBlock, "Auction has ended");
        require(winner == address(0), "Auction already has a winner");

        uint256 price = currentPrice();
        require(msg.value >= price, "Bid is too low");

        winner = msg.sender;
        finalPrice = price;

        uint256 refund = msg.value - price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function finalize() external override {
        require(block.number > endBlock || winner != address(0), "Auction not yet ended");
        require(!isFinalized, "Auction already finalized");

        isFinalized = true;
        if (winner != address(0)) {
            payable(seller).transfer(finalPrice);
        }
    }

    function currentPrice() public view override returns (uint256) {
        if (block.number > endBlock) {
            return 0;
        }
        uint256 elapsedBlocks = block.number - startBlock;
        uint256 discount = elapsedBlocks * priceDecrement;
        if (discount >= initialPrice) {
            return 0;
        }
        return initialPrice - discount;
    }
}