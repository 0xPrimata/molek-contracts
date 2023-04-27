//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

import "./INFTContract.sol";

interface IMarketplace {

    event CreateAsk(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price
    );
    event CancelAsk(address indexed nft, uint256 indexed tokenID);
    event AcceptAsk(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price
    );

    event CreateBid(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price
    );
    event CancelBid(address indexed nft, uint256 indexed tokenID);
    event AcceptBid(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price
    );

    error NotOwnerOfTokenId();
    error PriceTooLow();
    error BidTooLow();
    error NotBidCreator();
    error NotAskCreator();
    error AskDoesNotExist();
    error AskIsReserved();
    error InsufficientValue();
    error AskCreatorNotOwner();
    error NFTNotSent();
    error InsufficientFunds();
    error ZeroAddress();

    struct Ask {
        bool exists;
        address seller;
        uint256 price;
    }

    struct Bid {
        bool exists;
        address buyer;
        uint256 price;
    }
}