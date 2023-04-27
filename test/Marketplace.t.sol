// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Marketplace.sol";
import "../src/utils/WrappedToken.sol";
import {TransferManager} from "../src/TransferManager.sol";
import "../src/interfaces/IMarketplace.sol";

contract MarketTest is Test, IMarketplace {
    TransparentUpgradeableProxy public market;
    Marketplace public marketplaceImplementation;
    ProxyAdmin public proxyAdmin;
    TransferManager public transferManager;
    WrappedToken public wrappedToken;
    Marketplace public marketplace;

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
        marketplace = Marketplace(address(market));
    }

    function testDeploy() public {
        assertTrue(address(market) != address(0x0));
        assertTrue(address(marketplaceImplementation) != address(0x0));

        assertTrue(marketplace.feeCollector() == feeCollector);
        assertTrue(marketplace.owner() == address(this));
    }

    function testFeeCollector() public {
        marketplace.changeFeeCollector(payable(address(0x2)));
        assertTrue(marketplace.feeCollector() == address(0x2));
        assertTrue(marketplace.owner() == address(this));
        assertTrue(marketplace.feeCollector() != address(0x1));
    }

    function testTransferManager() public {
        marketplace.changeTransferManager(address(transferManager));

        vm.prank(address(0x1337));
        vm.expectRevert("Ownable: caller is not the owner");
        marketplace.changeTransferManager(address(0x1337));

        vm.expectRevert(ZeroAddress.selector);
        marketplace.changeTransferManager(address(0x0));

        
        marketplace.changeTransferManager(address(0x1337));
    }

    function createAsk() internal {
        
    }

    function testCreateAsk() public {
        
    }
}
