// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract EnglishAuction is IEnglishAuction {
    uint256 public minIncrement;
    address public seller;
    address public winner;
    uint256 public finalPrice;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public biddingEnd;
    uint256 public initialPrice;
    uint256 public biddingPeriod;
    bool public finalized;

    constructor(
        uint256 _initialPrice,
        uint256 _minIncrement,
        uint256 _biddingPeriod
    ) {
        require(_initialPrice > 0, "Initial price must be greater than zero");
        require(_minIncrement > 0, "Minimum increment must be greater than zero");
        require(_biddingPeriod > 0, "Bidding period must be greater than zero");

        seller = msg.sender;
        minIncrement = _minIncrement;
        initialPrice = _initialPrice;
        biddingPeriod = _biddingPeriod;
        biddingEnd = block.number + _biddingPeriod;
    }

    function bid() external payable override {
        require(block.number < biddingEnd, "Bidding period has ended");
        require(!finalized, "Auction has been finalized");
        
        if (highestBidder == address(0)) {
            require(msg.value >= initialPrice, "Bid must be at least the initial price");
        } else {
            require(msg.value > highestBid, "Bid must be higher than current bid");
            require(msg.value >= highestBid + minIncrement, "Bid increment too low");
        }

        if (highestBidder != address(0)) {
            // Refund the previous highest bidder
            payable(highestBidder).transfer(highestBid);
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        // Only extend the bidding period if it hasn't ended yet
        if (block.number + biddingPeriod <= biddingEnd + biddingPeriod) {
            biddingEnd = block.number + biddingPeriod;
        }
    }

    function finalize() external override {
        require(block.number >= biddingEnd, "Bidding period has not ended");
        require(!finalized, "Auction has already been finalized");

        finalized = true;
        
        if (highestBidder != address(0)) {
            winner = highestBidder;
            finalPrice = highestBid;
            payable(seller).transfer(highestBid);
        } else {
            // No bids were placed, auction ends without a winner
            winner = address(0);
            finalPrice = 0;
        }
    }
}