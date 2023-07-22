// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFTV2} from "@LayerZero/contracts/token/oft/v2/OFTV2.sol";

interface IMolekMarket {
    function blacklisted(address _collection) external view returns (bool);
}

contract Favor is Ownable, OFTV2 {
    IMolekMarket public molekMarket;

    error DifferentLength();
    error CollectionNotBlacklisted();
    error NotOwnerOfTokenId();

    /**
     * @notice Constructor
     * @param _molekMarket Address of the MolekMarket contract
     * @param _lzEndpoint Address of the LayerZero endpoint
     * @param _totalSupply Total supply of the token
     */
    constructor(
        address _molekMarket,
        address _lzEndpoint,
        uint256 _totalSupply
    ) OFTV2("Favor", "FAVOR", 18, _lzEndpoint) {
        molekMarket = IMolekMarket(_molekMarket);
        _mint(msg.sender, _totalSupply);
    }

    function mint(
        address _to,
        address[] calldata _collections,
        uint256[] calldata _tokenIds
    ) external {
        if (_collections.length != _tokenIds.length) revert DifferentLength();
        for (uint256 i = 0; i < _collections.length; i++) {
            IERC721 collection = IERC721(_collections[i]);
            if (!molekMarket.blacklisted(_collections[i]))
                revert CollectionNotBlacklisted();
            if (collection.ownerOf(_tokenIds[i]) != msg.sender)
                revert NotOwnerOfTokenId();

            collection.safeTransferFrom(
                msg.sender,
                address(0xdead),
                _tokenIds[i]
            );
        }
        _mint(_to, _tokenIds.length);
    }

    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }
}
