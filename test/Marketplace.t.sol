// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/utils/WrappedToken.sol";
import {TransferManager} from "../src/TransferManager.sol";

contract MarketTest is Test {
    TransparentUpgradeableProxy public market;
    Marketplace public marketplaceImplementation;
    ProxyAdmin public proxyAdmin;
    TransferManager public transferManager;
    WrappedToken public wrappedToken;

    address public feeCollector;
    

    function setUp() public {
        marketplaceImplementation = new Marketplace();
        proxyAdmin = new ProxyAdmin();
        feeCollector = address(0x1);
        wrappedToken = new WrappedToken();

        market = new TransparentUpgradeableProxy(
            address(marketplaceImplementation),
            address(proxyAdmin),
            abi.encodeWithSignature(
                "initialize(address,address)",
                feeCollector,
                address(wrappedToken)
            )
        );

        transferManager = new TransferManager(address(market));
    }
}
