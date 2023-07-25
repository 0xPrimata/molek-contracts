//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

//     ▒▒                                          ▒▒░░
//   ░░▒▒                                            ▒▒░░
// ░░▒▒░░                                            ░░▒▒░░
// ░░░░                                                ▒▒░░
// ░░░░                                                ░░░░
// ░░░░                                              ░░▒▒░░
// ░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒  ▒▒      ░░  ░░▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒░░
// ░░░░▒▒░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▓▓░░▒▒░░▓▓▒▒
//   ░░▒▒▒▒░░░░▒▒▒▒▒▒▒▒░░▓▓▒▒░░▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒░░░░▒▒░░
//     ░░  ░░▒▒▒▒▒▒▓▓▓▓░░▒▒▒▒░░▒▒▒▒░░▒▒▓▓▓▓▒▒▒▒░░    ░░
//     ▒▒▒▒▒▒░░▒▒▒▒▒▒▓▓▒▒░░░░▓▓▓▓░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░
//       ▒▒▒▒▒▒▓▓██▒▒░░▒▒▒▒░░░░░░▒▒░░▓▓▒▒▒▒▓▓▓▓▒▒░░▒▒
//         ░░▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒██░░▓▓▒▒▒▒▒▒▒▒░░
//           ░░  ░░▒▒░░▒▒▒▒▒▒▓▓▒▒▒▒░░▓▓░░▒▒
//                 ▒▒▒▒▒▒▓▓▒▒▒▒▒▒▓▓▒▒▓▓░░▓▓
//                 ▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒░░▒▒░░▒▒
//                 ▒▒▒▒░░▒▒▒▒▒▒▓▓░░▒▒░░▒▒▒▒
//                 ▒▒░░░░▒▒▒▒▒▒░░▒▒▒▒▒▒░░░░
//                   ▒▒▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒
//                   ▓▓▒▒▒▒▒▒▒▒░░▓▓▓▓░░▓▓
//                   ▒▒▒▒▒▒▓▓▒▒░░▒▒▒▒░░░░
//                   ░░▒▒▒▒▒▒░░▒▒░░▒▒▓▓
//                     ▓▓▒▒  ▓▓▒▒░░▒▒██
//                     ▓▓▒▒░░░░▒▒░░▒▒▒▒
//    Molek Market      ▒▒▒▒██▒▒░░██▒▒
//      by primata      ▒▒▒▒▒▒▒▒▒▒▒▒

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/IMarketplace.sol";
import "./interfaces/ITransferManager.sol";
import "./interfaces/IWrapper.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/IERC20.sol";

