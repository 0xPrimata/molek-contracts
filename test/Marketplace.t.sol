// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Marketplace.sol";
import "../src/utils/WrappedToken.sol";
import {TransferManager} from "../src/TransferManager.sol";
import "../src/interfaces/IMarketplace.sol";

contract MockERC721 is ERC721 {
    constructor(
        string memory name,
        string memory token,
        uint256 mintAmount,
        address receiver
    ) ERC721(name, token) {
        for (uint256 i = 0; i < mintAmount; i++) {
            _mint(receiver, i);
        }
    }
}


contract MarketTest is Test, IMarketplace {
    TransparentUpgradeableProxy public market;
    Marketplace public marketplaceImplementation;
    ProxyAdmin public proxyAdmin;
    TransferManager public transferManager;
    WrappedToken public wrappedToken;
    Marketplace public marketplace;
    MockERC721 public blacklisted;
    MockERC721 public notBlacklisted;

    address public feeCollector;

    function setUp() public {
        marketplaceImplementation = new Marketplace();
        proxyAdmin = new ProxyAdmin();
        feeCollector = address(0x1);
        wrappedToken = new WrappedToken();
        blacklisted = new MockERC721("blacklisted", "BL", 3, address(this));
        notBlacklisted = new MockERC721(
            "notBlacklisted",
            "NBL",
            3,
            address(this)
        );

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

    function testBlacklisted() internal {
        vm.expectRevert(NotBlacklisted.selector);
        marketplace.createAsk([IERC721(blacklisted)], [uint256(1)], [uint256(1)]);
        vm.expectRevert(NotBlacklisted.selector);
        marketplace.createAsk([IERC721(blacklisted)], [uint256(1)], [uint256(1)]);

        vm.expectEmit(true, false, false, false);
        emit IMarketplace.Blacklisted(address(blacklisted), true);
        marketplace.blacklist(IERC721(blacklisted), true);

        vm.expectEmit(false, true, false, false);
        emit IMarketplace.AskCreated(address(marketplace), 1, 1);
        marketplace.createAsk([IERC721(blacklisted)], [uint256(1)], [uint256(1)]);

        vm.expectRevert(NotBlacklisted.selector);
        marketplace.createAsk([IERC721(blacklisted)], [uint256(1)], [uint256(1)]);
    }

    function createAsk() internal {}

    function testCreateAsk() public {}
}
