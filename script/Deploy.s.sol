// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../src/MolekMarket.sol";
import "../src/utils/WrappedToken.sol";
import "../src/interfaces/IMarketplace.sol";
import "forge-std/Script.sol";

contract MarketScript is Script {
    TransparentUpgradeableProxy public market;
    MolekMarket public marketplaceImplementation;
    ProxyAdmin public proxyAdmin;
    address public wavaxFuji = 0x1D308089a2D1Ced3f1Ce36B1FcaF815b07217be3;
    address public wavax = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    MolekMarket public marketplace;

    address public feeCollector;
    uint256 public deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        marketplaceImplementation = new MolekMarket();
        proxyAdmin = new ProxyAdmin();
        feeCollector = address(0x90FB67b45d73e8f6f24C1FA1aB0d21a972DbE0AE);
        address wrappedToken = block.chainid == 43113 ? wavaxFuji : wavax;

        market = new TransparentUpgradeableProxy(
            address(marketplaceImplementation),
            address(proxyAdmin),
            abi.encodeWithSignature(
                "initialize(address,address)",
                feeCollector,
                wrappedToken
            )
        );

        marketplace = MolekMarket(address(market));

        marketplace.toggleBlacklist(0xdd811213C7d94D5243815884Ed273c934E7DB009);
        marketplace.toggleBlacklist(0xb6168bd82410FdcBA31cFBECadB705B63f5376D1);
        marketplace.toggleBlacklist(0x048c939bEa33c5dF4d2C69414B9385d55b3bA62E);
        marketplace.toggleBlacklist(0xfcf7613d90B64e1ca2bEaC37a20EE0219eAA6DDb);

        vm.stopBroadcast();
    }
}
