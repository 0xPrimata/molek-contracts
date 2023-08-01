// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

//      Favor                       ╒████▌
//      by primata                ▄▄▓█████▄▄
//                              ▄▄▀▀▀█████▀▀▄▄.
//                           ,,▐▀▀  ]▓▓██▌  ▀▀▌,,
//                           ██▌    ]▓▓██▌    ▐██
//                           ██▌    ]▓▓██▌    ▐██
//                           ██▌    ]▓▓██▌    ▐██
//                           ██▌    ]▓▓██▌    ▐██
//                           ██▌  ██████████  ▐██
//                         ▄▄▀▀▐▄▄▀▀▀████▌▀▀▄▄▌▀▀▄▄φ
//                        ▐██  ▐██  ]▓▓██▌  ██▌  ██▌
//                        ▐██  ▐██  ]▓▓██▌  ██▌  ██▌
//                        ▐██  ▐██  ]▓▓██▌  ██▌  ██▌
//                        ▐██  ▐██  ]▓▓██▌  ██▌  ██▌
//                      ██▌    ▐██  ]▓▓██▌  ██▌    ▐██
//                      ██▌    ▐██  ]▓▓██▌  ██▌    ▐██
//                      ██▌    ▐██  ]▓▓██▌  ██▌    ▐██
//                    ▄▄╜╚      ╚╚  ]▓▓██▌  ╙╚      ╚╚▄▄Φ
//                 ▄▄▄██            ]▓▓██▌            ▀▀▐▄▄
//               ▄▄▀▀▀▀▀▄▄          ]▓▓██▌            ▄▄▐▀▀▄▄
//              ▐██     ██▌__     __J▓▓██▌__        __██▌  ██▌__
//              ▐██       ▐██     ██████████       ▐██       ▐██
//            ██▌  ██▌       ███▓▓█████  ▐████▌  ██▌       ██▌  ██▌
//         ▐██       ▐██       ▐████▌       █████       ▐██       ▐██
//       ██▌            ██▌    j▓▓██▌       ██▌       ██▌            ██▌
//    ╒██``             ``▐██▄▄▓██``        ``▐██  ╒██``             ``▐██
//    ▐██                 ]████▌▀▀             ▀▀▄▄▌▀▀                 ▐██
//     ▀▀▄▄.              ]▓▓██▌                 ██▌                 ▄▄▐▀▀
//       ▀▀▌,,,,,,,,,,,,,,▐██▀▀▌                 ▀▀▌,,             ,,▀▀▌
//         ▐██▓▓▓▓▓▓▓▓▓▓▓▓███                      ▐██            ▐██
//            ████████████▌                           ████████████▌

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
     * @param _molekMarket  Address of the MolekMarket contract
     * @param _lzEndpoint   Address of the LayerZero endpoint
     */
    constructor(
        address _molekMarket,
        address _lzEndpoint
    ) OFTV2("Favor", "FAVOR", 18, _lzEndpoint) {
        molekMarket = IMolekMarket(_molekMarket);
    }

    /**
     * @param _to           Address to mint to
     * @param _collections  Collections to mint from
     * @param _tokenIds     Token IDs to mint
     */
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
                address(0xdEaD),
                _tokenIds[i]
            );
        }
        _mint(_to, _tokenIds.length * 10 ** decimals());
    }

    /**
     * @param _value Amount to burn
     */
    function burn(uint256 _value) external {
        _burn(msg.sender, _value);
    }
}
