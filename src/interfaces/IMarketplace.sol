//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

interface IMarketplace {
    event CreateAsk(
        address indexed nft,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 price
    );
    event CancelAsk(address indexed nft, uint256 indexed tokenId);
    event AcceptAsk(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 price
    );

    event CreateBid(
        address indexed nft,
        address indexed creator,
        uint256 indexed tokenId,
        uint256 price
    );
    event CancelBid(address indexed nft, uint256 indexed tokenId);
    event AcceptBid(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 price
    );

    event Blacklisted(address indexed nft, bool isBlacklisted);

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
