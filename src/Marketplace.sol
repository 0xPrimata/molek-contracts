//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/IMarketplace.sol";
import "./interfaces/ITransferManager.sol";
import "./interfaces/IWrapper.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/IERC20.sol";
import "./NFTCommon.sol";

contract Marketplace is IMarketplace, OwnableUpgradeable {
    using Address for address;
    using NFTCommon for IERC721;

    mapping(address => mapping(uint256 => Ask)) public asks;
    mapping(address => mapping(uint256 => Bid)) public bids;

    address public feeCollector;
    address public wrappedToken;
    address private transferManager;
    mapping(address => bool) public blacklisted;

    modifier onlyBlacklisted(IERC721 nftContract) {
        if (!blacklisted[address(nftContract)]) revert NotBlacklisted();
        _;
    }

    function initialize(
        address payable _feeCollector,
        address _wrappedToken
    ) public initializer {
        feeCollector = _feeCollector;
        wrappedToken = _wrappedToken;
        __Ownable_init();
    }

    /// @notice Creates an ask for (`nft`, `tokenId`) tuple for `price`, which can
    /// be reserved for `to`, if `to` is not a zero address.
    /// @dev Creating an ask requires msg.sender to have at least one qty of
    /// (`nft`, `tokenId`).
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenId Token Ids of the NFTs msg.sender wishes to sell.
    /// @param price   Prices at which the seller is willing to sell the NFTs.
    function createAsk(
        IERC721[] calldata nft,
        uint256[] calldata tokenId,
        uint256[] calldata price
    ) external {
        for (uint256 i = 0; i < nft.length; i++) {
            _createSingleAsk(nft[i], tokenId[i], price[i]);
        }
    }

    function _createSingleAsk(
        IERC721 nft,
        uint256 tokenId,
        uint256 price
    ) internal onlyBlacklisted(nft) {
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwnerOfTokenId();
        if (price <= 10000) revert PriceTooLow();

        // overwrites or creates a new one
        asks[address(nft)][tokenId] = Ask({
            exists: true,
            seller: msg.sender,
            price: price
        });

        emit CreateAsk({
            nft: address(nft),
            creator: msg.sender,
            tokenId: tokenId,
            price: price
        });
    }

    /// @notice Cancels ask(s) that the seller previously created.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenId Token Ids of the NFTs msg.sender wishes to cancel the
    /// asks on.
    function cancelAsks(
        IERC721[] calldata nft,
        uint256[] calldata tokenId
    ) external {
        for (uint256 i = 0; i < nft.length; i++) {
            address nftAddress = address(nft[i]);
            if (asks[nftAddress][tokenId[i]].seller != msg.sender)
                revert NotAskCreator();

            delete asks[nftAddress][tokenId[i]];

            emit CancelAsk({nft: nftAddress, tokenId: tokenId[i]});
        }
    }

    /// @notice Seller placed ask(s), you (buyer) are fine with the terms. You accept
    /// their ask by sending the required msg.value and indicating the id of the
    /// token(s) you are purchasing.
    /// @param nft     An array of ERC-721 and / or ERC-1155 addresses.
    /// @param tokenId Token Ids of the NFTs msg.sender wishes to accept the
    /// asks on.
    function acceptAsk(
        IERC721 nft,
        uint256 tokenId,
        uint256 _weth
    ) external payable {
        address nftAddress = address(nft);
        Ask memory ask = asks[nftAddress][tokenId];
        if (!ask.exists) revert AskDoesNotExist();
        if (msg.value + _weth < ask.price) revert InsufficientValue();

        if (nft.quantityOf(ask.seller, tokenId) == 0)
            revert AskCreatorNotOwner();

        uint256 fee = _calculateFee(nftAddress, tokenId, ask.price);

        if (_weth > 0)
            IERC20(wrappedToken).transferFrom(msg.sender, address(this), _weth);
        _transferWrappedIfNeeded(ask.price);

        IWrapper(wrappedToken).deposit{value: msg.value}();
        _transferFundsAndFees(address(this), ask.seller, ask.price - fee, fee);
        nft.safeTransferFrom(
            asks[nftAddress][tokenId].seller,
            msg.sender,
            tokenId
        );
        delete asks[nftAddress][tokenId];
        emit AcceptAsk({nft: nftAddress, tokenId: tokenId, price: ask.price});
    }

    // ============ OWNER ==================================================

    /// @dev Used to change the address of the trade fee receiver.
    function changeFeeCollector(
        address payable _newFeeCollector
    ) external onlyOwner {
        if (_newFeeCollector == payable(address(0))) revert ZeroAddress();
        feeCollector = _newFeeCollector;
    }

    /// @dev Used to change the address of the trade fee receiver.
    function changeTransferManager(
        address _newTransferManager
    ) external onlyOwner {
        if (_newTransferManager == address(0)) revert ZeroAddress();
        transferManager = _newTransferManager;
    }

    /// @dev Used to blacklist a contract
    function blacklist(
        address _collection,
        bool _condition
    ) external onlyOwner {
        if (_collection == address(0)) revert ZeroAddress();
        blacklisted[_collection] = _condition;

        emit Blacklisted(_collection, _condition);
    }

    // ============ PROCESS =============================================

    function _transferFundsAndFees(
        address from,
        address to,
        uint256 toSeller,
        uint256 toFeeCollector
    ) internal {
        IERC20(wrappedToken).transferFrom(from, to, toSeller);
        IERC20(wrappedToken).transferFrom(from, feeCollector, toFeeCollector);
    }

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