contract MolekMarket is IMarketplace, OwnableUpgradeable {
    using Address for address;

    mapping(address => mapping(uint256 => Ask)) public asks;
    mapping(address => mapping(uint256 => Bid)) public bids;

    bool private paused;
    address public feeCollector;
    ITransferManager private transferManager;
    IERC20 public wrappedToken;
    mapping(address => bool) public blacklisted;

    modifier onlyBlacklisted(IERC721 _collection) {
        if (!blacklisted[address(_collection)]) revert NotBlacklisted();
        _;
    }

    modifier enabledOnly() {
        if (paused) revert Paused();
        _;
    }

    function initialize(
        address _feeCollector,
        address _wrappedToken
    ) public initializer {
        feeCollector = _feeCollector;
        wrappedToken = IERC20(_wrappedToken);
        paused = false;
        __Ownable_init();
    }

    /// @notice Creates an ask for (`collection`, `tokenId`) tuple for `price`, which can
    /// be reserved for `to`, if `to` is not a zero address.
    /// @dev Creating an ask requires msg.sender to have at least one qty of
    /// (`collection`, `tokenId`).
    /// @param _collections An array of ERC-721 and / or ERC-1155 addresses.
    /// @param _tokenIds    Token Ids of the NFTs msg.sender wishes to sell.
    /// @param _prices      Prices at which the seller is willing to sell the NFTs.
    function createAsk(
        IERC721[] calldata _collections,
        uint256[] calldata _tokenIds,
        uint256[] calldata _prices
    ) external enabledOnly {
        for (uint256 i = 0; i < _collections.length; i++) {
            _createSingleAsk(_collections[i], _tokenIds[i], _prices[i]);
        }
    }

    function _createSingleAsk(
        IERC721 _collection,
        uint256 _tokenId,
        uint256 _price
    ) internal onlyBlacklisted(_collection) {
        if (_collection.ownerOf(_tokenId) != msg.sender)
            revert NotOwnerOfTokenId();
        if (_price <= 10000) revert PriceTooLow();

        // overwrites or creates a new one
        asks[address(_collection)][_tokenId] = Ask({
            creator: msg.sender,
            price: _price
        });

        emit CreateAsk({
            collection: address(_collection),
            creator: msg.sender,
            tokenId: _tokenId,
            price: _price
        });
    }

    /// @notice Cancels ask(s) that the seller previously created.
    /// @param _collections An array of ERC-721 and / or ERC-1155 addresses.
    /// @param _tokenIds    Token Ids of the NFTs msg.sender wishes to cancel the
    /// asks on.
    function cancelAsks(
        IERC721[] calldata _collections,
        uint256[] calldata _tokenIds
    ) external enabledOnly {
        for (uint256 i = 0; i < _collections.length; i++) {
            address collectionAddress = address(_collections[i]);
            if (asks[collectionAddress][_tokenIds[i]].creator != msg.sender)
                revert NotAskCreator();

            delete asks[collectionAddress][_tokenIds[i]];

            emit CancelAsk({
                collection: collectionAddress,
                tokenId: _tokenIds[i]
            });
        }
    }

    /// @notice Seller placed ask, you (buyer) are fine with the terms. You accept
    /// their ask by sending the required msg.value and indicating the id of the
    /// token you are purchasing.
    /// @param _collection  ERC-721 address.
    /// @param _tokenId     Token Id of the NFTs msg.sender wishes to accept the ask on.
    /// @param _wrapped     Amount of wrapped tokens to send to the seller.
    function acceptAsk(
        IERC721 _collection,
        uint256 _tokenId,
        uint256 _wrapped
    ) public payable enabledOnly {
        address collectionAddress = address(_collection);
        Ask memory ask = asks[collectionAddress][_tokenId];
        if (ask.creator == address(0)) revert AskDoesNotExist();
        if (msg.value + _wrapped < ask.price) revert InsufficientValue();
        if (_collection.ownerOf(_tokenId) != ask.creator)
            revert AskCreatorNotOwner();

        uint256 fee = _calculateFee(collectionAddress, _tokenId, ask.price);

        delete asks[collectionAddress][_tokenId];

        _chargeAndRefund(ask.price, msg.value, _wrapped);
        _transferFundsAndFees(address(this), ask.creator, ask.price - fee, fee);
        _collection.safeTransferFrom(ask.creator, msg.sender, _tokenId);

        emit AcceptAsk({
            collection: collectionAddress,
            tokenId: _tokenId,
            price: ask.price
        });
    }

    /// @notice Seller placed ask, you (buyer) are fine with the terms. You accept
    /// their ask by sending the required msg.value and indicating the id of the
    /// token you are purchasing.
    /// @param _collection  ERC-721 address.
    /// @param _tokenId     Token Id of the NFTs msg.sender wishes to accept the ask on.
    function acceptAskAVAX(
        IERC721 _collection,
        uint256 _tokenId
    ) public payable enabledOnly {
        address collectionAddress = address(_collection);
        Ask memory ask = asks[collectionAddress][_tokenId];
        if (ask.creator == address(0)) revert AskDoesNotExist();
        if (msg.value < ask.price) revert InsufficientValue();
        if (_collection.ownerOf(_tokenId) != ask.creator)
            revert AskCreatorNotOwner();

        uint256 fee = _calculateFee(collectionAddress, _tokenId, ask.price);

        delete asks[collectionAddress][_tokenId];

        _chargeAndRefundAVAX(ask.price, msg.value);
        _transferFundsAndFees(address(this), ask.creator, ask.price - fee, fee);
        _collection.safeTransferFrom(ask.creator, msg.sender, _tokenId);

        emit AcceptAsk({
            collection: collectionAddress,
            tokenId: _tokenId,
            price: ask.price
        });
    }

    // ============ OWNER ==================================================

    /// @dev Used to change the address of the trade fee receiver.
    function changeFeeCollector(
        address payable _newFeeCollector
    ) external onlyOwner {
        if (_newFeeCollector == address(0)) revert ZeroAddress();
        feeCollector = _newFeeCollector;
        emit SetFeeCollector(_newFeeCollector);
    }

    /// @dev Used to change the address of the trade fee receiver.
    function changeTransferManager(
        address _newTransferManager
    ) external onlyOwner {
        if (_newTransferManager == address(0)) revert ZeroAddress();
        transferManager = ITransferManager(_newTransferManager);
        emit SetTransferManager(_newTransferManager);
    }

    /// @dev Used to blacklist a contract
    function toggleBlacklist(address _collectionAddress) external onlyOwner {
        if (_collectionAddress == address(0)) revert ZeroAddress();
        blacklisted[_collectionAddress] = !blacklisted[_collectionAddress];
        emit Blacklisted(_collectionAddress, blacklisted[_collectionAddress]);
    }

    /// @dev used to pause the marketplace
    function togglePause() external onlyOwner {
        paused = !paused;
        emit PauseToggled(paused);
    }

    // ============ PROCESS =============================================

    function _transferFundsAndFees(
        address _from,
        address _to,
        uint256 _toSeller,
        uint256 _toFeeCollector
    ) internal {
        wrappedToken.transferFrom(_from, _to, _toSeller);
        wrappedToken.transferFrom(_from, feeCollector, _toFeeCollector);
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

    function _transferNonFungibleToken(
        address _collectionAddress,
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        ITransferManager(transferManager).transferNonFungibleToken(
            _collectionAddress,
            _from,
            _to,
            _tokenId
        );
    }

    function _chargeAndRefund(
        uint256 _cost,
        uint256 _msgValue,
        uint256 _wrapped
    ) internal {
        uint256 excess = _msgValue + _wrapped - _cost;
        if (_msgValue > 0) {
            IWrapper(address(wrappedToken)).deposit{value: msg.value}();
        }
        if (_wrapped > 0) {
            wrappedToken.transferFrom(msg.sender, address(this), _wrapped);
        }
        if (excess > 0) {
            wrappedToken.transferFrom(address(this), msg.sender, excess);
        }
    }

    function _chargeAndRefundAVAX(uint256 _cost, uint256 _msgValue) internal {
        uint256 excess = _msgValue - _cost;
        IWrapper(address(wrappedToken)).deposit{value: msg.value}();
        if (excess > 0) {
            wrappedToken.transferFrom(address(this), msg.sender, excess);
        }
    }
}
