//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

interface IMarketplace {
    event CreateAsk(
        address indexed collection,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 price
    );
    event CancelAsk(address indexed collection, uint256 indexed tokenId);
    event AcceptAsk(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 price
    );

    event CreateBid(
        address indexed collection,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 price
    );
    event CancelBid(address indexed collection, uint256 indexed tokenId);
    event AcceptBid(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 price
    );

    event Blacklisted(address indexed collection, bool isBlacklisted);

    error NotOwnerOfTokenId();
    error PriceTooLow();
    error BidTooLow();
    error NotBidCreator();
    error NotBlacklisted();
    error NotAskCreator();
    error AskDoesNotExist();
    error AskIsReserved();
    error InsufficientValue();
    error AskCreatorNotOwner();
    error NFTNotSent();
    error InsufficientFunds();
    error ZeroAddress();

    struct Ask {
        address creator;
        uint256 price;
    }

    struct Bid {
        address buyer;
        uint256 price;
    }
}
