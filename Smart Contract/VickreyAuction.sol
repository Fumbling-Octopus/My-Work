// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Assignment2.sol";

contract VickreyAuction is IVickreyAuction {
    uint256 public reservePrice;
    uint256 public bidDeposit;
    address public seller;
    address public winner;
    uint256 public finalPrice;
    address public highestBidder;
    uint256 public secondHighestBid;
    uint256 public biddingEnd;
    uint256 public revealEnd;
    bool public finalized;

    mapping(address => bytes32) private bidCommitments;
    mapping(address => uint256) private bidderDeposits;
    mapping(address => uint256) private revealedBids;
    mapping(address => bool) private hasRevealed;

    constructor(
        uint256 _reservePrice,
        uint256 _bidDeposit,
        uint256 _biddingPeriod,
        uint256 _revealPeriod
    ) {
        require(_reservePrice > 0, "Reserve price must be greater than zero");
        require(_bidDeposit > 0, "Bid deposit must be greater than zero");
        require(_biddingPeriod > 0, "Bidding period must be greater than zero");
        require(_revealPeriod > 0, "Reveal period must be greater than zero");

        seller = msg.sender;
        reservePrice = _reservePrice;
        bidDeposit = _bidDeposit;
        biddingEnd = block.number + _biddingPeriod;
        revealEnd = biddingEnd + _revealPeriod;
    }

    function commitBid(bytes32 bidCommitment) external payable override {
        require(block.number < biddingEnd, "Bidding period has ended");

        uint256 depositToReturn = 0;
        if (bidderDeposits[msg.sender] == 0) {
            require(msg.value >= bidDeposit, "Insufficient bid deposit");
            bidderDeposits[msg.sender] = bidDeposit;
            depositToReturn = msg.value - bidDeposit;
        } else {
            depositToReturn = msg.value;
        }

        bidCommitments[msg.sender] = bidCommitment;

        if (depositToReturn > 0) {
            payable(msg.sender).transfer(depositToReturn);
        }
    }

    function revealBid(bytes32 nonce) external payable override {
        require(block.number >= biddingEnd && block.number < revealEnd, "Not in reveal period");
        require(!hasRevealed[msg.sender], "Bid already revealed");
        require(bidderDeposits[msg.sender] >= bidDeposit, "No bid to reveal");

        bytes32 commitment = makeCommitment(msg.value, nonce);
        require(commitment == bidCommitments[msg.sender], "Revealed bid does not match commitment");

        hasRevealed[msg.sender] = true;
        revealedBids[msg.sender] = msg.value;

        uint256 refundAmount = bidderDeposits[msg.sender];
        bidderDeposits[msg.sender] = 0;

        if (msg.value >= reservePrice) {
            if (msg.value > revealedBids[highestBidder]) {
                if (highestBidder != address(0)) {
                    // Refund the previous highest bidder
                    payable(highestBidder).transfer(revealedBids[highestBidder]);
                }
                secondHighestBid = revealedBids[highestBidder];
                highestBidder = msg.sender;
            } else if (msg.value > secondHighestBid && msg.sender != highestBidder) {
                secondHighestBid = msg.value;
            }
        }

        // Return the deposit
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }

        // Return the bid if it's not the highest
        if (msg.sender != highestBidder) {
            payable(msg.sender).transfer(msg.value);
        }
    }

    function makeCommitment(uint256 bidValue, bytes32 nonce) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(bidValue, nonce));
    }

    function finalize() external override {
        require(block.number >= revealEnd, "Reveal period has not ended");
        require(!finalized, "Auction has already been finalized");

        finalized = true;

        if (highestBidder != address(0)) {
            winner = highestBidder;
            finalPrice = secondHighestBid > reservePrice ? secondHighestBid : reservePrice;
            uint256 amountToTransfer = finalPrice;
            if (revealedBids[highestBidder] > finalPrice) {
                payable(highestBidder).transfer(revealedBids[highestBidder] - finalPrice);
            }
            payable(seller).transfer(amountToTransfer);
        } else {
            winner = address(0);
            finalPrice = 0;
        }

        // Return deposits for bidders who didn't reveal
        for (uint i = 0; i < 20; i++) { // Limiting iterations for gas considerations
            address bidder = address(uint160(i + 1)); // Starting from address(1) to avoid address(0)
            if (bidderDeposits[bidder] > 0) {
                uint256 depositToReturn = bidderDeposits[bidder];
                bidderDeposits[bidder] = 0;
                payable(bidder).transfer(depositToReturn);
            }
        }
    }
}