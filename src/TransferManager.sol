// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import  "./interfaces/ITransferManager.sol";

contract TransferManager is ITransferManager, Initializable {
    address public molekMarket;

    error NotMarket();

    constructor (address _molekMarket) {
        molekMarket = _molekMarket;
    }
    function transferNonFungibleToken(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) external {
        if (msg.sender != molekMarket) revert NotMarket();
        IERC721(collection).safeTransferFrom(from, to, tokenId);
    }
}