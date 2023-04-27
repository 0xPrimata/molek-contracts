// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITransferManager {
    function transferNonFungibleToken(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) external;
}