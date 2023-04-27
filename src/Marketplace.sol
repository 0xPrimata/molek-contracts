//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./interfaces/IMarketplace.sol";
import "./interfaces/ITransferManager.sol";
import "./interfaces/INFTContract.sol";
import "./interfaces/IWrapper.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/IERC20.sol";
import "./NFTCommon.sol";

contract Marketplace is IMarketplace, OwnableUpgradeable {
    using Address for address;
    using NFTCommon for INFTContract;

    mapping(address => mapping(uint256 => Ask)) public asks;
    mapping(address => mapping(uint256 => Bid)) public bids;

    // =====================================================================

    address public feeCollector;
    address public wrappedToken;
    address private transferManager;

    // =====================================================================

    

    // =====================================================================

    function initialize(
        address payable _feeCollector,
        address _wrappedToken
    ) public initializer {
        feeCollector = _feeCollector;
        wrappedToken = _wrappedToken;
        __Ownable_init();
    }

    // ======= CREATE ASK / BID ============================================

    /// @notice Creates an ask for (`nft`, `tokenID`) tuple for `price`, which can
    /// be reserved for `to`, if `to` is not a zero address.
    /// @dev Creating an ask requires msg.sender to have at least one qty of
    /// (`nft`, `tokenID`).
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenID Token Ids of the NFTs msg.sender wishes to sell.
    /// @param price   Prices at which the seller is willing to sell the NFTs.
    function createAsk(
        INFTContract[] calldata nft,
        uint256[] calldata tokenID,
        uint256[] calldata price
    ) external {
        for (uint256 i = 0; i < nft.length; i++) {
            _createSingleAsk(nft[i], tokenID[i], price[i]);
        }
    }

    function _createSingleAsk(
        INFTContract nft,
        uint256 tokenID,
        uint256 price
    ) internal {
        if (nft.quantityOf(msg.sender, tokenID) == 0)
            revert NotOwnerOfTokenId();
        if (price <= 10_000) revert PriceTooLow();

        // overwrites or creates a new one
        asks[address(nft)][tokenID] = Ask({
            exists: true,
            seller: msg.sender,
            price: price
        });

        emit CreateAsk({
            nft: address(nft),
            tokenID: tokenID,
            price: price
        });
    }

    /// @notice Creates a bid on (`nft`, `tokenID`) tuple for `price`.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenID Token Ids of the NFTs msg.sender wishes to buy.
    /// @param price   Prices at which the buyer is willing to buy the NFTs.
    // function createBid(
    //     INFTContract nft,
    //     uint256 tokenID,
    //     uint256 price
    // ) external override {
    //     uint256 totalPrice = 0;

    //     for (uint256 i = 0; i < nft.length; i++) {
    //         address nftAddress = address(nft[i]);
    //         // bidding on own NFTs is possible. But then again, even if we wanted to disallow it,
    //         // it would not be an effective mechanism, since the agent can bid from his other
    //         // wallets
    //         if (IERC20(wrappedToken).balanceOf(msg.sender) < price) revert NotEnoughFunds();

    //         // if bid existed, let the prev. creator withdraw their bid. new overwrites
    //         if (bids[nftAddress][tokenID[i]].exists) {}

    //         // overwrites or creates a new one
    //         bids[nftAddress][tokenID[i]] = Bid({
    //             exists: true,
    //             buyer: msg.sender,
    //             price: price[i]
    //         });

    //         emit CreateBid({
    //             nft: nftAddress,
    //             tokenID: tokenID[i],
    //             price: price[i]
    //         });

    //         totalPrice += price[i];
    //     }

    //     if (totalPrice != msg.value) InsufficientFunds();
    // }

    // ======= CANCEL ASK / BID ============================================

    /// @notice Cancels ask(s) that the seller previously created.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenID Token Ids of the NFTs msg.sender wishes to cancel the
    /// asks on.
    function cancelAsks(
        INFTContract[] calldata nft,
        uint256[] calldata tokenID
    ) external {
        for (uint256 i = 0; i < nft.length; i++) {
            address nftAddress = address(nft[i]);
            if (asks[nftAddress][tokenID[i]].seller != msg.sender) revert
                NotAskCreator();

            delete asks[nftAddress][tokenID[i]];

            emit CancelAsk({nft: nftAddress, tokenID: tokenID[i]});
        }
    }

    /// @notice Cancels bid(s) that the msg.sender previously created.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenID Token Ids of the NFTs msg.sender wishes to cancel the
    /// bids on.
    // function cancelBid(
    //     INFTContract[] calldata nft,
    //     uint256[] calldata tokenID
    // ) external override {
    //     for (uint256 i = 0; i < nft.length; i++) {
    //         address nftAddress = address(nft[i]);
    //         if (bids[nftAddress][tokenID[i]].buyer != msg.sender)
    //             NotBidCreator();

    //         escrow[msg.sender] += bids[nftAddress][tokenID[i]].price;

    //         delete bids[nftAddress][tokenID[i]];

    //         emit CancelBid({nft: nftAddress, tokenID: tokenID[i]});
    //     }
    // }

    // ======= ACCEPT ASK / BID ===========================================

    /// @notice Seller placed ask(s), you (buyer) are fine with the terms. You accept
    /// their ask by sending the required msg.value and indicating the id of the
    /// token(s) you are purchasing.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenID Token Ids of the NFTs msg.sender wishes to accept the
    /// asks on.
    function acceptAsk(INFTContract nft, uint256 tokenID) external payable {
        address nftAddress = address(nft);
        Ask memory ask = asks[nftAddress][tokenID];
        if (!ask.exists) revert AskDoesNotExist();

        if (nft.quantityOf(ask.seller, tokenID) == 0) revert AskCreatorNotOwner();

        uint256 fee = _calculateFee(nftAddress, tokenID, ask.price);

        emit AcceptAsk({nft: nftAddress, tokenID: tokenID, price: ask.price});

        delete asks[nftAddress][tokenID];
        
        _transferWrappedIfNeeded(ask.price);
        IWrapper(wrappedToken).deposit{value: msg.value}();
        _transferFundsAndFees(
            address(this),
            ask.seller,
            ask.price - fee,
            fee
        );
        bool success = nft.safeTransferFrom_(
            asks[nftAddress][tokenID].seller,
            msg.sender,
            tokenID,
            new bytes(0)
        );
        if (!success) revert NFTNotSent();
    }

    function _transferFundsAndFees(
        address from,
        address to,
        uint256 toSeller,
        uint256 toFeeCollector
    ) internal {
        IERC20(wrappedToken).transferFrom(from, to, toSeller);
        IERC20(wrappedToken).transferFrom(
            from,
            feeCollector,
            toFeeCollector
        );
    }

    /// @notice You are the owner of the NFTs, someone submitted the bids on them.
    /// You accept one or more of these bids.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenID Token Ids of the NFTs msg.sender wishes to accept the
    /// bids on.
    // function acceptBid(
    //     INFTContract[] calldata nft,
    //     uint256[] calldata tokenID
    // ) external override {
    //     uint256 escrowDelta = 0;
    //     for (uint256 i = 0; i < nft.length; i++) {
    //         if (nft[i].quantityOf(msg.sender, tokenID[i]) == 0)
    //             NotOwnerOfTokenId();

    //         address nftAddress = address(nft[i]);

    //         escrowDelta += bids[nftAddress][tokenID[i]].price;
    //         // escrow[msg.sender] += bids[nftAddress][tokenID[i]].price;

    //         emit AcceptBid({
    //             nft: nftAddress,
    //             tokenID: tokenID[i],
    //             price: bids[nftAddress][tokenID[i]].price
    //         });

    //         bool success = nft[i].safeTransferFrom_(
    //             msg.sender,
    //             bids[nftAddress][tokenID[i]].buyer,
    //             tokenID[i],
    //             new bytes(0)
    //         );
    //         if (!success) NFTNotSent();

    //         delete asks[nftAddress][tokenID[i]];
    //         delete bids[nftAddress][tokenID[i]];
    //     }

    //     uint256 remaining = _takeFee(escrowDelta);
    //     escrow[msg.sender] = remaining;
    // }

    // ============ OWNER ==================================================

    /// @dev Used to change the address of the trade fee receiver.
    function changeFeeCollector(address payable _newFeeCollector) external onlyOwner {
        if (_newFeeCollector == payable(address(0))) revert ZeroAddress();
        feeCollector = _newFeeCollector;
    }

    /// @dev Used to change the address of the trade fee receiver.
    function changeTransferManager(address _newTransferManager) external onlyOwner {
        if (_newTransferManager == address(0)) revert ZeroAddress();
        transferManager = _newTransferManager;
    }

    // ============ PROCESS =============================================

    function _calculateFee(
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) internal view returns (uint256 fee) {
        // check if it supports the ERC2981 interface
        if (IERC165(_collection).supportsInterface(0x2a55205a)) {
            (, fee) = IERC2981(_collection).royaltyInfo(_tokenId, _amount);
        }
    }

    /**
     * @notice Transfer WAVAX from the buyer if not enough AVAX to cover the cost
     * @param cost the total cost of the sale
     */
    function _transferWrappedIfNeeded(uint256 cost) internal {
        if (cost > msg.value) {
            IERC20(wrappedToken).transferFrom(
                msg.sender,
                address(this),
                (cost - msg.value)
            );
        } else {
            if (cost != msg.value) revert InsufficientValue();
        }
    }

    function _transferNonFungibleToken(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) internal {
        ITransferManager(transferManager).transferNonFungibleToken(
            collection,
            from,
            to,
            tokenId
        );
    }
}
